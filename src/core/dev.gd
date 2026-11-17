extends Node
## Dev — autoload. CLI harness (screenshot, sim) + in-game dev actions.
## Contract: docs/architecture.md §3.6, §11.

signal sim_requested(request: SimRequest)

const SCREENSHOT_DIR := "res://reports/screenshots"
const DEFAULT_SHOT_FRAMES := 20
const SIM_HANDLER_TIMEOUT_S := 1.0

## Manual fast-forward multiplier for headless sims (simulation module reads it).
var sim_speed: float = 1.0
## Last parsed sim request (kept for the simulation runner / debugging).
var sim_request: SimRequest = null
## True while --shot/--sim owns the boot; the main scene must not forward.
var harness_active: bool = false

var _args: PackedStringArray = []

func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	var shot := _arg_value("--shot=")
	if not shot.is_empty():
		harness_active = true
		_run_shot(shot)
		return
	var sim := _arg_value("--sim=")
	if not sim.is_empty():
		harness_active = true
		_run_sim(sim)

func is_dev() -> bool:
	return OS.is_debug_build() or _args.has("--dev")

## Capture the root viewport to a PNG. Returns true on success. `path` may be
## absolute, `res://`/`user://`, or relative to the project root.
func capture_screenshot(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return false
	var abs_path := _absolute(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	return image.save_png(abs_path) == OK

func _unhandled_input(event: InputEvent) -> void:
	if not is_dev() or not event.is_action_pressed(&"screenshot"):
		return
	get_viewport().set_input_as_handled()
	# Input runs before this frame is drawn; wait for the swap so the capture
	# includes what the player actually sees.
	await RenderingServer.frame_post_draw
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/shot_%s.png" % [SCREENSHOT_DIR, stamp]
	if capture_screenshot(path):
		print("SHOT_OK %s" % _absolute(path))
	else:
		push_warning("Dev: screenshot failed (headless or no viewport texture)")

## Parse right-to-left: scene paths contain a colon (`res://`), the frame
## count does not, and the output path is always last.
func _run_shot(spec: String) -> void:
	if DisplayServer.get_name() == "headless":
		_fail_shot("headless")
		return
	var tail := spec.rsplit(":", true, 1)
	if tail.size() != 2:
		_fail_shot("bad --shot spec (want <scene>:<frames>:<out.png>)")
		return
	var out_path := tail[1]
	var head := tail[0]
	var frames := DEFAULT_SHOT_FRAMES
	var scene_path := head
	var frame_split := head.rsplit(":", true, 1)
	if frame_split.size() == 2 and frame_split[1].is_valid_int():
		scene_path = frame_split[0]
		frames = maxi(int(frame_split[1]), 1)
	if not out_path.ends_with(".png"):
		_fail_shot("output path must end with .png")
		return
	var packed := ResourceLoader.load(scene_path) as PackedScene
	if packed == null:
		_fail_shot("cannot load scene %s" % scene_path)
		return
	# Autoload _ready runs before the main scene enters the tree; changing scene
	# now would race the pending main-scene load.
	await get_tree().process_frame
	var target := get_tree().current_scene
	if target == null or target.scene_file_path != scene_path:
		var err := get_tree().change_scene_to_packed(packed)
		if err != OK:
			_fail_shot("change_scene_to_packed(%s) failed: %d" % [scene_path, err])
			return
	for i: int in frames:
		await RenderingServer.frame_post_draw
	if capture_screenshot(out_path):
		print("SHOT_OK %s" % _absolute(out_path))
		get_tree().quit(0)
	else:
		_fail_shot("capture failed")

func _run_sim(spec: String) -> void:
	var request := SimRequest.parse(spec)
	if request == null:
		print("SIM_FAIL bad --sim spec (want <map>:<mode>:<seed>:<count>)")
		get_tree().quit(1)
		return
	sim_request = request
	sim_requested.emit(request)
	# The simulation module connects when it boots; none yet = not implemented.
	await get_tree().create_timer(SIM_HANDLER_TIMEOUT_S).timeout
	if sim_requested.get_connections().is_empty():
		print("SIM_FAIL no-handler")
		get_tree().quit(1)

func _fail_shot(reason: String) -> void:
	print("SHOT_FAIL %s" % reason)
	get_tree().quit(1)

func _arg_value(prefix: String) -> String:
	for arg: String in _args:
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""

func _absolute(path: String) -> String:
	if path.is_absolute_path():
		return path
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return ProjectSettings.globalize_path("res://" + path)