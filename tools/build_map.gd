extends SceneTree
## Builds a playable map scene from a BlockoutDef.
## Run: `tools/godot.sh --headless --path . -s tools/build_map.gd -- --map=dustworks`
##
## Output: maps/<id>/map.tscn — Ground/Walls/Deco TileMapLayers (TileSet from
## tools/gen_tiles.gd), Nav (MapNavigation, baked), Spawns (12/team grid-jitter),
## Cover (CoverPoint on block faces toward lanes), Objectives (Battle),
## Bounds (Min/Max markers). Deterministic: geometry comes from the blockout,
## jitter from a fixed seed, so rebuilds are diff-stable.
##
## Everything is laid out in tile coordinates (1 tile = 32 px) with map origin
## at (0,0); the scene root sits at world origin.

const MAP_DIR := "res://maps"
const BOUNDARY_TILES := 2
const MARGIN := 2
const COVER_INSET := 0.5
const SEED := 20410
const SPAWN_SPACING := 3
const COVER_SCAN_RADIUS := 14.0
const LANE_ANGLE_DEG := 45.0

var _def: BlockoutDef
var _tile_set: TileSet
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var map_id := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
	if map_id.is_empty():
		push_error("usage: -s tools/build_map.gd -- --map=<id>")
		quit(2)
		return
	_build.call_deferred(map_id)


func _build(map_id: String) -> void:
	_def = load("%s/%s/blockout.tres" % [MAP_DIR, map_id]) as BlockoutDef
	if _def == null:
		push_error("build_map: no blockout at %s/%s" % [MAP_DIR, map_id])
		quit(2)
		return
	var errors := _def.validate()
	if not errors.is_empty():
		for e: String in errors:
			push_error("build_map: %s" % e)
		quit(3)
		return
	_tile_set = load(Tiles.TILESET_PATH) as TileSet
	if _tile_set == null:
		push_error("build_map: missing %s — run tools/gen_tiles.gd first" % Tiles.TILESET_PATH)
		quit(3)
		return
	_rng.seed = SEED

	var root := _make_root()
	# In the tree so tile bodies exist for the nav parse; detached at the end.
	get_root().add_child(root)
	_paint_layers(root)
	var nav := _make_nav(root)
	var spawns := _make_spawns(root)
	var cover := _make_cover(root, spawns)
	var objectives := _make_objectives(root)
	_make_bounds(root)

	# Nav bakes from the live tile colliders, so wait for them to register.
	# Bake BEFORE packing: an empty NavigationPolygon would be saved instead.
	for i: int in 2:
		await physics_frame
	var baked := nav.bake()
	if not baked:
		push_error("build_map: navigation bake produced no polygons")
		quit(5)
		return

	# Owners must be set for PackedScene.pack() to serialise the children.
	_own(root)
	var scene := PackedScene.new()
	var pack_err := scene.pack(root)
	if pack_err != OK:
		push_error("build_map: pack failed (%d)" % pack_err)
		quit(4)
		return

	var out := "%s/%s/map.tscn" % [MAP_DIR, map_id]
	var save_err := ResourceSaver.save(scene, out)
	if save_err != OK:
		push_error("build_map: cannot write %s (%d)" % [out, save_err])
		quit(4)
		return
	print("BUILD_OK %s" % out)
	print("  size=%s tiles (%d x %d px)" % [_def.size, _def.size.x * Tiles.SIZE, _def.size.y * Tiles.SIZE])
	print("  floors=%d walls=%d low_cover=%d" % [
		_floor_cells(root), _wall_cells(root), _cover_cells(root)])
	print("  spawns=%d cover_points=%d objectives=%d nav_polygons=%d nav_verts=%d" % [
		spawns.get_child_count(), cover.get_child_count(), objectives.get_child_count(),
		nav.navigation_polygon.get_polygon_count(), nav.navigation_polygon.get_vertices().size()])
	# Detach before quitting: frees the temp scene cleanly (no leak spam).
	get_root().remove_child(root)
	root.free()
	quit(0)


