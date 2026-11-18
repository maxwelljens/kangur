extends Node2D
## Rig states sheet (art-direction §6: every visual system ships a fixture).
## Run: tools/godot.sh --path . -- --shot=res://tools/shot_rig.tscn:20:reports/screenshots/rig_states.png
## Draws both factions × several weapons × all rig states so a regression shows
## up as a visible diff in the one PNG.

const RigScript := preload("res://src/entities/rig.gd")
const WeaponVisual := preload("res://src/entities/weapon_visual.gd")

const BACKGROUND := Color(0.043, 0.055, 0.078)
const GRID := Color(0.16, 0.19, 0.24)
const LABEL := Color(0.72, 0.78, 0.85)
const CELL := Vector2(150.0, 132.0)
const ORIGIN := Vector2(96.0, 86.0)
const RIG_SCALE := 2.4
## Rigs sit low in their cell so the row/faction labels clear the drawn body.
const RIG_DROP := 22.0
const DT := 1.0 / 60.0

## Weapon + class matrix: one row per silhouette family.
const ROWS: Array[Dictionary] = [
	{&"class": &"vanguard", &"weapon": &"kestrel", &"label": "Vanguard / Kestrel AR"},
	{&"class": &"pathfinder", &"weapon": &"vespa", &"label": "Pathfinder / Vespa SMG"},
	{&"class": &"bulwark", &"weapon": &"mule", &"label": "Bulwark / Mule LMG"},
	{&"class": &"ram", &"weapon": &"breve", &"label": "Ram / Breve shotgun"},
	{&"class": &"longshot", &"weapon": &"lynx", &"label": "Longshot / Lynx sniper"},
	{&"class": &"vanguard", &"weapon": &"adder", &"label": "Vanguard / Adder pistol"},
]

## State columns shown for every row.
const STATES: Array[StringName] = [
	&"idle", &"walk", &"sprint", &"crouch", &"focus", &"reload", &"bandage",
	&"hit", &"death",
]

var _rigs: Array[Node2D] = []

func _ready() -> void:
	_build_sheet()
	await get_tree().physics_frame
	_drive_poses()
	await get_tree().process_frame
	await get_tree().process_frame

func _build_sheet() -> void:
	var rows := ROWS.size()
	var cols := STATES.size()
	var size := Vector2(ORIGIN.x + CELL.x * float(cols) + 24.0,
		ORIGIN.y + CELL.y * float(rows) + 24.0)
	RenderingServer.set_default_clear_color(BACKGROUND)
	for row: int in rows:
		var team := Enums.Team.BASTION if row % 2 == 0 else Enums.Team.SIROCCO
		for col: int in cols:
			var pos := ORIGIN + Vector2(CELL.x * float(col), CELL.y * float(row))
			_place_rig(pos, team, ROWS[row], STATES[col])
	# Rows are faction-alternating so readability of both palettes is obvious.
	_add_labels(size)

func _place_rig(pos: Vector2, team: int, row: Dictionary, state: StringName) -> void:
	var holder := Node2D.new()
	holder.position = pos + Vector2(0.0, RIG_DROP)
	add_child(holder)
	var rig: Node2D = RigScript.new()
	rig.scale = Vector2(RIG_SCALE, RIG_SCALE)
	holder.add_child(rig)
	rig.apply_team_palette(team)
	rig.setup(team, rig.faction_primary, rig.faction_accent, rig.visor_color,
		row[&"class"])
	var weapon := Defs.weapon(row[&"weapon"])
	rig.set_weapon(weapon if weapon != null else _fallback_weapon(row[&"weapon"]))
	_pose(rig, state)
	rig.queue_redraw()
	_rigs.append(rig)

