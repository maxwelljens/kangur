class_name Blackboard
extends RefCounted
## Per-NPC decision state for one tick. Holds references (host, shared intel,
## danger map) but no enemy nodes: AI reads only memory + intel. Contract:
## architecture §4 ("AIController owns Blackboard").

## Decision cadence (design §9: 5–10 Hz, staggered per NPC).
const DECISION_HZ_MIN := 5.0
const DECISION_HZ_MAX := 10.0
## After a kill, the winner repositions toward the objective for this long
## instead of sitting on the corpse farming the next duel (design §9.8 push).
const PUSH_AFTER_KILL_S := 6.0
## Hysteresis: the running action gets this bonus so borderline scores do not
## flip-flop (design §9.2 "hysteresis prevents jitter").
const HYSTERESIS_BONUS := 0.12
## A freshly entered action cannot be swapped by a marginal win.
const ACTION_MIN_S := 0.35
## No-progress timer that unlocks Flank/Suppress escalation (design §9.7).
const STALL_S := 6.0
## Personal goal offset radius, px (skill: route jitter / spacing ±40 px).
const GOAL_OFFSET_PX := 40.0
## When the whole squad shares a waypoint (free hunt axis, objective) the goal
## offset above is too small: twelve bodies inside ±40 px bunch (sims: 33 px,
## under the 48 px gate). Converging squads spread this wide instead.
const CONVERGE_OFFSET_PX := 150.0
## Rejection samples when a free-hunt patrol point lands outside the enemy half.
const HUNT_ATTEMPTS := 12
## Linger window at corners/waypoints (design §9.3).
const LINGER_MIN_S := 0.5
const LINGER_MAX_S := 2.0
## Check-six cadence and duration while holding (design §9.3).
const CHECK_SIX_MIN_S := 8.0
const CHECK_SIX_MAX_S := 20.0
const CHECK_SIX_HOLD_MIN_S := 0.6
const CHECK_SIX_HOLD_MAX_S := 1.2
## Route/waypoint replan period, seconds.
const REPATH_S := 0.4
## Pseudo-random overpeek chance per peek, scaled by low caution (§9.3).
const OVERPEEK_CHANCE := 0.18
## Keep goals this far inside the map rect (px).
const MAP_EDGE_PX := 48.0
## A limb bleed is a slower clock than a torso bleed (design §7 rates).
const LIMB_BLEED_WEIGHT := 0.6
## How long "I just got shot" stays fresh enough to duck (design §9.5 cover).
const HIT_MEMORY_S := 1.2
## How far from the cover spot still counts as "in cover" (one body step).
const COVER_STICK_PX := 40.0

# --- identity / ownership ---------------------------------------------------
var host: Node2D = null
var controller: Node = null
var personality: Personality = null
var difficulty: DifficultyDef = null
var memory: MemoryModel = null
## Shared per team (null in isolated fixtures — the brain then has no radio).
var team_intel: TeamIntel = null
var danger_map: DangerMap = null
var squad: Node = null
var world: World = null
## FactionDef.doctrine behavior weights (uniform when no faction data).
var doctrine: Dictionary = {}
var callsign: String = "Operator"

# --- tactical state ---------------------------------------------------------
var team: int = 0
var role: StringName = &"point"
var current_action: StringName = &"advance"
var action_time: float = 0.0
var nav_target: Vector2 = Vector2.ZERO
var has_nav_target: bool = false
## Long-term intent (objective / patrol waypoint), before personal offset.
var goal: Vector2 = Vector2.ZERO
var stall_timer: float = 0.0
## Seconds left on the post-kill push window (Battle attackers).
var push_timer: float = 0.0
## Seconds since this NPC last took damage (>0 = taking hits right now).
var hit_timer: float = 0.0
var linger_timer: float = 0.0
var check_six_timer: float = 0.0
var repath_accum: float = 0.0
var check_six_count: int = 0
var peek_count: int = 0
var flank_count: int = 0
var retreat_count: int = 0
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0

