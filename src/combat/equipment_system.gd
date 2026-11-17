extends Node2D
## EquipmentSystem — grenade bodies, fuses and detonations. Spawns from
## `EventBus.equipment_thrown` (Arsenal already decrements the kit) and keeps
## the smoke record that VisionSystem consumes. Contract: architecture §5
## (equipment_thrown / equipment_detonated / flash_effect / sound_emitted),
## design §6 (frag 2.2 s cookable, flash LOS-gated, smoke 12 s).

## SmokeVision contract: VisionSystem connects to `smoke_deployed` for new
## clouds and calls `smoke_clouds()` each perception tick for the live list,
## then treats a cloud as an opaque disc of `radius` px around `pos`.
signal smoke_deployed(pos: Vector2, radius: float, duration: float)

## Held-frag shortening (design §6: cookable; PlayerController flags intent.cook
## after 0.3 s). One flat step: the fuse still cannot be cooked to zero.
const COOK_FUSE_MULT := 0.45
## Safety floor so a cooked frag always has a beat of visible travel.
const MIN_FUSE := 0.25
## Throw speed, px/s (topdown lob; travels ~180-260 px before the fuse ends).
const THROW_SPEED := 420.0
## Lift the grenade arm from the thrower's centre so it does not spawn inside
## the thrower's own collision circle.
const THROW_SPAWN_OFFSET := 12.0
## Frag: full damage at the centre, linear falloff to 0 at `radius`.
## A blast is a volume, not a bullet: it lands on the torso mass (design §6
## "part-aware" — limbs and head are inside the same radius, so weighting them
## separately would double-count the same body).
const FRAG_PART := Enums.Part.TORSO
## LOS ray for blast gating: walls and low cover stop it (a crate between you
## and the blast saves you). Glass passes, matching its vision rule.
const BLAST_MASK := Layers.VISION_MASK
const BLAST_LOS_PASSES := 3
## Flash: strength falls off to 0 at the radius edge and this much per radian
## away from the victim's facing (looking away from the bang helps).
const FLASH_ANGLE_FALLOFF := 0.5
const FLASH_MIN_STRENGTH := 0.15
## Smoke: grows from a seed to the def radius so it never pops in as a disc.
const SMOKE_GROW_S := 1.0
const SMOKE_COLOR := Color(0.62, 0.64, 0.66, 0.30)
const SMOKE_EDGE := Color(0.72, 0.74, 0.76, 0.42)
## Explosion loudness, px (design §12) and the frag's own audio kind.
const EXPLOSION_LOUDNESS := 2000.0
const FLASH_LOUDNESS := 1200.0
const SMOKE_LOUDNESS := 700.0

const GrenadeScript := preload("res://src/combat/grenade.gd")

## Live smoke clouds: {&"pos", &"radius", &"max_radius", &"age", &"t" (left)}.
var _smoke: Array[Dictionary] = []

## Injected: World (blast LOS queries). Null in pure fixtures = LOS always true.
var world: Node = null
var _characters: Array[Character] = []


func _ready() -> void:
	EventBus.equipment_thrown.connect(_on_equipment_thrown)


func _exit_tree() -> void:
	if EventBus.equipment_thrown.is_connected(_on_equipment_thrown):
		EventBus.equipment_thrown.disconnect(_on_equipment_thrown)


func setup(world_node: Node, characters: Array[Character] = []) -> void:
	world = world_node
	_characters = characters


func add_character(character: Character) -> void:
	if character != null and not _characters.has(character):
		_characters.append(character)


## Live smoke for VisionSystem: [{&"pos": Vector2, &"radius": float}].
## `radius` is the current grown radius, not the final one.
func smoke_clouds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cloud: Dictionary in _smoke:
		out.append({&"pos": cloud[&"pos"], &"radius": cloud[&"radius"]})
	return out


## True when a sightline point→point crosses a live cloud (both sides blind).
func is_smoked(from: Vector2, to: Vector2) -> bool:
	for cloud: Dictionary in _smoke:
		if Geometry2D.get_closest_point_to_segment(cloud[&"pos"], from, to) \
				.distance_to(cloud[&"pos"]) <= float(cloud[&"radius"]):
			return true
	return false


func _process(dt: float) -> void:
	_tick_smoke(dt)
	queue_redraw()


func _on_equipment_thrown(who: Node, kind: StringName, pos: Vector2) -> void:
	var def := Defs.equipment(kind)
	if def == null:
		return
	# EventBus.equipment_thrown has no cook flag; the thrower's Intent still
	# holds it in the same tick the throw was emitted from.
	var intent: Variant = who.get(&"intent") if who != null else null
	var cook := false
	if intent is Intent and (intent as Intent).throw_equipment >= 0:
		cook = (intent as Intent).cook
	throw_grenade(def, who, pos, cook)


