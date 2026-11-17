extends CanvasLayer
class_name Hud
## Match HUD (design §11). One CanvasLayer holding every widget; it reads the
## pure models through `bind_character(character)` and never mutates gameplay.
##
## Wiring contract (thin layer over models — no Character dependency):
##   bind_character(char) reads defensively:
##     char.team:int, char.callsign:String, char.class_def:ClassDef
##     char.get_body_model() -> BodyModel    (fallback: `body_model` property)
##     char.get_weapon_model() -> WeaponModel (fallback: `weapon_model` property)
##     char.get_bandages() -> int            (fallback: `bandages`, then class_def)
##   The match calls `refresh()` (or relies on the built-in 10 Hz tick).
## Spectating/death: `show_killcam()` / `clear_killcam()`.
##
## EventBus: character_died, character_hit, radio_message, objective_progress,
## tickets_changed, settings_changed.

const KangurTheme := preload("res://src/ui/theme.gd")
const UiFx := preload("res://src/ui/ui_fx.gd")
const HW := preload("res://src/ui/holo_widgets.gd")
const PauseMenuScript := preload("res://src/ui/pause/pause_menu.gd")

const MINIMAP_SIZE := 200.0
const HUD_MARGIN := 22.0
const KILLFEED_MAX := 5
const RADIO_MAX := 4
const LOW_HP_THRESHOLD := 0.35
const REFRESH_HZ := 10.0
const MAG_LOW_RATIO := 0.30
const TICKET_WARN := 6

var character: Node = null
var body: BodyModel = null
var weapon: WeaponModel = null
var bandages: int = 0
var team: int = Enums.Team.BASTION

## Minimap + crosshair API for the world/VisionSystem wiring.
var minimap: HW.MinimapFrame = null
var crosshair: HW.Crosshair = null
var hitmarker: HW.Hitmarker = null
var damage_arcs: HW.DamageArcs = null
var body_diagram: HW.BodyDiagram = null
var pause_menu: Control = null
var objective_chain: HW.ObjectiveChain = null

var _root: Control = null
var _hp_value: Label = null
var _hp_bar: HW.Bar = null
var _bandage_label: Label = null
var _bandage_bar: HW.Bar = null
var _vest_pips: HW.ArmorPips = null
var _helmet_pips: HW.ArmorPips = null
var _weapon_name: Label = null
var _weapon_glyph: HW.WeaponGlyph = null
var _ammo_label: Label = null
var _reserve_label: Label = null
var _fire_mode: Label = null
var _reload_bar: HW.Bar = null
var _equip_row: HBoxContainer = null
var _timer_label: Label = null
var _alive_label: Label = null
var _enemy_alive: Label = null
var _ticket_row: HBoxContainer = null
var _ticket_bars: Array[HW.Bar] = []
var _killfeed: VBoxContainer = null
var _radio_stack: VBoxContainer = null
var _vignette: HW.LowHpVignette = null
var _scoreboard: Control = null
var _score_rows: VBoxContainer = null
var _killcam: Control = null
var _killcam_labels: Array[Label] = []
var _strip: Control = null
var _health_panel: Control = null
var _weapon_panel: Control = null

var _refresh_timer := 0.0
var _time_left := 0.0
var _mode: int = Enums.Mode.ELIMINATION
var _tickets: Array[int] = [0, 0]
var _alive: Array[int] = [0, 0]
var _roster: Array[Dictionary] = []
## HUD scale factor from Settings (video/hud_scale, 0.8–1.4).
var _k := 1.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mode = Game.match_config.mode if Game.match_config != null else Enums.Mode.ELIMINATION
	_time_left = Game.match_config.time_limit_s if Game.match_config != null else 0.0
	_build()
	_connect_bus()
	_refresh()

## Scale a designed px value by the HUD scale setting. Scaling offsets rather
## than the whole CanvasLayer keeps every block anchored to its screen corner.
func _s(px: float) -> float:
	return px * _k

func _fs(px: int) -> int:
	return maxi(int(round(float(px) * _k)), 8)

