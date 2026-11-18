class_name AIController
extends Node
## One NPC's brain: Node shell around pure models. Perception → MemoryModel →
## Blackboard → UtilityAI → behavior → Intent. Decision tick 5–10 Hz (staggered
## per NPC); Intent every physics tick so aim tracks continuously through the
## shared Aim pipeline. Contract: architecture §4 ("AI runtime"), design §9.
##
## FAIRNESS (sacred): this file never reads an enemy node position. Enemy truth
## arrives only as (1) our own Perception sighting (copied position + id),
## (2) occluded hearing, (3) TeamIntel radio contacts (delayed + noisy). Every
## trigger pull passes `_justified_fire`, which requires a first-hand sighting
## recent enough (LOS at fire) or an active Suppress on a contact the NPC saw.

const AdvanceScript := preload("res://src/ai/behaviors/advance.gd")
const EngageScript := preload("res://src/ai/behaviors/engage.gd")
const SuppressScript := preload("res://src/ai/behaviors/suppress.gd")
const TakeCoverScript := preload("res://src/ai/behaviors/take_cover.gd")
const PeekScript := preload("res://src/ai/behaviors/peek.gd")
const FlankScript := preload("res://src/ai/behaviors/flank.gd")
const HoldAngleScript := preload("res://src/ai/behaviors/hold_angle.gd")
const CheckSixScript := preload("res://src/ai/behaviors/check_six.gd")
const InvestigateScript := preload("res://src/ai/behaviors/investigate.gd")
const RetreatScript := preload("res://src/ai/behaviors/retreat.gd")
const RegroupScript := preload("res://src/ai/behaviors/regroup.gd")
const BandageScript := preload("res://src/ai/behaviors/bandage.gd")
const ReloadScript := preload("res://src/ai/behaviors/reload.gd")
const AvoidDangerScript := preload("res://src/ai/behaviors/avoid_danger.gd")
const UseEquipmentScript := preload("res://src/ai/behaviors/use_equipment.gd")
const CaptureScript := preload("res://src/ai/behaviors/capture_objective.gd")
const DefendScript := preload("res://src/ai/behaviors/defend_objective.gd")

## A sighting this recent counts as "LOS at fire". Perception re-spots a
## still-visible enemy every 0.5 s, so one missed refresh (0.5–1.0 s) means the
## contact may be stale: 0.9 s tolerates exactly one bad frame, no more.
const FIRE_FRESH_S := 0.9
## Suppressive fire window on a personally-seen contact (design §9.7).
const SUPPRESS_WINDOW_S := 4.0
## Aim at a remembered contact this long after the sighting (los vanish).
const AIM_MEMORY_S := 3.0
## Radio throttle (docs/design/radio-lines.md: ≤1 line / 1.5 s per NPC).
const RADIO_MIN_INTERVAL := 1.5
const RADIO_URGENT_INTERVAL := 0.5
const RADIO_QUEUE_MAX := 6
## Separation steering: keeps NPCs out of conga lines.
const SPACING_PX := 64.0
const SPACING_WEIGHT := 1.6
## Suppression: a near impact while we have a live contact sharpens the penalty.
const SUPPRESS_RADIUS_PX := 90.0
const SUPPRESS_HOLD_S := 1.4
const SUPPRESS_CONTACT_AGE_S := 3.0
## Friendly-fire guard: never shoot a teammate inside this cone/range.
const FF_ANGLE_DEG := 12.0
const FF_RANGE_PX := 220.0
## Low-HP radio line threshold (torso ratio).
const LOW_HP_CALL_RATIO := 0.35
## Grid reference resolution (docs/design/radio-lines.md: 8×8, A–H × 1–8).
const GRID_COLS := 8
const GRID_ROWS := 8

## Debug-only ledger: sim tests read it; normal play never appends.
static var fairness_violations: Array[String] = []

## Scripted-driver surface (tests, arena harness). Touching a setter switches
## the brain off so a scripted pose is never fought by utility decisions.
var move_target: Vector2 = Vector2.ZERO
var aim_target: Vector2 = Vector2.ZERO
var want_fire: bool = false
var want_focus: bool = false
var want_sprint: bool = false
var want_reload: bool = false
var want_bandage: bool = false
var stance: Enums.Stance = Enums.Stance.STAND

