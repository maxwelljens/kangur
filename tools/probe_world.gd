extends Node
## World probe: loads a built map through `World` and asserts every contract the
## rest of the game depends on. Run:
##   tools/godot.sh --headless --path . tools/probe_world.tscn -- --map=dustworks
##
## Prints PASS/FAIL per check and `WORLD_PROBE_OK` / `WORLD_PROBE_FAIL`.
## A scene (not `-s`) because `-s` replaces the main loop and skips autoloads.

const DEFAULT_MAP := &"dustworks"
const EXPECTED_SPAWNS_PER_TEAM := 12
const EXPECTED_MIN_COVER := 40
const MINIMAP_HEADER_BYTES := 8
const NAV_WAIT_FRAMES := 60
## Per-map expected spawn surfaces, from docs/design/maps.md carve rects.
const SPAWN_SURFACES := {
	&"dustworks": [[Enums.Team.BASTION, Enums.Surface.CONCRETE], [Enums.Team.SIROCCO, Enums.Surface.SAND]],
	&"compound": [[Enums.Team.BASTION, Enums.Surface.CONCRETE], [Enums.Team.SIROCCO, Enums.Surface.CONCRETE]],
}

var _failures: Array[String] = []
var _nav_ready := false


func _ready() -> void:
	var map_id := DEFAULT_MAP
	var args := OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i].begins_with("--map="):
			map_id = StringName(args[i].trim_prefix("--map="))
	await _run(map_id)
	if _failures.is_empty():
		print("WORLD_PROBE_OK %s" % map_id)
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			print("  FAIL %s" % failure)
		print("WORLD_PROBE_FAIL %s (%d)" % [map_id, _failures.size()])
		get_tree().quit(1)


func _run(map_id: StringName) -> void:
	print("probe: map=%s" % map_id)
	var world := World.new()
	world.map_scene_path = "res://maps/%s/map.tscn" % map_id
	add_child(world)
	_check(world.map != null, "map scene loaded")
	if world.map == null:
		return
	await get_tree().physics_frame
	await get_tree().physics_frame

	# --- spawns -------------------------------------------------------------
	var bastion := world.spawn_points(Enums.Team.BASTION)
	var sirocco := world.spawn_points(Enums.Team.SIROCCO)
	_check(bastion.size() == EXPECTED_SPAWNS_PER_TEAM,
		"BASTION spawns = %d (want %d)" % [bastion.size(), EXPECTED_SPAWNS_PER_TEAM])
	_check(sirocco.size() == EXPECTED_SPAWNS_PER_TEAM,
		"SIROCCO spawns = %d (want %d)" % [sirocco.size(), EXPECTED_SPAWNS_PER_TEAM])
	# Spawns must be on walkable floor, not inside geometry.
	var blocked := 0
	for pos: Vector2 in bastion + sirocco:
		if world.is_wall(pos):
			blocked += 1
	_check(blocked == 0, "%d spawns inside geometry" % blocked)

	# --- cover --------------------------------------------------------------
	var cover := world.cover_points()
	_check(cover.size() > EXPECTED_MIN_COVER,
		"cover points = %d (want > %d)" % [cover.size(), EXPECTED_MIN_COVER])
	var tagged := 0
	for point: CoverPoint in cover:
		if not point.lanes.is_empty():
			tagged += 1
	_check(tagged > cover.size() / 2, "lane-tagged cover = %d/%d" % [tagged, cover.size()])
	var near := world.cover_points_near(cover[0].global_position, 200.0) if not cover.is_empty() else []
	_check(not near.is_empty(), "cover_points_near finds neighbours")

	# --- navigation ---------------------------------------------------------
	# The nav server syncs a few frames after the map enters the tree; wait for
	# the signal instead of guessing a frame count.
	if world.nav != null and not world.nav.map_ready.is_connected(_on_nav_ready):
		world.nav.map_ready.connect(_on_nav_ready, CONNECT_ONE_SHOT)
	for i: int in NAV_WAIT_FRAMES:
		if _nav_ready:
			break
		await get_tree().physics_frame
	_check(world.nav != null and world.nav.is_ready(), "nav polygon baked")
	var from := bastion[0]
	var to := sirocco[0]
	var path := world.find_path(from, to)
	_check(path.size() >= 2, "nav path bastion->sirocco nodes = %d" % path.size())
	_check(world.nav.closest_point(Vector2(-100, -100)) != Vector2(-100, -100),
		"closest_point clamps onto the nav mesh")

	# --- surfaces -----------------------------------------------------------
	# Spawn-zone surfaces come straight from the blockout spec (maps.md):
	# Dustworks SIROCCO spawns on sand, Compound both spawns on concrete.
	for entry: Array in SPAWN_SURFACES[map_id]:
		var actual: int = world.surface_at(world.spawn_points(int(entry[0]))[0])
		_check(actual == int(entry[1]),
			"%s spawn surface %d (want %d)" % [Enums.team_name(entry[0]), actual, entry[1]])
	_check(world.surface_at(Vector2(-64, -64)) == Enums.Surface.CONCRETE,
		"off-map surface falls back to CONCRETE")

	# --- walls / low cover / glass -----------------------------------------
	_check(world.is_wall(Vector2(4, 4)), "map corner is solid")
	var low := _first_low_cover(world)
	_check(low != null, "map has low cover tiles")
	if low != null:
		var lp := _cell_center(low)
		_check(world.is_low_cover(lp), "low cover tile reports low_cover at %s" % lp)
		_check(world.is_wall(lp), "low cover blocks movement at %s" % lp)
		_check(not world.blocks_sound(lp), "low cover does not block sound at %s" % lp)

	# --- bounds / minimap ---------------------------------------------------
	var rect := world.bounds()
	_check(rect.size.x > 0 and rect.size.y > 0, "bounds = %s" % rect)
	var minimap := "res://maps/%s/minimap.png" % map_id
	_check(FileAccess.file_exists(minimap), "minimap exists: %s" % minimap)
	var file := FileAccess.open(minimap, FileAccess.READ)
	if file != null:
		_check(file.get_length() > MINIMAP_HEADER_BYTES,
			"minimap nonzero: %d bytes" % file.get_length())

	# --- objectives (Battle maps) ------------------------------------------
	for zone: ObjectiveZone in world.objectives():
		_check(world.objective(zone.obj_id) == zone, "objective(%s) resolves" % zone.obj_id)
		_check(zone.occupancy(Enums.Team.BASTION) == 0, "objective %s starts empty" % zone.obj_id)

	print("probe stats: %d bastion spawns, %d sirocco spawns, %d cover, %d nav nodes, bounds %s" % [
		bastion.size(), sirocco.size(), cover.size(), path.size(), rect])


func _on_nav_ready() -> void:
	_nav_ready = true


func _first_low_cover(world: World) -> Vector2i:
	for cell: Vector2i in world.walls.get_used_cells():
		var data := world.walls.get_cell_tile_data(cell)
		if data != null and bool(data.get_custom_data(&"low_cover")):
			return cell
	return Vector2i(-1, -1)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * Tiles.SIZE + Vector2(Tiles.SIZE, Tiles.SIZE) * 0.5


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures.append(label)