func _build() -> void:
	_k = clampf(float(Settings.get_value(&"video", &"hud_scale", 1.0)), 0.8, 1.4)
	_root = Control.new()
	_root.name = "HudRoot"
	_root.theme = load("res://src/ui/kangur_theme.tres")
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_vignette = HW.LowHpVignette.new()
	_root.add_child(_vignette)
	damage_arcs = HW.DamageArcs.new()
	_root.add_child(damage_arcs)
	crosshair = HW.Crosshair.new()
	_root.add_child(crosshair)
	hitmarker = HW.Hitmarker.new()
	_root.add_child(hitmarker)

	_build_health_block()
	_build_weapon_block()
	_build_mode_strip()
	_build_minimap()
	_build_feed()
	_build_scoreboard()
	_build_killcam()

	pause_menu = PauseMenuScript.new()
	add_child(pause_menu)

## Rebuild at a new scale. Transient feed lines are dropped; persistent state
## (alive/tickets/objectives/roster) is re-applied.
func _relayout() -> void:
	var alive := _alive.duplicate()
	var tickets := _tickets.duplicate()
	var roster := _roster.duplicate()
	if _root != null:
		_root.queue_free()
	_build()
	set_alive_counts(alive[0], alive[1])
	set_tickets(tickets[0], tickets[1])
	set_roster(roster)
	_refresh()

# --- bottom-left: body, HP, bandages, armour ---------------------------------
func _build_health_block() -> void:
	var width := _s(346.0)
	var height := _s(196.0)
	var panel := HW.Plate.new()
	panel.name = "HealthBlock"
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = _s(HUD_MARGIN)
	panel.offset_right = _s(HUD_MARGIN) + width
	panel.offset_top = -height - _s(HUD_MARGIN)
	panel.offset_bottom = -_s(HUD_MARGIN)
	_root.add_child(panel)
	_health_panel = panel

	body_diagram = HW.BodyDiagram.new()
	body_diagram.position = Vector2(_s(16.0), _s(14.0))
	body_diagram.custom_minimum_size = Vector2(_s(104.0), _s(132.0))
	body_diagram.size = body_diagram.custom_minimum_size
	panel.add_child(body_diagram)

	var col := VBoxContainer.new()
	col.position = Vector2(_s(136.0), _s(14.0))
	col.custom_minimum_size.x = width - _s(152.0)
	col.size = Vector2(width - _s(152.0), height - _s(28.0))
	col.add_theme_constant_override(&"separation", _fs(4))
	panel.add_child(col)

	col.add_child(_caption("VITALS"))
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override(&"separation", _fs(6))
	col.add_child(hp_row)
	_hp_value = Label.new()
	_hp_value.text = "80"
	_hp_value.add_theme_font_override(&"font", KangurTheme.FONT_MONO)
	_hp_value.add_theme_font_size_override(&"font_size", _fs(40))
	hp_row.add_child(_hp_value)
	var hp_unit := _caption("HP")
	hp_unit.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hp_row.add_child(hp_unit)

	_hp_bar = HW.Bar.new()
	_hp_bar.custom_minimum_size = Vector2(0.0, _s(8.0))
	col.add_child(_hp_bar)

	# Armour gets its own rows: two 4-pip bars side by side overflow the panel.
	_vest_pips = HW.ArmorPips.new()
	_vest_pips.caption = "VST"
	_vest_pips.color = KangurTheme.HOLO
	_vest_pips.custom_minimum_size = Vector2(0.0, _s(11.0))
	col.add_child(_vest_pips)
	_helmet_pips = HW.ArmorPips.new()
	_helmet_pips.caption = "HLM"
	_helmet_pips.color = KangurTheme.HOLO
	_helmet_pips.custom_minimum_size = Vector2(0.0, _s(11.0))
	col.add_child(_helmet_pips)

	var bandage_row := HBoxContainer.new()
	bandage_row.add_theme_constant_override(&"separation", _fs(8))
	col.add_child(bandage_row)
	bandage_row.add_child(_caption("BANDAGE"))
	_bandage_label = Label.new()
	_bandage_label.text = "x3"
	_bandage_label.theme_type_variation = &"Mono"
	bandage_row.add_child(_bandage_label)

	_bandage_bar = HW.Bar.new()
	_bandage_bar.custom_minimum_size = Vector2(0.0, _s(6.0))
	_bandage_bar.color = KangurTheme.TEXT
	col.add_child(_bandage_bar)