var bb: Blackboard = null
var squad: Node = null
var manual_driver: bool = false

var _host: Node2D = null
var _fire_was_held: bool = false
var _behaviors: Dictionary[StringName, RefCounted] = {}
var _rng := RandomNumberGenerator.new()
var _decision_period: float = 0.15
var _decision_accum: float = 0.0
var _aim_key: int = 0
var _engaged: bool = false
var _radio_queue: Array[Dictionary] = []
var _radio_cd: float = 0.0
var _denials: int = 0
var _denials_by_action: Dictionary[StringName, int] = {}
var _low_hp_called: bool = false
var _suppress_left: float = 0.0
var _suppress_deg: float = 0.0
var _suppress_applied: bool = false
var _aim_floor_base: float = 0.0
var _aim_initial_base: float = 0.0
var _last_hostile_shooter: Node = null
var _world: World = null

func setup(host: Node2D) -> void:
	_host = host
	if host == null:
		return
	# A bare Node2D host (entity unit fixtures, scripted probes) has no
	# Perception/Body to feed a brain: stay an idle intent writer so scripted
	# drivers keep the stub's contract.
	if host.get(&"perception") == null:
		manual_driver = true
		return
	_rng.seed = _derive_seed()
	_decision_period = 1.0 / _rng.randf_range(Blackboard.DECISION_HZ_MIN,
		Blackboard.DECISION_HZ_MAX)
	_decision_accum = _rng.randf() * _decision_period
	_behaviors = {
		&"advance": AdvanceScript.new(), &"engage": EngageScript.new(),
		&"suppress": SuppressScript.new(), &"take_cover": TakeCoverScript.new(),
		&"peek": PeekScript.new(), &"flank": FlankScript.new(),
		&"hold_angle": HoldAngleScript.new(), &"check_six": CheckSixScript.new(),
		&"investigate": InvestigateScript.new(), &"retreat": RetreatScript.new(),
		&"regroup": RegroupScript.new(), &"bandage": BandageScript.new(),
		&"reload": ReloadScript.new(), &"avoid_danger": AvoidDangerScript.new(),
		&"use_equipment": UseEquipmentScript.new(),
		&"capture_objective": CaptureScript.new(),
		&"defend_objective": DefendScript.new(),
	}
	_world = _find_world()
	_build_blackboard()
	_connect_signals()

## Every match fresh (AGENTS §7): callsign × team × match seed.
func _derive_seed() -> int:
	var seed_value := hash(str(_host.get(&"callsign"))) ^ (_team_of(_host) << 20)
	var game := get_node_or_null(^"/root/Game")
	if game != null:
		var match_seed: Variant = game.get(&"match_seed")
		seed_value ^= match_seed if match_seed is int else 0
	return seed_value

func _build_blackboard() -> void:
	bb = Blackboard.new(_rng.randi())
	bb.host = _host
	bb.controller = self
	bb.team = _team_of(_host)
	bb.intent = Intent.new()
	bb.memory = MemoryModel.new(_rng.randi())
	bb.difficulty = _resolve_difficulty()
	bb.personality = Personality.roll(_rng, bb.difficulty)
	bb.world = _world
	bb.doctrine = _resolve_doctrine()
	bb.callsign = _name_of(_host)
	bb.goal = _host.global_position
	bb.nav_target = bb.goal
	bb.check_six_timer = bb.roll_check_six()
	squad = SquadCoordinator.for_team(get_tree(), bb.team)
	if squad != null:
		squad.call(&"register", self)
		bb.squad = squad
		bb.team_intel = squad.get(&"intel")
		bb.danger_map = squad.get(&"danger")
		bb.objective_info = squad.get(&"objective_info")
		bb.role = squad.call(&"role_for", self)
	_aim_floor_base = _aim_float(&"error_floor_deg")
	_aim_initial_base = _aim_float(&"error_initial_deg")

## Character does not expose its DifficultyDef; read the private field read-only.
func _resolve_difficulty() -> DifficultyDef:
	var diff: Variant = _host.get(&"_difficulty")
	return diff if diff is DifficultyDef else null

## Faction doctrine weights behaviors by id (design §9.2). Missing data →
## uniform weights, never a failure.
func _resolve_doctrine() -> Dictionary:
	var faction := Defs.faction(StringName(Enums.team_name(bb.team).to_lower()))
	return faction.doctrine if faction != null else {}

