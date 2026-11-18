extends Node
## PlayerController — fills an Intent from the InputMap each physics tick.
## Contract: docs/architecture.md §4 (controllers produce Intent; Character
## consumes it). Crouch/focus/sprint follow Settings gameplay toggles.

## Cook window: holding a frag throw this long before release detonates early.
const COOK_HOLD_S := 0.3
## Default stance when the player has no controller state yet.
var _crouch_toggle: bool = false
var _sprint_latch: bool = false
var _focus_latch: bool = false

var _host: Node2D = null

func setup(host: Node2D) -> void:
	_host = host

## Build/refresh the Intent for this tick. `intent` is reused (no allocation).
func fill_intent(intent: Intent, dt: float) -> void:
	intent.clear_edges()
	intent.move = InputDefaults.move_vector()
	intent.aim = _aim_vector()
	intent.fire = Input.is_action_pressed(&"fire")
	intent.fire_press = Input.is_action_just_pressed(&"fire")
	intent.focus = _focus_held()
	intent.sprint = _sprint_held()
	intent.stance = Enums.Stance.CROUCH if _crouch_held() else Enums.Stance.STAND
	intent.reload = Input.is_action_just_pressed(&"reload")
	intent.bandage = Input.is_action_pressed(&"bandage")
	intent.switch_slot = _slot_edge()
	intent.cycle_fire_mode = Input.is_action_just_pressed(&"cycle_mode")
	intent.interact = Input.is_action_pressed(&"use")
	_fill_throw(intent, dt)

## World-space direction to the cursor, normalized. Falls back to the last
## non-zero aim so a pointer sitting on the character does not snap the rig.
func _aim_vector() -> Vector2:
	if _host == null:
		return Vector2.RIGHT
	var delta := _host.get_global_mouse_position() - _host.global_position
	if delta.length() < 1.0:
		var last: Variant = _host.get(&"aim_dir")
		return last if last is Vector2 else Vector2.RIGHT
	return delta.normalized()

func _crouch_held() -> bool:
	if bool(Settings.get_value(&"gameplay", &"crouch_toggle", true)):
		if Input.is_action_just_pressed(&"crouch"):
			_crouch_toggle = not _crouch_toggle
		return _crouch_toggle
	return Input.is_action_pressed(&"crouch")

func _focus_held() -> bool:
	if not bool(Settings.get_value(&"gameplay", &"focus_toggle", false)):
		return Input.is_action_pressed(&"focus")
	if Input.is_action_just_pressed(&"focus"):
		_focus_latch = not _focus_latch
	return _focus_latch

func _sprint_held() -> bool:
	if not bool(Settings.get_value(&"gameplay", &"sprint_toggle", false)):
		return Input.is_action_pressed(&"sprint")
	if Input.is_action_just_pressed(&"sprint"):
		_sprint_latch = not _sprint_latch
	return _sprint_latch

## 0 primary, 1 sidearm, -1 none (edge).
func _slot_edge() -> int:
	if Input.is_action_just_pressed(&"slot_primary"):
		return 0
	if Input.is_action_just_pressed(&"slot_sidearm"):
		return 1
	return -1

## equip_1/equip_2 map to kit indices. Release throws; holding past
## COOK_HOLD_S flags intent.cook so the EquipmentSystem shortens the fuse.
var _throw_slot: int = -1
var _throw_hold: float = 0.0

func _fill_throw(intent: Intent, dt: float) -> void:
	if Input.is_action_just_pressed(&"equip_1"):
		_throw_slot = 0
		_throw_hold = 0.0
	elif Input.is_action_just_pressed(&"equip_2"):
		_throw_slot = 1
		_throw_hold = 0.0
	if _throw_slot < 0:
		return
	_throw_hold += dt
	if Input.is_action_just_released(&"equip_1") or Input.is_action_just_released(&"equip_2"):
		intent.throw_equipment = _throw_slot
		intent.cook = _throw_hold >= COOK_HOLD_S
		_throw_slot = -1
		_throw_hold = 0.0