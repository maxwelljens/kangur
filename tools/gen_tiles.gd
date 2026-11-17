extends SceneTree
## Procedural tile atlas generator (art-direction §3).
## Run: `tools/godot.sh --headless --path . -s tools/gen_tiles.gd`
##
## Writes:
##   assets/sprites/tiles/floor_<surface>.png   (3 variants × 6 surfaces, 96×32)
##   assets/sprites/tiles/walls_<material>.png  (16 bitmask variants, 512×32)
##   assets/sprites/tiles/cover.png             (crate/sandbag/car, 96×32)
##   assets/sprites/tiles/glass.png             (intact/crack1/crack2/open)
##   data/tilesets/kangur.tres                  (one TileSet, 4 atlas sources,
##                                               physics 1/5/6, nav on walls,
##                                               custom data surface/penetrable/
##                                               low_cover/blocks_sound)
##   data/palettes/default.tres                 (only if missing)
##
## Deterministic: every draw call is seeded from (surface, variant, pixel).
## Re-running with the same palette yields byte-identical PNGs.

const OUT_DIR := "res://assets/sprites/tiles"
const PALETTE_PATH := "res://data/palettes/default.tres"
const TILESET_PATH := Tiles.TILESET_PATH

const BAR_H := Tiles.SIZE

var palette: PaletteDef
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_ensure_palette()
	palette = load(PALETTE_PATH) as PaletteDef
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TILESET_PATH.get_base_dir()))

	var floors: Array[Texture2D] = []
	for surface: int in Tiles.FLOOR_SURFACES:
		floors.append(_save(_floor_atlas(surface), "floor_%s.png" % Tiles.surface_name(surface)))
	var walls: Array[Texture2D] = []
	for material: int in Tiles.WALL_MATERIALS.size():
		walls.append(_save(_wall_atlas(material), "walls_%s.png" % Tiles.WALL_MATERIALS[material]))
	var cover := _save(_cover_atlas(), "cover.png")
	var glass := _save(_glass_atlas(), "glass.png")

	_build_tileset(floors, walls, cover, glass)
	print("TILES_OK")
	print("  floors: %d atlases %dx%d" % [floors.size(), Tiles.SIZE * Tiles.FLOOR_VARIANTS, BAR_H])
	print("  walls:  %d atlases %dx%d" % [walls.size(), Tiles.SIZE * Tiles.WALL_COLUMNS, BAR_H])
	print("  cover:  %dx%d   glass: %dx%d" % [
		Tiles.SIZE * Tiles.LOW_COVER_KINDS.size(), BAR_H, Tiles.SIZE * Tiles.GLASS_TILES, BAR_H])
	quit(0)


## ---------------------------------------------------------------- palette --

func _ensure_palette() -> void:
	if ResourceLoader.exists(PALETTE_PATH):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PALETTE_PATH.get_base_dir()))
	var err := ResourceSaver.save(PaletteDef.make_default(), PALETTE_PATH)
	assert(err == OK, "cannot write %s" % PALETTE_PATH)
	print("gen_tiles: wrote default palette %s" % PALETTE_PATH)


## ------------------------------------------------------------------ noise --