## Static poses instead of simulated physics: the sheet must be deterministic.
func _pose(rig: Node2D, state: StringName) -> void:
	var aim := Vector2.RIGHT
	var velocity := Vector2.ZERO
	var stance: Enums.Stance = Enums.Stance.STAND
	var extra := {&"focus": false, &"reloading": false, &"reload_progress": 0.0,
		&"bandaging": false, &"bandage_progress": 0.0, &"health": 1.0}
	match state:
		&"walk":
			velocity = Vector2(130.0, 0.0)
			rig.set(&"_gait_phase", 1.1)
			rig.set(&"_bob", 0.4)
			rig.set(&"_lean", RigScript.SPRINT_LEAN_PX * 0.4)
		&"sprint":
			velocity = Vector2(215.0, 0.0)
			extra[&"sprinting"] = true
			rig.set(&"_gait_phase", 2.2)
			rig.set(&"_bob", 0.2)
			rig.set(&"_lean", RigScript.SPRINT_LEAN_PX)
		&"crouch":
			stance = Enums.Stance.CROUCH
			rig.set(&"_scale", RigScript.CROUCH_SCALE)
		&"focus":
			extra[&"focus"] = true
			rig.set(&"_lean", -RigScript.FOCUS_LEAN_PX)
		&"reload":
			extra[&"reloading"] = true
			extra[&"reload_progress"] = 0.22
		&"bandage":
			extra[&"bandaging"] = true
			extra[&"bandage_progress"] = 0.5
			extra[&"health"] = 0.45
		&"hit":
			extra[&"health"] = 0.7
			rig.set(&"_flinch", RigScript.FLINCH_TIME)
			rig.set(&"_flinch_dir", Vector2(-1.0, 0.2).normalized())
		&"death":
			rig.set(&"alive", false)
			rig.set(&"_death_rot", RigScript.DEATH_ROT)
			rig.set(&"_death_t", 0.8)
	rig.update(velocity, aim, stance, extra)

## Content wave provides the real weapons; the fixture must still draw before
## data/ is populated, so a synthetic def keeps every silhouette visible.
func _fallback_weapon(id: StringName) -> WeaponDef:
	var def := WeaponDef.new()
	def.id = id
	def.display_name = String(id)
	def.category = &"ar"
	def.weight = 3.5
	return def

func _add_labels(size: Vector2) -> void:
	for col: int in STATES.size():
		var label := Label.new()
		label.text = String(STATES[col])
		label.position = ORIGIN + Vector2(CELL.x * float(col) - 26.0, -46.0)
		label.add_theme_color_override(&"font_color", LABEL)
		label.add_theme_font_size_override(&"font_size", 13)
		add_child(label)
	for row: int in ROWS.size():
		var label := Label.new()
		label.text = ROWS[row][&"label"]
		label.position = Vector2(6.0, ORIGIN.y + CELL.y * float(row) - 20.0)
		label.add_theme_color_override(&"font_color", LABEL)
		label.add_theme_font_size_override(&"font_size", 11)
		add_child(label)
		var faction := Label.new()
		faction.text = "BASTION" if row % 2 == 0 else "SIROCCO"
		faction.position = Vector2(6.0, ORIGIN.y + CELL.y * float(row) - 8.0)
		faction.add_theme_color_override(&"font_color",
			RigScript.BASTION_ACCENT if row % 2 == 0 else RigScript.SIROCCO_PRIMARY)
		faction.add_theme_font_size_override(&"font_size", 10)
		add_child(faction)
	var title := Label.new()
	title.text = "Kangur rig states — both factions, weapon silhouettes, pose set"
	title.position = Vector2(6.0, 6.0)
	title.add_theme_color_override(&"font_color", LABEL)
	title.add_theme_font_size_override(&"font_size", 15)
	add_child(title)
	var note := Label.new()
	note.text = "size=%s (viewport stretch canvas_items)" % size
	note.position = Vector2(6.0, 24.0)
	note.add_theme_color_override(&"font_color", GRID)
	note.add_theme_font_size_override(&"font_size", 10)
	add_child(note)

func _drive_poses() -> void:
	for rig: Node2D in _rigs:
		rig.queue_redraw()