func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"MonoSmall"
	label.add_theme_font_size_override(&"font_size", _fs(KangurTheme.SIZE_MONO_SMALL))
	label.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	return label

# --- bottom-right: weapon, ammo, equipment -----------------------------------
func _build_weapon_block() -> void:
	var width := _s(356.0)
	var height := _s(150.0)
	var panel := HW.Plate.new()
	panel.name = "WeaponBlock"
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -width - _s(HUD_MARGIN)
	panel.offset_right = -_s(HUD_MARGIN)
	panel.offset_top = -height - _s(HUD_MARGIN)
	panel.offset_bottom = -_s(HUD_MARGIN)
	_root.add_child(panel)
	_weapon_panel = panel

	var col := VBoxContainer.new()
	col.position = Vector2(_s(16.0), _s(12.0))
	col.custom_minimum_size = Vector2(width - _s(32.0), height - _s(24.0))
	col.size = col.custom_minimum_size
	col.add_theme_constant_override(&"separation", _fs(3))
	panel.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", _fs(10))
	col.add_child(top)
	_weapon_glyph = HW.WeaponGlyph.new()
	_weapon_glyph.custom_minimum_size = Vector2(_s(104.0), _s(30.0))
	top.add_child(_weapon_glyph)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override(&"separation", 0)
	top.add_child(identity)
	_weapon_name = Label.new()
	_weapon_name.text = "NO WEAPON"
	_weapon_name.add_theme_font_size_override(&"font_size", _fs(KangurTheme.SIZE_SECTION))
	_weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	identity.add_child(_weapon_name)
	_fire_mode = _caption("—")
	_fire_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	identity.add_child(_fire_mode)

	var ammo_row := HBoxContainer.new()
	ammo_row.alignment = BoxContainer.ALIGNMENT_END
	ammo_row.add_theme_constant_override(&"separation", _fs(4))
	col.add_child(ammo_row)
	_ammo_label = Label.new()
	_ammo_label.text = "0"
	_ammo_label.add_theme_font_override(&"font", KangurTheme.FONT_MONO)
	_ammo_label.add_theme_font_size_override(&"font_size", _fs(42))
	ammo_row.add_child(_ammo_label)
	var slash := Label.new()
	slash.text = "/"
	slash.add_theme_font_override(&"font", KangurTheme.FONT_MONO)
	slash.add_theme_font_size_override(&"font_size", _fs(22))
	slash.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	slash.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ammo_row.add_child(slash)
	_reserve_label = Label.new()
	_reserve_label.text = "0"
	_reserve_label.add_theme_font_override(&"font", KangurTheme.FONT_MONO)
	_reserve_label.add_theme_font_size_override(&"font_size", _fs(22))
	_reserve_label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	_reserve_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ammo_row.add_child(_reserve_label)

	_reload_bar = HW.Bar.new()
	_reload_bar.custom_minimum_size = Vector2(0.0, _s(4.0))
	_reload_bar.color = KangurTheme.AMBER
	col.add_child(_reload_bar)

	_equip_row = HBoxContainer.new()
	_equip_row.add_theme_constant_override(&"separation", _fs(12))
	col.add_child(_equip_row)