## Seeded per-pixel hash → [0,1). Stable across runs and platforms.
func _hash(x: int, y: int, salt: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + salt * 2246822519
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0

## Deterministic dither over a rect: `amount` is the max lightness delta.
func _speckle(img: Image, ox: int, oy: int, r: Rect2i, amount: float,
		salt: int, density: float = 1.0) -> void:
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			if _hash(x, y, salt) > density:
				continue
			var c := img.get_pixel(ox + x, oy + y)
			var d := (_hash(x, y, salt + 1) - 0.5) * 2.0 * amount
			img.set_pixel(ox + x, oy + y, c.lightened(d) if d > 0.0 else c.darkened(-d))


func _fill_rect(img: Image, ox: int, r: Rect2i, color: Color) -> void:
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			img.set_pixel(ox + x, y, color)


func _hline(img: Image, ox: int, x0: int, x1: int, y: int, color: Color) -> void:
	for x: int in range(x0, x1):
		img.set_pixel(ox + x, y, color)


func _vline(img: Image, ox: int, x: int, y0: int, y1: int, color: Color) -> void:
	for y: int in range(y0, y1):
		img.set_pixel(ox + x, y, color)


## ----------------------------------------------------------------- floors --

func _floor_atlas(surface: int) -> Image:
	var img := Image.create(Tiles.SIZE * Tiles.FLOOR_VARIANTS, BAR_H, false, Image.FORMAT_RGBA8)
	for variant: int in Tiles.FLOOR_VARIANTS:
		var ox := variant * Tiles.SIZE
		match surface:
			Enums.Surface.CONCRETE: _draw_concrete(img, ox, variant)
			Enums.Surface.SAND: _draw_sand(img, ox, variant)
			Enums.Surface.METAL: _draw_metal(img, ox, variant)
			Enums.Surface.GRASS: _draw_grass(img, ox, variant)
			Enums.Surface.WOOD: _draw_wood(img, ox, variant)
			Enums.Surface.WATER: _draw_water(img, ox, variant)
	return img


func _draw_concrete(img: Image, ox: int, variant: int) -> void:
	var base := palette.floor_color(Enums.Surface.CONCRETE)
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, base)
	_speckle(img, ox, 0, full, 0.07, 11 + variant)
	# Aggregate flecks.
	for i: int in 18:
		var x := int(_hash(i, variant, 21) * Tiles.SIZE)
		var y := int(_hash(i, variant, 22) * Tiles.SIZE)
		img.set_pixel(ox + x, y, base.darkened(0.16))
	# Panel seams: 1 px inset border, brighter than the field.
	_hline(img, ox, 0, Tiles.SIZE, 0, base.darkened(0.22))
	_vline(img, ox, 0, 0, Tiles.SIZE, base.darkened(0.18))
	_hline(img, ox, 0, Tiles.SIZE, Tiles.SIZE - 1, base.lightened(0.08))
	_vline(img, ox, Tiles.SIZE - 1, 0, Tiles.SIZE, base.lightened(0.06))
	# Hairline crack on the third variant so long floors do not tile flat.
	if variant == 2:
		for i: int in 12:
			img.set_pixel(ox + 6 + i, 9 + int(_hash(i, variant, 33) * 3), palette.grout.lightened(0.35))


func _draw_sand(img: Image, ox: int, variant: int) -> void:
	var base := palette.floor_color(Enums.Surface.SAND)
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, base)
	_speckle(img, ox, 0, full, 0.09, 41 + variant)
	# Wind ripples: offset sine bands, shallow contrast.
	for y: int in Tiles.SIZE:
		var phase := fmod(float(y) + variant * 5.5, 11.0)
		if phase < 1.0:
			var shade := base.darkened(0.07)
			for x: int in Tiles.SIZE:
				if _hash(x, y + variant, 51) > 0.18:
					img.set_pixel(ox + x, y, shade)
		elif phase > 9.6:
			var light := base.lightened(0.06)
			for x: int in Tiles.SIZE:
				if _hash(x, y + variant, 52) > 0.25:
					img.set_pixel(ox + x, y, light)


func _draw_metal(img: Image, ox: int, variant: int) -> void:
	var base := palette.floor_color(Enums.Surface.METAL)
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, base)
	_speckle(img, ox, 0, full, 0.05, 61 + variant)
	# Diamond plate tread.
	for y: int in range(2, Tiles.SIZE - 2, 8):
		for x: int in range((y / 8 % 2) * 4 + 2, Tiles.SIZE - 3, 8):
			_hline(img, ox, x, x + 4, y, base.lightened(0.13))
			_hline(img, ox, x, x + 4, y + 1, base.darkened(0.12))
	# Rivets at the corners, two per edge.
	for p: Vector2i in [Vector2i(3, 3), Vector2i(Tiles.SIZE - 4, 3),
			Vector2i(3, Tiles.SIZE - 4), Vector2i(Tiles.SIZE - 4, Tiles.SIZE - 4)]:
		img.set_pixel(ox + p.x, p.y, base.lightened(0.22))
		img.set_pixel(ox + p.x + 1, p.y + 1, base.darkened(0.2))
	# Panel seam.
	_hline(img, ox, 0, Tiles.SIZE, 0, base.darkened(0.2))
	_vline(img, ox, 0, 0, Tiles.SIZE, base.darkened(0.2))


