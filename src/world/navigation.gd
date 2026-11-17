class_name MapNavigation
extends NavigationRegion2D
## Navigation bake + path queries. The whole 2D navigation stack is
## Experimental in Godot 4.7 (research/godot-tech.md §2.1), so every nav call in
## Kangur lives here: a rename in a future release touches one file.
##
## Bake route (§2.2 route B): parse the map's static colliders, add the map
## rectangle as a traversable outline, bake synchronously. Route A
## (`bake_navigation_polygon`) produced 0 polygons from TileMapLayer colliders
## on 4.7.2 — verified; do not "simplify" back to it.
##
## Doors: a toggled region/obstacle does NOT invalidate existing paths. Repath
## agents after opening one.

## Emitted once the navigation server actually serves this map's polygons.
## Path queries before this return empty (the server syncs asynchronously).
signal map_ready

const AGENT_RADIUS := 10.0
const CELL_SIZE := 1.0
## Everything that blocks movement: WORLD | LOW_COVER | GLASS.
const PARSED_MASK := Layers.WORLD_BIT | Layers.LOW_COVER_BIT | Layers.GLASS_BIT
## Physics frames to wait for the server sync before giving up (observed ~6).
const SERVER_SYNC_FRAMES := 30

## Root parsed for collider geometry (the map scene root).
@export var bake_root: Node2D
## Map size in tiles; used for the traversable outline.
@export var map_size: Vector2i = Vector2i(80, 64)


## A baked polygon is saved inside the map scene, so a loaded map is already
## usable. The server still needs the polygon pushed after the node is in the
## tree (assigning in _ready alone serves nothing), and it syncs a few physics
## frames later — so poll here rather than guessing in every caller. A polling
## `_physics_process` (not a coroutine) so a freed map instance cannot resume
## into a dead object during headless builds.
var _sync_pending := false
var _sync_frames := 0


func _ready() -> void:
	_sync_pending = true
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not _sync_pending:
		return
	if _sync_frames == 0:
		_sync()
	_sync_frames += 1
	if _server_has_polygon():
		_sync_pending = false
		map_ready.emit()
	elif _sync_frames > SERVER_SYNC_FRAMES:
		_sync_pending = false
		push_warning("MapNavigation: server never served the nav polygon")
		map_ready.emit()


func _server_has_polygon() -> bool:
	if navigation_polygon == null or navigation_polygon.get_polygon_count() == 0:
		return false
	var map_rid := get_world_2d().get_navigation_map()
	# Querying before the first map iteration errors in the console; skip it.
	if NavigationServer2D.map_get_iteration_id(map_rid) == 0:
		return false
	var probe := NavigationServer2D.map_get_closest_point(
		map_rid, navigation_polygon.get_vertices()[0])
	return probe != Vector2.ZERO


func _sync() -> void:
	if not is_inside_tree():
		return
	var map_rid := get_world_2d().get_navigation_map()
	NavigationServer2D.region_set_map(get_rid(), map_rid)
	# Re-assigning is what pushes the saved polygon to the server.
	navigation_polygon = navigation_polygon
	NavigationServer2D.map_force_update(map_rid)


## Bakes synchronously into this region. Colliders must already exist, so call
## this after the tile layers are populated and one physics frame has run.
func bake() -> bool:
	return bake_now()


func bake_now() -> bool:
	if bake_root == null:
		push_error("MapNavigation: bake_root is not set")
		return false
	var poly := NavigationPolygon.new()
	poly.agent_radius = AGENT_RADIUS
	poly.cell_size = CELL_SIZE
	poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	poly.parsed_collision_mask = PARSED_MASK

	var geometry := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(poly, geometry, bake_root)
	# Collider-only parsing yields obstructions with nothing to cut into.
	geometry.add_traversable_outline(_map_rect())
	NavigationServer2D.bake_from_source_geometry_data(poly, geometry)

	navigation_polygon = poly
	if is_inside_tree():
		_sync()
	return poly.get_polygon_count() > 0


func is_ready() -> bool:
	return navigation_polygon != null and navigation_polygon.get_polygon_count() > 0


## Straight-ish path between two world points. Empty = no route (or no nav).
## Cheap enough for AI orders, too costly to call per tick per agent.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if navigation_polygon == null:
		return PackedVector2Array()
	return NavigationServer2D.map_get_path(
		get_world_2d().get_navigation_map(), from, to, true)


## Nearest navigable point to `pos` — for spawning NPCs and picking patrols.
func closest_point(pos: Vector2) -> Vector2:
	return NavigationServer2D.map_get_closest_point(get_world_2d().get_navigation_map(), pos)


func _map_rect() -> PackedVector2Array:
	var size := Vector2(map_size) * Tiles.SIZE
	return PackedVector2Array([
		Vector2.ZERO, Vector2(0, size.y), size, Vector2(size.x, 0),
	])