## Public so AI/tests/tools can throw without an Arsenal counter behind it.
## `cook` shortens the fuse (held frag). Returns the grenade node.
func throw_grenade(def: EquipmentDef, who: Node, pos: Vector2, cook: bool) -> Node:
	var dir := Vector2.RIGHT
	if who is Node2D:
		var aimed: Variant = who.get(&"aim_dir")
		if aimed is Vector2 and (aimed as Vector2) != Vector2.ZERO:
			dir = (aimed as Vector2).normalized()
	var grenade: RigidBody2D = GrenadeScript.new()
	grenade.name = "Grenade_%s" % def.id
	grenade.position = pos + dir * THROW_SPAWN_OFFSET
	add_child(grenade)
	var fuse := maxf(MIN_FUSE, def.fuse * (COOK_FUSE_MULT if cook else 1.0))
	grenade.call(&"setup", def, who, dir * THROW_SPEED, fuse, _on_grenade_detonate)
	return grenade


func _on_grenade_detonate(grenade: Node) -> void:
	var def: EquipmentDef = grenade.get(&"def")
	var thrower: Node = grenade.get(&"thrower")
	var pos: Vector2 = grenade.global_position
	if def == null:
		return
	match def.kind:
		Enums.EquipKind.FRAG:
			_detonate_frag(def, pos, thrower)
		Enums.EquipKind.FLASH:
			_detonate_flash(def, pos)
		Enums.EquipKind.SMOKE:
			_detonate_smoke(def, pos)
	EventBus.equipment_detonated.emit(def.id, pos, def.radius)


func _detonate_frag(def: EquipmentDef, pos: Vector2, thrower: Node) -> void:
	for target: Character in _live_characters():
		var distance := pos.distance_to(target.global_position)
		if distance > def.radius:
			continue
		if not _has_blast_los(pos, target.global_position):
			continue
		var falloff := 1.0 - distance / maxf(def.radius, 1.0)
		target.apply_hit(FRAG_PART, def.damage * falloff, 1.0, thrower)
	EventBus.sound_emitted.emit(pos, EXPLOSION_LOUDNESS, &"explosion", thrower,
		Enums.Surface.CONCRETE)


func _detonate_flash(def: EquipmentDef, pos: Vector2) -> void:
	for target: Character in _live_characters():
		var distance := pos.distance_to(target.global_position)
		if distance > def.radius or not _has_blast_los(pos, target.global_position):
			continue
		var facing := target.aim_dir
		var to_blast := (pos - target.global_position).normalized()
		if facing != Vector2.ZERO:
			var angle := absf(facing.angle_to(to_blast))
			distance += def.radius * FLASH_ANGLE_FALLOFF * angle / PI
		var strength := maxf(0.0, 1.0 - distance / maxf(def.radius, 1.0))
		if strength < FLASH_MIN_STRENGTH:
			continue
		EventBus.flash_effect.emit(target, strength)
		target.flash(strength)
	EventBus.sound_emitted.emit(pos, FLASH_LOUDNESS, &"flash", null,
		Enums.Surface.CONCRETE)


func _detonate_smoke(def: EquipmentDef, pos: Vector2) -> void:
	_smoke.append({
		&"pos": pos, &"radius": 0.0, &"max_radius": def.radius,
		&"age": 0.0, &"t": def.vision_block_time,
	})
	smoke_deployed.emit(pos, def.radius, def.vision_block_time)
	EventBus.sound_emitted.emit(pos, SMOKE_LOUDNESS, &"smoke", null,
		Enums.Surface.CONCRETE)


func _tick_smoke(dt: float) -> void:
	var kept: Array[Dictionary] = []
	for cloud: Dictionary in _smoke:
		cloud[&"t"] = float(cloud[&"t"]) - dt
		if float(cloud[&"t"]) <= 0.0:
			continue
		cloud[&"age"] = float(cloud[&"age"]) + dt
		var grow := clampf(float(cloud[&"age"]) / SMOKE_GROW_S, 0.0, 1.0)
		cloud[&"radius"] = float(cloud[&"max_radius"]) * grow
		kept.append(cloud)
	_smoke = kept


## Blast LOS: walls and low cover stop a frag/flash (cover saves you, design
## §5/§6). Glass passes — it never blocks vision or sightline effects.
func _has_blast_los(from: Vector2, to: Vector2) -> bool:
	if world == null or not is_inside_tree():
		return true
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, BLAST_MASK)
	query.collide_with_areas = false
	var excluded: Array[RID] = []
	for _pass: int in BLAST_LOS_PASSES:
		query.exclude = excluded
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider: Object = hit[&"collider"]
		if collider == null or not (collider is CollisionObject2D):
			return false
		var layer := (collider as CollisionObject2D).collision_layer
		if (layer & Layers.GLASS_BIT) == 0:
			return false
		excluded.append((collider as CollisionObject2D).get_rid())
	return false


func _live_characters() -> Array[Character]:
	var out: Array[Character] = []
	for character: Character in _characters:
		if character != null and is_instance_valid(character) and character.alive:
			out.append(character)
	return out


func _draw() -> void:
	for cloud: Dictionary in _smoke:
		var center: Vector2 = cloud[&"pos"]
		var radius := float(cloud[&"radius"])
		draw_circle(center, radius, SMOKE_COLOR, true, -1.0, true)
		draw_circle(center, radius, SMOKE_EDGE, false, 2.0, true)