extends GdUnitTestSuite
## EquipmentSystem shell: frag LOS-gated radius damage, flash LOS gating, the
## smoke contract VisionSystem will consume, and the throw path from Arsenal.
## Real StaticBody2D walls gate the rays; the character is a real scene so the
## damage lands through BodyModel/armor exactly as in play.

const EquipmentScript := preload("res://src/combat/equipment_system.gd")
const CharacterScene := preload("res://src/entities/character.tscn")

const BLAST_POS := Vector2(600.0, 400.0)
## Fuse 0.02 s → the grenade travels ~8 px (THROW_SPEED 420) past BLAST_POS.
const THROW_TRAVEL := 8.4
const WALL_X := 645.0
## Inside the 90 px frag radius, but behind the wall at WALL_X.
const TARGET_BEHIND_WALL := Vector2(680.0, 400.0)
const TARGET_NEAR := Vector2(660.0, 400.0)

var _detonated: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []

func before_test() -> void:
	_detonated.clear()
	_flashes.clear()
	EventBus.equipment_detonated.connect(_on_detonated)
	EventBus.flash_effect.connect(_on_flash)

func after_test() -> void:
	EventBus.equipment_detonated.disconnect(_on_detonated)
	EventBus.flash_effect.disconnect(_on_flash)

func _on_detonated(kind: StringName, pos: Vector2, radius: float) -> void:
	_detonated.append({&"kind": kind, &"pos": pos, &"radius": radius})

func _on_flash(who: Node, strength: float) -> void:
	_flashes.append({&"who": who, &"strength": strength})


## ---- fixtures --------------------------------------------------------------

## `blast_los` = wire the LOS gate to a real physics query (the system itself
## is the non-null World stand-in). False leaves the gate open for pure-radius
## arithmetic — the same behaviour as a fixture with no World injected.
func _system(blast_los: bool = true) -> Node2D:
	var system: Node2D = EquipmentScript.new()
	add_child(system)
	auto_free(system)
	var none: Array[Character] = []
	system.setup(system if blast_los else null, none)
	return system

## Physics is off: the AI tick would overwrite `aim_dir` and re-fire, and these
## tests are about the blast maths, not about a character acting.
func _character(pos: Vector2, equipment: Array[StringName] = []) -> Character:
	var character: Character = CharacterScene.instantiate()
	character.position = pos
	add_child(character)
	auto_free(character)
	var class_def := _class_def()
	class_def.equipment = equipment
	character.setup({
		&"team": Enums.Team.SIROCCO, &"class_def": class_def,
		&"callsign": "Target", &"is_player": false, &"seed": 3,
	})
	character.set_physics_process(false)
	return character

## Zero armor: the frag arithmetic is base × falloff only.
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

func _wall(at_x: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(at_x, BLAST_POS.y)
	body.collision_layer = Layers.WORLD_BIT
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4.0, 240.0)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	auto_free(body)

func _def(kind: int, damage: float = 110.0, radius: float = 90.0) -> EquipmentDef:
	var def := EquipmentDef.new()
	def.id = StringName("test_%d" % kind)
	def.display_name = "Test"
	def.kind = kind
	def.fuse = 0.02
	def.radius = radius
	def.damage = damage
	def.vision_block_time = 12.0
	return def

## Throw at BLAST_POS and step physics until the fuse fires.
func _detonate(system: Node2D, def: EquipmentDef, cook: bool = false) -> void:
	system.throw_grenade(def, null, BLAST_POS, cook)
	for _i: int in 20:
		await get_tree().physics_frame
		if not _detonated.is_empty():
			return

func _blast_pos() -> Vector2:
	return _detonated[0][&"pos"] if not _detonated.is_empty() else BLAST_POS


## ---- frag ------------------------------------------------------------------

func test_frag_damages_a_character_within_the_radius() -> void:
	var system := _system(false)
	var target := _character(TARGET_NEAR)
	system.add_character(target)
	await _detonate(system, _def(Enums.EquipKind.FRAG))
	assert_array(_detonated).has_size(1)
	assert_str(String(_detonated[0][&"kind"])).is_equal("test_%d" % Enums.EquipKind.FRAG)
	# Linear falloff to zero at the radius, torso part, no armor.
	var distance: float = _blast_pos().distance_to(TARGET_NEAR)
	var expected := 110.0 * (1.0 - distance / 90.0)
	assert_float(target.body.part_hp(Enums.Part.TORSO)) \
		.is_equal_approx(BodyModel.PART_MAX[Enums.Part.TORSO] - expected, 0.5)

func test_frag_is_los_gated_by_a_wall() -> void:
	var system := _system(true)
	var behind := _character(TARGET_BEHIND_WALL)
	system.add_character(behind)
	_wall(WALL_X)
	await _detonate(system, _def(Enums.EquipKind.FRAG))
	assert_array(_detonated).has_size(1)
	# The same blast, same distance, no wall: proves the wall is what saved it.
	assert_float(behind.body.part_hp(Enums.Part.TORSO)) \
		.is_equal(BodyModel.PART_MAX[Enums.Part.TORSO])

func test_frag_outside_the_radius_is_untouched() -> void:
	var system := _system(false)
	var far_away := _character(BLAST_POS + Vector2(200.0, 0.0))
	system.add_character(far_away)
	await _detonate(system, _def(Enums.EquipKind.FRAG))
	assert_float(far_away.body.part_hp(Enums.Part.TORSO)) \
		.is_equal(BodyModel.PART_MAX[Enums.Part.TORSO])

