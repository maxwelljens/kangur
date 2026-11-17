extends Control
class_name MenuScreen
## Shared shell for menu screens: theme, scanline overlay, fade-in entrance,
## mouse release, and the common Back/Esc behaviour.
## Screens call `_build()` from their `_ready()`; content is added to `body`.

const KangurTheme := preload("res://src/ui/theme.gd")
const UiFx := preload("res://src/ui/ui_fx.gd")
const HW := preload("res://src/ui/holo_widgets.gd")

## Root of the screen content. Present once `_ready()` has run.
var body: Control = null
## Screens that should NOT quit on Esc (match HUD is not a MenuScreen anyway).
@export var closes_on_esc: bool = true

var _scanlines: Control = null

func _ready() -> void:
	theme = load("res://src/ui/kangur_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	body = Control.new()
	body.name = "Body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(body)
	_build()
	_add_scanlines()
	UiFx.fade_in(self, 0.0)
	_on_ready_done()

## Screens override to build their layout inside `body`.
func _build() -> void:
	pass

## Screens override for post-build binding (signals, defaults, first focus).
func _on_ready_done() -> void:
	pass

func _add_scanlines() -> void:
	_scanlines = Control.new()
	_scanlines.name = "Scanlines"
	_scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scanlines.draw.connect(_draw_scanlines)
	add_child(_scanlines)

func _draw_scanlines() -> void:
	# Subtle holo scanlines over menus only (HUD scanlines would fight the game).
	var y := 0.0
	while y < _scanlines.size.y:
		_scanlines.draw_line(Vector2(0.0, y), Vector2(_scanlines.size.x, y),
			KangurTheme.SCANLINE, 1.0)
		y += 3.0

func _unhandled_input(event: InputEvent) -> void:
	if closes_on_esc and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		UiFx.back()
		_on_back()

## Default: title screen. Lobby/settings/credits override to their parent.
func _on_back() -> void:
	Game.to_title()
