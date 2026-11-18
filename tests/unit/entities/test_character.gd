extends GdUnitTestSuite
## Character contract tests that do not need physics: setup wiring, intent
## mapping through a real PlayerController, aim pipeline limits, body/arsenal
## modifier application, and EventBus translation on hit/death.

const CharacterScene := preload("res://src/entities/character.tscn")
const AimScript := preload("res://src/entities/aim.gd")
const PlayerControllerScript := preload("res://src/entities/player_controller.gd")
const AIControllerScript := preload("res://src/entities/ai_controller.gd")

## Synthetic weapon defs: the shell contract must hold before data/ content.
func _weapon_def(category: StringName) -> WeaponDef:
	var def := WeaponDef.new()
	def.id = StringName("%s_test" % category)
	def.display_name = String(category)
	def.category = category
	def.weight = 3.5
	def.fire_modes = [Enums.FireMode.AUTO, Enums.FireMode.SEMI]
	return def

func _spawn(config: Dictionary = {}) -> Character:
	var character: Character = CharacterScene.instantiate()
	add_child(character)
	auto_free(character)
	var merged := {
		&"team": Enums.Team.BASTION, &"class_id": &"vanguard",
		&"callsign": "Test", &"is_player": true, &"seed": 42,
		&"primary_id": &"kestrel", &"sidearm_id": &"adder",
		&"primary_def": _weapon_def(&"ar"), &"sidearm_def": _weapon_def(&"pistol"),
	}
	merged.merge(config, true)
	character.setup(merged)
	return character


func test_setup_sets_identity_and_components() -> void:
	var c := _spawn({&"callsign": "Vuk", &"team": Enums.Team.SIROCCO})
	assert_str(c.callsign).is_equal("Vuk")
	assert_int(c.team).is_equal(Enums.Team.SIROCCO)
	assert_bool(c.is_player).is_true()
	assert_bool(c.alive).is_true()
	assert_object(c.body.model).is_not_null()
	assert_object(c.movement).is_not_null()
	assert_object(c.arsenal.current()).is_not_null()
	assert_object(c.class_def).is_not_null()


func test_player_gets_player_controller_and_ai_gets_stub() -> void:
	var p := _spawn({&"is_player": true})
	var b := _spawn({&"is_player": false, &"callsign": "Bot"})
	assert_object(p.controller).is_instanceof(PlayerControllerScript)
	assert_object(b.controller).is_instanceof(AIControllerScript)


func test_body_armor_comes_from_class_def() -> void:
	var c := _spawn()
	assert_float(c.body.vest_durability()).is_equal_approx(c.class_def.armor_vest, 0.001)
	assert_int(c.body.bandages_left).is_equal(c.class_def.bandages)


func test_ai_aim_is_turn_rate_limited_and_erroneous() -> void:
	var c := _spawn({&"is_player": false, &"ai": true})
	assert_bool(c.aim.ai_limited).is_true()
	assert_float(c.aim.turn_rate_deg).is_greater(0.0)
	assert_float(c.aim.error_initial_deg).is_greater(0.0)
	# Error must never fall to exactly zero (fairness: research §5.5).
	c.aim.acquire(Vector2.DOWN)
	assert_float(c.aim.error_deg()).is_greater(0.0)


func test_player_aim_is_instant() -> void:
	var c := _spawn()
	var intent := Intent.new()
	intent.aim = Vector2.UP
	var dir := c.aim.tick(1.0 / 60.0, intent, Vector2.ZERO)
	assert_float(dir.dot(Vector2.UP)).is_equal_approx(1.0, 0.0001)


func test_recoil_offset_perturbs_aim_then_recovers() -> void:
	var c := _spawn()
	var intent := Intent.new()
	intent.aim = Vector2.RIGHT
	var clean := c.aim.tick(1.0 / 60.0, intent, Vector2.ZERO)
	var kicked := c.aim.tick(1.0 / 60.0, intent, Vector2(0.0, 0.25))
	assert_float(kicked.dot(clean)).is_less(1.0)
	# Recovery returns toward the tracking direction, never past it.
	assert_float(kicked.length()).is_equal_approx(1.0, 0.0001)


