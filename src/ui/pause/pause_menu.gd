extends Control
## Pause overlay for the match. Esc toggles (input action `pause`).
## Lives in the HUD's CanvasLayer; pauses the tree with PROCESS_MODE_ALWAYS.
## Resume / Settings / Surrender→lobby / Quit to title.

const KangurTheme := preload("res://src/ui/theme.gd")
const UiFx := preload("res://src/ui/ui_fx.gd")
const HW := preload("res://src/ui/holo_widgets.gd")
const HoloButtonScript := preload("res://src/ui/holo_button.gd")

signal resumed

const PANEL_W := 380.0

var _panel: HW.Plate = null
var _buttons: Array[Control] = []

func _ready() -> void:
	theme = load("res://src/ui/kangur_theme.tres")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func _build() -> void:
	var veil := ColorRect.new()
	veil.color = Color(KangurTheme.BACKDROP, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	_panel = HW.Plate.new()
	_panel.title = "OPERATION PAUSED"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(PANEL_W, 340.0)
	_panel.offset_left = -PANEL_W * 0.5
	_panel.offset_right = PANEL_W * 0.5
	_panel.offset_top = -170.0
	_panel.offset_bottom = 170.0
	add_child(_panel)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 26.0
	column.offset_right = -26.0
	column.offset_top = 46.0
	column.add_theme_constant_override(&"separation", 10)
	_panel.add_child(column)

	var state := Label.new()
	state.text = _match_line()
	state.theme_type_variation = &"MonoSmall"
	state.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(state)
	column.add_child(_gap(8))

	_buttons.clear()
	_buttons.append(_button(column, "RESUME", _resume, true))
	_buttons.append(_button(column, "SETTINGS", _settings))
	_buttons.append(_button(column, "SURRENDER", _surrender))
	_buttons.append(_button(column, "QUIT TO TITLE", _quit_title))

func _match_line() -> String:
	var config := Game.match_config
	if config == null:
		return "no active contract"
	var mode := "ELIMINATION" if config.mode == Enums.Mode.ELIMINATION else \
		("BATTLE" if config.mode == Enums.Mode.BATTLE else "TRAINING")
	return "%s · %s · SEED %08X" % [mode, String(config.map_id).to_upper(), Game.match_seed]

func _gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer

func _button(parent: VBoxContainer, text: String, action: Callable,
		primary: bool = false) -> HoloButton:
	var button := HoloButtonScript.new() as HoloButton
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.primary = primary
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

## Called by the HUD when Esc is pressed; returns the new visibility.
func toggle() -> bool:
	if visible:
		_resume()
		return false
	open()
	return true

func open() -> void:
	visible = true
	_panel.modulate.a = 0.0
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UiFx.play_sound(&"notify")
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, UiFx.FADE_S)
	UiFx.stagger(_buttons, 0.03)
	(_buttons[0] as Control).grab_focus()

func _resume() -> void:
	UiFx.back()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()

func _settings() -> void:
	# Settings swaps the scene, so drop the pause before handing over.
	visible = false
	get_tree().paused = false
	Game.to_settings()

func _surrender() -> void:
	visible = false
	get_tree().paused = false
	Game.surrender()

func _quit_title() -> void:
	visible = false
	get_tree().paused = false
	Game.quit_match()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_resume()