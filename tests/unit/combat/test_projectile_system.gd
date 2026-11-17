extends GdUnitTestSuite
## ProjectileSystem shell: swept-ray correctness (no tunnelling at 8000 px/s),
## penetration rules, glass, falloff wiring and the part hit. The penetration
## table is a pure static; the sweep tests use real StaticBody2D walls so a
## regression in the ray segment (Area2D-style overlap) fails here.

const ProjectileScript := preload("res://src/combat/projectile_system.gd")
const CharacterScene := preload("res://src/entities/character.tscn")

const WALL_X := 300.0
const WALL_SIZE := Vector2(2.0, 200.0)
const BULLET_Y := 300.0
const FAST_SPEED := 8000.0

var _impacts: Array[Dictionary] = []
var _hits: Array[Dictionary] = []

func before_test() -> void:
	_impacts.clear()
	_hits.clear()
	EventBus.bullet_impact.connect(_on_impact)
	EventBus.character_hit.connect(_on_hit)

func after_test() -> void:
	EventBus.bullet_impact.disconnect(_on_impact)
	EventBus.character_hit.disconnect(_on_hit)

func _on_impact(pos: Vector2, normal: Vector2, surface: int, penetrated: bool) -> void:
	_impacts.append({&"pos": pos, &"normal": normal, &"surface": surface,
		&"penetrated": penetrated})

func _on_hit(_v: Node, _a: Node, part: int, damage: float, _fatal: bool,
		_pos: Vector2) -> void:
	_hits.append({&"part": part, &"damage": damage})


## ---- fixtures --------------------------------------------------------------

func _system(seed_value: int = 7) -> Node2D:
	var system: Node2D = ProjectileScript.new()
	add_child(system)
	auto_free(system)
	var none: Array[Character] = []
	system.setup(null, none, seed_value)
	return system

func _chars(list: Array) -> Array[Character]:
	var out: Array[Character] = []
	for item: Variant in list:
		if item is Character:
			out.append(item as Character)
	return out

func _wall(size: Vector2 = WALL_SIZE, layer: int = Layers.WORLD_BIT) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(WALL_X, BULLET_Y)
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	auto_free(body)
	return body

## Stubs the tile lookups: no TileMap in the unit-test world.
func _stub_surface(system: Node2D, surface: int, penetrable: bool) -> void:
	system.set(&"surface_provider", func(_pos: Vector2) -> int: return surface)
	system.set(&"penetrable_provider", func(_pos: Vector2) -> bool: return penetrable)

func _shot(overrides: Dictionary = {}) -> ShotRequest:
	var shot := ShotRequest.new()
	shot.origin = Vector2(100.0, BULLET_Y)
	shot.speed = FAST_SPEED
	shot.damage = 30.0
	shot.penetration = 1.0
	shot.falloff_start = 500.0
	shot.falloff_end = 1400.0
	shot.min_mult = 0.5
	for key: StringName in overrides:
		shot.set(key, overrides[key])
	return shot

## `human` = player controller; a target only needs a body, no weapon.
func _character(pos: Vector2, with_weapon: bool = false) -> Character:
	var character: Character = CharacterScene.instantiate()
	character.position = pos
	add_child(character)
	auto_free(character)
	character.setup({
		&"team": Enums.Team.SIROCCO,
		&"class_def": _class_def(),
		&"callsign": "Target",
		&"is_player": false,
		&"seed": 11,
		&"primary_id": &"test_ar" if with_weapon else &"",
		&"primary_def": _weapon_def() if with_weapon else null,
	})
	return character

## Zero armor so the arithmetic is base × part multiplier only.
func _class_def() -> ClassDef:
	var def := ClassDef.new()
	def.id = &"test_class"
	def.display_name = "Test"
	def.armor_vest = 0.0
	def.armor_helmet = 0.0
	def.bandages = 0
	def.primary_categories = []
	def.sidearm_id = &""
	return def

func _weapon_def() -> WeaponDef:
	var def := WeaponDef.new()
	def.id = &"test_ar"
	def.display_name = "Test AR"
	def.fire_modes = [Enums.FireMode.AUTO]
	def.rpm = 600.0
	def.mag_size = 30
	def.equip_time = 0.0
	def.damage = 30.0
	def.bullet_speed = FAST_SPEED
	def.spread_base = 0.0
	def.bloom_per_shot = 0.0
	def.recoil_kick = 0.0
	def.penetration = 1.0
	def.falloff_start = 500.0
	def.falloff_end = 1400.0
	def.min_mult = 0.5
	return def


## ---- sweep / tunnelling ----------------------------------------------------

func test_8000_px_per_second_round_hits_a_2px_wall() -> void:
	var system := _system()
	_wall()
	system.fire(null, _shot())
	for _i: int in 4:
		await get_tree().physics_frame
	assert_array(_impacts).is_not_empty()
	var hit: Dictionary = _impacts[0]
	assert_float(hit[&"pos"].x).is_between(WALL_X - 2.0, WALL_X + 1.0)
	assert_bool(hit[&"penetrated"]).is_false()
	assert_int(system.active_count()).is_equal(0)

func test_round_stops_at_the_first_hit_and_never_crosses_the_wall() -> void:
	var system := _system()
	_wall()
	system.fire(null, _shot())
	await get_tree().physics_frame
	# One tick is 133 px: still short of the wall, so the round is alive.
	var alive: Array = system.bullets_debug()
	if not alive.is_empty():
		assert_float(float(alive[0][&"pos"].x)).is_less(WALL_X)
	for _i: int in 4:
		await get_tree().physics_frame
	assert_int(system.active_count()).is_equal(0)


## ---- penetration rules -----------------------------------------------------

