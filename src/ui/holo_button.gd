extends Button
class_name HoloButton
## Holo menu button: bracket-corner plate, hover glow sweep, press depth.
## Base Button so it keeps keyboard focus, `pressed` and accessibility.
## Palette comes from the theme; only geometry lives here.

const KangurTheme := preload("res://src/ui/theme.gd")
const UiFx := preload("res://src/ui/ui_fx.gd")

const BRACKET := 10.0
const HOVER_S := 0.14

## Draw an accent marker when this is the screen's primary call to action.
@export var primary: bool = false

var _glow := 0.0

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = 40.0
	add_theme_stylebox_override(&"normal", _box(false))
	add_theme_stylebox_override(&"hover", _box(true))
	add_theme_stylebox_override(&"pressed", _pressed_box())
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	resized.connect(queue_redraw)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _box(hot: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(KangurTheme.PANEL_SOLID,
		0.9 if hot else 0.55)
	box.content_margin_left = 20
	box.content_margin_right = 16
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	box.border_color = Color(KangurTheme.HOLO, 0.9 if hot else 0.22)
	box.set_border_width_all(1)
	return box

func _pressed_box() -> StyleBoxFlat:
	var box := _box(true)
	box.bg_color = Color(KangurTheme.HOLO, 0.16)
	box.border_color = KangurTheme.HOLO
	return box

func _on_hover() -> void:
	UiFx.play_sound(&"hover")
	_animate_glow(1.0)

func _on_unhover() -> void:
	_animate_glow(0.0)

func _animate_glow(target: float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_glow, _glow, target, HOVER_S).set_trans(Tween.TRANS_CUBIC)
	queue_redraw()

func _set_glow(value: float) -> void:
	_glow = value
	queue_redraw()

func _draw() -> void:
	var accent := KangurTheme.HOLO if not primary else KangurTheme.AMBER
	var ink := Color(accent, 0.25 + 0.6 * _glow)
	if has_focus() and not _glow >= 0.5:
		ink = Color(accent, 0.5)
	var arm := BRACKET
	for corner: Vector2 in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
		var sx := 1.0 if corner.x <= 0.0 else -1.0
		var sy := 1.0 if corner.y <= 0.0 else -1.0
		draw_line(corner, corner + Vector2(arm * sx, 0.0), ink, 1.5, true)
		draw_line(corner, corner + Vector2(0.0, arm * sy), ink, 1.5, true)
	if primary or _glow > 0.0:
		var bar := 6.0 * (0.4 + 0.6 * _glow)
		draw_rect(Rect2(Vector2(0.0, size.y * 0.5 - bar * 0.5),
			Vector2(2.0 + 2.0 * _glow, bar)), accent)