## Idempotent: a host may be re-setup (test fixtures, respawns), and a double
## connection would double-count every sighting and shot.
func _connect_signals() -> void:
	var perception: Node = _host.get(&"perception")
	if perception != null and perception.has_signal(&"enemy_spotted"):
		if not perception.is_connected(&"enemy_spotted", _on_enemy_spotted):
			perception.connect(&"enemy_spotted", _on_enemy_spotted)
		if not perception.is_connected(&"heard", _on_heard):
			perception.connect(&"heard", _on_heard)
	for pair: Array in [
		[EventBus.bullet_impact, _on_bullet_impact],
		[EventBus.shot_fired, _on_shot_fired],
		[EventBus.character_died, _on_character_died],
		[EventBus.character_hit, _on_character_hit],
	]:
		var sig: Signal = pair[0]
		if not sig.is_connected(pair[1]):
			sig.connect(pair[1])

func _exit_tree() -> void:
	var perception: Node = _host.get(&"perception") if _host != null else null
	if perception != null and perception.has_signal(&"enemy_spotted"):
		if perception.is_connected(&"enemy_spotted", _on_enemy_spotted):
			perception.disconnect(&"enemy_spotted", _on_enemy_spotted)
		if perception.is_connected(&"heard", _on_heard):
			perception.disconnect(&"heard", _on_heard)
	if EventBus.bullet_impact.is_connected(_on_bullet_impact):
		EventBus.bullet_impact.disconnect(_on_bullet_impact)
	if EventBus.shot_fired.is_connected(_on_shot_fired):
		EventBus.shot_fired.disconnect(_on_shot_fired)
	if EventBus.character_died.is_connected(_on_character_died):
		EventBus.character_died.disconnect(_on_character_died)
	if EventBus.character_hit.is_connected(_on_character_hit):
		EventBus.character_hit.disconnect(_on_character_hit)
	if squad != null and is_instance_valid(squad):
		squad.call(&"unregister", self)

# --- perception ingress (the ONLY enemy truth) ------------------------------

## Perception's sighting: copy id + position, drop the node. Reading `team` off
## the payload is identity, never a live position.
func _on_enemy_spotted(spotter: Node, enemy: Node, pos: Vector2) -> void:
	if bb == null or spotter != _host or enemy == null:
		return
	var id := enemy.get_instance_id()
	var fresh := bb.memory.last_seen(id).is_empty()
	bb.memory.see(pos, id, _team_of(enemy))
	_refresh_visible()
	# Radio the first sighting of a new contact (the queue rate-limits us).
	if fresh:
		say(&"contact" if bb.visible_contacts.size() < 2 else &"contact_multiple", 1)

func _on_heard(pos: Vector2, loudness: float, kind: StringName, _surface: int) -> void:
	if bb != null:
		bb.memory.hear(pos, loudness, kind)

## A near impact is physically perceptible. The Bulwark shooter's perk only
## amplifies an existing (already sighted) contact — never creates knowledge.
func _on_bullet_impact(pos: Vector2, _normal: Vector2, _surface: int, _pen: bool) -> void:
	if bb == null or _host == null or _suppress_left > 0.0:
		return
	if pos.distance_to(_host.global_position) > SUPPRESS_RADIUS_PX:
		return
	var contact: Dictionary = bb.memory.freshest()
	if contact.is_empty() or bb.memory.freshest_age() > SUPPRESS_CONTACT_AGE_S:
		return
	_suppress_deg = _shooter_suppression()
	if _suppress_deg > 0.0:
		_suppress_left = SUPPRESS_HOLD_S

func _on_shot_fired(shooter: Node, _weapon: StringName, _origin: Vector2,
		_dir: Vector2, _pellets: int) -> void:
	if shooter == null or shooter == _host or bb == null:
		return
	if _team_of(shooter) != bb.team:
		_last_hostile_shooter = shooter

## Bulwark: the hostile shooter's fire costs us aim. 0 for every other perk.
func _shooter_suppression() -> float:
	if _last_hostile_shooter == null or not is_instance_valid(_last_hostile_shooter):
		return 0.0
	if _last_hostile_shooter.has_method(&"suppression_error_deg"):
		return float(_last_hostile_shooter.call(&"suppression_error_deg"))
	return 0.0

