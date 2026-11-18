extends GdUnitTestSuite
## Controller intent mapping. PlayerController reads the InputMap, so these tests
## install the real bindings and drive actions through Input.action_press — the
## same path the game uses. Each "tick" awaits a physics frame because edge
## detection (is_action_just_pressed) is per-frame state.
## AIController is a stub with a fixed interface; its setters must reach the
## Intent the AI wave will consume.

const PlayerControllerScript := preload("res://src/entities/player_controller.gd")
const AIControllerScript := preload("res://src/entities/ai_controller.gd")

const DT := 1.0 / 60.0

func before_test() -> void:
	InputDefaults.install()

func after_test() -> void:
	_release_all()

func _release_all() -> void:
	for action: StringName in InputDefaults.BINDINGS:
		if Input.is_action_pressed(action):
			Input.action_release(action)

func _player_controller() -> Node:
	var host := Node2D.new()
	add_child(host)
	auto_free(host)
	var controller: Node = PlayerControllerScript.new()
	host.add_child(controller)
	auto_free(controller)
	controller.setup(host)
	return controller

func _ai_controller() -> Node:
	var host := Node2D.new()
	host.set(&"aim_dir", Vector2.RIGHT)
	add_child(host)
	auto_free(host)
	var controller: Node = AIControllerScript.new()
	host.add_child(controller)
	auto_free(controller)
	controller.setup(host)
	return controller

## One controller tick on a fresh physics frame (edge actions need a new frame).
func _tick(controller: Node, intent: Intent) -> void:
	await get_tree().physics_frame
	controller.call(&"fill_intent", intent, DT)


func test_idle_intent_has_no_edges() -> void:
	var c := _player_controller()
	var intent := Intent.new()
	await _tick(c, intent)
	assert_vector(intent.move).is_equal(Vector2.ZERO)
	assert_bool(intent.fire).is_false()
	assert_bool(intent.sprint).is_false()
	assert_int(intent.switch_slot).is_equal(-1)
	assert_int(intent.throw_equipment).is_equal(-1)


func test_move_vector_maps_wasd() -> void:
	var c := _player_controller()
	var intent := Intent.new()
	Input.action_press(&"move_right")
	Input.action_press(&"move_up")
	await _tick(c, intent)
	assert_float(intent.move.x).is_greater(0.0)
	assert_float(intent.move.y).is_less(0.0)
	assert_float(intent.move.length()).is_equal_approx(1.0, 0.0001)


func test_fire_press_is_an_edge_and_hold_persists() -> void:
	var c := _player_controller()
	var intent := Intent.new()
	Input.action_press(&"fire")
	await _tick(c, intent)
	assert_bool(intent.fire).is_true()
	assert_bool(intent.fire_press).is_true()
	await _tick(c, intent)
	assert_bool(intent.fire).is_true()
	assert_bool(intent.fire_press).is_false()


func test_slot_keys_map_to_indices() -> void:
	var c := _player_controller()
	var intent := Intent.new()
	Input.action_press(&"slot_sidearm")
	await _tick(c, intent)
	assert_int(intent.switch_slot).is_equal(1)
	Input.action_release(&"slot_sidearm")
	await _tick(c, intent)
	Input.action_press(&"slot_primary")
	await _tick(c, intent)
	assert_int(intent.switch_slot).is_equal(0)


func test_reload_and_cycle_mode_are_edges() -> void:
	var c := _player_controller()
	var intent := Intent.new()
	Input.action_press(&"reload")
	Input.action_press(&"cycle_mode")
	await _tick(c, intent)
	assert_bool(intent.reload).is_true()
	assert_bool(intent.cycle_fire_mode).is_true()
	await _tick(c, intent)
	assert_bool(intent.reload).is_false()
	assert_bool(intent.cycle_fire_mode).is_false()


func test_crouch_toggle_setting_toggles_stance() -> void:
	var original: bool = bool(Settings.get_value(&"gameplay", &"crouch_toggle", true))
	Settings.set_value(&"gameplay", &"crouch_toggle", true)
	var c := _player_controller()
	var intent := Intent.new()
	await _tick(c, intent)
	assert_int(intent.stance).is_equal(Enums.Stance.STAND)
	Input.action_press(&"crouch")
	await _tick(c, intent)
	Input.action_release(&"crouch")
	assert_int(intent.stance).is_equal(Enums.Stance.CROUCH)
	await _tick(c, intent)
	assert_int(intent.stance).is_equal(Enums.Stance.CROUCH)
	Input.action_press(&"crouch")
	await _tick(c, intent)
	Input.action_release(&"crouch")
	assert_int(intent.stance).is_equal(Enums.Stance.STAND)
	Settings.set_value(&"gameplay", &"crouch_toggle", original)


func test_crouch_hold_setting_follows_the_key() -> void:
	var original: bool = bool(Settings.get_value(&"gameplay", &"crouch_toggle", true))
	Settings.set_value(&"gameplay", &"crouch_toggle", false)
	var c := _player_controller()
	var intent := Intent.new()
	Input.action_press(&"crouch")
	await _tick(c, intent)
	assert_int(intent.stance).is_equal(Enums.Stance.CROUCH)
	Input.action_release(&"crouch")
	await _tick(c, intent)
	assert_int(intent.stance).is_equal(Enums.Stance.STAND)
	Settings.set_value(&"gameplay", &"crouch_toggle", original)


func test_throw_fires_on_release_and_marks_cook_after_hold() -> void:
	var c := _player_controller()
	var intent := Intent.new()
	Input.action_press(&"equip_1")
	await _tick(c, intent)
	assert_int(intent.throw_equipment).is_equal(-1)
	for _i: int in 24:
		await _tick(c, intent)
	Input.action_release(&"equip_1")
	await _tick(c, intent)
	assert_int(intent.throw_equipment).is_equal(0)
	assert_bool(intent.cook).is_true()


func test_quick_tap_throw_is_not_cooked() -> void:
	var c := _player_controller()
	var intent := Intent.new()
	Input.action_press(&"equip_2")
	await _tick(c, intent)
	Input.action_release(&"equip_2")
	await _tick(c, intent)
	assert_int(intent.throw_equipment).is_equal(1)
	assert_bool(intent.cook).is_false()


func test_ai_stub_maps_setters_to_intent() -> void:
	var c := _ai_controller()
	var intent := Intent.new()
	c.call(&"set_move_target", Vector2.LEFT)
	c.call(&"set_stance", Enums.Stance.CROUCH)
	c.call(&"set_fire", true)
	c.call(&"set_focus", true)
	c.call(&"set_sprint", true)
	c.call(&"set_aim_target", Vector2.DOWN)
	await _tick(c, intent)
	assert_vector(intent.move).is_equal(Vector2.LEFT)
	assert_vector(intent.aim).is_equal(Vector2.DOWN)
	assert_int(intent.stance).is_equal(Enums.Stance.CROUCH)
	assert_bool(intent.fire).is_true()
	assert_bool(intent.fire_press).is_true()
	assert_bool(intent.focus).is_true()
	assert_bool(intent.sprint).is_true()
	# Fire is an edge: holding does not re-trigger.
	await _tick(c, intent)
	assert_bool(intent.fire).is_true()
	assert_bool(intent.fire_press).is_false()


func test_ai_stub_idles_with_the_character_aim() -> void:
	var c := _ai_controller()
	var intent := Intent.new()
	await _tick(c, intent)
	assert_vector(intent.move).is_equal(Vector2.ZERO)
	assert_bool(intent.fire).is_false()
	assert_vector(intent.aim).is_equal(Vector2.RIGHT)