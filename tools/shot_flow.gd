extends Node
## Full game-flow verification with rendering: TITLE → LOBBY → MATCH (real
## Match, player + bots, HUD mid-combat) → DEBRIEF. Each stage is captured, so a
## broken transition fails loudly instead of silently rendering the old screen.
##
##   DISPLAY=:0 tools/godot.sh --path . --resolution 2560x1440 \
##     tools/shot_flow.tscn -- --mode=0 --map=dustworks --bots=6
##
## It drives Game's real transitions, so it moves itself to the tree root first:
## a scene-change would otherwise free this fixture mid-flow. Args:
## --mode=0|1 --map=dustworks --bots=6 --seed=7 --combat-frames=260

const MatchScene := preload("res://src/modes/match/match.tscn")

var _mode := Enums.Mode.ELIMINATION
var _map_id := &"dustworks"
var _bots := 6
var _seed := 7
var _combat_frames := 260
var _failures: Array[String] = []
## The Game autoload. `_init` runs before the node is in the tree, so resolve it
## lazily once the scene exists.
var FlowGame: Node = null


func _ready() -> void:
	# Game swaps scenes four times below, and change_scene() frees whatever
	# `current_scene` points at. Detach, re-add under root, and clear the
	# pointer so this fixture survives the flow. Deferred: _ready itself runs
	# inside a tree edit.
	var tree := get_tree()
	tree.root.remove_child.call_deferred(self)
	await get_tree().process_frame
	tree.root.add_child(self)
	tree.current_scene = null
	FlowGame = tree.root.get_node(^"Game")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = int(arg.trim_prefix("--mode="))
		elif arg.begins_with("--map="):
			_map_id = StringName(arg.trim_prefix("--map="))
		elif arg.begins_with("--bots="):
			_bots = int(arg.trim_prefix("--bots="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--combat-frames="):
			_combat_frames = int(arg.trim_prefix("--combat-frames="))
	await _run()
	print("FLOW %s %s" % ["OK" if _failures.is_empty() else "FAIL",
		" | ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	# TITLE
	var title := await _goto(FlowGame.TITLE_SCENE)
	await _settle()
	await _shot("reports/screenshots/flow_title.png")
	if title == null:
		_failures.append("title did not load")
		return

	# LOBBY
	FlowGame.to_lobby()
	await _settle(30)
	await _shot("reports/screenshots/flow_lobby.png")
	if not _current_is(FlowGame.LOBBY_SCENE):
		_failures.append("Game.to_lobby did not swap scenes")
		return

	# MATCH — build the config the lobby would deploy, go through Game so the
	# real transition path (fade + capture) is exercised.
	var config := MatchConfig.new()
	config.mode = _mode
	config.map_id = _map_id
	config.player_team = Enums.Team.BASTION
	config.player_class_id = &"vanguard"
	config.primary_id = &"kestrel"
	config.sidearm_id = &"adder"
	config.bot_count_bastion = _bots
	config.bot_count_sirocco = _bots + 1
	config.difficulty_id = &"veteran"
	config.seed = _seed
	config.player_callsign = "Kestrel"
	FlowGame.to_match(config)
	await _settle(4)
	# Poll for the scene swap instead of guessing a duration: a loaded machine
	# stalls the fade tweens, and a fixed sleep is what made this flaky in the
	# gate (passing standalone, failing while three sims had just run).
	var arena: Match = null
	for _i: int in 600:
		arena = get_tree().current_scene as Match
		if arena != null:
			break
		await get_tree().process_frame
	if arena == null:
		_failures.append("Game.to_match did not land on the Match scene")
		return
	while not arena.running:
		await get_tree().process_frame
	# Hand the player body to the AI so the captured frame shows a firefight.
	if arena.player != null:
		arena.player.controller.set_script(load("res://src/entities/ai_controller.gd"))
		arena.player.controller.call(&"setup", arena.player)
	for i: int in _combat_frames:
		await get_tree().process_frame
	if arena.hud == null:
		_failures.append("match has no HUD")
	await _shot("reports/screenshots/flow_match.png")
	await _check_hud(arena)

	# Force the end (a real 8-minute match would eat the gate) and let the
	# match's own debrief transition run.
	# A real reason so the debrief banner renders its authored copy rather than
	# the "no reason recorded" fallback.
	arena.force_finish(Enums.Team.BASTION, &"elimination")
	# Poll for the hand-off rather than sleeping the exact delay: it is a Timer
	# plus two fades, and a fixed sleep flakes when the machine is busy.
	var handed_over := false
	for _i: int in 900:
		if _current_is(FlowGame.DEBRIEF_SCENE):
			handed_over = true
			break
		await get_tree().process_frame
	# Let Game's fade-in finish (matched event, not a race with the tween).
	for _i: int in 120:
		if not bool(FlowGame.get(&"_leaving")):
			break
		await get_tree().process_frame
	await _settle(20)
	await _shot("reports/screenshots/flow_debrief.png")
	if not handed_over:
		_failures.append("match did not hand over to the debrief")


## HUD truth check: the widgets must reflect the live match, not placeholders.
func _check_hud(arena: Match) -> void:
	var alive: Array = arena.hud.get(&"_alive")
	if alive.size() != 2 or int(alive[0]) + int(alive[1]) <= 0:
		_failures.append("HUD alive counts empty")
	var roster: Array = arena.hud.get(&"_roster")
	if roster.size() != arena.characters.size():
		_failures.append("HUD roster %d != %d characters" % [
			roster.size(), arena.characters.size()])
	var body: BodyModel = arena.hud.get(&"body")
	if body == null:
		_failures.append("HUD body model unbound")
	var objectives: Array = arena.rules_runner.objective_rows
	if _mode == Enums.Mode.BATTLE and objectives.size() != 3:
		_failures.append("Battle objective chain has %d nodes" % objectives.size())


func _goto(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		_failures.append("cannot load %s" % path)
		return null
	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		_failures.append("change_scene_to_packed(%s) = %d" % [path, err])
		return null
	await get_tree().process_frame
	return get_tree().current_scene


func _current_is(path: String) -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == path


## Let fades/entrance tweens finish and one frame render.
func _settle(frames: int = 26) -> void:
	for i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	if not Dev.capture_screenshot(path):
		_failures.append("screenshot failed: %s" % path)