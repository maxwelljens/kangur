class_name Perception
extends Node
## Perception — cone + LOS truth for one character. Self-contained raycasts, no
## src/ai dependency yet: it emits `enemy_spotted` / `heard` and lets the AI
## wave build memory on top. Contract: architecture §2 (VISION_MASK rules),
## design §5 (stance-dependent low cover). Fairness: this is the ONLY way an
## NPC may learn about an enemy position.

## Local sighting (spotter's own cone, immediate). Team radio stays in TeamIntel.
signal enemy_spotted(spotter: Node, enemy: Node, pos: Vector2)
## Occluded hearing. loudness is the post-wall value in px.
signal heard(pos: Vector2, loudness: float, kind: StringName, surface: int)

## Cone geometry (design §5): 100° stand/crouch, 80° sprinting, 70° focused.
const CONE_STAND_DEG := 100.0
const CONE_SPRINT_DEG := 80.0
const CONE_FOCUS_DEG := 70.0
const RANGE_STAND := 520.0
const RANGE_CROUCH := 420.0
const RANGE_FOCUS_BONUS := 1.15
## Sighting scans per second (raycast budget for 24 NPCs headless).
const SCAN_HZ := 12.0
## Re-emit `enemy_spotted` for a still-visible enemy this often (HUD refresh).
const SPOT_REFRESH_S := 0.5
## Each wall multiplies heard loudness by this (design §12 muffling).
const WALL_LOUDNESS_FACTOR := 0.6
## Guard against endless rays through stacked glass/cover.
const MAX_LOS_PASSES := 6
const WALL_RAY_PASSES := 4
## Distances below this count as "on top of the observer" (always visible).
const MIN_DISTANCE := 4.0
## Character group both teams share; filtered by `team` per node.
const CHARACTER_GROUP := &"characters"

var cone_angle_deg: float = CONE_STAND_DEG
var cone_range: float = RANGE_STAND
## Cached per-tick input state (set in tick, reused by can_see()).
var stance: Enums.Stance = Enums.Stance.STAND
var focused: bool = false
var sprinting: bool = false

var _host: CharacterBody2D = null
var _scan_accum: float = 0.0
var _last_spot: Dictionary[int, float] = {}
## Simulation clock: advanced from tick(dt), never wall clock, so headless sims
## (fixed dt) and the fixed-fps fast-forward see the same sighting cadence.
var _clock: float = 0.0

func setup(host: CharacterBody2D) -> void:
	_host = host
	if not EventBus.sound_emitted.is_connected(_on_sound_emitted):
		EventBus.sound_emitted.connect(_on_sound_emitted)
	_update_cone()

func _exit_tree() -> void:
	if EventBus.sound_emitted.is_connected(_on_sound_emitted):
		EventBus.sound_emitted.disconnect(_on_sound_emitted)

func tick(dt: float, current_stance: Enums.Stance, is_focused: bool,
		is_sprinting: bool) -> void:
	stance = current_stance
	focused = is_focused
	sprinting = is_sprinting
	_clock += dt
	_update_cone()
	_scan_accum += dt
	if _scan_accum < 1.0 / SCAN_HZ:
		return
	_scan_accum = 0.0
	_scan()

## The fairness test: cone + occluded LOS, stance-aware for low cover.
func can_see(target_pos: Vector2, target_stance: Enums.Stance) -> bool:
	if _host == null or not _host.is_inside_tree():
		return false
	if not in_cone(target_pos):
		return false
	return has_los(target_pos, target_stance)

## Pure cone test, no physics — unit-testable outside a physics frame.
func in_cone(target_pos: Vector2) -> bool:
	if _host == null:
		return false
	var to_target := target_pos - _host.global_position
	if to_target.length() > cone_range:
		return false
	if to_target.length() < MIN_DISTANCE:
		return true
	return absf(rad_to_deg(aim_dir().angle_to(to_target))) <= cone_angle_deg * 0.5

