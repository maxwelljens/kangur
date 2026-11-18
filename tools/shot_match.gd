extends Node2D
## Screenshot fixture: boots a real Match (player + bots) and lets the renderer
## run so the HUD, fog, rigs and effects are inspectable in one frame.
##
##   tools/godot.sh --path . --resolution 2560x1440 -- \
##     --shot=res://tools/shot_match.tscn:180:reports/screenshots/match_dustworks.png
##
## User args: --mode=0|1|2 --map=dustworks --bots=6 --warmup=200 --seed=1
##            --drive (hands the player body to the AI so the frame shows combat)

const MatchScene := preload("res://src/modes/match/match.tscn")

var run: Match = null
var _warmup := 150
var _drive := false
var _ticks := 0

func _ready() -> void:
	var mode := Enums.Mode.ELIMINATION
	var map_id := &"dustworks"
	var bots := 6
	var seed_value := 7
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = int(arg.trim_prefix("--mode="))
		elif arg.begins_with("--map="):
			map_id = StringName(arg.trim_prefix("--map="))
		elif arg.begins_with("--bots="):
			bots = int(arg.trim_prefix("--bots="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--warmup="):
			_warmup = int(arg.trim_prefix("--warmup="))
		elif arg == "--drive":
			_drive = true

	var config := MatchConfig.new()
	config.mode = mode
	config.map_id = map_id
	config.player_team = Enums.Team.BASTION
	config.player_class_id = &"vanguard"
	config.primary_id = &"kestrel"
	config.sidearm_id = &"adder"
	config.bot_count_bastion = bots
	config.bot_count_sirocco = bots + 1
	config.difficulty_id = &"veteran"
	config.seed = seed_value
	Game.match_config = config
	Game.match_seed = seed_value

	run = MatchScene.instantiate() as Match
	add_child(run)
	# Wait until the deferred start() has built the world and HUD.
	while not run.running:
		await get_tree().process_frame

	# Let the real loop run: bots path, fight, and the HUD fills. The player is
	# driven through the AI controller so the frame shows combat, not a statue.
	if _drive and run.player != null:
		run.player.controller.set_script(load("res://src/entities/ai_controller.gd"))
		run.player.controller.call(&"setup", run.player)


func _physics_process(_dt: float) -> void:
	_ticks += 1
	if _ticks >= _warmup and run != null and run.hud != null:
		# One last HUD push so the captured frame is fully populated.
		run.call(&"_feed_hud")
		set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"screenshot"):
		return