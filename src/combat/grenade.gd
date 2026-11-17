extends RigidBody2D
## One physical grenade: a topdown lobbed body that bounces, then hands itself
## to EquipmentSystem when the fuse runs out. Layer 4 EQUIPMENT (architecture
## §2) so other grenades collide but bullets never do.
## The lob is visual only: `_height` lifts the drawn body over a ground shadow
## while the physics body stays on the 2D plane (project gravity is 0).

## Body radius and drawn size, px.
const RADIUS := 4.0
const BODY_R := 5.0
## Fake vertical velocity + gravity for the lob arc, px/s and px/s².
const ARC_VZ := 120.0
const ARC_GRAVITY := 620.0
## Ground friction bled off the planar velocity, px/s².
const GROUND_FRICTION := 520.0
## Below this speed a resting grenade stops updating physics (no jitter).
const REST_SPEED := 6.0
const SHADOW_ALPHA := 0.30
const BODY_COLOR_FALLBACK := Color(0.42, 0.44, 0.42)
const KIND_COLORS: Dictionary[int, Color] = {
	Enums.EquipKind.FRAG: Color(0.36, 0.42, 0.30),
	Enums.EquipKind.FLASH: Color(0.55, 0.53, 0.60),
	Enums.EquipKind.SMOKE: Color(0.46, 0.48, 0.50),
}

var def: EquipmentDef = null
var thrower: Node = null
## Seconds left before detonation (already shortened by cooking).
var fuse_left: float = 0.0

var _on_detonate: Callable = Callable()
var _height: float = 0.0
var _vz: float = ARC_VZ


func setup(equipment: EquipmentDef, owner_node: Node, impulse: Vector2,
		fuse_seconds: float, on_detonate: Callable) -> void:
	def = equipment
	thrower = owner_node
	_on_detonate = on_detonate
	fuse_left = fuse_seconds
	_height = ARC_VZ * ARC_VZ / (2.0 * ARC_GRAVITY)
	collision_layer = Layers.EQUIPMENT_BIT
	collision_mask = Layers.EQUIPMENT_MASK
	gravity_scale = 0.0
	lock_rotation = true
	linear_velocity = impulse
	_build_body()


func _build_body() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	var material := PhysicsMaterial.new()
	material.bounce = 0.45
	material.friction = 1.0
	physics_material_override = material


func _physics_process(dt: float) -> void:
	fuse_left -= dt
	if fuse_left <= 0.0:
		_detonate()
		return
	_tick_arc(dt)
	if linear_velocity.length() > REST_SPEED:
		linear_velocity = linear_velocity.move_toward(Vector2.ZERO, GROUND_FRICTION * dt)
	else:
		linear_velocity = Vector2.ZERO
	queue_redraw()


func _detonate() -> void:
	var callback := _on_detonate
	_on_detonate = Callable()
	set_physics_process(false)
	# Free first so a detonation that spawns effects never overlaps the body.
	queue_free()
	if callback.is_valid():
		callback.call(self)


## Lob visual: the drawn body rises and falls, the shadow stays on the ground.
func _tick_arc(dt: float) -> void:
	if _height <= 0.0:
		return
	_height = maxf(0.0, _height + _vz * dt)
	_vz -= ARC_GRAVITY * dt
	if _height <= 0.0:
		_vz = 0.0


func _draw() -> void:
	var color: Color = KIND_COLORS.get(def.kind if def != null else -1, BODY_COLOR_FALLBACK)
	var shadow_scale := 1.0 / (1.0 + _height / ARC_VZ)
	draw_circle(Vector2.ZERO, BODY_R * shadow_scale,
		Color(0.0, 0.0, 0.0, SHADOW_ALPHA), true, -1.0, true)
	draw_circle(Vector2(0.0, -_height), BODY_R, color, true, -1.0, true)
	draw_circle(Vector2(0.0, -_height), BODY_R, color.lightened(0.35), false, 1.0, true)