class_name World
extends Node2D
## Runtime map host. Loads a map scene, then answers every world query the rest
## of the game needs — surfaces, walls, spawns, cover, objectives, patrols,
## navigation, glass — so no other module touches TileMapLayer internals.
## Contract: docs/architecture.md §7.
##
## Scene shape (maps/<id>/map.tscn, built by tools/build_map.gd):
##   World (this script)
##   └ Map (Node2D)                     ← loaded instance, owned by `map`
##       Ground / Walls / Deco TileMapLayer
##       Nav (MapNavigation) Spawns Cover Objectives Bounds Lights

## Fired when a glass tile shatters. Audio/decals hook this; keeps `World` free
## of EventBus autoload assumptions (headless tooling loads scenes too).
signal glass_shattered(global_pos: Vector2)

const SURFACE := &"surface"
const PENETRABLE := &"penetrable"
const LOW_COVER := &"low_cover"
const BLOCKS_SOUND := &"blocks_sound"
const GLASS_SHATTER_HITS := 2
## Rejection-sampling budget for random patrol points.
const PATROL_ATTEMPTS := 24

## Child node names of the map scene, fixed by maps.md + build_map.gd.
const LAYER_WALLS := ^"Walls"
const LAYER_GROUND := ^"Ground"
const NODE_NAV := ^"Nav"
const NODE_SPAWNS := ^"Spawns"
const NODE_COVER := ^"Cover"
const NODE_OBJECTIVES := ^"Objectives"
const NODE_BOUNDS := ^"Bounds"

@export var map_scene_path: String = ""

var map: Node2D
var walls: TileMapLayer
var ground: TileMapLayer
var nav: MapNavigation

## Tile -> remaining hits before it shatters, for glass only.
var _glass_hits: Dictionary[Vector2i, int] = {}


func _ready() -> void:
	if not map_scene_path.is_empty():
		load_map(map_scene_path)


## Instances `path` under this node and resolves the well-known child layers.
func load_map(path: String) -> bool:
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		push_error("World: cannot load map scene '%s'" % path)
		return false
	if map != null:
		map.queue_free()
	map = packed.instantiate() as Node2D
	map.name = "Map"
	add_child(map)
	map_scene_path = path
	walls = map.get_node_or_null(LAYER_WALLS) as TileMapLayer
	ground = map.get_node_or_null(LAYER_GROUND) as TileMapLayer
	nav = map.get_node_or_null(NODE_NAV) as MapNavigation
	if walls == null:
		push_error("World: map '%s' has no Walls TileMapLayer" % path)
		return false
	# Layout assertions: getting these wrong silently breaks every bullet,
	# vision ray and sound occlusion query in the map (research §1.3).
	_assert_layers()
	return true


## ---------------------------------------------------------------- queries --

## Enums.Surface at a world position. A wall/low-cover/glass tile answers with
## its own material surface; open floor answers from Ground. Unmapped = CONCRETE.
func surface_at(global_pos: Vector2) -> int:
	var surface := _surface_of(walls, global_pos)
	if surface >= 0:
		return surface
	surface = _surface_of(ground, global_pos)
	return surface if surface >= 0 else Enums.Surface.CONCRETE


## True for anything solid that blocks movement (high walls, low cover, glass).
func is_wall(global_pos: Vector2) -> bool:
	return cell_data(global_pos) != null


func is_penetrable(global_pos: Vector2) -> bool:
	var data := cell_data(global_pos)
	return data != null and bool(data.get_custom_data(PENETRABLE))


func is_low_cover(global_pos: Vector2) -> bool:
	var data := cell_data(global_pos)
	return data != null and bool(data.get_custom_data(LOW_COVER))


func blocks_sound(global_pos: Vector2) -> bool:
	var data := cell_data(global_pos)
	return data != null and bool(data.get_custom_data(BLOCKS_SOUND))


## TileData at a world position on the Walls layer, or null for open floor.
## `local_to_map(to_local(...))` is the only correct conversion (research §1.5).
func cell_data(global_pos: Vector2) -> TileData:
	if walls == null:
		return null
	return walls.get_cell_tile_data(walls.local_to_map(walls.to_local(global_pos)))


func _surface_of(layer: TileMapLayer, global_pos: Vector2) -> int:
	if layer == null:
		return -1
	var data := layer.get_cell_tile_data(layer.local_to_map(layer.to_local(global_pos)))
	if data == null:
		return -1
	var value: Variant = data.get_custom_data(SURFACE)
	return int(value) if value != null else -1


## ------------------------------------------------------------ spawns/cover --