func _draw_grass(img: Image, ox: int, variant: int) -> void:
	var base := palette.floor_color(Enums.Surface.GRASS)
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, base)
	_speckle(img, ox, 0, full, 0.11, 71 + variant)
	# Blades: short vertical strokes in two greens.
	for i: int in 22:
		var x := int(_hash(i, variant, 81) * Tiles.SIZE)
		var y := int(_hash(i, variant, 82) * (Tiles.SIZE - 3))
		var len := 2 + int(_hash(i, variant, 83) * 2)
		var c := base.lightened(0.18) if i % 3 != 0 else base.darkened(0.2)
		_vline(img, ox, x, y, y + len, c)


func _draw_wood(img: Image, ox: int, variant: int) -> void:
	var base := palette.floor_color(Enums.Surface.WOOD)
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, base)
	# Planks: 8 px high, staggered per variant, seam between each.
	const PLANK_H := 8
	for plank: int in Tiles.SIZE / PLANK_H:
		var y0 := plank * PLANK_H
		if plank % 2 == 1:
			_fill_rect(img, ox, Rect2i(0, y0, Tiles.SIZE, PLANK_H), base.darkened(0.05))
		for x: int in Tiles.SIZE:
			var g := (_hash(x / 4, plank + variant, 91) - 0.5) * 0.08
			var c := base.lightened(g) if g > 0.0 else base.darkened(-g)
			img.set_pixel(ox + x, y0 + PLANK_H - 1, c.darkened(0.24))
		_hline(img, ox, 0, Tiles.SIZE, y0, base.darkened(0.18))
		# Knots.
		var kx := int(_hash(plank, variant, 92) * (Tiles.SIZE - 4)) + 2
		img.set_pixel(ox + kx, y0 + 3, base.darkened(0.3))
		img.set_pixel(ox + kx + 1, y0 + 3, base.darkened(0.18))
	# Plank butt joint.
	var jx := 8 + variant * 7
	_vline(img, ox, jx, 0, Tiles.SIZE, base.darkened(0.26))


func _draw_water(img: Image, ox: int, variant: int) -> void:
	var base := palette.floor_color(Enums.Surface.WATER)
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, base)
	_speckle(img, ox, 0, full, 0.04, 101 + variant)
	# Shimmer bands; the runtime shader animates movement (art §3), so the
	# baked tile only needs a static wave read.
	for y: int in Tiles.SIZE:
		var w := sin((y + variant * 7.0) * 0.55) * 3.0
		for x: int in Tiles.SIZE:
			var off := sin((x + w) * 0.4) * 0.5 + 0.5
			if off > 0.86:
				img.set_pixel(ox + x, y, base.lightened(0.16))
			elif off < 0.12:
				img.set_pixel(ox + x, y, base.darkened(0.12))


## ------------------------------------------------------------------ walls --

## 16-variant bitmask: bit 0 N, 1 E, 2 S, 3 W = neighbour is wall. Edges facing
## open space get a bevel + outline so walls read as solid volume.
func _wall_atlas(material: int) -> Image:
	var img := Image.create(Tiles.SIZE * Tiles.WALL_COLUMNS, BAR_H, false, Image.FORMAT_RGBA8)
	var base := palette.wall_color(Tiles.WALL_MATERIALS[material])
	for mask: int in Tiles.WALL_VARIANTS:
		var ox := mask * Tiles.SIZE
		match material:
			0: _draw_concrete_block(img, ox, mask, base)
			1: _draw_brick(img, ox, mask, base)
			2: _draw_container(img, ox, mask, base)
		_draw_wall_edges(img, ox, mask, base)
	# Interior mass: no exposed face at all (building core, thick wall). Dark
	# fill, else solid geometry reads lighter than the floor it hides.
	var interior_ox := Tiles.WALL_INTERIOR_COL * Tiles.SIZE
	# Interior mass: same material, no bevel/lighting. Distinct from the lit
	# face ring but still obviously the same wall, not a hole in the map.
	_fill_rect(img, interior_ox, Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE), base.darkened(0.2))
	_speckle(img, interior_ox, 0, Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE), 0.05, 241)
	return img


