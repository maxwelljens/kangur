class_name RulesRunner
extends Node
## Bridges the pure rules to the live match: builds a MatchSnapshot from the
## characters + ObjectiveZones every tick, calls MatchRules.tick(), and applies
## the RuleEvents (spawns, objective feeds, tickets, phase, match end).
## Contract: architecture §4/§10 ("RulesRunner wraps MatchRules").

## Pushed to the squads only when the phase/objective actually changes.
const PHASE_HYSTERESIS_S := 0.0

var rules: MatchRules = null
var world: World = null
var spawn_manager: SpawnManager = null
var squads: Dictionary[int, SquadCoordinator] = {}
## Ids of the objective chain in order (Battle; empty for Elimination).
var objective_ids: Array[StringName] = []
## HUD-side rows, refreshed every tick from the active rules.
var objective_rows: Array[Dictionary] = []

## Emitted with every RuleEvent so Match/HUD can react without a second parse.
signal rule_event(event: RuleEvent)
## Emitted once when the rules end the match (winner, reason).
signal match_finished(winner: int, reason: StringName)
## Emitted after a reinforcement wave revived combatants (team, count).
signal wave_respawned(team: int, count: int)

## Last snapshot (sim metrics + debug overlay read it read-only).
var snapshot: MatchSnapshot = MatchSnapshot.new()

var characters: Array[Character] = []
var _time := 0.0
var _prev_alive: Array[int] = [0, 0]
var _finished := false
var _rng := RandomNumberGenerator.new()
var _objective_state: Dictionary[StringName, Dictionary] = {}


func setup(world_node: World, p_rules: MatchRules, p_spawn: SpawnManager,
		p_characters: Array[Character], p_squads: Dictionary[int, SquadCoordinator],
		seed_value: int) -> void:
	world = world_node
	rules = p_rules
	spawn_manager = p_spawn
	characters = p_characters
	squads = p_squads
	_rng.seed = hash([seed_value, &"rules"])
	_time = 0.0
	_finished = false
	_prev_alive = [0, 0]
	_objective_state.clear()
	objective_ids.clear()
	if world != null:
		for zone: ObjectiveZone in world.objectives():
			objective_ids.append(zone.obj_id)
	# Battle needs the chain definition before its first tick.
	if rules is BattleRules and world != null:
		var defs: Array[Dictionary] = []
		for zone: ObjectiveZone in world.objectives():
			defs.append({
				&"id": zone.obj_id, &"order": zone.order,
				&"capture_time": zone.capture_time,
				&"pos": zone.global_position,
			})
		(rules as BattleRules).setup(defs, (rules as BattleRules).tickets)
	_apply_phase(_phase_event())


func is_finished() -> bool:
	return _finished


## One rule tick. `dt` is the simulation step (never wall clock: sims).
func tick(dt: float) -> void:
	if rules == null or _finished:
		return
	_time += dt
	snapshot = _build_snapshot(dt)
	var events := rules.tick(snapshot, dt)
	for event: RuleEvent in events:
		_apply(event)
	_refresh_objective_rows()


func _build_snapshot(dt: float) -> MatchSnapshot:
	var snap := MatchSnapshot.new()
	snap.elapsed = _time
	var alive: Array[int] = [0, 0]
	var hp: Array[float] = [0.0, 0.0]
	for character: Character in characters:
		if character == null or not is_instance_valid(character) or not character.alive:
			continue
		if character.team < 0 or character.team > 1:
			continue
		alive[character.team] += 1
		hp[character.team] += character.body.part_hp(Enums.Part.TORSO)
	snap.alive_per_team.assign(alive)
	snap.total_hp_per_team.assign(hp)
	var deaths: Array[int] = [0, 0]
	for team: int in 2:
		deaths[team] = maxi(_prev_alive[team] - alive[team], 0)
	_prev_alive = alive
	snap.deaths_this_tick.assign(deaths)
	if rules is BattleRules:
		snap.tickets_per_team[rules.attacker_team()] = (rules as BattleRules).tickets_left()
	else:
		snap.tickets_per_team.assign(alive)
	snap.objective_states = _objective_states()
	return snap


## Occupancy → {present, contested, locked, owner, progress}. Progress itself is
## owned by BattleRules; the runner only reports who stands where.
##
## Bodies are counted from living characters inside `capture_rect()`, not from
## ObjectiveZone occupancy: an Area2D keeps a corpse registered until it is
## physically removed, so a dead attacker would keep "capturing" from the grave.
func _objective_states() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if world == null:
		return out
	for zone: ObjectiveZone in world.objectives():
		var rect := zone.capture_rect()
		var present: Array[int] = [0, 0]
		# No usable capture shape = stand-in for "unknown area". Counting every
		# character there would let a malformed zone capture from across the map,
		# so an unshaped zone has no occupants at all.
		var has_area := rect.size.x > 0.0 and rect.size.y > 0.0
		if has_area:
			for character: Character in characters:
				if character == null or not is_instance_valid(character) \
						or not character.alive:
					continue
				if character.team < 0 or character.team > 1:
					continue
				if not rect.has_point(character.global_position):
					continue
				present[character.team] += 1
		var contested := present[0] > 0 and present[1] > 0
		var locked := false
		var owner := -1
		var progress := 0.0
		if rules is BattleRules:
			var battle := rules as BattleRules
			var active := battle.active_objective()
			var id: StringName = active.get(&"id", &"") if not active.is_empty() else &""
			locked = id != zone.obj_id and battle.last_captured_order() >= zone.order
			owner = battle.attacker_team() if locked else -1
			battle.mark_contested(zone.obj_id, contested)
			if id == zone.obj_id:
				progress = _battle_progress(battle, zone.obj_id)
		out.append({
			&"id": zone.obj_id, &"order": zone.order,
			&"capture_time": zone.capture_time, &"pos": zone.global_position,
			&"locked": locked, &"owner": owner, &"progress": progress,
			&"contested": contested, &"present": present,
		})
	return out


