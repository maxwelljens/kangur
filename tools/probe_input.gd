extends Node
## Empirical input probe: does the W physical-key binding drive move_up?

func _ready() -> void:
	InputDefaults.install()
	for e: InputEvent in InputMap.action_get_events(&"move_up"):
		if e is InputEventKey:
			print("move_up binding physical=", (e as InputEventKey).physical_keycode,
				" keycode=", (e as InputEventKey).keycode)
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	w.pressed = true
	Input.parse_input_event(w)
	await get_tree().process_frame
	await get_tree().process_frame
	print("W pressed -> move_up=", Input.is_action_pressed(&"move_up"),
		" strength=", Input.get_action_strength(&"move_up"),
		" vector=", InputDefaults.move_vector())
	w.pressed = false
	Input.parse_input_event(w)
	await get_tree().process_frame
	var u := InputEventKey.new()
	u.physical_keycode = KEY_UP
	u.pressed = true
	Input.parse_input_event(u)
	await get_tree().process_frame
	await get_tree().process_frame
	print("UP pressed -> move_up=", Input.is_action_pressed(&"move_up"),
		" vector=", InputDefaults.move_vector())
	get_tree().quit(0)
