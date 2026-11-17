extends Node
## Game — autoload. App flow between screens, owns the pending MatchConfig and
## the last MatchResult. Contract: docs/architecture.md §3.5.
## UI scenes arrive in a later wave; a missing scene is a graceful error, not a
## crash, so core development (tests, sims) never depends on UI.

const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"
const LOBBY_SCENE := "res://src/ui/menus/lobby_screen.tscn"
const MATCH_SCENE := "res://src/modes/match/match.tscn"
const DEBRIEF_SCENE := "res://src/ui/menus/debrief_screen.tscn"
const CREDITS_SCENE := "res://src/ui/menus/credits_screen.tscn"
const SETTINGS_SCENE := "res://src/ui/menus/settings_screen.tscn"

## Fade timing (seconds). Short enough to feel instant, long enough to hide load.
const FADE_OUT_S := 0.18
const FADE_IN_S := 0.18
const FADE_LAYER := 100
const FADE_COLOR := Color(0.043, 0.055, 0.078, 1.0)

var current_scene_kind: StringName = &""
var match_config: MatchConfig = null
var last_result: MatchResult = null
## The seed actually used by the running/last match (0 until first to_match).
var match_seed: int = 0

var _fade_rect: ColorRect = null
var _leaving := false

func _ready() -> void:
	_build_fade_overlay()

func to_title() -> void:
	_go(TITLE_SCENE, &"title", false)

func to_lobby() -> void:
	_go(LOBBY_SCENE, &"lobby", false)

func to_match(config: MatchConfig) -> void:
	if config == null:
		push_error("Game.to_match: config is null")
		return
	if config.seed == 0:
		config.seed = randi()
	match_seed = config.seed
	match_config = config
	_go(MATCH_SCENE, &"match", true)

func to_debrief(result: MatchResult) -> void:
	last_result = result
	_go(DEBRIEF_SCENE, &"debrief", false)

func to_credits() -> void:
	_go(CREDITS_SCENE, &"credits", false)

func to_settings() -> void:
	_go(SETTINGS_SCENE, &"settings", false)

func quit() -> void:
	get_tree().quit()

## Pause menu → abandon the match; no result recorded.
func surrender() -> void:
	quit_match()

func quit_match() -> void:
	match_config = null
	to_lobby()

func _go(scene_path: String, kind: StringName, capture_mouse: bool) -> void:
	if _leaving:
		return
	if not ResourceLoader.exists(scene_path):
		push_error("Game: scene missing %s (UI wave pending)" % scene_path)
		return
	_leaving = true
	_capture_mouse(capture_mouse)
	await _fade_out()
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("Game: change_scene_to_file(%s) failed: %d" % [scene_path, err])
		_leaving = false
		await _fade_in()
		return
	current_scene_kind = kind
	await _fade_in()
	_leaving = false

func _capture_mouse(capture: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE

func _build_fade_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = FADE_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(FADE_COLOR, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)
	add_child(layer)

## Headless: no rendering, no tween frames to wait on — skip entirely so
## scripted flows (menu smoke test) do not depend on the renderer.
func _fade_out() -> void:
	if DisplayServer.get_name() == "headless" or _fade_rect == null:
		return
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_S)
	await tween.finished

func _fade_in() -> void:
	if DisplayServer.get_name() == "headless" or _fade_rect == null:
		return
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_S)
	await tween.finished