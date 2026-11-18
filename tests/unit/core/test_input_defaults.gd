extends GdUnitTestSuite
## Regression: install() must keep EVERY binding per action. A prior bug called
## apply_binding() (single-rebind erase semantics) in a loop, dropping all but
## the last binding — WASD was erased, leaving only arrow keys.

func test_install_keeps_all_bindings_per_action() -> void:
	InputDefaults.install()
	for action: StringName in InputDefaults.MOVE_ACTIONS:
		var events := InputMap.action_get_events(action)
		assert_int(events.size()).is_equal(2)
	var physicals: Array[int] = []
	for e: InputEvent in InputMap.action_get_events(&"move_up"):
		physicals.append((e as InputEventKey).physical_keycode)
	assert_bool(physicals.has(KEY_W)).is_true()
	assert_bool(physicals.has(KEY_UP)).is_true()

func test_all_default_actions_registered() -> void:
	InputDefaults.install()
	for action: StringName in InputDefaults.BINDINGS:
		assert_bool(InputMap.has_action(action)).is_true()
		assert_bool(InputMap.action_get_events(action).size() >= 1).is_true()
