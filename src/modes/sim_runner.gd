class_name SimRunner
extends Node
## Headless battle-sim harness (tests/simulation/README.md, architecture §11).
## Owns `--sim=<map>:<mode>:<seed>:<count>`: builds an all-AI Match, runs it to
## termination at a fixed 60 Hz step, asserts the hard invariants, writes
## metrics to reports/sim/ and exits 0 (pass) / 100 (fail).
##
## Determinism: sim_tick(dt = 1/60) is the ONLY clock (no Engine.time_scale, no
## rendering waits). Every combatant is stepped by hand in a fixed order, so the
## same seed replays the same kill timeline regardless of frame pacing.

const MatchScript := preload("res://src/modes/match.gd")
const OUTPUT_DIR := "res://reports/sim"
const DT := 1.0 / 60.0
## Hard cap beyond time_limit + rules grace: anything longer is a stall.
const STALL_MARGIN_S := 60.0
## No-bunching gate: mean nearest-teammate distance while advancing.
const BUNCHING_MIN_PX := 48.0
const BUNCHING_SAMPLE_S := 0.5
const HISTOGRAM_SAMPLE_S := 0.5
const ADVANCING_MOVE := 0.2
## Full-match roster (README: "full Match headless with 24 AI"). `--bots=N`
## overrides it for fast local runs; the per-commit gate uses this default.
const DEFAULT_BOTS_PER_TEAM := 12
## cover% is "engaged time spent near/behind cover", README soft metric ≥ 30%.
const ENGAGED_MEMORY_S := 4.0

var request: SimRequest = null
var _results: Array[Dictionary] = []
var _bots_per_team := DEFAULT_BOTS_PER_TEAM
var _running := false


func _ready() -> void:
	# Dev parses the CLI in its own _ready (autoloads boot before the main
	# scene). Connect first: Dev quits with SIM_FAIL unless a handler exists.
	if not Dev.sim_requested.is_connected(_on_request):
		Dev.sim_requested.connect(_on_request)
	if Dev.sim_request != null:
		_on_request(Dev.sim_request)
	elif not Dev.harness_active:
		queue_free()


func _on_request(req: SimRequest) -> void:
	if _running or req == null:
		return
	_running = true
	_start(req)


func _start(req: SimRequest) -> void:
	request = req
	# README CLI: <map>:<mode>:<seed>:<count> — count is the number of seeded
	# matches, not the roster. `--bots=N` shrinks the roster for quick runs.
	# A count of 0 is a malformed request, not "run nothing and pass".
	var seeds := req.bot_count
	if seeds <= 0:
		print("SIM_FAIL bad --sim spec: count must be >= 1 (got %d)" % seeds)
		get_tree().quit(1)
		return
	_bots_per_team = _bot_override()
	print("SIM_START map=%s mode=%s seed=%d seeds=%d bots/team=%d" % [
		req.map_id, Enums.Mode.keys()[req.mode], req.seed, seeds, _bots_per_team])
	_results.clear()
	for i: int in seeds:
		await _run_one(req.seed + i)
	_write_aggregate(req)
	_report_and_quit()


# --- one match --------------------------------------------------------------

func _run_one(seed_value: int) -> void:
	var config := MatchConfig.new()
	config.mode = request.mode
	config.map_id = request.map_id
	config.player_team = Enums.Team.BASTION
	config.bot_count_bastion = _bots_per_team
	config.bot_count_sirocco = _bots_per_team
	config.difficulty_id = StringName(Settings.get_value(&"gameplay", &"difficulty", &"operator"))
	# 0 lets Match pick the mode default (8 min Elimination / 15 min Battle).
	# MatchConfig's own default is the Elimination value, which would silently
	# shorten a Battle sim by seven minutes.
	config.time_limit_s = request.time_limit_s  # 0 lets Match pick the mode default
	config.seed = seed_value
	var run := MatchScript.new() as Match
	if run == null:
		# A compile error in match.gd lands here, and without this guard the
		# harness used to carry on and report PASS over zero matches.
		push_error("SimRunner: cannot instantiate match.gd")
		print("SIM_FAIL match.gd failed to instantiate")
		get_tree().quit(100)
		return
	add_child(run)
	await run.start(config, true)
	if not run.running:
		print("SIM_FAIL match did not start (map '%s', mode '%s')" % [
			config.map_id, Enums.Mode.keys()[config.mode]])
		get_tree().quit(100)
		return
	var metrics := _Metrics.new(seed_value)
	metrics.attach(run)
	var limit: float = run.rules.time_limit_s
	var max_ticks := int((limit + MatchRules.GRACE_S + STALL_MARGIN_S) * 60.0)
	var ticks := 0
	while not run.rules_runner.is_finished() and ticks < max_ticks:
		await get_tree().process_frame
		run.sim_tick(DT)
		metrics.sample(run, DT)
		ticks += 1
	var stalled := not run.rules_runner.is_finished()
	if stalled:
		run.force_finish(-1, &"stalled")
	metrics.finish(run, stalled)
	_results.append(metrics.report)
	_write_json(_seed_path(seed_value), metrics.report)
	run.queue_free()
	await get_tree().process_frame
	if is_inside_tree() and _results.size() % 1 == 0:
		print("SIM seed=%d winner=%d reason=%s kills=%d violations=%d t=%.0fs" % [
			seed_value, int(metrics.report["winner"]), String(metrics.report["reason"]),
			int(metrics.report["kills"].size()),
			int(metrics.report["fairness_violations"].size()),
			float(metrics.report["duration_s"])])


