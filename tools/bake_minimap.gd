extends SceneTree
## Bakes `maps/<id>/minimap.png` from a built map scene.
## Run: `tools/godot.sh --headless --path . -s tools/bake_minimap.gd -- --map=dustworks`
##
## Reads the painted tile data directly (no rendering, so it works headless and
## matches the layout exactly): floors tinted by surface, walls dark, low cover
## mid-tone, glass as the glass tint. 4 px per tile per architecture §7.
## Objectives/spawns are overlaid by the HUD at runtime, not baked in.

const MAP_DIR := "res://maps"
const PX_PER_TILE := 4

var _palette: PaletteDef


func _initialize() -> void:
	var map_id := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
	if map_id.is_empty():
		push_error("usage: -s tools/bake_minimap.gd -- --map=<id>")
		quit(2)
		return
	_bake.call_deferred(map_id)


func _bake(map_id: String) -> void:
	var scene_path := "%s/%s/map.tscn" % [MAP_DIR, map_id]
	if not ResourceLoader.exists(scene_path):
		push_error("bake_minimap: %s missing — run tools/build_map.gd first" % scene_path)
		quit(2)
		return
	_palette = load("res://data/palettes/default.tres") as PaletteDef
	if _palette == null:
		_palette = PaletteDef.make_default()

	var map := (load(scene_path) as PackedScene).instantiate()
	var ground := map.get_node(^"Ground") as TileMapLayer
	var walls := map.get_node(^"Walls") as TileMapLayer
	var bounds := map.get_node(^"Bounds")
	var size_tiles := Vector2i(
		(bounds.get_node(^"Max") as Marker2D).position / Tiles.SIZE)

	var img := Image.create(size_tiles.x * PX_PER_TILE, size_tiles.y * PX_PER_TILE,
		false, Image.FORMAT_RGBA8)
	# Background = solid: uncarved space is void, not walkable floor.
	img.fill(_palette.minimap_wall)
	_fill_layer(img, ground, walls, size_tiles, false)
	_fill_layer(img, walls, walls, size_tiles, true)

	var out := "%s/%s/minimap.png" % [MAP_DIR, map_id]
	var err := img.save_png(ProjectSettings.globalize_path(out))
	map.free()
	if err != OK:
		push_error("bake_minimap: cannot write %s (%d)" % [out, err])
		quit(3)
		return
	print("MINIMAP_OK %s %dx%d (%d x %d tiles @ %d px)" % [
		out, img.get_width(), img.get_height(), size_tiles.x, size_tiles.y, PX_PER_TILE])
	quit(0)


## Fills one rectangle of pixels per used cell. `walls_pass` distinguishes
## solid geometry (walls/low cover/glass) from floor tinting.
func _fill_layer(img: Image, layer: TileMapLayer, walls: TileMapLayer,
		size_tiles: Vector2i, walls_pass: bool) -> void:
	for cell: Vector2i in layer.get_used_cells():
		if cell.x < 0 or cell.y < 0 or cell.x >= size_tiles.x or cell.y >= size_tiles.y:
			continue
		var data := layer.get_cell_tile_data(cell)
		if data == null:
			continue
		var color := _color_for(data, walls_pass)
		if color.a <= 0.0:
			continue
		img.fill_rect(Rect2i(cell * PX_PER_TILE, Vector2i(PX_PER_TILE, PX_PER_TILE)), color)


func _color_for(data: TileData, walls_pass: bool) -> Color:
	if bool(data.get_custom_data(&"low_cover")):
		return _palette.minimap_cover
	var surface := int(data.get_custom_data(&"surface"))
	if surface == Enums.Surface.GLASS:
		return _palette.glass_tint.darkened(0.1)
	if walls_pass or bool(data.get_custom_data(&"blocks_sound")):
		return _palette.minimap_wall
	return _palette.minimap_tint(surface)