func _draw_concrete_block(img: Image, ox: int, mask: int, base: Color) -> void:
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, base)
	_speckle(img, ox, 0, full, 0.06, 201 + mask)
	# Block courses: 16×8 blocks, offset every other row. Low contrast: the
	# silhouette comes from the bevel, not from a grid.
	for row: int in 4:
		var y0 := row * 8
		_hline(img, ox, 0, Tiles.SIZE, y0, base.darkened(0.16))
		var offset := 8 if row % 2 == 1 else 0
		for x: int in range(offset, Tiles.SIZE, 16):
			_vline(img, ox, x, y0, y0 + 8, base.darkened(0.16))
	# Per-block tint jitter.
	for by: int in 4:
		for bx: int in 2:
			var d := (_hash(bx, by + mask, 211) - 0.5) * 0.035
			var r := Rect2i(bx * 16 + 1, by * 8 + 1, 15, 7)
			var c := base.lightened(d) if d > 0.0 else base.darkened(-d)
			_fill_rect(img, ox, r, c)
			_speckle(img, ox, 0, r, 0.04, 212 + mask + by * 4 + bx)


func _draw_brick(img: Image, ox: int, mask: int, base: Color) -> void:
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, palette.grout)
	# Bricks 16×8 with a 1 px mortar gap, staggered rows.
	for row: int in 4:
		var y0 := row * 8
		var offset := 8 if row % 2 == 1 else 0
		for x: int in range(-offset, Tiles.SIZE, 16):
			var x0 := maxi(x, 0)
			var w := mini(15, Tiles.SIZE - x0)
			if w <= 0:
				continue
			var r := Rect2i(x0, y0 + 1, w, 6)
			var d := (_hash(x, row + mask, 221) - 0.5) * 0.12
			var c := base.lightened(d) if d > 0.0 else base.darkened(-d)
			_fill_rect(img, ox, r, c)
			_speckle(img, ox, 0, r, 0.05, 222 + mask + row)


func _draw_container(img: Image, ox: int, mask: int, base: Color) -> void:
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, base)
	# Corrugation: vertical ridges every 6 px.
	for x: int in range(3, Tiles.SIZE, 6):
		_vline(img, ox, x, 0, Tiles.SIZE, base.darkened(0.16))
		_vline(img, ox, x + 1, 0, Tiles.SIZE, base.lightened(0.1))
	_speckle(img, ox, 0, full, 0.04, 231 + mask)
	# Rust bleeds.
	for i: int in 5:
		var x := int(_hash(i, mask, 232) * Tiles.SIZE)
		var y := int(_hash(i, mask, 233) * (Tiles.SIZE - 6))
		_vline(img, ox, x, y, y + 5, base.darkened(0.3))


## Bevel + outline only on sides facing open space (bitmask), so adjacent wall
## tiles merge into one silhouette.
func _draw_wall_edges(img: Image, ox: int, mask: int, base: Color) -> void:
	var light := base.lightened(0.16)
	var dark := base.darkened(0.3)
	if not (mask & 1):                       # N
		_hline(img, ox, 0, Tiles.SIZE, 0, light)
		_hline(img, ox, 0, Tiles.SIZE, 1, light.darkened(0.06))
	if not (mask & 8):                       # W
		_vline(img, ox, 0, 0, Tiles.SIZE, light)
		_vline(img, ox, 1, 0, Tiles.SIZE, light.darkened(0.06))
	if not (mask & 4):                       # S
		_hline(img, ox, 0, Tiles.SIZE, Tiles.SIZE - 1, dark)
		_hline(img, ox, 0, Tiles.SIZE, Tiles.SIZE - 2, dark.lightened(0.08))
	if not (mask & 2):                       # E
		_vline(img, ox, Tiles.SIZE - 1, 0, Tiles.SIZE, dark)
		_vline(img, ox, Tiles.SIZE - 2, 0, Tiles.SIZE, dark.lightened(0.08))


## ------------------------------------------------------------------ cover --

func _cover_atlas() -> Image:
	var img := Image.create(Tiles.SIZE * Tiles.LOW_COVER_KINDS.size(), BAR_H, false, Image.FORMAT_RGBA8)
	_draw_crate(img, 0)
	_draw_sandbag(img, Tiles.SIZE)
	_draw_car(img, Tiles.SIZE * 2)
	return img


