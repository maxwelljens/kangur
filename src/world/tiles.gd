class_name Tiles
extends RefCounted
## Tile atlas layout constants shared by `tools/gen_tiles.gd` (writes the
## atlases + TileSet) and `tools/build_map.gd` (paints cells). Atlas rows and
## columns are the single source of truth for the generated PNG layout.
## See `docs/design/art-direction.md` §3.

const SIZE := 32
## Lives next to the atlas PNGs it indexes, outside `data/` (Defs scans
## `data/**/*.tres` and warns on non-Def resources). Binary: it embeds the atlas
## images, which as text would be ~1.4 MB of byte arrays. Generated file — edit
## the palette + `tools/gen_tiles.gd`, never this.
const TILESET_PATH := "res://assets/sprites/tiles/kangur.res"
const FLOOR_DIR := "res://assets/sprites/tiles"

const SOURCE_FLOORS := 0
## Spaced per family: atlas source ids must be unique across the TileSet.
const SOURCE_WALLS := 16
const SOURCE_COVER := 32
const SOURCE_GLASS := 33

## Layout: floors `Vector2i(variant, surface)`, walls `Vector2i(mask, material)`,
## cover `Vector2i(kind, 0)`, glass `Vector2i(stage, 0)`.
const FLOOR_VARIANTS := 3
## 16 bitmask face variants + 1 interior column (no exposed face -> dark mass).
const WALL_VARIANTS := 16
const WALL_INTERIOR_COL := 16
const WALL_COLUMNS := 17
const GLASS_TILES := 4

## Enums.Surface order — do not reorder (glass included: 7 values).
const SURFACE_NAMES: Array[StringName] = [
	&"concrete", &"sand", &"metal", &"grass", &"wood", &"glass", &"water",
]
## Surfaces that get a floor atlas. Glass is a wall/window material only, so it
## is deliberately absent — floor atlas source ids index into this list.
const FLOOR_SURFACES: Array[int] = [
	Enums.Surface.CONCRETE, Enums.Surface.SAND, Enums.Surface.METAL,
	Enums.Surface.GRASS, Enums.Surface.WOOD, Enums.Surface.WATER,
]
const WALL_MATERIALS: Array[StringName] = [&"concrete_block", &"brick", &"container"]
## Surface a wall of each material reports to footsteps/bullet impacts.
const WALL_SURFACES: Array[int] = [
	Enums.Surface.CONCRETE, Enums.Surface.CONCRETE, Enums.Surface.METAL,
]
const LOW_COVER_KINDS: Array[StringName] = [&"crate", &"sandbag", &"car"]
const COVER_SURFACES: Array[int] = [
	Enums.Surface.WOOD, Enums.Surface.SAND, Enums.Surface.METAL,
]
## Wood crates are shoot-through (maps.md: wood penetrable ×0.55).
const COVER_PENETRABLE: Array[bool] = [true, false, false]

static func surface_name(surface: int) -> StringName:
	if surface < 0 or surface >= SURFACE_NAMES.size():
		return &"concrete"
	return SURFACE_NAMES[surface]

static func surface_from_name(surface: String) -> int:
	var idx := SURFACE_NAMES.find(StringName(surface))
	return maxi(idx, Enums.Surface.CONCRETE)

## Atlas coords for a floor tile. Each surface has its own atlas (one row), so
## the y is always 0 and the source id picks the surface (see `floor_source`).
static func floor_coord(surface: int, variant: int) -> Vector2i:
	return Vector2i(posmod(variant, FLOOR_VARIANTS), 0)

## Atlas source id for a floor surface; glass has no floor atlas -> concrete.
static func floor_source(surface: int) -> int:
	return SOURCE_FLOORS + maxi(FLOOR_SURFACES.find(surface), 0)

## Walls: one atlas per material, 16 bitmask face variants along x plus the
## interior column at WALL_INTERIOR_COL.
static func wall_coord(mask: int) -> Vector2i:
	return Vector2i(mask & 0xF, 0)

## Interior mass tile: used only when a cell has no exposed face at all, so a
## freestanding 2x2 pillar keeps its lit bevel instead of becoming a hole.
static func wall_interior_coord() -> Vector2i:
	return Vector2i(WALL_INTERIOR_COL, 0)

static func cover_coord(kind: int) -> Vector2i:
	return Vector2i(clampi(kind, 0, LOW_COVER_KINDS.size() - 1), 0)

static func glass_coord(stage: int) -> Vector2i:
	return Vector2i(clampi(stage, 0, GLASS_TILES - 1), 0)