## Stance-aware LOS through glass and low cover (design §5, architecture §2).
## Glass never blocks sight; low cover blocks when either endpoint is crouched.
func has_los(target_pos: Vector2, target_stance: Enums.Stance) -> bool:
	if _host == null or not _host.is_inside_tree():
		return false
	var space := _host.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		_host.global_position, target_pos, Layers.VISION_MASK)
	query.collide_with_areas = false
	var observer_crouched := stance == Enums.Stance.CROUCH
	var excluded: Array[RID] = [_host.get_rid()]
	for _pass: int in MAX_LOS_PASSES:
		query.exclude = excluded
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider: Object = hit.get(&"collider")
		if collider == null or not (collider is CollisionObject2D):
			return false
		var layer := (collider as CollisionObject2D).collision_layer
		var passes := false
		if (layer & Layers.GLASS_BIT) != 0:
			passes = true
		elif (layer & Layers.LOW_COVER_BIT) != 0:
			passes = not observer_crouched and target_stance != Enums.Stance.CROUCH
		if not passes:
			return false
		excluded.append((collider as CollisionObject2D).get_rid())
	return false

static func cone_angle_for(_current_stance: Enums.Stance, is_focused: bool,
		is_sprinting: bool) -> float:
	if is_focused:
		return CONE_FOCUS_DEG
	if is_sprinting:
		return CONE_SPRINT_DEG
	return CONE_STAND_DEG

static func range_for(current_stance: Enums.Stance, is_focused: bool) -> float:
	var base := RANGE_CROUCH if current_stance == Enums.Stance.CROUCH else RANGE_STAND
	return base * (RANGE_FOCUS_BONUS if is_focused else 1.0)

func aim_dir() -> Vector2:
	# `_host` may be any CharacterBody2D in tests/fixtures; fall back so a
	# missing property can never crash the cone maths.
	var dir: Variant = _host.get(&"aim_dir") if _host != null else null
	return dir if dir is Vector2 else Vector2.RIGHT

func _update_cone() -> void:
	cone_angle_deg = cone_angle_for(stance, focused, sprinting)
	cone_range = range_for(stance, focused)

func _scan() -> void:
	if _host == null or not _host.is_inside_tree():
		return
	var now := _clock
	for node: Node in _host.get_tree().get_nodes_in_group(CHARACTER_GROUP):
		if node == _host or not (node is Node2D):
			continue
		if int(node.get(&"team")) == int(_host.get(&"team")):
			continue
		if not bool(node.get(&"alive")):
			continue
		var enemy := node as Node2D
		var target_stance: Enums.Stance = int(enemy.get(&"stance"))
		if not can_see(enemy.global_position, target_stance):
			_last_spot.erase(enemy.get_instance_id())
			continue
		var id := enemy.get_instance_id()
		var last: float = _last_spot.get(id, -SPOT_REFRESH_S)
		if now - last < SPOT_REFRESH_S:
			continue
		_last_spot[id] = now
		enemy_spotted.emit(_host, enemy, enemy.global_position)

## Hearing hook: occluded loudness only, never a free position.
func _on_sound_emitted(pos: Vector2, loudness: float, kind: StringName,
		source: Node, surface: int) -> void:
	if _host == null or source == _host or not _host.is_inside_tree():
		return
	var distance := _host.global_position.distance_to(pos)
	if distance > loudness:
		return
	var effective := loudness * pow(WALL_LOUDNESS_FACTOR, float(_count_walls(pos)))
	if distance > effective:
		return
	heard.emit(pos, effective, kind, surface)

func _count_walls(pos: Vector2) -> int:
	var space := _host.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		_host.global_position, pos, Layers.SOUND_MASK)
	query.collide_with_areas = false
	var excluded: Array[RID] = [_host.get_rid()]
	var walls := 0
	for _pass: int in WALL_RAY_PASSES:
		query.exclude = excluded
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			break
		var collider: Object = hit.get(&"collider")
		if collider == null or not (collider is CollisionObject2D):
			break
		walls += 1
		excluded.append((collider as CollisionObject2D).get_rid())
	return walls