## Sightings fresh enough to count as "has LOS right now".
var visible_contacts: Array[Dictionary] = []
## Set by TakeCover/DefendObject on arrival — the rig/behaviors read it.
var in_cover: bool = false
## Where the current cover was taken. `in_cover` is derived from this each tick,
## so an NPC keeps its covered state across action switches (Peek needs it) and
## loses it exactly when it actually leaves the spot.
var cover_anchor: Vector2 = Vector2.ZERO
## Lean direction of that cover (into the open). Outlives action switches for the
## same reason: Peek reads it but only TakeCover/DefendObjective choose it.
var cover_lean: Vector2 = Vector2.ZERO
## Own-team characters (spacing only — never used to locate enemies).
var teammates: Array[Node2D] = []

## Mode/objective interface filled by Match (via SquadCoordinator). Defaults to
## a free hunt so standalone arenas and sims work with no Match runtime.
var objective_info: Dictionary = {
	&"mode": Enums.Mode.ELIMINATION,
	&"obj_id": &"",
	&"obj_pos": Vector2.ZERO,
	&"obj_order": 0,
	&"attacking": true,
	&"phase": &"hunt",
	&"obj_contested": false,
}

## Intent under construction this tick.
var intent: Intent = null
## Sticky per-action scratch (burst counters, peek phase, cooldowns).
var action_data: Dictionary = {}
## Every candidate's weighted score from the last decision tick (F3 overlay).
var last_scores: Dictionary[StringName, float] = {}

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value

func rng() -> RandomNumberGenerator:
	return _rng

# --- queries ----------------------------------------------------------------

func host_pos() -> Vector2:
	return host.global_position if host != null else Vector2.ZERO

func trait_of(name: StringName) -> float:
	return personality.trait_value(name) if personality != null else 0.5

func best_contact() -> Dictionary:
	return memory.freshest() if memory != null else {}

func has_target() -> bool:
	return not visible_contacts.is_empty()

## Closest currently-sighted enemy.
## Drop a visible contact by entity id (e.g. the enemy died — stop targeting it).
func remove_visible(id: int) -> void:
	for i: int in range(visible_contacts.size() - 1, -1, -1):
		if int(visible_contacts[i][&"id"]) == id:
			visible_contacts.remove_at(i)

func primary_visible() -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for contact: Dictionary in visible_contacts:
		var dist: float = host_pos().distance_squared_to(contact[&"pos"])
		if dist < best_dist:
			best_dist = dist
			best = contact
	return best

func visible_enemy_count() -> int:
	return visible_contacts.size()

## Team radio knowledge: delayed + noisy, and never fire-justifying.
func intel_contact() -> Dictionary:
	return team_intel.best_contact() if team_intel != null else {}

func intel_pos() -> Vector2:
	var contact := intel_contact()
	return contact.get(&"pos", Vector2.ZERO)

func nearest_teammate_dist() -> float:
	var best := INF
	for mate: Node2D in teammates:
		if mate == host or not is_instance_valid(mate):
			continue
		best = minf(best, host_pos().distance_to(mate.global_position))
	return best

func teammate_for_regroup() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for mate: Node2D in teammates:
		if mate == host or not is_instance_valid(mate):
			continue
		var dist := host_pos().distance_to(mate.global_position)
		if dist < best_dist:
			best_dist = dist
			best = mate
	return best

## Navigation is servable only after the NavigationServer's first map sync;
## queries before that log an engine error. World owns the region, we only ask.
func nav_ready() -> bool:
	if world == null or world.nav == null or not world.nav.is_ready():
		return false
	if not world.nav.is_inside_tree():
		return false
	var map_rid := world.nav.get_world_2d().get_navigation_map()
	return NavigationServer2D.map_get_iteration_id(map_rid) > 0

func danger_at(pos: Vector2) -> float:
	return danger_map.danger_at(pos) if danger_map != null else 0.0

func killzone_at(pos: Vector2) -> float:
	return danger_map.killzone_at(pos) if danger_map != null else 0.0

func stalled() -> bool:
	return stall_timer >= STALL_S

func mode() -> int:
	return int(objective_info.get(&"mode", Enums.Mode.ELIMINATION))

func has_objective() -> bool:
	return objective_pos() != Vector2.ZERO

