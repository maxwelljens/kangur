extends Control
## Credits fixture scrolled to the music section: the Incompetech titles must be
## visible and named individually (licence requirement). Also proves the long
## document scrolls and stays legible deep in.
##   tools/godot.sh --path . --resolution 2560x1440 -- \
##     --shot=res://tools/shot_ui_credits_music.tscn:30:reports/screenshots/ui_credits_music.png

const Screen := preload("res://src/ui/menus/credits_screen.tscn")
## Approximate scroll offset of §7 Audio — music in the rendered document.
const SCROLL_TO := 12800.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = Screen.instantiate()
	add_child(screen)
	for _i: int in 3:
		await get_tree().process_frame
	var scroll: ScrollContainer = screen.get(&"_scroll")
	if scroll != null:
		scroll.scroll_vertical = int(SCROLL_TO)