# --- top-center: mode strip --------------------------------------------------
func _build_mode_strip() -> void:
	_strip = HW.Plate.new()
	_strip.name = "ModeStrip"
	_strip.anchor_left = 0.5
	_strip.anchor_right = 0.5
	_strip.anchor_top = 0.0
	_strip.anchor_bottom = 0.0
	_strip.offset_left = -_s(300.0)
	_strip.offset_right = _s(300.0)
	_strip.offset_top = _s(14.0)
	_strip.offset_bottom = _s(14.0) + _s(102.0)
	_root.add_child(_strip)

	var col := VBoxContainer.new()
	col.position = Vector2(_s(16.0), _s(8.0))
	col.custom_minimum_size = Vector2(_s(568.0), _s(86.0))
	col.size = col.custom_minimum_size
	col.add_theme_constant_override(&"separation", _fs(2))
	_strip.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", _fs(8))
	col.add_child(top)
	_alive_label = Label.new()
	_alive_label.text = "0"
	_alive_label.custom_minimum_size.x = _s(54.0)
	_alive_label.add_theme_font_override(&"font", KangurTheme.FONT_MONO)
	_alive_label.add_theme_font_size_override(&"font_size", _fs(22))
	_alive_label.add_theme_color_override(&"font_color", KangurTheme.BASTION.lightened(0.4))
	top.add_child(_alive_label)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override(&"separation", 0)
	top.add_child(mid)
	_timer_label = Label.new()
	_timer_label.text = "00:00"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_override(&"font", KangurTheme.FONT_MONO)
	_timer_label.add_theme_font_size_override(&"font_size", _fs(28))
	mid.add_child(_timer_label)
	objective_chain = HW.ObjectiveChain.new()
	objective_chain.custom_minimum_size = Vector2(_s(280.0), _s(26.0))
	mid.add_child(objective_chain)

	_enemy_alive = Label.new()
	_enemy_alive.text = "0"
	_enemy_alive.custom_minimum_size.x = _s(54.0)
	_enemy_alive.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_enemy_alive.add_theme_font_override(&"font", KangurTheme.FONT_MONO)
	_enemy_alive.add_theme_font_size_override(&"font_size", _fs(22))
	_enemy_alive.add_theme_color_override(&"font_color", KangurTheme.SIROCCO.lightened(0.4))
	top.add_child(_enemy_alive)

	_ticket_row = HBoxContainer.new()
	_ticket_row.add_theme_constant_override(&"separation", _fs(8))
	col.add_child(_ticket_row)
	for i: int in 2:
		var bar := HW.Bar.new()
		bar.custom_minimum_size = Vector2(0.0, _s(5.0))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.color = KangurTheme.BASTION if i == Enums.Team.BASTION else KangurTheme.SIROCCO
		_ticket_row.add_child(bar)
		_ticket_bars.append(bar)

# --- top-left: minimap -------------------------------------------------------
func _build_minimap() -> void:
	minimap = HW.MinimapFrame.new()
	minimap.anchor_right = 0.0
	minimap.anchor_bottom = 0.0
	minimap.offset_left = _s(HUD_MARGIN)
	minimap.offset_top = _s(HUD_MARGIN)
	minimap.offset_right = _s(HUD_MARGIN) + _s(MINIMAP_SIZE)
	minimap.offset_bottom = _s(HUD_MARGIN) + _s(MINIMAP_SIZE)
	_root.add_child(minimap)

# --- top-right: killfeed + radio ---------------------------------------------
func _build_feed() -> void:
	var col := VBoxContainer.new()
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.offset_left = -_s(HUD_MARGIN) - _s(300.0)
	col.offset_right = -_s(HUD_MARGIN)
	col.offset_top = _s(HUD_MARGIN)
	col.add_theme_constant_override(&"separation", _fs(3))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)

	_killfeed = VBoxContainer.new()
	_killfeed.alignment = BoxContainer.ALIGNMENT_END
	_killfeed.add_theme_constant_override(&"separation", 1)
	col.add_child(_killfeed)
	var gap := Control.new()
	gap.custom_minimum_size.y = _s(10.0)
	col.add_child(gap)
	_radio_stack = VBoxContainer.new()
	_radio_stack.add_theme_constant_override(&"separation", 1)
	col.add_child(_radio_stack)

# --- Tab scoreboard ----------------------------------------------------------
func _build_scoreboard() -> void:
	_scoreboard = Control.new()
	_scoreboard.visible = false
	_scoreboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_scoreboard)
	var veil := ColorRect.new()
	veil.color = Color(KangurTheme.BACKDROP, 0.78)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scoreboard.add_child(veil)

	var panel := HW.Plate.new()
	panel.title = "OPERATION ROSTER"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -_s(400.0)
	panel.offset_right = _s(400.0)
	panel.offset_top = -_s(230.0)
	panel.offset_bottom = _s(230.0)
	_scoreboard.add_child(panel)

	var header := HBoxContainer.new()
	header.position = Vector2(_s(18.0), _s(34.0))
	header.add_theme_constant_override(&"separation", _fs(8))
	panel.add_child(header)
	for spec: Array in [["CALLSIGN", 150.0], ["CLASS", 100.0], ["K", 36.0],
			["D", 36.0], ["DMG", 60.0], ["STATUS", 80.0]]:
		header.add_child(_score_cell(spec[0], _s(spec[1]), KangurTheme.TEXT_MUTED))

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(_s(18.0), _s(58.0))
	scroll.custom_minimum_size = Vector2(_s(764.0), _s(376.0))
	scroll.size = scroll.custom_minimum_size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_score_rows = VBoxContainer.new()
	_score_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_rows.add_theme_constant_override(&"separation", 2)
	scroll.add_child(_score_rows)

