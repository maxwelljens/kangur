extends Node2D
## Whole-map overview shot for visual inspection.
##   tools/godot.sh --path . -- --shot=res://tools/shot_map.tscn:15:reports/screenshots/dustworks.png
##   tools/godot.sh --path . -- --shot=res://tools/shot_map.tscn:15:reports/screenshots/compound.png --map=compound
##
## Fits a Camera2D to the map's Bounds so every lane is visible at once. The
## capture itself is the Dev autoload's --shot path (display required; --shot
## refuses to run headless rather than hanging).

const DEFAULT_MAP := &"dustworks"
## Fraction of the viewport the map may fill; leaves a dark margin so the map
## silhouette is readable against the clear colour.
const FIT_MARGIN := 0.96

@export var map_id: StringName = DEFAULT_MAP


func _ready() -> void:
	# `--map=` selects the map; --shot's own args are read by Dev, not here.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = StringName(arg.trim_prefix("--map="))

	var world := World.new()
	world.map_scene_path = "res://maps/%s/map.tscn" % map_id
	add_child(world)
	if world.map == null:
		push_error("shot_map: cannot load map '%s'" % map_id)
		return

	var rect := world.bounds()
	var camera := Camera2D.new()
	camera.name = "Camera"
	add_child(camera)
	camera.position = rect.get_center()
	camera.make_current()
	_fit(camera, rect)

	var label := Label.new()
	label.text = "%s  %d x %d tiles" % [map_id, int(rect.size.x / Tiles.SIZE), int(rect.size.y / Tiles.SIZE)]
	label.position = Vector2(24, 20)
	add_child(label)


func _fit(camera: Camera2D, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var viewport := get_viewport_rect().size
	var zoom := minf(viewport.x / rect.size.x, viewport.y / rect.size.y) * FIT_MARGIN
	camera.zoom = Vector2(zoom, zoom)