func test_body_speed_modifier_reaches_movement_model() -> void:
	var c := _spawn({&"class_id": &"pathfinder"})
	c._apply_modifiers()
	var expected: float = c.class_def.speed_mult * 1.08
	assert_float(c.movement.speed_mult).is_equal_approx(expected, 0.0001)


func test_crippled_leg_disables_sprint() -> void:
	var c := _spawn()
	c.body.model.hp[Enums.Part.LEG_L] = 0.0
	c._apply_modifiers()
	assert_bool(c.movement.can_sprint).is_false()
	assert_float(c.movement.speed_mult).is_less(1.0)


func test_apply_hit_emits_hit_and_dies_on_lethal_headshot() -> void:
	var c := _spawn()
	var hits: Array = []
	var deaths: Array = []
	var hit_handler := func(_v: Node, _a: Node, _p: int, _d: float, fatal: bool,
			_pos: Vector2) -> void: hits.append(fatal)
	var death_handler := func(v: Node, _a: Node, _w: StringName, _p: Vector2,
			_d: float) -> void: deaths.append(v)
	EventBus.character_hit.connect(hit_handler)
	EventBus.character_died.connect(death_handler)
	c.apply_hit(Enums.Part.HEAD, 110.0, 1.0, null)
	EventBus.character_hit.disconnect(hit_handler)
	EventBus.character_died.disconnect(death_handler)
	assert_array(hits).has_size(1)
	assert_array(deaths).has_size(1)
	assert_bool(c.alive).is_false()
	assert_bool(c.body.alive()).is_false()


func test_hit_after_death_is_ignored() -> void:
	var c := _spawn()
	c.apply_hit(Enums.Part.HEAD, 110.0, 1.0, null)
	var result := c.apply_hit(Enums.Part.TORSO, 30.0, 1.0, null)
	assert_bool(result.died).is_false()
	assert_float(result.absorbed).is_equal(0.0)


func test_part_at_world_pos_maps_head_and_legs() -> void:
	var c := _spawn()
	c.global_position = Vector2(100.0, 100.0)
	# aim_dir is +X after setup, so world +X is "forward" in BodyModel's zones.
	c.aim_dir = Vector2.RIGHT
	# Head disc sits at forward +2; legs are anything behind the hips (-4).
	assert_int(c.part_at_world_pos(Vector2(102.0, 100.0))).is_equal(Enums.Part.HEAD)
	assert_int(c.part_at_world_pos(Vector2(88.0, 100.0))).is_equal(Enums.Part.LEG_L)
	assert_int(c.part_at_world_pos(Vector2(108.0, 100.0))).is_equal(Enums.Part.TORSO)
	# Facing down: forward is +Y, so the head moves with the facing.
	c.aim_dir = Vector2.DOWN
	assert_int(c.part_at_world_pos(Vector2(100.0, 102.0))).is_equal(Enums.Part.HEAD)
	# World +X while facing down is a flank: the head zone did not travel with it.
	assert_int(c.part_at_world_pos(Vector2(110.0, 100.0))).is_not_equal(Enums.Part.HEAD)


func test_bandaging_blocks_firing() -> void:
	var c := _spawn()
	c.body.model.hp[Enums.Part.TORSO] = 20.0
	assert_bool(c.body.try_start_bandage()).is_true()
	assert_bool(c.body.is_bandaging()).is_true()
	c._try_fire()
	assert_array(c.pending_shots).is_empty()


func test_take_pending_shots_hands_over_once() -> void:
	var c := _spawn()
	c.arsenal.current().equip_timer = 0.0
	c.intent.fire = true
	c.intent.fire_press = true
	c._try_fire()
	var taken := c.take_pending_shots()
	assert_array(taken).has_size(1)
	assert_array(c.pending_shots).is_empty()
	assert_array(c.take_pending_shots()).is_empty()


func test_suppression_and_spot_bonus_are_zero_for_other_perks() -> void:
	var c := _spawn({&"class_id": &"vanguard"})
	assert_float(c.suppression_error_deg()).is_equal(0.0)
	assert_float(c.spot_persist_bonus_s()).is_equal(0.0)