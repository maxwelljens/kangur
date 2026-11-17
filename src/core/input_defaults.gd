class_name InputDefaults
extends RefCounted
## Default InputMap bindings. Contract: docs/architecture.md §8.
## Binding descriptors are plain Dictionaries so Settings can persist and
## restore them in ConfigFile/JSON:
##   {&"type": &"key", &"physical": Key}
##   {&"type": &"mouse", &"button": MouseButton}

## Digital movement actions get a deadzone so a partly-pressed axis is ignored.
const MOVE_DEADZONE := 0.2
const MOVE_ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
]

const BINDINGS: Dictionary[StringName, Array] = {
	&"move_up": [
		{&"type": &"key", &"physical": KEY_W},
		{&"type": &"key", &"physical": KEY_UP},
	],
	&"move_down": [
		{&"type": &"key", &"physical": KEY_S},
		{&"type": &"key", &"physical": KEY_DOWN},
	],
	&"move_left": [
		{&"type": &"key", &"physical": KEY_A},
		{&"type": &"key", &"physical": KEY_LEFT},
	],
	&"move_right": [
		{&"type": &"key", &"physical": KEY_D},
		{&"type": &"key", &"physical": KEY_RIGHT},
	],
	&"sprint": [{&"type": &"key", &"physical": KEY_SHIFT}],
	&"crouch": [{&"type": &"key", &"physical": KEY_CTRL}],
	&"fire": [{&"type": &"mouse", &"button": MOUSE_BUTTON_LEFT}],
	&"focus": [{&"type": &"mouse", &"button": MOUSE_BUTTON_RIGHT}],
	&"reload": [{&"type": &"key", &"physical": KEY_R}],
	&"bandage": [{&"type": &"key", &"physical": KEY_B}],
	&"use": [{&"type": &"key", &"physical": KEY_E}],
	&"slot_primary": [{&"type": &"key", &"physical": KEY_1}],
	&"slot_sidearm": [{&"type": &"key", &"physical": KEY_2}],
	&"cycle_mode": [{&"type": &"key", &"physical": KEY_X}],
	&"equip_1": [{&"type": &"key", &"physical": KEY_G}],
	&"equip_2": [{&"type": &"key", &"physical": KEY_F}],
	&"cook": [{&"type": &"key", &"physical": KEY_G}],
	&"scoreboard": [{&"type": &"key", &"physical": KEY_TAB}],
	&"pause": [{&"type": &"key", &"physical": KEY_ESCAPE}],
	&"screenshot": [{&"type": &"key", &"physical": KEY_F12}],
	&"debug_overlay": [{&"type": &"key", &"physical": KEY_F3}],
	&"spectate_next": [{&"type": &"key", &"physical": KEY_SPACE}],
}

## Build every action from scratch. Safe to call repeatedly (hot reload).
static func install() -> void:
	for action: StringName in BINDINGS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		if MOVE_ACTIONS.has(action):
			InputMap.action_set_deadzone(action, MOVE_DEADZONE)
		for binding: Dictionary in BINDINGS[action]:
			apply_binding(action, binding)

## Replace one action's events with a single descriptor.
static func apply_binding(action: StringName, binding: Dictionary) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	else:
		InputMap.action_erase_events(action)
	var event := event_from(binding)
	if event != null:
		InputMap.action_add_event(action, event)

static func event_from(binding: Dictionary) -> InputEvent:
	match binding.get(&"type", &""):
		&"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(binding.get(&"physical", 0))
			return key
		&"mouse":
			var click := InputEventMouseButton.new()
			click.button_index = int(binding.get(&"button", 0))
			return click
	return null

## Descriptor for a captured InputEvent; null when we cannot persist it
## (joypad/gesture events are out of scope per design §14).
static func binding_from(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.physical_keycode != KEY_NONE:
			return {&"type": &"key", &"physical": key.physical_keycode}
		return {&"type": &"key", &"physical": key.keycode}
	if event is InputEventMouseButton:
		return {&"type": &"mouse", &"button": (event as InputEventMouseButton).button_index}
	return {}

## Digital WASD/arrow movement as a normalized vector (length 0..1).
static func move_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")