func _battle_progress(battle: BattleRules, id: StringName) -> float:
	for row: Dictionary in battle.objective_rows():
		if StringName(row["id"]) == id:
			return float(row.get("progress", 0.0))
	return 0.0


func _apply(event: RuleEvent) -> void:
	rule_event.emit(event)
	match event.type:
		RuleEvent.SPAWN:
			_apply_spawn(event.data)
		RuleEvent.OBJECTIVE_PROGRESS:
			EventBus.objective_progress.emit(
				StringName(event.data[&"id"]), int(event.data[&"team"]),
				float(event.data[&"progress"]), bool(event.data[&"contested"]))
		RuleEvent.OBJECTIVE_CAPTURED:
			var id := StringName(event.data[&"id"])
			var team := int(event.data[&"team"])
			EventBus.objective_captured.emit(id, team)
			_apply_phase(_phase_event())
		RuleEvent.TICKETS:
			EventBus.tickets_changed.emit(int(event.data[&"team"]), int(event.data[&"tickets"]))
		RuleEvent.PHASE:
			_apply_phase(event)
		RuleEvent.MATCH_END:
			_finished = true
			var winner := int(event.data[&"winner"])
			var reason := StringName(event.data[&"reason"])
			EventBus.match_ended.emit(winner, reason)
			match_finished.emit(winner, reason)


func _apply_spawn(data: Dictionary) -> void:
	if spawn_manager == null:
		return
	var team := int(data.get(&"team", -1))
	if team < 0:
		return
	var revived := spawn_manager.refill(team, int(data.get(&"forward_order", 0)))
	if revived > 0:
		wave_respawned.emit(team, revived)


## Feed both coordinators the current phase. The defender's view mirrors the
## objective but with `attacking = false` (DefendObjective, design §9.8).
func _apply_phase(event: RuleEvent) -> void:
	if event.data.is_empty() or squads.is_empty():
		return
	var attacker := rules.attacker_team() if rules != null else -1
	for team: int in squads.keys():
		var squad: SquadCoordinator = squads[team]
		if squad == null or not is_instance_valid(squad):
			continue
		var is_attacker := attacker < 0 or team == attacker
		var phase: StringName = event.data.get(
			&"attacker_phase" if is_attacker else &"defender_phase", &"hunt")
		squad.set_objective_info({
			&"mode": Enums.Mode.BATTLE if rules is BattleRules else Enums.Mode.ELIMINATION,
			&"obj_id": event.data.get(&"obj_id", &""),
			&"obj_pos": event.data.get(&"obj_pos", Vector2.ZERO),
			&"obj_order": int(event.data.get(&"obj_order", 0)),
			&"attacking": is_attacker and rules is BattleRules,
			&"phase": phase,
			&"obj_contested": bool(event.data.get(&"contested", false)),
		})


func _phase_event() -> RuleEvent:
	if rules is BattleRules:
		var battle := rules as BattleRules
		var active := battle.active_objective()
		return RuleEvent.make(RuleEvent.PHASE, {
			&"obj_id": active.get(&"id", &""),
			&"obj_pos": active.get(&"pos", Vector2.ZERO),
			&"obj_order": int(active.get(&"order", 0)),
			&"contested": false,
			&"attacker_phase": &"push",
			&"defender_phase": &"hold",
		})
	return RuleEvent.make(RuleEvent.PHASE, {
		&"obj_id": &"", &"obj_pos": Vector2.ZERO, &"obj_order": 0,
		&"contested": false, &"attacker_phase": &"hunt",
		&"defender_phase": &"hunt",
	})


# --- HUD --------------------------------------------------------------------

func _refresh_objective_rows() -> void:
	objective_rows.clear()
	if rules is BattleRules:
		objective_rows = (rules as BattleRules).objective_rows()
		for row: Dictionary in objective_rows:
			var zone := world.objective(StringName(row["id"])) if world != null else null
			if zone != null:
				row["pos"] = _normalise(zone.global_position)
		return
	# Elimination: one neutral row per authored zone so the chain stays hidden.
	if world == null:
		return
	for zone: ObjectiveZone in world.objectives():
		objective_rows.append({
			"id": zone.obj_id, "letter": String(zone.obj_id).to_upper(),
			"state": "neutral", "team": -1, "progress": 0.0,
			"contested": false, "pos": _normalise(zone.global_position),
		})


## World → 0..1 map-space for minimap blips/objectives (UI contract §11a).
func _normalise(pos: Vector2) -> Vector2:
	if world == null:
		return Vector2(0.5, 0.5)
	var rect := world.bounds()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2(0.5, 0.5)
	return (pos - rect.position) / rect.size


## World → 0..1 helper for the Match minimap feed.
static func normalise(world_node: World, pos: Vector2) -> Vector2:
	var rect := world_node.bounds() if world_node != null else Rect2()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2(0.5, 0.5)
	return (pos - rect.position) / rect.size