## Crate: wood face + X brace + bright top face (the "shoot over" read).
func _draw_crate(img: Image, ox: int) -> void:
	var base := palette.cover_color(&"crate")
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, base)
	_speckle(img, ox, 0, full, 0.05, 301)
	var frame := base.darkened(0.35)
	# Plank lines.
	for y: int in [7, 15, 23]:
		_hline(img, ox, 2, Tiles.SIZE - 2, y, frame.darkened(0.1))
	# Frame.
	for i: int in 3:
		_hline(img, ox, 1, Tiles.SIZE - 1, i, frame)
		_vline(img, ox, i, 0, Tiles.SIZE, frame)
		_hline(img, ox, 1, Tiles.SIZE - 1, Tiles.SIZE - 1 - i, frame)
		_vline(img, ox, Tiles.SIZE - 1 - i, 0, Tiles.SIZE, frame)
	# X brace.
	for i: int in range(3, Tiles.SIZE - 3):
		var t := float(i - 3) / float(Tiles.SIZE - 6)
		var yl := 3 + int(t * (Tiles.SIZE - 7))
		img.set_pixel(ox + i, yl, frame.lightened(0.08))
		img.set_pixel(ox + i, Tiles.SIZE - 1 - yl, frame.lightened(0.08))
	# Top-face highlight: the top 4 px read as the lid you shoot over.
	_fill_rect(img, ox, Rect2i(3, 0, Tiles.SIZE - 6, 3), base.lightened(0.3))
	_hline(img, ox, 3, Tiles.SIZE - 3, 3, base.lightened(0.12))
	# Stencil.
	img.set_pixel(ox + 14, 12, frame.darkened(0.2))
	img.set_pixel(ox + 15, 12, frame.darkened(0.2))


func _draw_sandbag(img: Image, ox: int) -> void:
	var base := palette.cover_color(&"sandbag")
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, base.darkened(0.45))
	# Three staggered rows of bags; the top row is the bright lip.
	for row: int in 3:
		var y0 := 2 + row * 10
		var offset := 0 if row % 2 == 0 else 5
		for bag: int in 2:
			var x0 := 1 + offset + bag * 15
			if x0 >= Tiles.SIZE - 3:
				continue
			var w := mini(14, Tiles.SIZE - 2 - x0)
			var r := Rect2i(x0, y0, w, 8)
			var shade := base.lightened(0.18) if row == 0 else base.darkened(0.04 * row)
			_fill_rect(img, ox, r, shade)
			_speckle(img, ox, 0, r, 0.06, 311 + row * 3 + bag)
			# Bag seam + rounded end.
			_hline(img, ox, x0, x0 + w, y0 + 7, base.darkened(0.3))
			img.set_pixel(ox + x0 + w - 1, y0 + 4, base.darkened(0.22))
	# Top-face highlight.
	_hline(img, ox, 2, Tiles.SIZE - 2, 1, base.lightened(0.34))


func _draw_car(img: Image, ox: int) -> void:
	var base := palette.cover_color(&"car")
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, base.darkened(0.5))
	# Roof: bright top face.
	_fill_rect(img, ox, Rect2i(2, 1, Tiles.SIZE - 4, Tiles.SIZE - 5), base)
	_speckle(img, ox, 0, Rect2i(2, 1, Tiles.SIZE - 4, Tiles.SIZE - 5), 0.04, 321)
	# Windshield strip at the top edge (cyan glass), roof rails.
	_fill_rect(img, ox, Rect2i(4, 2, Tiles.SIZE - 8, 4), palette.glass_tint.darkened(0.15))
	_vline(img, ox, 3, 2, Tiles.SIZE - 4, base.lightened(0.22))
	_vline(img, ox, Tiles.SIZE - 4, 2, Tiles.SIZE - 4, base.lightened(0.22))
	# Outline.
	for i: int in 2:
		_hline(img, ox, 1, Tiles.SIZE - 1, i + Tiles.SIZE - 3, base.darkened(0.45))
		_vline(img, ox, i, 0, Tiles.SIZE, base.darkened(0.4))
		_vline(img, ox, Tiles.SIZE - 1 - i, 0, Tiles.SIZE, base.darkened(0.4))
	_hline(img, ox, 1, Tiles.SIZE - 1, 0, base.darkened(0.3))
	# Top-face highlight lip.
	_hline(img, ox, 2, Tiles.SIZE - 2, 1, base.lightened(0.3))


## ------------------------------------------------------------------ glass --

func _glass_atlas() -> Image:
	var img := Image.create(Tiles.SIZE * Tiles.GLASS_TILES, BAR_H, false, Image.FORMAT_RGBA8)
	for stage: int in Tiles.GLASS_TILES:
		_draw_glass(img, stage * Tiles.SIZE, stage)
	return img