func _score_cell(text: String, width: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = width
	label.theme_type_variation = &"MonoSmall"
	label.add_theme_font_size_override(&"font_size", _fs(KangurTheme.SIZE_MONO_SMALL))
	label.add_theme_color_override(&"font_color", color)
	return label

# --- death killcam card ------------------------------------------------------
func _build_killcam() -> void:
	_killcam = HW.Plate.new()
	_killcam.visible = false
	(_killcam as HW.Plate).title = "ELIMINATED"
	(_killcam as HW.Plate).accent = KangurTheme.DANGER
	_killcam.anchor_left = 0.5
	_killcam.anchor_right = 0.5
	_killcam.anchor_top = 0.5
	_killcam.anchor_bottom = 0.5
	_killcam.offset_left = -_s(260.0)
	_killcam.offset_right = _s(260.0)
	_killcam.offset_top = -_s(80.0)
	_killcam.offset_bottom = _s(104.0)
	_killcam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_killcam)

	var col := VBoxContainer.new()
	col.position = Vector2(_s(18.0), _s(34.0))
	col.custom_minimum_size = Vector2(_s(484.0), _s(150.0))
	col.size = col.custom_minimum_size
	col.add_theme_constant_override(&"separation", _fs(3))
	_killcam.add_child(col)
	for i: int in 3:
		var label := Label.new()
		if i == 0:
			label.add_theme_font_override(&"font", KangurTheme.FONT_MONO)
			label.add_theme_font_size_override(&"font_size", _fs(20))
		else:
			label.theme_type_variation = &"MonoSmall"
			label.add_theme_font_size_override(&"font_size", _fs(KangurTheme.SIZE_MONO_SMALL))
			label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
		col.add_child(label)
		_killcam_labels.append(label)

# --- bindings ----------------------------------------------------------------
## Attach the local player's character. Safe to call with null to clear.
func bind_character(new_character: Node) -> void:
	character = new_character
	body = null
	weapon = null
	bandages = 0
	if character != null:
		var team_value: Variant = character.get(&"team")
		if team_value != null:
			team = int(team_value)
		body = _read_body(character)
		weapon = _read_weapon(character)
		bandages = _read_bandages(character)
		set_equipment(_read_equipment(character))
	body_diagram.bind(body)
	_refresh()

func _read_body(source: Node) -> BodyModel:
	if source.has_method(&"get_body_model"):
		var result: Variant = source.call(&"get_body_model")
		if result is BodyModel:
			return result
	var property: Variant = source.get(&"body_model")
	return property if property is BodyModel else null

func _read_weapon(source: Node) -> WeaponModel:
	if source.has_method(&"get_weapon_model"):
		var result: Variant = source.call(&"get_weapon_model")
		if result is WeaponModel:
			return result
	var property: Variant = source.get(&"weapon_model")
	return property if property is WeaponModel else null

func _read_bandages(source: Node) -> int:
	if source.has_method(&"get_bandages"):
		var result: Variant = source.call(&"get_bandages")
		if result != null:
			return int(result)
	var count: Variant = source.get(&"bandages")
	if count != null:
		return int(count)
	var class_def: Variant = source.get(&"class_def")
	return (class_def as ClassDef).bandages if class_def is ClassDef else 0