# --- output -----------------------------------------------------------------

## `--bots=N` after `--`; absent = full roster.
func _bot_override() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bots="):
			return clampi(int(arg.trim_prefix("--bots=")), 1, 24)
	return DEFAULT_BOTS_PER_TEAM


func _mode_name() -> String:
	return Enums.Mode.keys()[request.mode].to_lower()


func _seed_path(seed_value: int) -> String:
	return "%s/%s_%s_%d.json" % [OUTPUT_DIR, request.map_id, _mode_name(), seed_value]


func _write_aggregate(req: SimRequest) -> void:
	var wins: Array[int] = [0, 0]
	var draws := 0
	for report: Dictionary in _results:
		var winner := int(report["winner"])
		if winner == Enums.Team.BASTION or winner == Enums.Team.SIROCCO:
			wins[winner] += 1
		else:
			draws += 1
	var aggregate := {
		"map": String(req.map_id), "mode": Enums.Mode.keys()[req.mode],
		"seeds": _results.size(), "seed_start": req.seed,
		"bot_count": _bots_per_team,
		"faction_winrate": {
			"bastion": float(wins[0]) / float(maxi(_results.size(), 1)),
			"sirocco": float(wins[1]) / float(maxi(_results.size(), 1)),
			"draws": draws,
		},
		"reports": _results.map(func(r: Dictionary) -> Dictionary:
			return {"seed": r["seed"], "winner": r["winner"], "reason": r["reason"],
				"duration_s": r["duration_s"],
				"fairness_violations": (r["fairness_violations"] as Array).size(),
				"bunching_mean_px": r["bunching_mean_px"],
				"cover_pct_engaged_time": r["cover_pct_engaged_time"]}),
	}
	_write_json("%s/aggregate_%s_%s.json" % [OUTPUT_DIR, req.map_id, _mode_name()], aggregate)


