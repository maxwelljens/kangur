extends Node
## Shot provenance — the fairness ledger (tests/simulation/README.md).
## Every NPC shot is recorded with the perception facts the sim asserts on:
## had LOS at fire, age of the last confirmed sighting, suppression, and what
## the bullet's line crossed. Cheap append-only array; enabled in debug/sim
## builds only (release strips it, architecture §11).
##
## This node owns no sighting truth of its own: VisionSystem feeds it the
## per-perception `enemy_spotted` bridge and the smoke blocker, and the sim
## reads `provenance_log`.

const MAX_LOG := 20000

## Array[Dictionary] — see `_record` for the exact field set.
var provenance_log: Array[Dictionary] = []
var enabled: bool = OS.is_debug_build()

## Audit reach for the fired ray: long enough to catch a wall in front of the
## muzzle regardless of current cone range (a blind shot still crosses walls).
const AUDIT_REACH := 900.0

var _characters: Array[Character] = []
var _world: World = null
var _blocks: Callable = Callable()
## (shooter_id, target_id) -> last confirmed sighting, seconds.
var _sighting: Dictionary = {}
var _time: float = 0.0


func setup(characters: Array[Character], world: World, blocks_sight: Callable) -> void:
	_characters = characters
	_world = world
	_blocks = blocks_sight
	if not EventBus.shot_fired.is_connected(_on_shot_fired):
		EventBus.shot_fired.connect(_on_shot_fired)
	# Sighting truth comes from Perception itself, never a parallel cone test.
	for c: Character in characters:
		if c == null or c.perception == null:
			continue
		if not c.perception.enemy_spotted.is_connected(_on_enemy_spotted):
			c.perception.enemy_spotted.connect(_on_enemy_spotted)


func _exit_tree() -> void:
	if EventBus.shot_fired.is_connected(_on_shot_fired):
		EventBus.shot_fired.disconnect(_on_shot_fired)
	for c: Character in _characters:
		if c != null and c.perception != null \
				and c.perception.enemy_spotted.is_connected(_on_enemy_spotted):
			c.perception.enemy_spotted.disconnect(_on_enemy_spotted)


func _on_enemy_spotted(spotter: Node, enemy: Node, _pos: Vector2) -> void:
	if spotter == null or enemy == null:
		return
	note_sighting(spotter.get_instance_id(), enemy.get_instance_id())


## Advanced by VisionSystem's physics tick, so sims stay deterministic
## (never wall-clock time — README "determinism rules").
func tick(dt: float) -> void:
	_time += dt


## Perception bridge hook: a shooter confirmed seeing `enemy`.
func note_sighting(shooter_id: int, target_id: int) -> void:
	_sighting[Vector2i(shooter_id, target_id)] = _time


func age_of_sighting(shooter_id: int, target_id: int) -> float:
	var key := Vector2i(shooter_id, target_id)
	if not _sighting.has(key):
		return -1.0
	return _time - float(_sighting[key])


func _on_shot_fired(shooter: Node, weapon_id: StringName, origin: Vector2,
		dir: Vector2, _pellets: int) -> void:
	if not enabled or not (shooter is Character):
		return
	var who := shooter as Character
	# The invariant is about NPC fairness; the player's own shots are not audited.
	if who.is_player or not who.alive or who.perception == null:
		return
	var target := _visible_target(who)
	var had_los := target != null
	var prior := -1.0
	if target != null:
		# Seeing the target at the trigger pull IS the sighting; recording it here
		# keeps later shots' ages honest instead of always reading "never seen".
		note_sighting(who.get_instance_id(), target.get_instance_id())
		prior = age_of_sighting(who.get_instance_id(), target.get_instance_id())
	else:
		target = _last_seen_target(who)
		if target != null:
			prior = age_of_sighting(who.get_instance_id(), target.get_instance_id())
	# Firing at where a target was (or was last confirmed) is suppression, not
	# a blind shot, and must be justified by a prior sighting.
	var suppressing: bool = not had_los and prior >= 0.0
	var wall := _classify_ray(who, origin, dir)
	_record(who, target, weapon_id, had_los, prior, suppressing, bool(wall[0]), bool(wall[1]))


func _record(shooter: Character, target: Character, weapon_id: StringName,
		had_los: bool, prior: float, suppressing: bool, wall: bool, pen: bool) -> void:
	if provenance_log.size() >= MAX_LOG:
		# shortcut: fairness log is capped, upgrade to a streaming sink for
		# full-length 200-seed balance runs.
		return
	provenance_log.append({
		&"shooter_id": shooter.get_instance_id(),
		&"target_id": target.get_instance_id() if target != null else 0,
		&"weapon_id": weapon_id,
		&"had_los_at_fire": had_los,
		&"prior_sighting_age": prior,
		&"suppressing": suppressing,
		&"wall_penetrated": wall,
		&"pen_surface_penetrable": pen,
	})


## Nearest enemy the shooter can actually see right now (perception truth).
func _visible_target(shooter: Character) -> Character:
	var best: Character = null
	var best_distance := INF
	for c: Character in _characters:
		if c == null or not is_instance_valid(c) or c == shooter:
			continue
		if c.team == shooter.team or not c.alive:
			continue
		var distance := shooter.global_position.distance_to(c.global_position)
		if distance >= best_distance:
			continue
		if _smoke_blocks(shooter.global_position, c.global_position):
			continue
		if shooter.perception.can_see(c.global_position, c.stance):
			best = c
			best_distance = distance
	return best


## Most recently confirmed enemy (radio/memory-free: shooter's own eyes only).
func _last_seen_target(shooter: Character) -> Character:
	var best: Character = null
	var best_age := INF
	for c: Character in _characters:
		if c == null or not is_instance_valid(c) or c == shooter or c.team == shooter.team:
			continue
		var age := age_of_sighting(shooter.get_instance_id(), c.get_instance_id())
		if age >= 0.0 and age < best_age:
			best_age = age
			best = c
	return best


func _smoke_blocks(from: Vector2, to: Vector2) -> bool:
	return _blocks.is_valid() and bool(_blocks.call(from, to))


## [wall_between, surface_penetrable] for the ray the bullet actually travels.
## Sweeping the fired ray (not the target line) keeps the record truthful when
## the shooter is firing blind at a remembered position.
func _classify_ray(shooter: Character, origin: Vector2, dir: Vector2) -> Array:
	if shooter == null or not shooter.is_inside_tree() or dir == Vector2.ZERO:
		return [false, false]
	var reach: float = AUDIT_REACH
	var space := shooter.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		origin, origin + dir.normalized() * reach, Layers.VISION_MASK)
	query.collide_with_areas = false
	query.exclude = [shooter.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return [false, false]
	var collider: Object = hit.get(&"collider")
	if collider == null or not (collider is CollisionObject2D):
		return [false, false]
	var layer := (collider as CollisionObject2D).collision_layer
	# Glass and low cover never stop sight in the tile contract (§2): they are
	# not "walls" for the fairness assertion.
	if (layer & (Layers.GLASS_BIT | Layers.LOW_COVER_BIT)) != 0:
		return [false, false]
	var at: Vector2 = hit.get(&"position", origin)
	return [true, _world != null and _world.is_penetrable(at)]