func _draw_glass(img: Image, ox: int, stage: int) -> void:
	var tint := palette.glass_tint
	var full := Rect2i(0, 0, Tiles.SIZE, Tiles.SIZE)
	_fill_rect(img, ox, full, tint.darkened(0.15))
	# Frame.
	var frame := Color(0.22, 0.26, 0.28, 0.95)
	for i: int in 2:
		_hline(img, ox, 0, Tiles.SIZE, i, frame)
		_hline(img, ox, 0, Tiles.SIZE, Tiles.SIZE - 1 - i, frame)
		_vline(img, ox, i, 0, Tiles.SIZE, frame)
		_vline(img, ox, Tiles.SIZE - 1 - i, 0, Tiles.SIZE, frame)
	# Highlight streaks.
	for i: int in 3:
		var x := 5 + i * 8
		for y: int in range(4, Tiles.SIZE - 4):
			if _hash(x, y, 401 + stage) > 0.35:
				continue
			img.set_pixel(ox + x, y, tint.lightened(0.35))
	if stage >= 1:
		_draw_crack(img, ox, 12, 14, stage * 7)
		_draw_crack(img, ox, 20, 20, stage * 9 + 3)
	if stage >= 2:
		_draw_crack(img, ox, 9, 22, 881)
		_draw_crack(img, ox, 24, 10, 882)
	if stage == Tiles.GLASS_TILES - 1:
		# Open: only the frame + a few shards at the sill remain.
		_fill_rect(img, ox, Rect2i(2, 2, Tiles.SIZE - 4, Tiles.SIZE - 4), Color(0, 0, 0, 0))
		var shard := tint.lightened(0.3)
		for p: Vector2i in [Vector2i(4, Tiles.SIZE - 5), Vector2i(7, Tiles.SIZE - 4),
				Vector2i(Tiles.SIZE - 6, Tiles.SIZE - 5), Vector2i(Tiles.SIZE - 9, Tiles.SIZE - 3)]:
			img.set_pixel(ox + p.x, p.y, shard)


func _draw_crack(img: Image, ox: int, start_x: int, start_y: int, salt: int) -> void:
	var x := start_x
	var y := start_y
	var color := Color(0.9, 0.97, 1.0, 0.8)
	for step: int in 9:
		var dx := 1 if _hash(step, salt, 411) > 0.35 else 0
		var dy := 1 if _hash(step, salt, 412) > 0.5 else -1
		x = clampi(x + dx, 2, Tiles.SIZE - 3)
		y = clampi(y + dy, 2, Tiles.SIZE - 3)
		img.set_pixel(ox + x, y, color)
		# Branch every third step.
		if step % 3 == 0:
			var bx := clampi(x + (1 if step % 2 == 0 else -1), 2, Tiles.SIZE - 3)
			img.set_pixel(ox + bx, clampi(y + 1, 2, Tiles.SIZE - 3), color.darkened(0.15))


## ---------------------------------------------------------------- tileset --

