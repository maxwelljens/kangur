extends Node2D
## ProjectileSystem — the match's single bullet sweep. One `intersect_ray` per
## active bullet per physics tick over the segment travelled that tick, so an
## 8000 px/s round cannot tunnel a 2 px wall (docs/research/godot-tech.md §4.1).
## Contract: docs/architecture.md §2 (BULLET_MASK), §5 (bullet_impact),
## §10 (one system, pooled visuals); numbers: docs/design/game-design.md §6.
## Pure maths stays in Ballistics; this node owns nodes, rays and events.

## Shooters hand their projectiles over through `take_pending_shots()`; the
## system runs after Character._physics_process so the tick's shots are in.
const PHYSICS_PRIORITY := 10
## Hard pool cap: 24v24 automatic fire at 60 Hz stays far below this.
const MAX_BULLETS := 256
const MAX_RANGE := 6000.0
const MAX_LIFE := 2.0
## Bullets may pass at most this many surfaces (wood → glass → thin concrete).
const MAX_PENETRATIONS := 2
## Start the next ray just past the face so the surface is not hit twice. Rays
## that start inside a body do not report it (hit_from_inside = false), which is
## also how a bullet exits a thick tile without re-colliding.
const PEN_EPSILON := 0.5
## Surface pass rules (design §6): wood/glass ×0.55/×0.8, thin concrete ×0.35
## and sniper-only. 0 = the surface stops the round.
const GLASS_PEN_MULT := 0.8
const GLASS_MIN_PEN := 0.1
const WOOD_PEN_MULT := 0.55
const WOOD_MIN_PEN := 0.4
const CONCRETE_PEN_MULT := 0.35
const CONCRETE_MIN_PEN := 2.0
## Deflection after a pass, degrees (design §6: up to 4°).
const MAX_DEFLECT_DEG := 4.0
## Tracer: this tick's travelled segment, fading out over 60 ms.
const TRACER_TIME := 0.06
const TRACER_WIDTH := 1.8
## Fallback tracer colour/the falloff defaults of a ShotRequest with no weapon.
const DEFAULT_TRACER_COLOR := Color(0.95, 0.65, 0.25, 1.0)

class Bullet extends RefCounted:
	var pos: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 0.0
	var damage: float = 0.0
	var penetration: float = 1.0
	var falloff_start: float = 500.0
	var falloff_end: float = 1400.0
	var min_mult: float = 0.6
	var weapon_id: StringName = &""
	var owner: Node = null
	var armor_piercing: bool = false
	var tracer_color: Color = DEFAULT_TRACER_COLOR
	var travelled: float = 0.0
	var life: float = 0.0
	var passes: int = 0
	var exclude: Array[RID] = []

## Injected world queries as callables so tests/tools stub them without a
## TileMap (same pattern as Character.surface_provider). `world` is duck-typed:
## combat never types against src/world.
var world: Node = null
var surface_provider: Callable = Callable()
var penetrable_provider: Callable = Callable()
var glass_breaker: Callable = Callable()

var _characters: Array[Character] = []
var _bullets: Array[Bullet] = []
var _tracers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _def_cache: Dictionary[StringName, WeaponDef] = {}

func _ready() -> void:
	# After Character (priority 0) so pending_shots for this tick is complete.
	process_physics_priority = PHYSICS_PRIORITY

## Match injects the world and the combatant list; tests inject a seed.
func setup(world_node: Node, characters: Array[Character] = [],
		seed_value: int = 0) -> void:
	world = world_node
	if world_node != null:
		surface_provider = Callable(world_node, &"surface_at")
		penetrable_provider = Callable(world_node, &"is_penetrable")
		glass_breaker = Callable(world_node, &"glass_shatter")
	_characters = characters
	if seed_value != 0:
		_rng.seed = seed_value

func add_character(character: Character) -> void:
	if character != null and not _characters.has(character):
		_characters.append(character)