## Kill calls: only the killer reports, and only for a kill (never assists).
func _on_character_died(victim: Node, attacker: Node, _weapon: StringName,
		_pos: Vector2, _distance: float) -> void:
	if bb == null or victim == _host:
		return
	# Invalidate dead enemies immediately so we never target corpses: the aim
	# fallback (memory.freshest) and Suppress would otherwise keep firing at them.
	if int(victim.get(&"team")) != int(_host.get(&"team")):
		var vid := victim.get_instance_id()
		bb.memory.forget(vid)
		bb.remove_visible(vid)
		if _aim_key == vid:
			_release_aim()
	if attacker != _host:
		return
	bb.note_kill()
	say(&"kill", 1)

## "I'm hit bad" — once per life, at the low-HP threshold.
func _on_character_hit(victim: Node, _attacker: Node, _part: int, _damage: float,
		_fatal: bool, _pos: Vector2) -> void:
	if bb == null or victim != _host:
		return
	bb.note_hit()
	if _low_hp_called:
		return
	if bb.torso_ratio() < LOW_HP_CALL_RATIO:
		_low_hp_called = true
		say(&"low_hp", 2)

# --- Intent production ------------------------------------------------------

func fill_intent(intent: Intent, dt: float) -> void:
	intent.clear_edges()
	if _host == null:
		return
	if manual_driver:
		_fill_manual(intent)
		return
	# Held fields are rewritten by behaviors; defaults must not latch from the
	# previous tick (a stale `fire` would look like a blind trigger pull).
	intent.move = Vector2.ZERO
	intent.fire = false
	intent.focus = false
	intent.sprint = false
	intent.bandage = false
	intent.stance = Enums.Stance.STAND
	if bb == null or _host.get(&"alive") == false:
		intent.move = Vector2.ZERO
		intent.aim = _host_aim()
		return
	bb.intent = intent
	bb.tick_timers(dt)
	bb.memory.tick(dt)
	_refresh_visible()
	_follow_path()
	# A bandage channel is asserted for its whole duration, not just while the
	# Bandage action happens to hold the tick: Character._handle_edges only
	# feeds `intent.bandage` through, and an action switch mid-channel used to
	# drop it (sims: 13 channels started, 5 finished, 8 charges wasted).
	intent.bandage = _body_bandaging()
	_decision_accum += dt
	if _decision_accum >= _decision_period:
		_decision_accum = fmod(_decision_accum, _decision_period)
		_decide()
	_tick_current(dt)
	_apply_aim(intent)
	_apply_fire_gate(intent)
	_apply_spacing(intent)
	_tick_suppression(dt)
	_tick_radio(dt)

## Scripted pose — identical mapping to the entity stub's contract so scripted
## drivers (arena selftest, controller tests) keep working.
func _fill_manual(intent: Intent) -> void:
	intent.move = move_target
	intent.aim = aim_target if aim_target != Vector2.ZERO else _host_aim()
	intent.fire = want_fire
	intent.fire_press = want_fire and not _fire_was_held
	intent.focus = want_focus
	intent.sprint = want_sprint
	intent.stance = stance
	intent.reload = want_reload
	intent.bandage = want_bandage
	_fire_was_held = want_fire

func _decide() -> void:
	_sync_squad_state()
	var best: UtilityAI.Action = UtilityAI.choose(_candidates(), bb)
	if best == null:
		return
	if best.id != bb.current_action:
		var previous: Variant = _behaviors.get(bb.current_action)
		if previous != null:
			previous.exit(bb, self)
		bb.current_action = best.id
		bb.action_time = 0.0
		bb.action_data.clear()
		var next: Variant = _behaviors.get(best.id)
		if next != null:
			next.enter(bb, self)
	_audit_fairness()

func _candidates() -> Array:
	var out: Array = []
	for id: StringName in _behaviors:
		var behavior: RefCounted = _behaviors[id]
		out.append(UtilityAI.Action.new(id, behavior.score(bb)))
	return out

func _tick_current(dt: float) -> void:
	var behavior: Variant = _behaviors.get(bb.current_action)
	if behavior != null:
		behavior.tick(bb, self, dt)