func _build_tileset(floors: Array[Texture2D], walls: Array[Texture2D],
		cover: Texture2D, glass: Texture2D) -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(Tiles.SIZE, Tiles.SIZE)

	# Physics layers 0/1/2 -> collision layers 1 WORLD, 5 LOW_COVER, 6 GLASS.
	for layer: int in 3:
		ts.add_physics_layer(-1)
	ts.set_physics_layer_collision_layer(0, Layers.WORLD_BIT)
	ts.set_physics_layer_collision_layer(1, Layers.LOW_COVER_BIT)
	ts.set_physics_layer_collision_layer(2, Layers.GLASS_BIT)
	for layer: int in 3:
		ts.set_physics_layer_collision_mask(layer, 0)
	# Navigation layer 0 (bit 1). Baked into Nav; TileMapLayer nav stays off.
	ts.add_navigation_layer(-1)
	ts.set_navigation_layer_layers(0, 1)

	_add_custom_data(ts, &"surface", TYPE_INT)
	_add_custom_data(ts, &"penetrable", TYPE_BOOL)
	_add_custom_data(ts, &"low_cover", TYPE_BOOL)
	_add_custom_data(ts, &"blocks_sound", TYPE_BOOL)

	# Floors: walkable, no collision, no nav polygon. Source id == row index
	# into Tiles.FLOOR_SURFACES (not Enums.Surface, which has glass in the middle).
	for row: int in floors.size():
		var surface: int = Tiles.FLOOR_SURFACES[row]
		var src := _source(ts, floors[row], Tiles.FLOOR_VARIANTS, 1, Tiles.SOURCE_FLOORS + row)
		for v: int in Tiles.FLOOR_VARIANTS:
			var td := src.get_tile_data(Vector2i(v, 0), 0)
			td.set_custom_data(&"surface", surface)
			td.set_custom_data(&"penetrable", false)
			td.set_custom_data(&"low_cover", false)
			td.set_custom_data(&"blocks_sound", false)
	# Wall materials share one source id range (Tiles.SOURCE_WALLS + material).
	for material: int in walls.size():
		var src := _source(ts, walls[material], Tiles.WALL_COLUMNS, 1,
			Tiles.SOURCE_WALLS + material)
		for column: int in Tiles.WALL_COLUMNS:
			var td := src.get_tile_data(Vector2i(column, 0), 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, _rect_points())
			_set_nav_polygon(td)
			td.set_custom_data(&"surface", Tiles.WALL_SURFACES[material])
			td.set_custom_data(&"penetrable", false)
			td.set_custom_data(&"low_cover", false)
			td.set_custom_data(&"blocks_sound", true)
	# Low cover: physics layer 1, blocks movement/bullets, not sound.
	var cover_src := _source(ts, cover, Tiles.LOW_COVER_KINDS.size(), 1, Tiles.SOURCE_COVER)
	for kind: int in Tiles.LOW_COVER_KINDS.size():
		var td := cover_src.get_tile_data(Tiles.cover_coord(kind), 0)
		td.add_collision_polygon(1)
		td.set_collision_polygon_points(1, 0, _rect_points())
		_set_nav_polygon(td)
		td.set_custom_data(&"surface", Tiles.COVER_SURFACES[kind])
		td.set_custom_data(&"penetrable", Tiles.COVER_PENETRABLE[kind])
		td.set_custom_data(&"low_cover", true)
		td.set_custom_data(&"blocks_sound", false)
	# Glass: physics layer 2, blocks movement, penetrable, one-wall sound.
	var glass_src := _source(ts, glass, Tiles.GLASS_TILES, 1, Tiles.SOURCE_GLASS)
	for stage: int in Tiles.GLASS_TILES:
		var td := glass_src.get_tile_data(Tiles.glass_coord(stage), 0)
		td.add_collision_polygon(2)
		td.set_collision_polygon_points(2, 0, _rect_points())
		_set_nav_polygon(td)
		td.set_custom_data(&"surface", Enums.Surface.GLASS)
		td.set_custom_data(&"penetrable", true)
		td.set_custom_data(&"low_cover", false)
		td.set_custom_data(&"blocks_sound", true)

	var err := ResourceSaver.save(ts, TILESET_PATH)
	assert(err == OK, "cannot write %s" % TILESET_PATH)


func _add_custom_data(ts: TileSet, name: StringName, type: int) -> void:
	ts.add_custom_data_layer(-1)
	ts.set_custom_data_layer_name(ts.get_custom_data_layers_count() - 1, name)
	ts.set_custom_data_layer_type(ts.get_custom_data_layers_count() - 1, type)


func _source(ts: TileSet, tex: Texture2D, columns: int, rows: int, id: int) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(Tiles.SIZE, Tiles.SIZE)
	ts.add_source(src, id)
	for y: int in rows:
		for x: int in columns:
			src.create_tile(Vector2i(x, y), Vector2i(1, 1))
	return src


## Tile-local (top-left origin) full-tile polygon.
func _rect_points() -> PackedVector2Array:
	var s := float(Tiles.SIZE)
	return PackedVector2Array([Vector2.ZERO, Vector2(s, 0), Vector2(s, s), Vector2(0, s)])


## Tile nav polygon (layer 0). Built from vertices+indices directly:
## `make_polygons_from_outlines` is deprecated in 4.7.
func _set_nav_polygon(td: TileData) -> void:
	var nav := NavigationPolygon.new()
	nav.vertices = _rect_points()
	nav.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	td.set_navigation_polygon(0, nav)


## ------------------------------------------------------------------- save --

func _save(img: Image, name: String) -> Texture2D:
	var path := "%s/%s" % [OUT_DIR, name]
	var abs_path := ProjectSettings.globalize_path(path)
	var err := img.save_png(abs_path)
	assert(err == OK, "cannot write %s" % path)
	return ImageTexture.create_from_image(img)