func objective_pos() -> Vector2:
	return objective_info.get(&"obj_pos", Vector2.ZERO)

func objective_distance() -> float:
	var pos := objective_pos()
	return INF if pos == Vector2.ZERO else host_pos().distance_to(pos)

func attacking() -> bool:
	return bool(objective_info.get(&"attacking", true))

func contested() -> bool:
	return bool(objective_info.get(&"obj_contested", false))

func phase() -> StringName:
	return StringName(objective_info.get(&"phase", &""))

## Authoritative capture area when the map has a shaped zone, else a point.
func objective_rect() -> Rect2:
	if world != null:
		var zone := world.objective(StringName(objective_info.get(&"obj_id", &"")))
		if zone != null:
			var rect := zone.capture_rect()
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				return rect
	return Rect2(objective_pos(), Vector2.ZERO)

## Mean of the other team's authored spawn markers: static map knowledge, never
## a live enemy position (the same thing a player reads off the map).
func enemy_spawn_centroid() -> Vector2:
	if world == null:
		return Vector2.ZERO
	return _centroid(world.spawn_points(Enums.other_team(team)))

func own_spawn_centroid() -> Vector2:
	if world == null:
		return Vector2.ZERO
	return _centroid(world.spawn_points(team))

## Where a free hunt converges: the freshest radio contact if the team has one,
## else a patrol point inside the enemy half. Design §9.8 "TDM → hunt via intel
## + patrol hotspots": a patrol that ignores the enemy half never meets anybody.
func hunt_point() -> Vector2:
	var contact := intel_contact()
	if not contact.is_empty():
		return contact[&"pos"]
	var half := enemy_half_bounds()
	if half.size.x <= 0.0 or half.size.y <= 0.0 or world == null:
		return Vector2.ZERO
	for _attempt: int in HUNT_ATTEMPTS:
		var candidate := world.random_patrol_point(_rng, team)
		if half.has_point(candidate):
			return candidate
	return half.get_center()

## The half of the map on the other team's side, split on whichever axis
## separates the two spawn groups. Static map knowledge, never enemy truth.
func enemy_half_bounds() -> Rect2:
	if world == null:
		return Rect2()
	var rect := world.bounds()
	var enemy := enemy_spawn_centroid()
	var own := own_spawn_centroid()
	if rect.size.x <= 0.0 or enemy == Vector2.ZERO or own == Vector2.ZERO:
		return Rect2()
	var mid := (own + enemy) * 0.5
	var out := rect
	if absf(enemy.y - own.y) >= absf(enemy.x - own.x):
		var edge_y := clampf(mid.y, rect.position.y, rect.end.y)
		out.position.y = edge_y if enemy.y > own.y else rect.position.y
		out.end.y = rect.end.y if enemy.y > own.y else edge_y
	else:
		var edge_x := clampf(mid.x, rect.position.x, rect.end.x)
		out.position.x = edge_x if enemy.x > own.x else rect.position.x
		out.end.x = rect.end.x if enemy.x > own.x else edge_x
	return out.abs()

## Direction from us toward the other team's spawns (unit, ZERO when unknown).
## For a defender that is exactly the attacker approach: two teams, so the
## other team *is* the attacking team.
func toward_enemy_spawns() -> Vector2:
	return _toward(enemy_spawn_centroid())

func _toward(target: Vector2) -> Vector2:
	if target == Vector2.ZERO:
		return Vector2.ZERO
	var to := target - host_pos()
	return to.normalized() if to.length() > 1.0 else Vector2.ZERO