func test_cooked_frag_has_a_shorter_fuse() -> void:
	var system := _system(false)
	var def := _def(Enums.EquipKind.FRAG)
	def.fuse = 2.2
	var raw: Node = system.throw_grenade(def, null, BLAST_POS, false)
	var cooked: Node = system.throw_grenade(def, null, BLAST_POS, true)
	assert_float(raw.get(&"fuse_left")).is_equal_approx(2.2, 0.001)
	assert_float(cooked.get(&"fuse_left")) \
		.is_equal_approx(2.2 * EquipmentScript.COOK_FUSE_MULT, 0.001)


## ---- flash -----------------------------------------------------------------

## `radius` covers both targets; the near one must be hit harder facing in.
func _flash_radius() -> float:
	return 220.0

func test_flash_blinds_characters_in_los() -> void:
	var system := _system(true)
	var near := _character(BLAST_POS + Vector2(60.0, 0.0))
	near.aim_dir = Vector2.LEFT
	system.add_character(near)
	await _detonate(system, _def(Enums.EquipKind.FLASH, 0.0, _flash_radius()))
	assert_array(_flashes).has_size(1)
	assert_float(_flashes[0][&"strength"]).is_greater(0.0)
	assert_float(_flashes[0][&"strength"]).is_less_equal(1.0)
	assert_object(_flashes[0][&"who"]).is_same(near)

func test_flash_is_los_gated() -> void:
	var system := _system(true)
	var behind := _character(TARGET_BEHIND_WALL)
	behind.aim_dir = Vector2.LEFT
	system.add_character(behind)
	_wall(WALL_X)
	await _detonate(system, _def(Enums.EquipKind.FLASH, 0.0, _flash_radius()))
	assert_array(_flashes).is_empty()

func test_looking_away_from_the_flash_weakens_it() -> void:
	var system := _system(true)
	# Both at the same distance; `at_bang` looks at the blast, `away` does not.
	var at_bang := _character(BLAST_POS + Vector2(60.0, 0.0))
	at_bang.aim_dir = Vector2.LEFT
	var away := _character(BLAST_POS - Vector2(60.0, 0.0))
	away.aim_dir = Vector2.LEFT
	system.add_character(at_bang)
	system.add_character(away)
	await _detonate(system, _def(Enums.EquipKind.FLASH, 0.0, _flash_radius()))
	var facing_strength := 0.0
	var away_strength := 0.0
	for entry: Dictionary in _flashes:
		if is_same(entry[&"who"], at_bang):
			facing_strength = float(entry[&"strength"])
		elif is_same(entry[&"who"], away):
			away_strength = float(entry[&"strength"])
	assert_float(facing_strength).is_greater(0.0)
	assert_float(facing_strength).is_greater(away_strength)


## ---- smoke -----------------------------------------------------------------

func test_smoke_emits_the_vision_contract_and_blocks_sight() -> void:
	var system := _system(false)
	var deployed: Array[Dictionary] = []
	var handler := func(pos: Vector2, radius: float, duration: float) -> void:
		deployed.append({&"pos": pos, &"radius": radius, &"duration": duration})
	system.smoke_deployed.connect(handler)
	await _detonate(system, _def(Enums.EquipKind.SMOKE, 0.0, 140.0))
	await get_tree().physics_frame
	assert_array(deployed).has_size(1)
	assert_float(deployed[0][&"radius"]).is_equal(140.0)
	assert_float(deployed[0][&"duration"]).is_equal(12.0)
	assert_array(system.smoke_clouds()).has_size(1)
	assert_float(system.smoke_clouds()[0][&"radius"]).is_greater(0.0)
	# A sightline through the cloud is blocked; one that misses it is not.
	var center: Vector2 = _blast_pos()
	assert_bool(system.is_smoked(center - Vector2(300.0, 0.0),
		center + Vector2(300.0, 0.0))).is_true()
	assert_bool(system.is_smoked(center + Vector2(0.0, 300.0),
		center + Vector2(400.0, 300.0))).is_false()
	system.smoke_deployed.disconnect(handler)

func test_smoke_expires_after_its_vision_block_time() -> void:
	var system := _system(false)
	var def := _def(Enums.EquipKind.SMOKE, 0.0, 140.0)
	def.vision_block_time = 0.05
	await _detonate(system, def)
	for _i: int in 10:
		await get_tree().process_frame
	assert_array(system.smoke_clouds()).is_empty()


## ---- throw path ------------------------------------------------------------

func test_arsenal_throw_spawns_a_grenade_and_decrements_the_kit() -> void:
	var system := _system(false)
	var thrower := _character(Vector2(400.0, 400.0), [&"frag"])
	assert_object(thrower.arsenal.throw_equipment(0)).is_not_null()
	assert_int(thrower.arsenal.kit_counts[0]).is_equal(0)
	assert_int(system.get_child_count()).is_equal(1)
	var grenade: Node = system.get_child(0)
	assert_bool(grenade is RigidBody2D).is_true()
	assert_int(grenade.collision_layer).is_equal(Layers.EQUIPMENT_BIT)
	assert_int(grenade.collision_mask).is_equal(Layers.EQUIPMENT_MASK)