## Reads a character's kit. Damaged/missing data yields an empty list, so the
## row simply stays empty rather than drawing wrong counts.
func _read_equipment(source: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not source.has_method(&"get_equipment_counts"):
		return out
	var raw: Variant = source.call(&"get_equipment_counts")
	if not (raw is Array):
		return out
	for entry: Variant in (raw as Array):
		if entry is Dictionary:
			out.append(entry)
	return out

## Called by the match at ~10 Hz; also safe to call every frame.
func refresh() -> void:
	_refresh()

func _refresh() -> void:
	_refresh_health()
	_refresh_weapon()
	_refresh_crosshair()
	_refresh_strip()
	body_diagram.refresh()

func _refresh_health() -> void:
	var hp_max := BodyModel.PART_MAX[Enums.Part.TORSO]
	var hp := body.part_hp(Enums.Part.TORSO) if body != null else hp_max
	var ratio := hp / hp_max if hp_max > 0.0 else 0.0
	_hp_value.text = "%d" % int(ceil(hp))
	_hp_value.add_theme_color_override(&"font_color", KangurTheme.part_color(ratio))
	_hp_bar.set_ratio(ratio)
	_hp_bar.color = KangurTheme.part_color(ratio)
	_vest_pips.set_ratio(body.vest_durability / BodyModel.VEST_MAX_DURABILITY if body != null else 0.0)
	_helmet_pips.set_ratio(body.helmet_durability / BodyModel.HELMET_MAX_DURABILITY if body != null else 0.0)
	_bandage_label.text = "x%d" % bandages
	_bandage_label.add_theme_color_override(&"font_color",
		KangurTheme.DANGER if bandages == 0 else KangurTheme.TEXT)
	var channel := body.bandage_progress if body != null and body.bandaging else 0.0
	_bandage_bar.set_ratio(channel)
	_bandage_bar.color = KangurTheme.HOLO
	var bleed := body.bleed_rate_total() if body != null else 0.0
	_vignette.set_intensity(0.0 if ratio >= LOW_HP_THRESHOLD else
		(1.0 - ratio / LOW_HP_THRESHOLD) * (0.55 + 0.45 * clampf(bleed, 0.0, 1.0)))

func _refresh_weapon() -> void:
	if weapon == null:
		_weapon_name.text = "NO WEAPON"
		_weapon_glyph.set_category(&"")
		_ammo_label.text = "0"
		_reserve_label.text = "0"
		_fire_mode.text = "—"
		_reload_bar.set_ratio(0.0)
		return
	var weapon_def := weapon.def
	if weapon_def != null:
		_weapon_name.text = weapon_def.display_name.to_upper()
		_weapon_glyph.set_category(weapon_def.category)
	_ammo_label.text = "%d" % weapon.mag
	var low := weapon_def != null and weapon.mag <= int(weapon_def.mag_size * MAG_LOW_RATIO)
	_ammo_label.add_theme_color_override(&"font_color",
		KangurTheme.DANGER if low else KangurTheme.TEXT)
	_reserve_label.text = "%d" % weapon.reserve_rounds
	_fire_mode.text = _fire_mode_name(weapon.fire_mode())
	_reload_bar.set_ratio(weapon.reload_progress())

func _fire_mode_name(mode: int) -> String:
	match mode:
		Enums.FireMode.AUTO:
			return "AUTO"
		Enums.FireMode.BURST:
			return "BURST"
		Enums.FireMode.BOLT:
			return "BOLT"
		Enums.FireMode.PUMP:
			return "PUMP"
		_:
			return "SEMI"

func _refresh_crosshair() -> void:
	crosshair.set_spread_deg(weapon.current_spread_deg() if weapon != null else 0.0)

func _refresh_strip() -> void:
	_timer_label.text = KangurTheme.format_clock(_time_left)
	var own := team if team == Enums.Team.BASTION or team == Enums.Team.SIROCCO else Enums.Team.BASTION
	_alive_label.text = "%d" % _alive[own]
	_alive_label.add_theme_color_override(&"font_color", KangurTheme.team_color(own).lightened(0.4))
	_enemy_alive.text = "%d" % _alive[Enums.other_team(own)]
	var max_tickets := 1.0
	if Game.match_config != null:
		max_tickets = maxf(float(Game.match_config.attacker_tickets), 1.0)
	for i: int in _ticket_bars.size():
		_ticket_bars[i].set_ratio(float(_tickets[i]) / max_tickets)
	_ticket_row.visible = _mode == Enums.Mode.BATTLE
	objective_chain.visible = _mode == Enums.Mode.BATTLE

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_refresh_timer += delta
	if _refresh_timer >= 1.0 / REFRESH_HZ:
		_refresh_timer = 0.0
		_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if pause_menu == null:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		pause_menu.toggle()
	elif event.is_action_pressed(&"scoreboard"):
		get_viewport().set_input_as_handled()
		_show_scoreboard(true)
	elif event.is_action_released(&"scoreboard"):
		get_viewport().set_input_as_handled()
		_show_scoreboard(false)

func _show_scoreboard(show: bool) -> void:
	_scoreboard.visible = show
	if show:
		_rebuild_scoreboard()
		UiFx.play_sound(&"click", UiFx.HOVER_DB)
		_scoreboard.modulate.a = 0.0
		create_tween().tween_property(_scoreboard, "modulate:a", 1.0, UiFx.FADE_S)

func _rebuild_scoreboard() -> void:
	for child: Node in _score_rows.get_children():
		child.queue_free()
	if _roster.is_empty():
		var placeholder := Label.new()
		placeholder.text = "roster pending — match runtime calls hud.set_roster(rows)"
		placeholder.theme_type_variation = &"MonoSmall"
		placeholder.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
		_score_rows.add_child(placeholder)
		return
	for row: Dictionary in _roster:
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", _fs(8))
		var row_team := int(row.get("team", -1))
		line.add_child(_score_cell(str(row.get("callsign", "—")), _s(150.0), KangurTheme.team_color(row_team)))
		line.add_child(_score_cell(String(row.get("class_id", "—")).to_upper(), _s(100.0),
			KangurTheme.TEXT))
		line.add_child(_score_cell("%d" % int(row.get("kills", 0)), _s(36.0), KangurTheme.TEXT))
		line.add_child(_score_cell("%d" % int(row.get("deaths", 0)), _s(36.0), KangurTheme.TEXT))
		line.add_child(_score_cell("%d" % int(float(row.get("damage", 0.0))), _s(60.0),
			KangurTheme.TEXT_DIM))
		var alive := bool(row.get("alive", true))
		line.add_child(_score_cell("ALIVE" if alive else "KIA", _s(80.0),
			KangurTheme.OK if alive else KangurTheme.DANGER))
		_score_rows.add_child(line)

## Match runtime pushes live rows here (same shape as MatchResult.characters).
func set_roster(rows: Array[Dictionary]) -> void:
	_roster = rows
	if _scoreboard.visible:
		_rebuild_scoreboard()

## Equipment counts, index-aligned with the class kit:
##   [{kind: Enums.EquipKind, count: int}]
func set_equipment(items: Array[Dictionary]) -> void:
	for child: Node in _equip_row.get_children():
		child.queue_free()
	for item: Dictionary in items:
		var icon := HW.EquipIcon.new()
		icon.setup(int(item.get("kind", Enums.EquipKind.FRAG)), int(item.get("count", 0)))
		icon.custom_minimum_size = Vector2(_s(34.0), _s(22.0))
		_equip_row.add_child(icon)

## Minimap feed: list of {pos: Vector2 (0..1), kind: StringName, color: Color, dir}.
func set_minimap_blips(blips: Array[Dictionary]) -> void:
	minimap.set_blips(blips)

## {pos: Vector2 (0..1), dir: Vector2, half_deg: float, dist: float 0..1}
func set_minimap_cone(cone: Dictionary) -> void:
	minimap.set_cone(cone)

func set_objectives(objectives: Array[Dictionary]) -> void:
	minimap.set_objectives(objectives)
	objective_chain.set_nodes(objectives)

func show_killcam(killer: String, weapon_name: String, distance_px: float) -> void:
	_killcam.visible = true
	_killcam_labels[0].text = "KILLED BY %s" % killer.to_upper()
	_killcam_labels[1].text = "%s · %d m" % [weapon_name, int(round(distance_px / 32.0))]
	_killcam_labels[2].text = "wound map: see vitals panel"
	_killcam.modulate.a = 0.0
	create_tween().tween_property(_killcam, "modulate:a", 1.0, 0.2)

func clear_killcam() -> void:
	_killcam.visible = false

func set_alive_counts(bastion: int, sirocco: int) -> void:
	_alive = [bastion, sirocco]
	_refresh_strip()

func set_tickets(bastion: int, sirocco: int) -> void:
	_tickets = [bastion, sirocco]
	_refresh_strip()

func add_killfeed(killer: String, victim: String, killer_team_id: int,
		victim_team_id: int, player_involved: bool) -> void:
	var entry := HW.KillfeedEntry.new()
	entry.setup(killer, victim, killer_team_id, victim_team_id, player_involved)
	_killfeed.add_child(entry)
	while _killfeed.get_child_count() > KILLFEED_MAX:
		var oldest := _killfeed.get_child(0)
		_killfeed.remove_child(oldest)
		oldest.queue_free()
	entry.modulate.a = 0.0
	create_tween().tween_property(entry, "modulate:a", 1.0, UiFx.FADE_S)

func add_radio(callsign: String, text: String, priority: int) -> void:
	if not bool(Settings.get_value(&"gameplay", &"show_radio", true)):
		return
	var line := HW.RadioLine.new()
	line.setup(callsign, text, priority)
	_radio_stack.add_child(line)
	while _radio_stack.get_child_count() > RADIO_MAX:
		var oldest := _radio_stack.get_child(0)
		_radio_stack.remove_child(oldest)
		oldest.queue_free()

func flash_hitmarker(kill: bool) -> void:
	hitmarker.flash(kill)

## Screen-space damage arc angle (radians); the match computes it from the
## camera transform — the HUD deliberately has no camera reference.
func show_damage_angle(angle: float) -> void:
	damage_arcs.add_source(angle)

# --- EventBus ----------------------------------------------------------------
func _connect_bus() -> void:
	EventBus.character_died.connect(_on_character_died)
	EventBus.character_hit.connect(_on_character_hit)
	EventBus.radio_message.connect(_on_radio_message)
	EventBus.objective_progress.connect(_on_objective_progress)
	EventBus.tickets_changed.connect(_on_tickets_changed)
	EventBus.settings_changed.connect(_on_settings_changed)

func _on_character_died(victim: Node, attacker: Node, weapon_id: StringName,
		_pos: Vector2, distance: float) -> void:
	var victim_name := _callsign_of(victim, "UNKNOWN")
	var killer_name := _callsign_of(attacker, "ENVIRONMENT")
	var killer_team := _team_of(attacker)
	var victim_team := _team_of(victim)
	var involves_player := victim == character or attacker == character
	add_killfeed(killer_name, victim_name, killer_team, victim_team, involves_player)
	if attacker == character:
		flash_hitmarker(true)
	if victim == character:
		var weapon_def := Defs.weapon(weapon_id) if weapon_id != &"" else null
		show_killcam(killer_name, weapon_def.display_name if weapon_def != null else "unknown",
			distance)

func _on_character_hit(victim: Node, attacker: Node, _part: int, _damage: float,
		fatal: bool, _pos: Vector2) -> void:
	# Damage arcs need the camera transform; a fatal player hit still marks the
	# crosshair so the death frame reads correctly.
	if fatal and attacker == character and victim != character:
		flash_hitmarker(true)

func _on_radio_message(team_id: int, callsign: String, text: String, priority: int) -> void:
	if team_id != team:
		return
	add_radio(callsign, text, priority)

func _on_objective_progress(obj_id: StringName, team_id: int, progress: float,
		contested: bool) -> void:
	objective_chain.update_progress(obj_id, team_id, progress, contested)
	if contested and progress > 0.0 and progress < 1.0:
		UiFx.play_sound(&"objective", -20.0)

func _on_tickets_changed(team_id: int, tickets: int) -> void:
	if team_id != Enums.Team.BASTION and team_id != Enums.Team.SIROCCO:
		return
	_tickets[team_id] = tickets
	if tickets <= TICKET_WARN:
		UiFx.play_sound(&"ticket_warning", -16.0)
	_refresh_strip()

func _on_settings_changed(section: StringName) -> void:
	if section == &"video":
		var wanted := clampf(float(Settings.get_value(&"video", &"hud_scale", 1.0)), 0.8, 1.4)
		if not is_equal_approx(wanted, _k):
			_relayout()
	elif section == &"gameplay":
		crosshair.style = int(Settings.get_value(&"gameplay", &"crosshair_style", 0))
		crosshair.color = Settings.get_value(&"gameplay", &"crosshair_color", KangurTheme.HOLO)
		crosshair.queue_redraw()

func _team_of(who: Node) -> int:
	if who == null:
		return -1
	var value: Variant = who.get(&"team")
	return int(value) if value != null else -1

func _callsign_of(who: Node, fallback: String) -> String:
	if who == null:
		return fallback
	var callsign: Variant = who.get(&"callsign")
	return str(callsign) if callsign != null and not str(callsign).is_empty() else fallback