func _centroid(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var mean := Vector2.ZERO
	for point: Vector2 in points:
		mean += point
	return mean / float(points.size())

# --- host state (read-only helpers; the Character owns the truth) ------------

func body() -> Node:
	return component(&"body", ^"Body")

func arsenal() -> Node:
	return component(&"arsenal", ^"Arsenal")

## Character exposes components as properties; bare fixtures hang them as the
## same-named child node. Either way the blackboard finds one.
func component(prop: StringName, child: NodePath) -> Node:
	if host == null:
		return null
	var node: Variant = host.get(prop)
	if node is Node:
		return node
	return host.get_node_or_null(child)

func torso_ratio() -> float:
	var body_node := body()
	return float(body_node.call(&"torso_ratio")) if body_node != null else 1.0

func bleeding() -> bool:
	var body_node := body()
	return bool(body_node.call(&"is_bleeding_any")) if body_node != null else false

## 0..1 urgency of the current bleed: full for a torso bleed, scaled for limbs.
## Reading the wound type (not just torso HP) is the difference between a bot
## that bandages a bleeding arm and one that dies of it at full torso.
func bleed_urgency() -> float:
	var body_node := body()
	if body_node == null:
		return 0.0
	var model: Variant = body_node.get(&"model")
	if model == null or not (model is RefCounted):
		return 1.0 if bleeding() else 0.0
	var drain: float = float(model.call(&"bleed_rate_total"))
	if drain <= 0.0:
		return 0.0
	var torso := float(model.call(&"is_bleeding", Enums.Part.TORSO))
	var weight := 1.0 if torso > 0.0 else LIMB_BLEED_WEIGHT
	return clampf(drain / BodyModel.TORSO_BLEED_RATE, 0.0, 1.0) * weight

func bandages() -> int:
	var body_node := body()
	return int(body_node.get(&"bandages_left")) if body_node != null else 0

func mag_ratio() -> float:
	var tools: Node = arsenal()
	if tools == null or not tools.has_method(&"current"):
		return 1.0
	var weapon: Variant = tools.call(&"current")
	if weapon == null:
		var stub: Variant = tools.get(&"ratio")
		return stub if stub is float else 1.0
	var model: WeaponModel = weapon
	if model.def == null or model.def.mag_size <= 0:
		return 1.0
	return float(model.mag) / float(model.def.mag_size)

func is_reloading() -> bool:
	return host.has_method(&"is_reloading") and bool(host.call(&"is_reloading"))

func team_alive() -> int:
	var alive := 0
	for mate: Node2D in teammates:
		if is_instance_valid(mate) and mate.get(&"alive") != false:
			alive += 1
	return alive

func kit_count(kind: StringName) -> int:
	var tools: Node = arsenal()
	if tools == null or not (&"kit_ids" in tools):
		return 0
	var ids: Array[StringName] = tools.get(&"kit_ids")
	var counts: Array[int] = tools.get(&"kit_counts")
	var total := 0
	for i: int in ids.size():
		if i < counts.size() and counts[i] > 0 and _kit_kind(ids[i]) == kind:
			total += counts[i]
	return total

func kit_index(kind: StringName) -> int:
	var tools: Node = arsenal()
	if tools == null or not (&"kit_ids" in tools):
		return -1
	var ids: Array[StringName] = tools.get(&"kit_ids")
	var counts: Array[int] = tools.get(&"kit_counts")
	for i: int in ids.size():
		if i < counts.size() and counts[i] > 0 and _kit_kind(ids[i]) == kind:
			return i
	return -1

func _kit_kind(id: StringName) -> StringName:
	var def: EquipmentDef = Defs.equipment(id)
	if def == null:
		return &""
	match def.kind:
		Enums.EquipKind.FRAG:
			return &"frag"
		Enums.EquipKind.FLASH:
			return &"flash"
		Enums.EquipKind.SMOKE:
			return &"smoke"
	return &""

# --- navigation -------------------------------------------------------------

func set_nav_target(pos: Vector2) -> void:
	# Snap to the navigable mesh: map "bounds" include dead space outside the
	# walls, and a goal out there is a bot walking into a corner forever.
	pos = world.nav.closest_point(pos) if nav_ready() else clamp_to_map(pos)
	if has_nav_target and nav_target.distance_squared_to(pos) < 1.0:
		return
	nav_target = pos
	has_nav_target = true
	path.clear()
	path_index = 0
	repath_accum = REPATH_S

## Personal offsets and random patrols must never leave the playable rectangle
## (or the NPC walks into the void and the camera loses it).
func clamp_to_map(pos: Vector2) -> Vector2:
	if world == null:
		return pos
	var rect := world.bounds()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return pos
	return Vector2(clampf(pos.x, rect.position.x + MAP_EDGE_PX,
		rect.end.x - MAP_EDGE_PX), clampf(pos.y, rect.position.y + MAP_EDGE_PX,
		rect.end.y - MAP_EDGE_PX))

func clear_nav() -> void:
	has_nav_target = false
	path.clear()
	path_index = 0

## Move direction toward the nav target; zero when arrived/unset.
func nav_dir(arrive_px: float = 18.0) -> Vector2:
	if not has_nav_target:
		return Vector2.ZERO
	var to := nav_target - host_pos()
	if to.length() <= arrive_px:
		return Vector2.ZERO
	if path.size() > path_index:
		var waypoint := path[path_index]
		if host_pos().distance_to(waypoint) < arrive_px:
			path_index += 1
			if path_index >= path.size():
				return to.normalized()
			waypoint = path[path_index]
		return (waypoint - host_pos()).normalized()
	return to.normalized()

func arrived(arrive_px: float = 22.0) -> bool:
	return not has_nav_target or nav_target.distance_to(host_pos()) <= arrive_px

func at(pos: Vector2, arrive_px: float = 24.0) -> bool:
	return host_pos().distance_to(pos) <= arrive_px

# --- timers / rolls ---------------------------------------------------------

func tick_timers(dt: float) -> void:
	action_time += dt
	stall_timer += dt
	push_timer = maxf(0.0, push_timer - dt)
	hit_timer = maxf(0.0, hit_timer - dt)
	linger_timer = maxf(0.0, linger_timer - dt)
	check_six_timer = maxf(0.0, check_six_timer - dt)
	repath_accum += dt
	# Cover is a place, not a mood: standing on the cover spot IS being covered,
	# whichever action is running (Peek/Engage both read it).
	in_cover = at_cover()

func note_progress() -> void:
	stall_timer = 0.0

## Taking fire: the one signal that legitimately outranks shooting back.
func note_hit() -> void:
	hit_timer = HIT_MEMORY_S

## Battle attacker just won a duel: go take ground, do not farm the spot.
func note_kill() -> void:
	if mode() == Enums.Mode.BATTLE and has_objective() and attacking():
		push_timer = PUSH_AFTER_KILL_S

func pushing() -> bool:
	return push_timer > 0.0

func roll_linger() -> float:
	var bias := 0.35 + 0.65 * trait_of(&"caution")
	return _rng.randf_range(LINGER_MIN_S, LINGER_MAX_S) * bias

func roll_check_six() -> float:
	return _rng.randf_range(CHECK_SIX_MIN_S, CHECK_SIX_MAX_S)

func roll_check_six_hold() -> float:
	return _rng.randf_range(CHECK_SIX_HOLD_MIN_S, CHECK_SIX_HOLD_MAX_S)

## Personal goal offset so twelve bots never stack on one pixel.
func personal_offset() -> Vector2:
	var spread := GOAL_OFFSET_PX * (0.5 + trait_of(&"independence"))
	return Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * _rng.randf_range(0.0, spread)

## Convergence offset for a point the whole squad shares (hunt axis, objective):
## a ring this wide, so a converging squad arrives spread rather than stacked.
func converge_offset() -> Vector2:
	var spread := CONVERGE_OFFSET_PX * (0.6 + 0.6 * trait_of(&"independence"))
	return Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * _rng.randf_range(
		CONVERGE_OFFSET_PX * 0.35, spread)

## Occasional peek-too-far mistake: low caution leaks overpeeks (design §9.3).
func roll_overpeek() -> bool:
	return _rng.randf() < OVERPEEK_CHANCE * (1.0 - trait_of(&"caution"))

## Covered = still standing on the spot where cover was taken. Derived, not a
## flag the action layer has to remember to re-set on every switch.
func at_cover() -> bool:
	return cover_anchor != Vector2.ZERO and at(cover_anchor, COVER_STICK_PX)

func take_cover_at(pos: Vector2, lean: Vector2 = Vector2.ZERO) -> void:
	cover_anchor = pos
	in_cover = true
	if lean != Vector2.ZERO:
		cover_lean = lean

func leave_cover() -> void:
	cover_anchor = Vector2.ZERO
	in_cover = false
	cover_lean = Vector2.ZERO