## Spawn positions for a team, in marker order. Empty if the map has none.
func spawn_points(team: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var spawns := map.get_node_or_null(NODE_SPAWNS)
	if spawns == null:
		return out
	for child: Node in spawns.get_children():
		if child is SpawnMarker and child.team == team:
			out.append(child.global_position)
	return out


func cover_points() -> Array[CoverPoint]:
	var out: Array[CoverPoint] = []
	var cover := map.get_node_or_null(NODE_COVER)
	if cover == null:
		return out
	for child: Node in cover.get_children():
		if child is CoverPoint:
			out.append(child)
	return out


## Cover points within `radius` of a world position, unsorted.
## Callers that care about quality/tactics sort themselves (AI cover scoring).
func cover_points_near(pos: Vector2, radius: float) -> Array[CoverPoint]:
	var out: Array[CoverPoint] = []
	var r2 := radius * radius
	for point: CoverPoint in cover_points():
		if point.global_position.distance_squared_to(pos) <= r2:
			out.append(point)
	return out


## Cover points whose `lanes` contain any of `lanes`.
func cover_points_for_lanes(lanes: Array[StringName], pos: Vector2, radius: float) -> Array[CoverPoint]:
	var out: Array[CoverPoint] = []
	for point: CoverPoint in cover_points_near(pos, radius):
		for lane: StringName in point.lanes:
			if lanes.has(lane):
				out.append(point)
				break
	return out


func objective(id: StringName) -> ObjectiveZone:
	var objectives := map.get_node_or_null(NODE_OBJECTIVES)
	if objectives == null:
		return null
	for child: Node in objectives.get_children():
		if child is ObjectiveZone and child.obj_id == id:
			return child
	return null


func objectives() -> Array[ObjectiveZone]:
	var out: Array[ObjectiveZone] = []
	var node := map.get_node_or_null(NODE_OBJECTIVES)
	if node == null:
		return out
	for child: Node in node.get_children():
		if child is ObjectiveZone:
			out.append(child)
	out.sort_custom(func(a: ObjectiveZone, b: ObjectiveZone) -> bool: return a.order < b.order)
	return out


## Own-team random walkable point (patrol/rine positions). Uses the seeded RNG
## the caller owns, so matches stay reproducible per seed.
func random_patrol_point(rng: RandomNumberGenerator, team: int) -> Vector2:
	var rect := bounds()
	if rect.size == Vector2.ZERO:
		var spawns := spawn_points(team)
		return spawns[0] if not spawns.is_empty() else Vector2.ZERO
	for attempt: int in PATROL_ATTEMPTS:
		var candidate := Vector2(
			rng.randf_range(rect.position.x, rect.end.x),
			rng.randf_range(rect.position.y, rect.end.y))
		if not is_wall(candidate):
			return nav.closest_point(candidate) if nav != null and nav.is_ready() else candidate
	return rect.get_center()

## ---------------------------------------------------------------- bounds --

## Map rectangle in world px (Bounds marker pair, else tile extents).
func bounds() -> Rect2:
	var node := map.get_node_or_null(NODE_BOUNDS)
	if node != null:
		var first := node.get_node_or_null(^"Min") as Marker2D
		var second := node.get_node_or_null(^"Max") as Marker2D
		if first != null and second != null:
			return Rect2(first.position, second.position - first.position).abs()
	if walls != null:
		var rect := walls.get_used_rect()
		return Rect2(Vector2(rect.position) * Tiles.SIZE, Vector2(rect.size) * Tiles.SIZE)
	return Rect2()


## --------------------------------------------------------------- glass --

## Bullet hit registration. Returns true when the tile broke. Shatters on the
## second hit (maps.md): the cell becomes empty and a sound spike is emitted.
func glass_shatter(global_pos: Vector2) -> bool:
	var data := cell_data(global_pos)
	if data == null or int(data.get_custom_data(SURFACE)) != Enums.Surface.GLASS:
		return false
	var cell := walls.local_to_map(walls.to_local(global_pos))
	var hits: int = int(_glass_hits.get(cell, 0)) + 1
	if hits < GLASS_SHATTER_HITS:
		_glass_hits[cell] = hits
		# Crack stage tile: index 1 = first crack, 2 = spiderweb.
		walls.set_cell(cell, Tiles.SOURCE_GLASS, Tiles.glass_coord(hits))
		return false
	_glass_hits.erase(cell)
	walls.erase_cell(cell)
	glass_shattered.emit(walls.to_global(walls.map_to_local(cell)))
	return true


## ------------------------------------------------------------------- nav --

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return nav.find_path(from, to) if nav != null else PackedVector2Array()


## Loads the map's baked minimap, if one exists (MapDef.minimap_path points here).
func minimap_path(map_id: StringName) -> String:
	var path := "res://maps/%s/minimap.png" % map_id
	return path if ResourceLoader.exists(path) else ""


## ----------------------------------------------------------------- checks --

func _assert_layers() -> void:
	var tile_set := walls.tile_set
	assert(tile_set != null, "World: Walls has no TileSet")
	assert(tile_set.get_physics_layers_count() >= 3,
		"World: TileSet needs physics layers 1 (WORLD), 5 (LOW_COVER), 6 (GLASS)")
	var expected: Array[int] = [Layers.WORLD_BIT, Layers.LOW_COVER_BIT, Layers.GLASS_BIT]
	for layer: int in expected.size():
		assert(tile_set.get_physics_layer_collision_layer(layer) == expected[layer],
			"World: physics layer %d must be collision layer %d" % [layer, expected[layer]])
	for name: StringName in [SURFACE, PENETRABLE, LOW_COVER, BLOCKS_SOUND]:
		assert(tile_set.get_custom_data_layer_by_name(name) >= 0,
			"World: TileSet is missing custom data layer '%s'" % name)