## ------------------------------------------------------------------- scene --

## Root `Map` exactly as architecture §7 specifies; `World` instantiates this
## scene as its `Map` child and resolves Ground/Walls/... from it.
func _make_root() -> Node2D:
	var root := Node2D.new()
	root.name = "Map"
	return root


func _tile_layer(root: Node2D, name: String, sorting: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = name
	layer.tile_set = _tile_set
	layer.y_sort_enabled = sorting
	root.add_child(layer)
	return layer


## Ground = carve rects (walkable floor). Walls = everything else: block rects
## plus all uncarved space (building interiors, the map ring). Unpainted void
## would let bullets, vision rays and nav queries pass through solid geometry.
func _paint_layers(root: Node2D) -> void:
	var ground := _tile_layer(root, "Ground", false)
	var walls := _tile_layer(root, "Walls", false)
	# Ground carries no collision/nav; walls carry collision + sound, but their
	# built-in tile navigation stays OFF: per-tile nav polygons pollute the map
	# with thousands of regions and give worse paths (research §2.2: "TileMap
	# built-in navigation is a trap"). `Nav` is baked from the wall colliders.
	ground.collision_enabled = false
	ground.navigation_enabled = false
	walls.navigation_enabled = false

	for entry: Dictionary in _def.carve:
		var surface := Tiles.surface_from_name(str(entry["surface"]))
		for y: int in range(entry["y"], entry["y"] + entry["h"]):
			for x: int in range(entry["x"], entry["x"] + entry["w"]):
				# Deterministic variant scatter so floors do not look stamped.
				var noise := (x * 7 + y * 13) % Tiles.FLOOR_VARIANTS
				ground.set_cell(Vector2i(x, y), Tiles.floor_source(surface),
					Tiles.floor_coord(surface, noise))

	# Void first, then blocks on top of it.
	var concrete := 0
	for y: int in _def.size.y:
		for x: int in _def.size.x:
			var cell := Vector2i(x, y)
			if not _is_open_floor(cell):
				var mask := _void_mask(cell)
				walls.set_cell(cell, Tiles.SOURCE_WALLS + concrete, _wall_tile(mask))

	for entry: Dictionary in _def.blocks:
		var rect := BlockoutDef.rect(entry)
		var low_cover := bool(entry.get("low_cover", false))
		var material := str(entry.get("material", "concrete_block"))
		var cover_kind := str(entry.get("cover", "crate"))
		for cell: Vector2i in _cells(rect):
			if low_cover:
				var kind := Tiles.LOW_COVER_KINDS.find(StringName(cover_kind))
				walls.set_cell(cell, Tiles.SOURCE_COVER, Tiles.cover_coord(maxi(kind, 0)))
			else:
				var mat := maxi(Tiles.WALL_MATERIALS.find(StringName(material)), 0)
				walls.set_cell(cell, Tiles.SOURCE_WALLS + mat, _wall_tile(_wall_mask(cell, rect)))
	ground.update_internals()
	walls.update_internals()


## Pick the face variant, or the interior mass when every neighbour is solid
## (only then does the cell have no face to light).
func _wall_tile(mask: int) -> Vector2i:
	return Tiles.wall_interior_coord() if mask == 0xF else Tiles.wall_coord(mask)


## Void tiles join every neighbouring void/wall tile, so interiors read as one
## mass rather than a grid of bevels.
func _void_mask(cell: Vector2i) -> int:
	var mask := 0
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i: int in dirs.size():
		var neighbour := cell + dirs[i]
		if neighbour.x < 0 or neighbour.y < 0 \
				or neighbour.x >= _def.size.x or neighbour.y >= _def.size.y:
			mask |= 1 << i
		elif not _is_open_floor(neighbour):
			mask |= 1 << i
	return mask


## Bit 0 N, 1 E, 2 S, 3 W = neighbour belongs to the same block (so interior
## edges stay seamless). Neighbours outside the block count as wall too if a
## different wall tile is already painted there.
func _wall_mask(cell: Vector2i, rect: Rect2i) -> int:
	var mask := 0
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i: int in dirs.size():
		var neighbour := cell + dirs[i]
		if rect.has_point(neighbour):
			mask |= 1 << i
		elif not _is_open_floor(neighbour):
			mask |= 1 << i
	return mask


func _is_open_floor(cell: Vector2i) -> bool:
	for entry: Dictionary in _def.carve:
		if BlockoutDef.rect(entry).has_point(cell):
			return true
	return false


func _cells(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out


func _floor_cells(root: Node2D) -> int:
	return (root.get_node(^"Ground") as TileMapLayer).get_used_cells().size()


func _wall_cells(root: Node2D) -> int:
	var walls := root.get_node(^"Walls") as TileMapLayer
	return walls.get_used_cells_by_id(Tiles.SOURCE_WALLS, -Vector2i.ONE, -1).size() \
		+ walls.get_used_cells_by_id(Tiles.SOURCE_WALLS + 1, -Vector2i.ONE, -1).size() \
		+ walls.get_used_cells_by_id(Tiles.SOURCE_WALLS + 2, -Vector2i.ONE, -1).size()


func _cover_cells(root: Node2D) -> int:
	return (root.get_node(^"Walls") as TileMapLayer)\
		.get_used_cells_by_id(Tiles.SOURCE_COVER, -Vector2i.ONE, -1).size()


## --------------------------------------------------------------------- nav --

func _make_nav(root: Node2D) -> MapNavigation:
	var nav := MapNavigation.new()
	nav.name = "Nav"
	nav.bake_root = root
	nav.map_size = _def.size
	root.add_child(nav)
	return nav


## ------------------------------------------------------------------ spawns --

## Grid within the spawn rect, jittered per marker by the map seed (maps.md:
## "12 markers/team spread inside spawn rects (grid jitter)"). Cells already
## filled by a block (crate in the spawn area) are skipped — a marker inside a
## wall would trap the character that spawns on it.
func _make_spawns(root: Node2D) -> Node2D:
	var spawns := Node2D.new()
	spawns.name = "Spawns"
	root.add_child(spawns)
	var walls := root.get_node(^"Walls") as TileMapLayer
	for entry: Dictionary in _def.spawn_rects:
		var rect := BlockoutDef.rect(entry)
		var team := int(entry["team"])
		var count := int(entry["count"])
		var cells := _free_cells(rect, walls)
		if cells.size() < count:
			push_warning("build_map: spawn rect %s has %d free cells for %d spawns"
				% [rect, cells.size(), count])
		# Shuffle deterministically, then take the first `count` free cells.
		for i: int in range(cells.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp := cells[i]
			cells[i] = cells[j]
			cells[j] = tmp
		for index: int in mini(count, cells.size()):
			var cell := cells[index]
			var jitter := Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
			var marker := SpawnMarker.new()
			marker.name = "spawn_%s_%02d" % [Enums.team_name(team).to_lower(), index + 1]
			marker.team = team
			marker.position = (Vector2(cell) + Vector2(0.5, 0.5) + jitter) * Tiles.SIZE
			spawns.add_child(marker)
	return spawns


## Walkable, unused cells of a rect, in row-major order.
func _free_cells(rect: Rect2i, walls: TileMapLayer) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if walls.get_cell_source_id(cell) == -1:
				out.append(cell)
	return out


## ------------------------------------------------------------------- cover --

## CoverPoint per open tile edge of every block, pushed one tile into the open
## lane. `lean_dir` points from the cover into the lane; `quality` favours low
## cover (crouch to vanish) and penalises points with no lane.
func _make_cover(root: Node2D, spawns: Node2D) -> Node2D:
	var cover := Node2D.new()
	cover.name = "Cover"
	root.add_child(cover)
	var taken: Dictionary[Vector2i, bool] = {}
	for entry: Dictionary in _def.blocks:
		var rect := BlockoutDef.rect(entry)
		var low := bool(entry.get("low_cover", false))
		var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		for cell: Vector2i in _cells(rect):
			for dir: Vector2i in dirs:
				var outside := cell + dir
				if rect.has_point(outside) or not _is_open_floor(outside):
					continue
				if taken.has(outside):
					continue
				taken[outside] = true
				var point := CoverPoint.new()
				point.name = "cover_%02d" % cover.get_child_count()
				point.position = (Vector2(outside) + Vector2(0.5, 0.5)) * Tiles.SIZE \
					+ Vector2(dir) * -(COVER_INSET * Tiles.SIZE)
				point.lean_dir = Vector2(dir)
				point.quality = _cover_quality(outside, rect, low)
				point.lanes = _lanes_at(outside)
				cover.add_child(point)
	return cover


func _cover_quality(cell: Vector2i, block: Rect2i, low_cover: bool) -> float:
	var quality := 0.55
	# Crouch cover is strongest: you vanish behind it and can stand to shoot.
	if low_cover:
		quality += 0.25
	# Corners give a lean both ways.
	if _edge_count(cell, block) >= 2:
		quality += 0.1
	# No lane in range = a point AI will never use.
	if _lanes_at(cell).is_empty():
		quality -= 0.2
	return clampf(quality, 0.05, 1.0)


func _edge_count(cell: Vector2i, rect: Rect2i) -> int:
	var count := 0
	for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if not rect.has_point(cell + dir):
			count += 1
	return count


## Lane names whose segment passes within COVER_SCAN_RADIUS tiles of the cell.
func _lanes_at(cell: Vector2i) -> Array[StringName]:
	var out: Array[StringName] = []
	var p := Vector2(cell) + Vector2(0.5, 0.5)
	for entry: Dictionary in _def.lanes:
		var a := Vector2(entry["from"])
		var b := Vector2(entry["to"])
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= COVER_SCAN_RADIUS:
			out.append(StringName(entry["id"]))
	return out


## -------------------------------------------------------------- objectives --

func _make_objectives(root: Node2D) -> Node2D:
	var objectives := Node2D.new()
	objectives.name = "Objectives"
	root.add_child(objectives)
	for entry: Dictionary in _def.objectives:
		var rect := BlockoutDef.rect(entry)
		var zone := ObjectiveZone.new()
		zone.name = "objective_%s" % entry["id"]
		zone.obj_id = StringName(entry["id"])
		zone.order = int(entry.get("order", 1))
		zone.capture_time = float(entry.get("capture_time", 20.0))
		zone.lock_on_capture = bool(entry.get("lock_on_capture", false))
		zone.position = (Vector2(rect.position) + Vector2(rect.size) * 0.5) * Tiles.SIZE
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var box := RectangleShape2D.new()
		box.size = Vector2(rect.size) * Tiles.SIZE
		shape.shape = box
		zone.add_child(shape)
		objectives.add_child(zone)
	return objectives


## ------------------------------------------------------------------ bounds --

## Marker pair for camera clamp / minimap extent (architecture §7).
func _make_bounds(root: Node2D) -> void:
	var bounds := Node2D.new()
	bounds.name = "Bounds"
	root.add_child(bounds)
	for pair: Array in [[&"Min", Vector2.ZERO], [&"Max", Vector2(_def.size) * Tiles.SIZE]]:
		var marker := Marker2D.new()
		marker.name = pair[0]
		marker.position = pair[1]
		bounds.add_child(marker)


## PackedScene.pack() only serialises nodes whose `owner` is the root.
func _own(root: Node) -> void:
	for child: Node in root.get_children():
		_own_recursive(child, root)


func _own_recursive(node: Node, root: Node) -> void:
	node.owner = root
	for child: Node in node.get_children():
		_own_recursive(child, root)