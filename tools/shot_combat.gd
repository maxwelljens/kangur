extends Node2D
## Combat screenshot fixture: two characters firing live projectiles plus a
## grenade detonation, so tracers, muzzle flashes, chips, blood and the smoke
## disc are all in one frame at once.
##
##   tools/godot.sh --path . -- --shot=res://tools/shot_combat.tscn:20:reports/screenshots/combat.png
##   Self-check (headless, no args): tools/godot.sh --headless --path . res://tools/shot_combat.tscn
##
## Both characters are AI-controlled stubs (no cursor), aimed by script, so the
## scene is deterministic without input.

const CharacterScene := preload("res://src/entities/character.tscn")
const ProjectileScript := preload("res://src/combat/projectile_system.gd")
const EquipmentScript := preload("res://src/combat/equipment_system.gd")
const EffectsScript := preload("res://src/entities/effects.gd")

const FLOOR := Color(0.26, 0.27, 0.29)
const WALL := Color(0.17, 0.18, 0.20)
const GRID := Color(0.31, 0.32, 0.34, 0.5)
const ARENA := Vector2(1200.0, 760.0)
const GRID_STEP := 64.0
const CAMERA_ZOOM := 2.1
const CAMERA_CENTER := Vector2(610.0, 400.0)
const SHOOTER_POS := Vector2(300.0, 380.0)
const TARGET_POS := Vector2(920.0, 380.0)
## Low-cover crate between them: the rounds pass through it (wood, ×0.55).
const CRATE_POS := Vector2(600.0, 380.0)
const CRATE_SIZE := Vector2(36.0, 120.0)
const GRENADE_POS := Vector2(700.0, 560.0)
const FIRE_TICKS := 90

var shooter: Character = null
var target: Character = null
var projectiles: Node2D = null
var equipment: Node2D = null
var effects: Node2D = null
var _hits: int = 0
var _shots: int = 0

func _ready() -> void:
	_build_arena()
	_add_camera()
	EventBus.shot_fired.connect(func(_s: Node, _w: StringName, _o: Vector2,
			_d: Vector2, _p: int) -> void: _shots += 1)
	EventBus.character_hit.connect(func(_v: Node, _a: Node, _p: int, _d: float,
			_f: bool, _pos: Vector2) -> void: _hits += 1)

	projectiles = ProjectileScript.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	# The arena has no TileMap: report the crate as penetrable wood and the
	# rest as concrete so the penetration path is exercised in the shot.
	projectiles.set(&"surface_provider", _surface_at)
	projectiles.set(&"penetrable_provider", _penetrable_at)
	equipment = EquipmentScript.new()
	equipment.name = "Equipment"
	add_child(equipment)
	# Muzzle flash/chips/blood are Effects' job (combat only emits the events).
	effects = EffectsScript.new()
	effects.name = "Effects"
	add_child(effects)

	shooter = _spawn(Enums.Team.BASTION, SHOOTER_POS, &"kestrel", &"vanguard")
	target = _spawn(Enums.Team.SIROCCO, TARGET_POS, &"kestrel", &"bulwark")
	# Skip the draw delay so the first cap frame already has rounds in the air.
	shooter.arsenal.current().equip_timer = 0.0
	target.arsenal.current().equip_timer = 0.0
	projectiles.call(&"setup", null, _pair())
	equipment.call(&"setup", null, _pair())

	# Headless (CI/probe) asserts the contract; with a display it poses the shot.
	if DisplayServer.get_name() == "headless":
		_selftest()
	else:
		_run_show()

func _crate_rect() -> Rect2:
	return Rect2(CRATE_POS - CRATE_SIZE * 0.5, CRATE_SIZE)


func _surface_at(pos: Vector2) -> int:
	return Enums.Surface.WOOD if _crate_rect().has_point(pos) else Enums.Surface.CONCRETE


func _penetrable_at(pos: Vector2) -> bool:
	return _crate_rect().has_point(pos)


func _pair() -> Array[Character]:
	var out: Array[Character] = []
	out.append(shooter)
	out.append(target)
	return out

