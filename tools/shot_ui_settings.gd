extends Control
## Settings tab fixture: opens a chosen tab so each page is screenshot-verifiable.
##   tools/godot.sh --path . --resolution 2560x1440 -- \
##     --shot=res://tools/shot_ui_settings.tscn:25:reports/screenshots/ui_settings_controls.png
## Tab index comes from the `--tab=` user arg (0..3), default 0.

const Screen := preload("res://src/ui/menus/settings_screen.tscn")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = Screen.instantiate()
	add_child(screen)
	var tab := 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tab="):
			tab = int(arg.trim_prefix("--tab="))
	await get_tree().process_frame
	await get_tree().process_frame
	screen.call(&"_show_tab", clampi(tab, 0, 3))