func test_surface_pen_mult_table() -> void:
	assert_float(ProjectileScript.surface_pen_mult(Enums.Surface.WOOD, 1.0, true)) \
		.is_equal(ProjectileScript.WOOD_PEN_MULT)
	assert_float(ProjectileScript.surface_pen_mult(Enums.Surface.WOOD, 0.1, true)) \
		.is_equal(0.0)
	assert_float(ProjectileScript.surface_pen_mult(Enums.Surface.WOOD, 1.0, false)) \
		.is_equal(0.0)
	assert_float(ProjectileScript.surface_pen_mult(Enums.Surface.GLASS, 1.0, true)) \
		.is_equal(ProjectileScript.GLASS_PEN_MULT)
	assert_float(ProjectileScript.surface_pen_mult(Enums.Surface.CONCRETE, 1.2, true)) \
		.is_equal(0.0)
	assert_float(ProjectileScript.surface_pen_mult(Enums.Surface.CONCRETE, 2.5, true)) \
		.is_equal(ProjectileScript.CONCRETE_PEN_MULT)

func test_wood_pass_costs_damage_and_keeps_the_round_alive() -> void:
	var system := _system()
	_wall()
	_stub_surface(system, Enums.Surface.WOOD, true)
	system.fire(null, _shot())
	# The await resumes before the node's own tick for that frame, so N awaits
	# is N-1 sweeps. Three frames put the round well past the wall.
	for _i: int in 3:
		await get_tree().physics_frame
	assert_int(system.active_count()).is_equal(1)
	var alive: Array = system.bullets_debug()
	assert_float(float(alive[0][&"damage"])).is_equal_approx(30.0 * 0.55, 0.001)
	assert_float(float(alive[0][&"pos"].x)).is_greater(WALL_X)
	assert_array(_impacts).is_not_empty()
	assert_bool(_impacts[0][&"penetrated"]).is_true()

func test_concrete_stops_a_rifle_round() -> void:
	var system := _system()
	_wall()
	_stub_surface(system, Enums.Surface.CONCRETE, true)
	system.fire(null, _shot({&"penetration": 1.2}))
	for _i: int in 3:
		await get_tree().physics_frame
	assert_int(system.active_count()).is_equal(0)
	assert_bool(_impacts[0][&"penetrated"]).is_false()

func test_sniper_passes_thin_concrete_at_035() -> void:
	var system := _system()
	_wall()
	_stub_surface(system, Enums.Surface.CONCRETE, true)
	system.fire(null, _shot({&"penetration": 2.5, &"damage": 110.0}))
	for _i: int in 3:
		await get_tree().physics_frame
	var alive: Array = system.bullets_debug()
	assert_array(alive).has_size(1)
	assert_float(float(alive[0][&"damage"])).is_equal_approx(110.0 * 0.35, 0.001)
	assert_float(float(alive[0][&"pos"].x)).is_greater(WALL_X)

func test_glass_registers_two_hits_and_passes() -> void:
	var system := _system()
	_wall(Vector2(2.0, 200.0), Layers.GLASS_BIT)
	_stub_surface(system, Enums.Surface.GLASS, true)
	var breaks: Array[Vector2] = []
	system.set(&"glass_breaker", func(pos: Vector2) -> void: breaks.append(pos))
	system.fire(null, _shot({&"penetration": 0.6}))
	system.fire(null, _shot({&"penetration": 0.6}))
	for _i: int in 3:
		await get_tree().physics_frame
	assert_array(breaks).has_size(2)
	assert_int(system.active_count()).is_equal(2)


## ---- damage wiring ---------------------------------------------------------

func test_far_hit_falls_off_and_lands_on_the_body_part() -> void:
	var system := _system()
	var target := _character(Vector2(900.0, BULLET_Y))
	system.fire(null, _shot())
	for _i: int in 12:
		await get_tree().physics_frame
		if not _hits.is_empty():
			break
	assert_array(_hits).has_size(1)
	var expected := Ballistics.falloff(30.0, 790.0, 500.0, 1400.0, 0.5)
	var part: int = _hits[0][&"part"]
	var dealt := expected * Enums.PART_DAMAGE_MULT[part]
	assert_int(part).is_equal(target.part_at_world_pos(Vector2(890.0, BULLET_Y)))
	assert_float(_hits[0][&"damage"]).is_equal_approx(dealt, 0.01)
	assert_float(target.body.part_hp(part)) \
		.is_equal_approx(BodyModel.PART_MAX[part] - dealt, 0.01)

func test_falloff_past_end_clamps_to_min_mult() -> void:
	var system := _system()
	_character(Vector2(900.0, BULLET_Y))
	system.fire(null, _shot({&"falloff_start": 100.0, &"falloff_end": 200.0}))
	for _i: int in 12:
		await get_tree().physics_frame
		if not _hits.is_empty():
			break
	assert_array(_hits).has_size(1)
	# Past falloff_end the multiplier is min_mult, never lower.
	var dealt := 30.0 * 0.5 * Enums.PART_DAMAGE_MULT[_hits[0][&"part"]]
	assert_float(_hits[0][&"damage"]).is_equal_approx(dealt, 0.01)


## ---- shot intake -----------------------------------------------------------

func test_character_shots_reach_the_system_and_impact_a_wall() -> void:
	var system := _system()
	_wall()
	var shooter := _character(Vector2(150.0, BULLET_Y), true)
	system.setup(null, _chars([shooter]))
	var ai: Node = shooter.controller
	ai.call(&"set_aim_target", Vector2.RIGHT)
	ai.call(&"set_fire", true)
	for _i: int in 24:
		await get_tree().physics_frame
		if not _impacts.is_empty():
			break
	ai.call(&"set_fire", false)
	assert_array(_impacts).is_not_empty()
	assert_bool(_impacts[0][&"penetrated"]).is_false()