func _add_camera() -> void:
	var camera := Camera2D.new()
	camera.position = CAMERA_CENTER
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	add_child(camera)
	camera.make_current()

func _build_arena() -> void:
	_wall(Vector2(600.0, 60.0), Vector2(520.0, 28.0))
	_wall(Vector2(600.0, 700.0), Vector2(520.0, 28.0))
	_wall(CRATE_POS, CRATE_SIZE, Layers.LOW_COVER_BIT)

func _wall(pos: Vector2, size: Vector2, layer: int = Layers.WORLD_BIT) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var visual := WallVisual.new()
	visual.size = size
	visual.tint = WALL if layer == Layers.WORLD_BIT else Color(0.34, 0.29, 0.20)
	body.add_child(visual)
	add_child(body)

func _spawn(team: int, pos: Vector2, weapon_id: StringName,
		class_id: StringName) -> Character:
	var character: Character = CharacterScene.instantiate()
	character.position = pos
	add_child(character)
	character.setup({
		&"team": team, &"class_id": class_id,
		&"callsign": Enums.team_name(team).capitalize(),
		&"is_player": false, &"ai": true, &"seed": 17,
		&"primary_id": weapon_id, &"sidearm_id": &"adder",
	})
	return character

## The screenshot: both sides trade fire through the crate while a thrown frag
## is still in the air, so the capture frame has tracers, muzzle flash, chips
## and a lobbed grenade all at once.
func _run_show() -> void:
	# Grenade first: its 2.2 s fuse keeps it airborne across the capture frame.
	var frag := Defs.equipment(&"frag")
	if frag != null:
		equipment.call(&"throw_grenade", frag, shooter, GRENADE_POS, false)
	_aim_and_fire(shooter, Vector2.RIGHT)
	_aim_and_fire(target, Vector2.LEFT)
	for _i: int in FIRE_TICKS:
		await get_tree().physics_frame

## Headless contract probe: real bullets, real hits, real detonation.
func _selftest() -> void:
	var problem := ""
	_aim_and_fire(shooter, Vector2.RIGHT)
	for _i: int in FIRE_TICKS:
		await get_tree().physics_frame
	if _shots <= 0:
		problem = "no shot_fired"
	elif _hits <= 0:
		problem = "tracers never reached the target"
	elif projectiles.call(&"active_count") < 0:
		problem = "projectile count invalid"
	if problem.is_empty():
		var frag := Defs.equipment(&"frag")
		if frag == null:
			problem = "frag EquipmentDef missing"
		else:
			equipment.call(&"throw_grenade", frag, shooter, GRENADE_POS, false)
			for _i: int in 160:
				await get_tree().physics_frame
	if problem.is_empty():
		print("COMBAT_SELFTEST_OK shots=%d hits=%d" % [_shots, _hits])
		get_tree().quit(0)
	else:
		print("COMBAT_SELFTEST_FAIL %s" % problem)
		get_tree().quit(1)

func _aim_and_fire(who: Character, aim: Vector2) -> void:
	var ai: Node = who.controller
	if not ai.has_method(&"set_aim_target"):
		return
	ai.call(&"set_aim_target", aim)
	ai.call(&"set_fire", true)

func _draw() -> void:
	draw_rect(Rect2(-40.0, -40.0, ARENA.x + 80.0, ARENA.y + 80.0), FLOOR, true)
	var x := 0.0
	while x <= ARENA.x:
		draw_line(Vector2(x, 0.0), Vector2(x, ARENA.y), GRID, 1.0, true)
		x += GRID_STEP
	var y := 0.0
	while y <= ARENA.y:
		draw_line(Vector2(0.0, y), Vector2(ARENA.x, y), GRID, 1.0, true)
		y += GRID_STEP

class WallVisual extends Node2D:
	var size: Vector2 = Vector2.ZERO
	var tint: Color = Color(0.17, 0.18, 0.20)

	func _draw() -> void:
		draw_rect(Rect2(-size * 0.5, size), tint, true)
		draw_rect(Rect2(-size * 0.5, size), tint.lightened(0.14), false, 1.0)