func _physics_process(dt: float) -> void:
	_consume_shots()
	var space := get_world_2d().direct_space_state
	var i := _bullets.size() - 1
	while i >= 0:
		if _sweep(_bullets[i], space, dt):
			_bullets.remove_at(i)
		i -= 1
	_tick_tracers(dt)
	queue_redraw()

## Every combatant hands over this tick's projectiles exactly once.
func _consume_shots() -> void:
	for character: Character in _characters:
		if character == null or not is_instance_valid(character):
			continue
		for shot: ShotRequest in character.take_pending_shots():
			fire(character, shot)

## Public for tests and tools. Returns the spawned bullet, or null when the
## pool is full (dropped shot: the cap must never reorder existing bullets).
func fire(shooter: Node, shot: ShotRequest) -> Bullet:
	if _bullets.size() >= MAX_BULLETS:
		return null
	var def := _weapon_def(shot.weapon_id)
	var bullet := Bullet.new()
	bullet.pos = shot.origin
	bullet.dir = shot.dir.normalized() if shot.dir != Vector2.ZERO else Vector2.RIGHT
	bullet.speed = shot.speed
	bullet.damage = shot.damage
	bullet.penetration = shot.penetration
	bullet.falloff_start = shot.falloff_start
	bullet.falloff_end = shot.falloff_end
	bullet.min_mult = shot.min_mult
	bullet.weapon_id = shot.weapon_id
	bullet.owner = shooter
	bullet.armor_piercing = def.armor_piercing if def != null else false
	bullet.tracer_color = def.tracer_color if def != null else DEFAULT_TRACER_COLOR
	if shooter is CollisionObject2D:
		bullet.exclude = [(shooter as CollisionObject2D).get_rid()]
	_bullets.append(bullet)
	return bullet

## Read-only inspection for tests/debug overlays.
func bullets_debug() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for bullet: Bullet in _bullets:
		out.append({
			&"pos": bullet.pos, &"dir": bullet.dir, &"speed": bullet.speed,
			&"damage": bullet.damage, &"travelled": bullet.travelled,
			&"passes": bullet.passes,
		})
	return out

func active_count() -> int:
	return _bullets.size()

func clear() -> void:
	_bullets.clear()
	_tracers.clear()

## One bullet, one tick. Returns true when it is finished (hit, range, life).
## A penetrable surface keeps the remaining distance alive inside the loop, so
## a fast round cannot skip a thin wall between two ticks.
func _sweep(bullet: Bullet, space: PhysicsDirectSpaceState2D, dt: float) -> bool:
	bullet.life += dt
	if bullet.life > MAX_LIFE:
		return true
	var origin := bullet.pos
	var finished := _sweep_segments(bullet, space, bullet.speed * dt)
	_tracer(origin, bullet.pos, bullet.tracer_color)
	return finished

## Segment loop inside one tick; returns true when the round is spent.
func _sweep_segments(bullet: Bullet, space: PhysicsDirectSpaceState2D,
		distance: float) -> bool:
	var remaining := distance
	var guard := MAX_PENETRATIONS + 1
	while remaining > 0.0 and guard > 0:
		guard -= 1
		var from := bullet.pos
		var to := from + bullet.dir * remaining
		var query := PhysicsRayQueryParameters2D.create(from, to, Layers.BULLET_MASK)
		query.collide_with_areas = false
		query.exclude = bullet.exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			bullet.pos = to
			bullet.travelled += remaining
			return bullet.travelled >= MAX_RANGE
		bullet.pos = hit["position"]
		var step := from.distance_to(bullet.pos)
		bullet.travelled += step
		remaining -= step
		var collider: Object = hit["collider"]
		if collider is Character:
			_hit_character(bullet, collider as Character, bullet.pos)
			return true
		var surface := _surface_at(bullet.pos)
		if surface == Enums.Surface.GLASS:
			_break_glass(bullet.pos)
		var mult := 0.0
		if bullet.passes < MAX_PENETRATIONS:
			mult = surface_pen_mult(surface, bullet.penetration, _is_penetrable(bullet.pos))
		var normal: Vector2 = hit["normal"]
		if mult <= 0.0:
			_impact(bullet.pos, normal, surface, false)
			return true
		# Through: lose damage, deflect up to 4°, continue from past the face.
		bullet.damage = Ballistics.pen_damage(bullet.damage, mult)
		bullet.passes += 1
		bullet.dir = bullet.dir.rotated(deg_to_rad(_rng.randf_range(
			-MAX_DEFLECT_DEG, MAX_DEFLECT_DEG)))
		_impact(bullet.pos, normal, surface, true)
		bullet.pos += bullet.dir * PEN_EPSILON
	return false

