class_name PaletteDef
extends Resource
## Colour palette for procedural tile atlases and the minimap bake.
## Instances live in `res://data/palettes/`. Designer-editable: recolour the
## `.tres` and re-run `tools/gen_tiles.gd` to regenerate the PNG atlases.
## World-owned schema addition (not a core contract, no MapDef field).

@export var surface_colors: Dictionary[StringName, Color] = {}
@export var wall_colors: Dictionary[StringName, Color] = {}
@export var cover_colors: Dictionary[StringName, Color] = {}
@export var glass_tint: Color = Color(0.55, 0.9, 0.95, 0.42)
@export var minimap_floor_tints: Dictionary[StringName, Color] = {}
@export var minimap_wall: Color = Color(0.09, 0.1, 0.12)
@export var minimap_cover: Color = Color(0.42, 0.44, 0.47)
## Mortar seams, bevels, outlines.
@export var grout: Color = Color(0.16, 0.17, 0.19)

## Base palette used when `data/palettes/default.tres` does not exist yet
## (first `gen_tiles` run writes it). After that the .tres is the source.
static func make_default() -> PaletteDef:
	var p := PaletteDef.new()
	p.surface_colors = {
		&"concrete": Color(0.43, 0.44, 0.46),
		&"sand": Color(0.79, 0.64, 0.41),
		&"metal": Color(0.49, 0.52, 0.55),
		&"grass": Color(0.30, 0.48, 0.23),
		&"wood": Color(0.54, 0.35, 0.22),
		&"water": Color(0.18, 0.43, 0.56),
	}
	p.wall_colors = {
		&"concrete_block": Color(0.50, 0.51, 0.53),
		&"brick": Color(0.55, 0.29, 0.23),
		&"container": Color(0.30, 0.42, 0.37),
	}
	p.cover_colors = {
		&"crate": Color(0.60, 0.42, 0.24),
		&"sandbag": Color(0.69, 0.60, 0.42),
		&"car": Color(0.35, 0.42, 0.45),
	}
	p.minimap_floor_tints = {
		&"concrete": Color(0.23, 0.24, 0.26),
		&"sand": Color(0.29, 0.25, 0.17),
		&"metal": Color(0.21, 0.24, 0.26),
		&"grass": Color(0.17, 0.23, 0.15),
		&"wood": Color(0.23, 0.18, 0.14),
		&"water": Color(0.12, 0.21, 0.25),
	}
	return p

func floor_color(surface: int) -> Color:
	return surface_colors.get(Tiles.surface_name(surface), Color.MAGENTA)

func wall_color(material: StringName) -> Color:
	return wall_colors.get(material, Color.MAGENTA)

func cover_color(kind: StringName) -> Color:
	return cover_colors.get(kind, Color.MAGENTA)

func minimap_tint(surface: int) -> Color:
	return minimap_floor_tints.get(Tiles.surface_name(surface), minimap_wall)