## Continuous aim through the shared Aim pipeline. `acquire` fires only when the
## aim target *changes* — calling it per tick would restart the reaction clock
## forever (no snap-aim, no frozen aim).
func _apply_aim(intent: Intent) -> void:
	var point := Vector2.ZERO
	var key := 0
	# Prefer the enemy Engage is actually shooting at (closest sighted), then the
	# freshest memory so a lost target stays covered for a beat.
	var target := bb.primary_visible()
	if target.is_empty() and bb.memory.freshest_age() <= AIM_MEMORY_S:
		target = bb.memory.freshest()
	if not target.is_empty():
		point = target[&"pos"]
		key = int(target[&"id"])
	elif bb.action_data.has(&"aim_pos"):
		point = bb.action_data[&"aim_pos"]
		key = -hash(point.round())
	elif bb.action_data.has(&"face"):
		point = bb.host_pos() + Vector2(bb.action_data[&"face"]) * 200.0
		key = -hash(Vector2(bb.action_data[&"face"]).round())
	# Track the LIVE sensor position of a visible target each tick. Sighting events
	# refresh slowly (SPOT_REFRESH_S); aiming at that stale pos let strafing enemies
	# outrun the aim. live_pos is sensor-gated (fair) and returns INF when not visible.
	if key > 0:
		var perc: Node = _host.get(&"perception")
		if perc != null and perc.has_method(&"live_pos"):
			var live: Vector2 = perc.call(&"live_pos", key)
			if live != Vector2.INF:
				point = live
	if point == Vector2.ZERO:
		intent.aim = _host_aim()
		if _engaged:
			_release_aim()
		return
	intent.aim = (point - bb.host_pos()).normalized()
	# Acquire once per *target*, never per position refresh: `acquire` restarts
	# the reaction clock and re-rolls the aim error sign, so calling it while
	# tracking would make a moving enemy look like a new one (jitter + handicap).
	if key != _aim_key:
		if key > 0:
			_acquire(intent.aim)
		elif _engaged:
			_release_aim()
			_acquire(intent.aim)
		_aim_key = key

func _acquire(dir: Vector2) -> void:
	var aim: Node = _host.get(&"aim")
	if aim != null and aim.has_method(&"acquire"):
		aim.call(&"acquire", dir)
	_engaged = true

func _release_aim() -> void:
	var aim: Node = _host.get(&"aim")
	if aim != null and aim.has_method(&"release"):
		aim.call(&"release")
	_engaged = false
	_aim_key = 0

## THE fairness seam for shots. Provenance is bound to the entity being fired
## at: a fresh sighting of somebody *else* does not license this shot.
##   1. Aiming at an enemy id  → that enemy must be freshly sighted (LOS now),
##      or actively suppressed inside SUPPRESS_WINDOW_S of a personal sighting.
##   2. Aiming at a remembered point → Suppress only, on a personal sighting.
func _justified_fire() -> bool:
	var id := _aim_key
	var contact: Dictionary = bb.memory.last_seen(id) if id > 0 \
		else bb.memory.freshest()
	if contact.is_empty():
		return false
	var age: float = bb.memory.contact_age(int(contact[&"id"]))
	if age < 0.0:
		return false
	if id > 0 and age <= FIRE_FRESH_S:
		return true
	return bb.current_action == &"suppress" and age <= SUPPRESS_WINDOW_S

func _apply_fire_gate(intent: Intent) -> void:
	var wanted := intent.fire
	if wanted and not _justified_fire():
		wanted = false
		_denials += 1
		_denials_by_action[bb.current_action] = \
			int(_denials_by_action.get(bb.current_action, 0)) + 1
		if OS.is_debug_build() and _denials <= 3:
			push_warning("AI %s: blind fire attempt blocked" % bb.callsign)
	if wanted and _friendly_blocking(intent.aim):
		wanted = false
	intent.fire = wanted
	intent.fire_press = wanted and not _fire_was_held
	_fire_was_held = wanted

## Never shoot through a teammate (own team only: their positions are legal).
func _friendly_blocking(aim: Vector2) -> bool:
	if aim.length() < 0.001:
		return false
	var origin := _host.global_position
	for mate: Node2D in bb.teammates:
		if mate == _host or not is_instance_valid(mate) or mate.get(&"alive") == false:
			continue
		var to := mate.global_position - origin
		var dist := to.length()
		if dist > FF_RANGE_PX or dist < 1.0:
			continue
		if absf(rad_to_deg(aim.angle_to(to))) < FF_ANGLE_DEG:
			return true
	return false

