extends Node2D
## Weapon-silhouette lineup: every indexed weapon drawn side by side at the same
## scale, so the authored visual params are inspectable in one frame.
##   tools/godot.sh --path . --resolution 2560x1440 \
##     -- --shot=res://tools/shot_weapons.tscn:20:reports/screenshots/weapons.png

const RigScript := preload("res://src/entities/rig.gd")

const BACKGROUND := Color(0.043, 0.055, 0.078)
const LABEL := Color(0.72, 0.78, 0.85)
const CELL := Vector2(620.0, 260.0)
const ORIGIN := Vector2(60.0, 90.0)
const RIG_SCALE := 4.0
const LABEL_DROP := 78.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND)
	var weapons := Defs.all_weapons()
	var cols := 3
	for i: int in weapons.size():
		var def: WeaponDef = weapons[i]
		var pos := ORIGIN + Vector2(CELL.x * float(i % cols),
			CELL.y * float(i / cols))
		_place(pos, def, i)
	_add_title(Vector2(ORIGIN.x - 40.0, 24.0))
	print("WEAPONS %d" % weapons.size())

func _place(pos: Vector2, def: WeaponDef, index: int) -> void:
	var holder := Node2D.new()
	holder.position = pos + Vector2(0.0, LABEL_DROP)
	add_child(holder)
	var rig: Node2D = RigScript.new()
	rig.scale = Vector2(RIG_SCALE, RIG_SCALE)
	holder.add_child(rig)
	var team := Enums.Team.BASTION if index % 2 == 0 else Enums.Team.SIROCCO
	rig.apply_team_palette(team)
	rig.setup(team, rig.faction_primary, rig.faction_accent, rig.visor_color,
		&"vanguard")
	rig.set_weapon(def)
	rig.update(Vector2.ZERO, Vector2.RIGHT, Enums.Stance.STAND,
		{&"focus": false, &"reloading": false, &"reload_progress": 0.0,
		&"bandaging": false, &"bandage_progress": 0.0, &"health": 1.0})
	rig.queue_redraw()
	_add_label(pos + Vector2(0.0, 168.0),
		"%s  %s" % [def.display_name, String(def.category)],
		LABEL, 15)
	_add_label(pos + Vector2(0.0, 188.0),
		"body %.0f barrel %.0f w %.1f mag %.0f@%.0f stock %.0f scope %s" % [
			def.body_len, def.barrel_len, def.body_width, def.mag_len,
			def.mag_offset, def.stock_len, str(def.has_scope)],
		LABEL.darkened(0.45), 11)

func _add_title(pos: Vector2) -> void:
	_add_label(pos, "Kangur weapon silhouettes — authored WeaponDef visual params",
		LABEL, 17)

func _add_label(pos: Vector2, text: String, color: Color, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", size)
	add_child(label)