func _write_json(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SimRunner: cannot write %s" % path)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _report_and_quit() -> void:
	# A harness that ran nothing proves nothing: refuse to report PASS.
	if _results.is_empty():
		print("SIM_FAIL no matches ran")
		get_tree().quit(100)
		return
	var failed := false
	var totals := {"kills": 0, "violations": 0, "bunch_sum": 0.0, "bunch_n": 0,
		"cover_sum": 0.0, "bandages": 0, "flank": 0, "check_six": 0, "killzone": 0}
	var ttk: Array[float] = []
	for report: Dictionary in _results:
		totals["kills"] += int((report["kills"] as Array).size())
		totals["violations"] += int((report["fairness_violations"] as Array).size())
		totals["bandages"] += int(report["bandages_used"])
		totals["flank"] += int(report["flank_count"])
		totals["check_six"] += int(report["check_six_count"])
		totals["killzone"] += int(report["killzone_reactions"])
		totals["cover_sum"] += float(report["cover_pct_engaged_time"])
		if float(report["bunching_mean_px"]) > 0.0:
			totals["bunch_sum"] += float(report["bunching_mean_px"])
			totals["bunch_n"] += 1
		ttk.append(float(report["weapon_ttk_median_s"]))
		failed = failed or not _passes(report)
	var wins: Array[int] = [0, 0]
	for report: Dictionary in _results:
		var winner := int(report["winner"])
		if winner == Enums.Team.BASTION or winner == Enums.Team.SIROCCO:
			wins[winner] += 1
	var seeds := maxi(_results.size(), 1)
	print("SIM_RESULT seeds=%d kills=%d fairness_violations=%d" % [
		_results.size(), totals["kills"], totals["violations"]])
	if totals["bunch_n"] > 0:
		print("SIM_RESULT bunching_mean_px=%.1f gate=>%.0f" % [
			float(totals["bunch_sum"]) / float(totals["bunch_n"]), BUNCHING_MIN_PX])
	print("SIM_RESULT cover_pct_engaged=%.1f bandages=%d flank=%d check_six=%d killzones=%d" % [
		100.0 * float(totals["cover_sum"]) / float(seeds), totals["bandages"],
		totals["flank"], totals["check_six"], totals["killzone"]])
	print("SIM_RESULT weapon_ttk_median_s=%.2f winrate bastion=%.0f%% sirocco=%.0f%% draws=%d" % [
		_median(ttk), 100.0 * float(wins[0]) / float(seeds),
		100.0 * float(wins[1]) / float(seeds), seeds - wins[0] - wins[1]])
	for report: Dictionary in _results:
		if not _passes(report):
			print("SIM_FAIL seed=%d stalled=%s kills=%d violations=%d bunching=%.1f" % [
				int(report["seed"]), str(report["stalled"]),
				int((report["kills"] as Array).size()),
				int((report["fairness_violations"] as Array).size()),
				float(report["bunching_mean_px"])])
			for line: Variant in report["fairness_violations"]:
				print("  violation: %s" % line)
	print("SIM %s" % ("PASS" if not failed else "FAIL"))
	get_tree().quit(0 if not failed else 100)


## Hard invariants (README "Quick gate"): termination, fairness, no bunching,
## and a match that actually produced kills (a zero-kill sim proves nothing).
func _passes(report: Dictionary) -> bool:
	if bool(report["stalled"]):
		return false
	if not (report["fairness_violations"] as Array).is_empty():
		return false
	# Zero kills is not a contract breach (tiny rosters can time out), but the
	# harness prints it: a gate run with no engagement proves nothing.
	if (report["kills"] as Array).is_empty():
		print("SIM_WARN seed=%d no kills — roster too small or AI stalled" % int(report["seed"]))
	var bunching := float(report["bunching_mean_px"])
	return bunching <= 0.0 or bunching >= BUNCHING_MIN_PX


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	return sorted[mid] if sorted.size() % 2 == 1 \
		else (sorted[mid - 1] + sorted[mid]) * 0.5


# --- per-match metrics ------------------------------------------------------

class _Metrics:
	var report: Dictionary = {}
	var _time := 0.0
	var _match: Match = null
	var _sample_accum := 0.0
	var _hist_accum := 0.0
	var _bunch_sum := 0.0
	var _bunch_n := 0
	var _engaged := 0
	var _covered := 0
	var _histogram: Dictionary = {}
	var _kills: Array[Dictionary] = []
	## [attacker_id, victim_id] -> {first: float, weapon: StringName}
	var _first_hit: Dictionary = {}
	## weapon -> Array[float] duel times
	var _ttk: Dictionary = {}
	var _bandages := 0
	var _killzones := 0
	## team -> highest live killzone count seen (zones expire, counts must not).
	var _live_killzones: Dictionary = {}

	func _init(seed_value: int) -> void:
		report = {
			"seed": seed_value, "map": "", "mode": "", "duration_s": 0.0,
			"winner": -1, "reason": "", "kills": [], "fairness_violations": [],
			"bunching_mean_px": 0.0, "cover_pct_engaged_time": 0.0,
			"flank_count": 0, "check_six_count": 0, "killzone_reactions": 0,
			"bandages_used": 0, "retreats": 0, "regroups": 0,
			"weapon_ttk": {}, "weapon_ttk_median_s": 0.0,
			"objective_timeline": [], "tickets_remaining": 0,
			"ai_action_histogram": {}, "stalled": false, "ticks": 0,
		}

	func attach(run: Match) -> void:
		_match = run
		report["map"] = String(run.config.map_id)
		report["mode"] = Enums.Mode.keys()[run.mode]
		AIController.fairness_violations.clear()
		EventBus.character_hit.connect(_on_hit)
		EventBus.character_died.connect(_on_death)
		EventBus.bandage_started.connect(_on_bandage)
		EventBus.objective_captured.connect(_on_capture)

	func _exit(run: Match) -> void:
		if EventBus.character_hit.is_connected(_on_hit):
			EventBus.character_hit.disconnect(_on_hit)
		if EventBus.character_died.is_connected(_on_death):
			EventBus.character_died.disconnect(_on_death)
		if EventBus.bandage_started.is_connected(_on_bandage):
			EventBus.bandage_started.disconnect(_on_bandage)
		if EventBus.objective_captured.is_connected(_on_capture):
			EventBus.objective_captured.disconnect(_on_capture)

	func _on_hit(victim: Node, attacker: Node, _part: int, _damage: float,
			_fatal: bool, _pos: Vector2) -> void:
		if not (victim is Character) or not (attacker is Character) \
				or attacker == victim:
			return
		# String key: Array keys rely on deep-hash equality, which is easy to
		# get wrong (and silently empty) when the arrays are rebuilt per event.
		var key := _duel_key(attacker.get_instance_id(), victim.get_instance_id())
		if _first_hit.has(key):
			return
		var killer := attacker as Character
		_first_hit[key] = {"t": _time, "weapon": killer.weapon_id()}

	func _on_death(victim: Node, attacker: Node, weapon_id: StringName,
			_pos: Vector2, distance: float) -> void:
		var killer := attacker as Character
		var dead := victim as Character
		var entry := {
			"t": _time,
			"killer": killer.callsign if killer != null else "environment",
			"victim": dead.callsign if dead != null else "unknown",
			"killer_team": killer.team if killer != null else -1,
			"weapon": String(weapon_id), "distance": distance,
		}
		# Duel TTK: first damaging hit by this killer on this victim → death.
		if killer != null and dead != null:
			var key := _duel_key(killer.get_instance_id(), dead.get_instance_id())
			var hit: Dictionary = _first_hit.get(key, {})
			# One duel = one life: the record is consumed here so a respawned
			# victim starts a fresh engagement instead of reporting a minutes-long
			# "time to kill" that spans several lives.
			if not hit.is_empty():
				_first_hit.erase(key)
				var duel := _time - float(hit["t"])
				entry["ttk_s"] = duel
				var weapon := String(weapon_id) if weapon_id != &"" \
					else String(hit["weapon"])
				if not _ttk.has(weapon):
					_ttk[weapon] = []
				(_ttk[weapon] as Array).append(duel)
		_kills.append(entry)

	static func _duel_key(attacker_id: int, victim_id: int) -> String:
		return "%d:%d" % [attacker_id, victim_id]

	func _on_bandage(_who: Node) -> void:
		_bandages += 1

	func _on_capture(obj_id: StringName, team: int) -> void:
		(report["objective_timeline"] as Array).append(
			{"t": _time, "obj": String(obj_id), "team": team})

	func sample(run: Match, dt: float) -> void:
		_time += dt
		_sample_accum += dt
		_hist_accum += dt
		if _hist_accum >= SimRunner.HISTOGRAM_SAMPLE_S:
			_hist_accum = 0.0
			_actions(run)
		if _sample_accum >= SimRunner.BUNCHING_SAMPLE_S:
			_sample_accum = 0.0
			_spacing(run)

	func _actions(run: Match) -> void:
		for character: Character in run.characters:
			if not character.alive or character.controller == null:
				continue
			var state: Dictionary = character.controller.call(&"debug_state")
			if state.is_empty():
				continue
			var action := String(state.get(&"action", "?"))
			_histogram[action] = int(_histogram.get(action, 0)) + 1
			var bb: Blackboard = character.controller.get(&"bb")
			if bb == null:
				continue
			var engaged := not bb.visible_contacts.is_empty() \
				or bb.memory.freshest_age() <= SimRunner.ENGAGED_MEMORY_S
			if not engaged:
				continue
			_engaged += 1
			# Cover usage: the action layer says the NPC is fighting from cover.
			if action in ["take_cover", "peek", "hold_angle", "defend_objective"]:
				_covered += 1
		_killzones = _count_killzones(run)

	## Distinct killzones triggered this match. Sampled as a running maximum per
	## team: a zone expires after KILLZONE_COOLDOWN_S, so counting only at the end
	## of the match would report 0 for every zone that actually fired.
	func _count_killzones(run: Match) -> int:
		var total := 0
		for team: int in [Enums.Team.BASTION, Enums.Team.SIROCCO]:
			var squad: SquadCoordinator = run.squads.get(team)
			if squad == null or squad.danger == null:
				continue
			var live := squad.danger.killzones().size()
			var key := "killzones_%d" % team
			_live_killzones[key] = maxi(int(_live_killzones.get(key, 0)), live)
		for key: String in _live_killzones:
			total += int(_live_killzones[key])
		return total

	func _spacing(run: Match) -> void:
		for team: int in [Enums.Team.BASTION, Enums.Team.SIROCCO]:
			var movers: Array[Character] = []
			for character: Character in run.characters:
				if character.alive and character.team == team \
						and character.intent.move.length() >= SimRunner.ADVANCING_MOVE:
					movers.append(character)
			if movers.size() < 2:
				continue
			for a: Character in movers:
				var best := INF
				for b: Character in movers:
					if a != b:
						best = minf(best, a.global_position.distance_to(b.global_position))
				if best < INF:
					_bunch_sum += best
					_bunch_n += 1

	func finish(run: Match, stalled: bool) -> void:
		var violations: Array[String] = AIController.fairness_violations.duplicate()
		var provenance := run.vision.shot_provenance
		if provenance != null:
			for entry: Dictionary in provenance.provenance_log:
				if not _provenance_ok(entry):
					violations.append("tick=%.2f killer=%d target=%d los=%s age=%.2f supp=%s wall=%s" % [
						_time, int(entry[&"shooter_id"]), int(entry[&"target_id"]),
						str(entry[&"had_los_at_fire"]), float(entry[&"prior_sighting_age"]),
						str(entry[&"suppressing"]), str(entry[&"wall_penetrated"])])
		var result := run.result
		report["duration_s"] = _time
		report["winner"] = result.winner if result != null else -1
		report["reason"] = String(result.reason) if result != null else ""
		report["kills"] = _kills
		report["fairness_violations"] = violations
		report["bunching_mean_px"] = _bunch_sum / float(_bunch_n) if _bunch_n > 0 else 0.0
		report["cover_pct_engaged_time"] = float(_covered) / float(_engaged) \
			if _engaged > 0 else 0.0
		report["bandages_used"] = _bandages
		report["ai_action_histogram"] = _histogram.duplicate()
		report["weapon_ttk"] = _ttk_summary()
		report["weapon_ttk_median_s"] = _overall_ttk_median()
		report["tickets_remaining"] = (run.rules as BattleRules).tickets_left() \
			if run.rules is BattleRules else 0
		report["flank_count"] = int(_histogram.get("flank", 0))
		report["check_six_count"] = _sum_counter(run, &"check_six_count")
		report["retreats"] = int(_histogram.get("retreat", 0))
		report["regroups"] = int(_histogram.get("regroup", 0))
		report["killzone_reactions"] = _killzones
		report["stalled"] = stalled
		report["ticks"] = int(round(_time * 60.0))
		_exit(run)

	## README fairness rule: LOS at fire, or a personal sighting recent enough,
	## or suppression on a personally seen contact; never through a solid wall.
	func _provenance_ok(entry: Dictionary) -> bool:
		if bool(entry[&"wall_penetrated"]) and not bool(entry[&"pen_surface_penetrable"]):
			return false
		if bool(entry[&"had_los_at_fire"]):
			return true
		return float(entry[&"prior_sighting_age"]) >= 0.0 and bool(entry[&"suppressing"])

	func _ttk_summary() -> Dictionary:
		var out: Dictionary = {}
		for weapon: String in _ttk:
			var times: Array[float] = []
			times.assign(_ttk[weapon])
			out[weapon] = {"kills": times.size(), "median_s": SimRunner._median(times)}
		return out

	## Sum an AI-owned counter across the roster. The action histogram only
	## samples the CURRENT action, so a 1 s CheckSix between 0.5 s samples reads
	## as zero; the blackboard counter is the honest number.
	func _sum_counter(run: Match, field: StringName) -> int:
		var total := 0
		for character: Character in run.characters:
			var bb: Blackboard = character.controller.get(&"bb") \
				if character.controller != null else null
			if bb != null:
				total += int(bb.get(field))
		return total

	func _overall_ttk_median() -> float:
		var all: Array[float] = []
		for weapon: String in _ttk:
			var times: Array[float] = []
			times.assign(_ttk[weapon])
			all.append_array(times)
		return SimRunner._median(all)