## Separation steering: no conga lines (sim asserts mean spacing > 48 px).
func _apply_spacing(intent: Intent) -> void:
	if intent.move.length() < 0.01:
		return
	var push := Vector2.ZERO
	for mate: Node2D in bb.teammates:
		if mate == _host or not is_instance_valid(mate):
			continue
		var away := _host.global_position - mate.global_position
		var dist := away.length()
		if dist > 0.001 and dist < SPACING_PX:
			push += away / dist * (1.0 - dist / SPACING_PX)
	intent.move = (intent.move.normalized() + push * SPACING_WEIGHT).limit_length(1.0)

func _tick_suppression(dt: float) -> void:
	_suppress_left = maxf(0.0, _suppress_left - dt)
	var aim: Node = _host.get(&"aim")
	if aim == null:
		return
	if _suppress_left > 0.0 and not _suppress_applied:
		aim.set(&"error_floor_deg", _aim_floor_base + _suppress_deg)
		aim.set(&"error_initial_deg", _aim_initial_base + _suppress_deg)
		_suppress_applied = true
	elif _suppress_left <= 0.0 and _suppress_applied:
		aim.set(&"error_floor_deg", _aim_floor_base)
		aim.set(&"error_initial_deg", _aim_initial_base)
		_suppress_applied = false

# --- state refresh ----------------------------------------------------------

func _sync_squad_state() -> void:
	if squad == null or not is_instance_valid(squad):
		return
	bb.teammates = squad.call(&"teammates_of", self)
	bb.role = squad.call(&"role_for", self)

## "Visible" = a personal sighting young enough to still count as LOS at fire.
## Derived from memory, so there is no second source of truth to drift.
func _refresh_visible() -> void:
	var out: Array[Dictionary] = []
	for contact: Dictionary in bb.memory.contacts.values():
		if bb.memory.contact_age(int(contact[&"id"])) <= FIRE_FRESH_S:
			out.append(contact)
	bb.visible_contacts = out

## Re-plan the nav path periodically; path following lives in Blackboard.
func _follow_path() -> void:
	if bb == null or not bb.has_nav_target or _world == null:
		return
	if not bb.nav_ready():
		return
	bb.repath_accum = minf(bb.repath_accum, Blackboard.REPATH_S)
	if bb.repath_accum < Blackboard.REPATH_S:
		return
	bb.repath_accum = 0.0
	bb.path = _world.find_path(_host.global_position, bb.nav_target)
	bb.path_index = 0

## Debug guard (sim builds): every contact acted on must trace to perception.
func _audit_fairness() -> void:
	if not OS.is_debug_build():
		return
	for contact: Dictionary in bb.visible_contacts:
		if bb.memory.contact_age(int(contact[&"id"])) < 0.0:
			fairness_violations.append("%s: visible contact without memory" % bb.callsign)

# --- radio ------------------------------------------------------------------

func say(event: StringName, priority: int = 1) -> void:
	if bb == null:
		return
	while _radio_queue.size() >= RADIO_QUEUE_MAX:
		_radio_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a[&"priority"]) < int(b[&"priority"]))
		_radio_queue.pop_front()
	_radio_queue.append({&"event": event, &"priority": priority})

func _tick_radio(dt: float) -> void:
	_radio_cd = maxf(0.0, _radio_cd - dt)
	if _radio_cd > 0.0 or _radio_queue.is_empty():
		return
	_radio_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a[&"priority"]) > int(b[&"priority"]))
	var entry: Dictionary = _radio_queue.pop_front()
	var priority := int(entry[&"priority"])
	_emit_radio(StringName(entry[&"event"]), priority)
	_radio_cd = RADIO_URGENT_INTERVAL if priority >= 2 else RADIO_MIN_INTERVAL

func _emit_radio(event: StringName, priority: int) -> void:
	var faction := Defs.faction(StringName(Enums.team_name(bb.team).to_lower()))
	if faction == null or faction.radio_set == &"":
		return
	var radio := Defs.radio(faction.radio_set)
	if radio == null:
		return
	var lines: Array = radio.lines.get(event, [])
	if lines.is_empty():
		return
	var text := _substitute(String(lines[_rng.randi_range(0, lines.size() - 1)]))
	EventBus.radio_message.emit(bb.team, bb.callsign, text, priority)

