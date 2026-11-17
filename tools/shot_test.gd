extends Control
## Minimal permanent screenshot fixture: proves the Dev --shot path end-to-end
## without depending on any UI wave. Run:
##   tools/godot.sh --path . -- --shot=res://tools/shot_test.tscn:5:reports/screenshots/smoke.png

const BACKGROUND := Color(0.043, 0.055, 0.078)
const PANEL := Color(0.95, 0.65, 0.25)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var panel := ColorRect.new()
	panel.color = PANEL
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -160.0
	panel.offset_top = -90.0
	panel.offset_right = 160.0
	panel.offset_bottom = 90.0
	add_child(panel)
	var label := Label.new()
	label.text = "Kangur shot fixture"
	label.add_theme_font_size_override(&"font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -160.0
	label.offset_top = -90.0
	label.offset_right = 160.0
	label.offset_bottom = 90.0
	add_child(label)