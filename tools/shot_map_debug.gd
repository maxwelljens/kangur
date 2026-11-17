extends Node2D
## Map overview WITH the invisible contracts drawn on top: objectives (capture
## rect + id), spawns (Bastion/Sirocco dots), forward spawns, and Range markers.
## The plain `shot_map.tscn` proves geometry only; this proves what BattleRules
## and the Range actually read.
##   tools/godot.sh --path . -- --shot=res://tools/shot_map_debug.tscn:15:reports/screenshots/range_debug.png --map=range

const DEFAULT_MAP := &"terminal"
const FIT_MARGIN := 0.96
const DOT_RADIUS := 5.0

const SPAWN_COLOR := {Enums.Team.BASTION: Color(0.45, 0.7, 1.0), Enums.Team.SIROCCO: Color(1.0, 0.6, 0.25)}
const FWD_COLOR := Color(1.0, 0.9, 0.3)
const OBJ_COLOR := Color(0.3, 1.0, 0.6, 0.85)
const MARKER_COLOR := Color(1.0, 0.35, 0.75)

@export var map_id: StringName = DEFAULT_MAP


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = StringName(arg.trim_prefix("--map="))
	var world := World.new()
	world.map_scene_path = "res://maps/%s/map.tscn" % map_id
	add_child(world)
	if world.map == null:
		push_error("shot_map_debug: cannot load map '%s'" % map_id)
		return
	var rect := world.bounds()
	_draw_contracts(world)
	var camera := Camera2D.new()
	camera.position = rect.get_center()
	add_child(camera)
	camera.make_current()
	var zoom := minf(get_viewport_rect().size.x / rect.size.x,
		get_viewport_rect().size.y / rect.size.y) * FIT_MARGIN
	camera.zoom = Vector2(zoom, zoom)
	var label := Label.new()
	label.text = "%s  objectives=%d spawns=%d/%d cover=%d" % [
		map_id, world.objectives().size(), world.spawn_points(Enums.Team.BASTION).size(),
		world.spawn_points(Enums.Team.SIROCCO).size(), world.cover_points().size()]
	label.position = Vector2(24, 20)
	add_child(label)


func _draw_contracts(world: World) -> void:
	var overlay := Node2D.new()
	overlay.draw.connect(_on_overlay_draw.bind(world, overlay))
	add_child(overlay)


func _on_overlay_draw(world: World, overlay: Node2D) -> void:
	for zone: ObjectiveZone in world.objectives():
		var r := zone.capture_rect()
		overlay.draw_rect(r, OBJ_COLOR, false, 3.0)
		overlay.draw_string(ThemeDB.fallback_font, r.position + Vector2(6, 22),
			str(zone.obj_id).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, OBJ_COLOR)
	for team: int in [Enums.Team.BASTION, Enums.Team.SIROCCO]:
		for pos: Vector2 in world.spawn_points(team):
			overlay.draw_circle(pos, DOT_RADIUS, SPAWN_COLOR[team])
	var fwd := world.map.get_node_or_null(^"ForwardSpawns")
	if fwd != null:
		for child: Node in fwd.get_children():
			overlay.draw_circle((child as Node2D).global_position, DOT_RADIUS, FWD_COLOR)
	var markers := world.map.get_node_or_null(^"Markers")
	if markers != null:
		for child: Node in markers.get_children():
			var at := (child as Node2D).global_position
			overlay.draw_rect(Rect2(at - Vector2(8, 8), Vector2(16, 16)), MARKER_COLOR, false, 2.0)