func _substitute(text: String) -> String:
	var out := text.replace("{callsign}", bb.callsign)
	out = out.replace("{grid}", _grid_ref(_host.global_position))
	out = out.replace("{weapon}", _weapon_name())
	out = out.replace("{count}", str(maxi(bb.visible_contacts.size(), 1)))
	out = out.replace("{obj}", _obj_letter())
	return out

func _weapon_name() -> String:
	var id := StringName(_host.call(&"weapon_id")) if _host.has_method(&"weapon_id") else &""
	var def: WeaponDef = Defs.weapon(id) if id != &"" else null
	return def.display_name if def != null else "rifle"

func _obj_letter() -> String:
	var id := StringName(bb.objective_info.get(&"obj_id", &""))
	return String(id).to_upper() if id != &"" else "the site"

## 8×8 map grid, A–H × 1–8 (docs/design/radio-lines.md). No world = "grid".
func _grid_ref(pos: Vector2) -> String:
	if _world == null:
		return "grid"
	var rect := _world.bounds()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return "grid"
	var col := clampi(int(floor(pos.x / (rect.size.x / GRID_COLS))), 0, GRID_COLS - 1)
	var row := clampi(int(floor(pos.y / (rect.size.y / GRID_ROWS))), 0, GRID_ROWS - 1)
	return "%s-%d" % [String.chr(65 + col), row + 1]

# --- scripted-driver surface (unchanged contract) ---------------------------

func set_aim_target(dir: Vector2) -> void:
	manual_driver = true
	aim_target = dir
	if _host != null and _host.get(&"aim") != null:
		_host.get(&"aim").call(&"acquire", dir)

func set_move_target(dir: Vector2) -> void:
	manual_driver = true
	move_target = dir

func set_sprint(on: bool) -> void:
	manual_driver = true
	want_sprint = on

func set_stance(new_stance: Enums.Stance) -> void:
	manual_driver = true
	stance = new_stance

func set_fire(on: bool) -> void:
	manual_driver = true
	want_fire = on

func set_focus(on: bool) -> void:
	manual_driver = true
	want_focus = on

func release_aim() -> void:
	aim_target = Vector2.ZERO
	_release_aim()

## Match runtime hook: mode/objective state. Keys: mode, obj_id, obj_pos,
## obj_order, attacking, phase, obj_contested. Unset = free hunt (TDM).
func set_objective_info(info: Dictionary) -> void:
	if bb != null:
		bb.objective_info.merge(info, true)

func debug_state() -> Dictionary:
	if bb == null:
		return {}
	return {
		&"action": bb.current_action, &"role": bb.role,
		&"personality": bb.personality.label(), &"stall": bb.stall_timer,
		&"visible": bb.visible_contacts.size(), &"contacts": bb.memory.contacts.size(),
		&"denials": _denials, &"denials_by": _denials_by_action.duplicate(),
		&"scores": bb.last_scores.duplicate(),
	}

## Fixture-safe reads: a bare Node2D host (controller unit tests, arena probes)
## has no Character properties, so every read degrades instead of erroring.
func _team_of(node: Object) -> int:
	var value: Variant = node.get(&"team") if node != null else null
	return value if value is int else 0

func _name_of(node: Object) -> String:
	var value: Variant = node.get(&"callsign") if node != null else null
	return value if value is String else "Operator"

func _host_aim() -> Vector2:
	var dir: Variant = _host.get(&"aim_dir") if _host != null else null
	return dir if dir is Vector2 else Vector2.RIGHT

## True while the shared Body is mid-bandage channel (fixtures without a Body
## report false, never crash).
func _body_bandaging() -> bool:
	var body_node: Variant = _host.get(&"body") if _host != null else null
	if body_node == null or not (body_node is Node):
		body_node = _host.get_node_or_null(^"Body") if _host != null else null
	if body_node == null:
		return false
	return (body_node as Node).has_method(&"is_bandaging") \
		and bool((body_node as Node).call(&"is_bandaging"))

func _aim_float(prop: StringName) -> float:
	var aim: Node = _host.get(&"aim") if _host != null else null
	return float(aim.get(prop)) if aim != null else 0.0

func _find_world() -> World:
	if get_tree() == null:
		return null
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if node is World:
			return node
	return null