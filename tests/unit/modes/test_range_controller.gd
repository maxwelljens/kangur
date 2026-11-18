extends GdUnitTestSuite
## RangeController shell: the rail clock must be the physics dt, not wall clock,
## so a headless sim and a live session put the moving dummies in the same place.
## The rest of the controller needs a live Match, so only the deterministic
## parts (rail phase, player lane pick) are pinned here.

const RangeScript := preload("res://src/modes/range_controller.gd")
const CharacterScene := preload("res://src/entities/character.tscn")

## One rail period is 4 s; a quarter period is a quarter amplitude.
const QUARTER := RangeScript.RAIL_PERIOD_S * 0.25


func _dummy(at: Vector2) -> Character:
	var dummy: Character = CharacterScene.instantiate()
	dummy.position = at
	add_child(dummy)
	auto_free(dummy)
	var class_def := ClassDef.new()
	class_def.id = &"range_dummy"
	class_def.display_name = "Dummy"
	class_def.armor_vest = 0.0
	class_def.armor_helmet = 0.0
	class_def.primary_categories = []
	class_def.sidearm_id = &""
	dummy.setup({&"team": Enums.Team.BASTION, &"class_def": class_def,
		&"callsign": "Dummy", &"is_player": false, &"ai": false, &"seed": 1,
		&"primary_id": &"", &"sidearm_id": &""})
	dummy.set_physics_process(false)
	return dummy


func _controller() -> Node2D:
	var controller: Node2D = RangeScript.new()
	add_child(controller)
	auto_free(controller)
	return controller


func test_rail_phase_advances_on_the_tick_clock_not_wall_clock() -> void:
	var controller := _controller()
	var dummy := _dummy(Vector2(500.0, 400.0))
	controller.get(&"_rails")[dummy] = {&"origin": Vector2(500.0, 400.0),
		&"lane": 0.0}
	# A quarter period is exactly one amplitude; a wall clock would put the
	# dummy somewhere unrelated (and the value would move between two runs).
	controller.call(&"_tick_rails", QUARTER)
	assert_float(dummy.global_position.x - 500.0) \
		.is_equal_approx(RangeScript.RAIL_AMPLITUDE_PX, 0.0001)
	# Continue: three quarters is the opposite extreme.
	controller.call(&"_tick_rails", QUARTER * 2.0)
	assert_float(dummy.global_position.x - 500.0) \
		.is_equal_approx(-RangeScript.RAIL_AMPLITUDE_PX, 0.0001)
	# A full period returns to the origin.
	controller.call(&"_tick_rails", QUARTER)
	assert_float(dummy.global_position.x) \
		.is_equal_approx(500.0, 0.0001)


func test_two_runs_of_the_same_dt_land_on_the_same_pose() -> void:
	var poses: Array[float] = []
	for _run: int in 2:
		var controller := _controller()
		var dummy := _dummy(Vector2(300.0, 300.0))
		controller.get(&"_rails")[dummy] = {&"origin": Vector2(300.0, 300.0),
			&"lane": 1.5}
		for _i: int in 7:
			controller.call(&"_tick_rails", 1.0 / 60.0)
		poses.append(dummy.global_position.x)
		controller.free()
		dummy.free()
	assert_float(poses[0]).is_equal_approx(poses[1], 0.0001)