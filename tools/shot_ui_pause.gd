extends Control
## Pause-menu screenshot fixture. The overlay is hidden by design until Esc, so
## this fixture opens it over a dark match-like backdrop.
##   tools/godot.sh --path . --resolution 2560x1440 -- \
##     --shot=res://tools/shot_ui_pause.tscn:25:reports/screenshots/ui_pause.png

const PauseScene := preload("res://src/ui/pause/pause_menu.tscn")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("141a20")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	Game.match_config = MatchConfig.new()
	Game.match_config.mode = Enums.Mode.BATTLE
	Game.match_config.map_id = &"terminal"
	Game.match_seed = 0x51cc0
	var menu: Control = PauseScene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.open()