## Damage multiplier for one surface pass; 0 = stop. Static + pure so the
## penetration table is testable without physics.
static func surface_pen_mult(surface: int, penetration: float, penetrable: bool) -> float:
	match surface:
		Enums.Surface.GLASS:
			return GLASS_PEN_MULT if penetration >= GLASS_MIN_PEN else 0.0
		Enums.Surface.WOOD:
			if penetrable and penetration >= WOOD_MIN_PEN:
				return WOOD_PEN_MULT
		Enums.Surface.CONCRETE:
			if penetrable and penetration >= CONCRETE_MIN_PEN:
				return CONCRETE_PEN_MULT
	return 0.0

func _hit_character(bullet: Bullet, target: Character, pos: Vector2) -> void:
	var damage := Ballistics.falloff(
		bullet.damage, bullet.travelled,
		bullet.falloff_start, bullet.falloff_end, bullet.min_mult)
	var part := target.part_at_world_pos(pos)
	# AP rounds (Lynx .338) bypass vest/helmet absorption via BodyModel.
	target.apply_hit(part, damage, 1.0, bullet.owner, bullet.armor_piercing)

func _impact(pos: Vector2, normal: Vector2, surface: int, penetrated: bool) -> void:
	EventBus.bullet_impact.emit(pos, normal, surface, penetrated)

func _tracer(from: Vector2, to: Vector2, color: Color) -> void:
	if from.distance_squared_to(to) < 0.01:
		return
	_tracers.append({
		&"from": from, &"to": to, &"t": TRACER_TIME, &"color": color,
	})
	while _tracers.size() > MAX_BULLETS:
		_tracers.pop_front()

func _tick_tracers(dt: float) -> void:
	for tracer: Dictionary in _tracers:
		tracer[&"t"] = float(tracer[&"t"]) - dt
	_tracers = _tracers.filter(
		func(t: Dictionary) -> bool: return float(t[&"t"]) > 0.0)

func _surface_at(pos: Vector2) -> int:
	if surface_provider.is_valid():
		return int(surface_provider.call(pos))
	return Enums.Surface.CONCRETE

func _is_penetrable(pos: Vector2) -> bool:
	return penetrable_provider.is_valid() and bool(penetrable_provider.call(pos))

func _break_glass(pos: Vector2) -> void:
	if glass_breaker.is_valid():
		glass_breaker.call(pos)

## Weapon def for tracer colour + the AP flag. Resolved once per id; unknown
## ids (fixtures) cache as null instead of Defs' push_error noise.
func _weapon_def(id: StringName) -> WeaponDef:
	if id == &"":
		return null
	if not _def_cache.has(id):
		_def_cache[id] = _find_weapon(id)
	return _def_cache[id]

func _find_weapon(id: StringName) -> WeaponDef:
	for def: WeaponDef in Defs.all_weapons():
		if def.id == id:
			return def
	return null

## Tracer tail: the segment travelled this tick, fading out over 60 ms.
func _draw() -> void:
	for tracer: Dictionary in _tracers:
		var fade := clampf(float(tracer[&"t"]) / TRACER_TIME, 0.0, 1.0)
		var color: Color = tracer[&"color"]
		draw_line(tracer[&"from"], tracer[&"to"], Color(color, fade),
			TRACER_WIDTH, true)