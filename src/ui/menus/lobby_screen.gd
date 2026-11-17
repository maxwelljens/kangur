extends MenuScreen
## Lobby: mode + map cards (briefing/minimap preview) on the left, faction /
## class / loadout / bot count / difficulty / rules on the right, DEPLOY below.
## Content comes from `Defs`; empty `data/` shows explicit placeholders so the
## screen is usable before the content wave lands.
## Game.LOBBY_SCENE path must stay as-is (src/core/game.gd).

const HoloButtonScript := preload("res://src/ui/holo_button.gd")

const EMBLEM_BASTION := "res://assets/ui/art/bastion_emblem.svg"
const EMBLEM_SIROCCO := "res://assets/ui/art/sirocco_emblem.svg"
const LEFT_W := 620.0
const RIGHT_W := 560.0
const MARGIN := 44.0
const BOT_COUNT_MIN := 1
const BOT_COUNT_MAX := 12
const TIME_RANGE := Vector2i(240, 720)
const TICKET_RANGE := Vector2i(12, 60)

var _config := MatchConfig.new()
var _map_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _class_buttons: Array[Button] = []
var _faction_buttons: Array[Button] = []
var _maps: Array[MapDef] = []
var _classes: Array[ClassDef] = []
var _difficulties: Array[DifficultyDef] = []
var _weapon_options: Array[WeaponDef] = []

var _briefing: Label = null
var _minimap: HW.MinimapFrame = null
var _map_title: Label = null
var _class_detail: Label = null
var _primary_pick: OptionButton = null
var _sidearm_pick: OptionButton = null
var _equip_picks: Array[OptionButton] = []
var _bot_labels: Array[Label] = []
var _difficulty_pick: OptionButton = null
var _time_slider: HSlider = null
var _time_label: Label = null
var _ticket_slider: HSlider = null
var _ticket_label: Label = null
var _deploy: HoloButton = null
var _faction_emblem: TextureRect = null
var _faction_name: Label = null

func _build() -> void:
	_config.player_team = Enums.Team.BASTION
	_config.difficulty_id = StringName(str(
		Settings.get_value(&"gameplay", &"difficulty", &"operator")))
	_maps = Defs.all_maps()
	_classes = Defs.all_classes()
	_difficulties = Defs.all_difficulties()
	_pick_defaults()
	_draw_backdrop()
	_build_header()
	_build_left()
	_build_right()
	_build_deploy_bar()
	_select_map(_maps[0] if not _maps.is_empty() else null)
	_sync_map_buttons()
	if not _classes.is_empty():
		_select_class(_classes[0])
	else:
		_apply_class_placeholders()
	_update_faction_ui()

func _draw_backdrop() -> void:
	# A dim port-holo wash: the lobby sits on the title world, blurred and dark.
	var bg := ColorRect.new()
	bg.color = KangurTheme.BACKDROP
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(bg)
	var diorama: Node = load("res://src/ui/title/port_diorama.gd").new()
	(diorama as CanvasItem).modulate = Color(1.0, 1.0, 1.0, 0.30)
	(diorama as CanvasItem).scale = Vector2(1.06, 1.06)
	(diorama as CanvasItem).offset_left = -48.0
	body.add_child(diorama)

func _pick_defaults() -> void:
	var best_map: MapDef = null
	for map_def: MapDef in _maps:
		if map_def.supported_modes.has(Enums.Mode.ELIMINATION):
			best_map = map_def
			break
	if best_map == null and not _maps.is_empty():
		best_map = _maps[0]
	if best_map != null:
		_config.map_id = best_map.id
	else:
		_config.map_id = &"dustworks"
	_config.mode = Enums.Mode.ELIMINATION
	# Sensible bot counts: 5v6 keeps the player-sided team human-sized.
	_config.bot_count_bastion = 5
	_config.bot_count_sirocco = 6
	_config.time_limit_s = 480.0
	_config.attacker_tickets = 36
	if _config.player_team == Enums.Team.SIROCCO:
		_config.bot_count_sirocco = 5
		_config.bot_count_bastion = 6

func _build_header() -> void:
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = MARGIN
	header.offset_right = -MARGIN
	header.offset_top = 24.0
	header.add_theme_constant_override(&"separation", 16)
	body.add_child(header)

	var title := Label.new()
	title.text = "OPERATIONS DESK"
	title.add_theme_font_override(&"font", KangurTheme.FONT_DISPLAY)
	title.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_TITLE)
	header.add_child(title)
	var tag := Label.new()
	tag.text = "// CONTRACT ASSEMBLY"
	tag.theme_type_variation = &"MonoSmall"
	tag.add_theme_color_override(&"font_color", KangurTheme.HOLO_DIM)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(tag)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var back := HoloButtonScript.new() as HoloButton
	back.text = "BACK"
	back.custom_minimum_size = Vector2(120.0, 36.0)
	back.pressed.connect(_on_back)
	header.add_child(back)

func _build_left() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	column.offset_left = MARGIN
	column.offset_top = 90.0
	column.custom_minimum_size.x = LEFT_W
	column.add_theme_constant_override(&"separation", 10)
	body.add_child(column)

	column.add_child(_section_label("MODE"))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override(&"separation", 8)
	column.add_child(modes)
	_add_mode_button(modes, "ELIMINATION", Enums.Mode.ELIMINATION)
	_add_mode_button(modes, "BATTLE", Enums.Mode.BATTLE)
	_add_mode_button(modes, "TRAINING", Enums.Mode.TRAINING)

	column.add_child(_section_label("MAP"))
	# HFlowContainer so five map names wrap inside LEFT_W instead of running
	# under the right column on narrow viewports.
	var map_row := HFlowContainer.new()
	map_row.add_theme_constant_override(&"h_separation", 8)
	map_row.add_theme_constant_override(&"v_separation", 8)
	map_row.custom_minimum_size.x = LEFT_W
	column.add_child(map_row)
	_map_buttons.clear()
	for map_def: MapDef in _maps:
		_add_map_button(map_row, map_def)
	if _maps.is_empty():
		var placeholder := Label.new()
		placeholder.text = "no maps in data/maps — DEPLOY falls back to the range"
		placeholder.theme_type_variation = &"MonoSmall"
		placeholder.add_theme_color_override(&"font_color", KangurTheme.AMBER)
		map_row.add_child(placeholder)

	var intel := HBoxContainer.new()
	intel.add_theme_constant_override(&"separation", 14)
	intel.custom_minimum_size = Vector2(LEFT_W, 240.0)
	column.add_child(intel)
	_minimap = HW.MinimapFrame.new()
	_minimap.custom_minimum_size = Vector2(210.0, 210.0)
	_minimap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	intel.add_child(_minimap)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override(&"separation", 6)
	intel.add_child(text_col)
	_map_title = Label.new()
	_map_title.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_SECTION)
	_map_title.add_theme_color_override(&"font_color", KangurTheme.TEXT)
	text_col.add_child(_map_title)
	_briefing = Label.new()
	_briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing.custom_minimum_size.x = LEFT_W - 240.0
	_briefing.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_SMALL)
	_briefing.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	text_col.add_child(_briefing)

	column.add_child(_section_label("RULES"))
	var time_row := _slider_row(column, "TIME LIMIT", TIME_RANGE, 30, _on_time_changed)
	_time_slider = time_row[0] as HSlider
	_time_label = time_row[1] as Label
	_time_slider.value = int(_config.time_limit_s)
	_on_time_changed(_time_slider.value)
	var ticket_row := _slider_row(column, "ATTACKER TICKETS", TICKET_RANGE, 2,
		_on_tickets_changed)
	_ticket_slider = ticket_row[0] as HSlider
	_ticket_label = ticket_row[1] as Label
	_ticket_slider.value = _config.attacker_tickets
	_on_tickets_changed(_ticket_slider.value)

func _add_mode_button(parent: HBoxContainer, text: String, mode: int) -> void:
	var button := HoloButtonScript.new() as HoloButton
	button.text = text
	button.custom_minimum_size = Vector2(164.0, 38.0)
	button.set_meta(&"mode", mode)
	button.toggle_mode = true
	button.pressed.connect(func() -> void: _select_mode(mode))
	parent.add_child(button)
	_mode_buttons.append(button)

func _add_map_button(parent: Control, map_def: MapDef) -> void:
	var button := HoloButtonScript.new() as HoloButton
	button.text = map_def.display_name.to_upper() if not map_def.display_name.is_empty() \
		else String(map_def.id).to_upper()
	button.custom_minimum_size = Vector2(186.0, 38.0)
	button.set_meta(&"map_id", map_def.id)
	button.pressed.connect(func() -> void: _select_map(map_def))
	parent.add_child(button)
	_map_buttons.append(button)

func _slider_row(parent: VBoxContainer, caption: String, limits: Vector2i,
		step: int, on_change: Callable) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 150.0
	label.theme_type_variation = &"MonoSmall"
	label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = limits.x
	slider.max_value = limits.y
	slider.step = step
	slider.value = limits.x
	slider.custom_minimum_size = Vector2(300.0, 18.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size.x = 76.0
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.theme_type_variation = &"Mono"
	row.add_child(readout)
	slider.value_changed.connect(func(v: float) -> void: on_change.call(v))
	return [slider, readout]

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"MonoSmall"
	label.add_theme_color_override(&"font_color", KangurTheme.HOLO)
	return label

func _build_right() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	column.offset_left = -RIGHT_W - MARGIN
	column.offset_right = -MARGIN
	column.offset_top = 90.0
	column.offset_bottom = 90.0 + 660.0
	column.custom_minimum_size.x = RIGHT_W
	column.add_theme_constant_override(&"separation", 10)
	body.add_child(column)

	column.add_child(_section_label("CONTRACTOR"))
	var faction_row := HBoxContainer.new()
	faction_row.add_theme_constant_override(&"separation", 16)
	column.add_child(faction_row)
	_faction_emblem = TextureRect.new()
	_faction_emblem.custom_minimum_size = Vector2(64.0, 64.0)
	_faction_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_faction_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	faction_row.add_child(_faction_emblem)
	var faction_col := VBoxContainer.new()
	faction_col.add_theme_constant_override(&"separation", 4)
	faction_row.add_child(faction_col)
	_faction_name = Label.new()
	_faction_name.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_SECTION)
	faction_col.add_child(_faction_name)
	var faction_buttons := HBoxContainer.new()
	faction_buttons.add_theme_constant_override(&"separation", 8)
	faction_col.add_child(faction_buttons)
	_add_faction_button(faction_buttons, "BASTION", Enums.Team.BASTION, KangurTheme.BASTION)
	_add_faction_button(faction_buttons, "SIROCCO", Enums.Team.SIROCCO, KangurTheme.SIROCCO)

	column.add_child(_section_label("CLASS"))
	var class_row := HFlowContainer.new()
	class_row.add_theme_constant_override(&"h_separation", 6)
	class_row.add_theme_constant_override(&"v_separation", 6)
	class_row.custom_minimum_size.x = RIGHT_W
	column.add_child(class_row)
	_class_buttons.clear()
	for class_def: ClassDef in _classes:
		_add_class_button(class_row, class_def)
	if _classes.is_empty():
		var placeholder := Label.new()
		placeholder.text = "no classes in data/classes — using squad defaults"
		placeholder.theme_type_variation = &"MonoSmall"
		placeholder.add_theme_color_override(&"font_color", KangurTheme.AMBER)
		class_row.add_child(placeholder)
	_class_detail = Label.new()
	_class_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_class_detail.custom_minimum_size = Vector2(RIGHT_W, 44.0)
	_class_detail.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_SMALL)
	_class_detail.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	column.add_child(_class_detail)

	column.add_child(_section_label("LOADOUT"))
	_primary_pick = _picker_row(column, "PRIMARY", _on_primary_changed)
	_sidearm_pick = _picker_row(column, "SIDEARM", _on_sidearm_changed)
	_equip_picks.clear()
	for i: int in 2:
		_equip_picks.append(_picker_row(column, "EQUIP %d" % (i + 1),
			func(_idx: int) -> void: _apply_equipment()))

	column.add_child(_section_label("OPPOSITION"))
	_bot_row(column, "BASTION BOTS", Enums.Team.BASTION)
	_bot_row(column, "SIROCCO BOTS", Enums.Team.SIROCCO)
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override(&"separation", 10)
	column.add_child(diff_row)
	var diff_label := Label.new()
	diff_label.text = "BOT SKILL"
	diff_label.custom_minimum_size.x = 150.0
	diff_label.theme_type_variation = &"MonoSmall"
	diff_label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	diff_row.add_child(diff_label)
	_difficulty_pick = OptionButton.new()
	_difficulty_pick.custom_minimum_size = Vector2(260.0, 32.0)
	_difficulty_pick.fit_to_longest_item = false
	for def: DifficultyDef in _difficulties:
		_difficulty_pick.add_item(def.display_name if not def.display_name.is_empty() else String(def.id))
		_difficulty_pick.set_item_metadata(_difficulty_pick.item_count - 1, def.id)
	if _difficulties.is_empty():
		_difficulty_pick.add_item("OPERATOR")
		_difficulty_pick.set_item_metadata(0, &"operator")
	_difficulty_pick.item_selected.connect(_on_difficulty_changed)
	diff_row.add_child(_difficulty_pick)

func _add_faction_button(parent: HBoxContainer, text: String, team: int, color: Color) -> void:
	var button := HoloButtonScript.new() as HoloButton
	button.text = text
	button.custom_minimum_size = Vector2(116.0, 32.0)
	button.toggle_mode = true
	button.set_meta(&"team", team)
	button.add_theme_color_override(&"font_color", color.lightened(0.3))
	button.pressed.connect(func() -> void: _select_team(team))
	parent.add_child(button)
	_faction_buttons.append(button)

func _add_class_button(parent: Control, class_def: ClassDef) -> void:
	var button := HoloButtonScript.new() as HoloButton
	var name := class_def.display_name if not class_def.display_name.is_empty() \
		else String(class_def.id).capitalize()
	button.text = name.to_upper()
	button.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_SMALL + 1)
	button.custom_minimum_size = Vector2(176.0, 34.0)
	button.toggle_mode = true
	button.set_meta(&"class_index", _classes.find(class_def))
	button.pressed.connect(func() -> void: _select_class(class_def))
	parent.add_child(button)
	_class_buttons.append(button)

func _picker_row(parent: VBoxContainer, caption: String, on_change: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 150.0
	label.theme_type_variation = &"MonoSmall"
	label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	row.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(260.0, 32.0)
	picker.item_selected.connect(on_change)
	row.add_child(picker)
	return picker

func _bot_row(parent: VBoxContainer, caption: String, team: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 150.0
	label.theme_type_variation = &"MonoSmall"
	label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = BOT_COUNT_MIN
	slider.max_value = BOT_COUNT_MAX
	slider.step = 1
	slider.value = _config.bot_count(team)
	slider.custom_minimum_size = Vector2(160.0, 18.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size.x = 96.0
	readout.text = _team_count_text(team)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.theme_type_variation = &"Mono"
	row.add_child(readout)
	_bot_labels.append(readout)
	slider.value_changed.connect(func(v: float) -> void: _on_bots_changed(team, int(v)))

func _team_count_text(team: int) -> String:
	return "%d (+YOU)" % _config.bot_count(team) if team == _config.player_team \
		else "%d" % _config.bot_count(team)

func _build_deploy_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = MARGIN
	bar.offset_right = -MARGIN
	bar.offset_top = -90.0
	bar.offset_bottom = -28.0
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override(&"separation", 14)
	body.add_child(bar)

	var summary := Label.new()
	summary.name = "Summary"
	summary.theme_type_variation = &"MonoSmall"
	summary.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(summary)

	_deploy = HoloButtonScript.new() as HoloButton
	_deploy.text = "DEPLOY"
	_deploy.primary = true
	_deploy.custom_minimum_size = Vector2(280.0, 52.0)
	_deploy.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_BUTTON + 3)
	_deploy.pressed.connect(_on_deploy)
	bar.add_child(_deploy)
	_refresh_summary()

func _refresh_summary() -> void:
	var summary := body.find_child("Summary", true, false) as Label
	if summary == null:
		return
	summary.text = "%s · %s · %d vs %d · %s" % [
		_mode_name(_config.mode).to_upper(),
		_map_label(),
		_config.total_team(Enums.Team.BASTION),
		_config.total_team(Enums.Team.SIROCCO),
		_difficulty_name(),
	]

func _mode_name(mode: int) -> String:
	match mode:
		Enums.Mode.ELIMINATION:
			return "elimination"
		Enums.Mode.BATTLE:
			return "battle"
		_:
			return "training"

func _map_label() -> String:
	if _config.map_id == &"":
		return "range"
	var def := Defs.map(_config.map_id) if not _maps.is_empty() else null
	return def.display_name if def != null and not def.display_name.is_empty() \
		else String(_config.map_id).capitalize()

func _difficulty_name() -> String:
	for def: DifficultyDef in _difficulties:
		if def.id == _config.difficulty_id:
			return def.display_name
	return String(_config.difficulty_id).capitalize()

# --- selection handlers ------------------------------------------------------
func _select_mode(mode: int) -> void:
	_config.mode = mode
	var compatible := Defs.maps_for_mode(mode)
	var current := _find_map(_config.map_id)
	# Keep the current map when it supports the mode; otherwise take the first
	# compatible one. `_select_map` is not used here because it would reject the
	# switch against the mode we just left.
	if not compatible.is_empty() and (current == null or not current.supported_modes.has(mode)):
		_select_map_compatible(compatible[0])
	_refresh_mode_buttons()
	_sync_map_buttons()
	_refresh_summary()

## Applies a map that is already known to support the active mode.
func _select_map_compatible(map_def: MapDef) -> void:
	_config.map_id = map_def.id
	_map_title.text = map_def.display_name if not map_def.display_name.is_empty() \
		else String(map_def.id).capitalize()
	_briefing.text = map_def.briefing if not map_def.briefing.is_empty() \
		else "No briefing authored for this contract."
	_minimap.map_texture = _load_minimap(map_def)
	_refresh_summary()

func _find_map(map_id: StringName) -> MapDef:
	for def: MapDef in _maps:
		if def.id == map_id:
			return def
	return null

func _refresh_mode_buttons() -> void:
	for button: Button in _mode_buttons:
		button.button_pressed = int(button.get_meta(&"mode")) == _config.mode

func _select_map(map_def: MapDef) -> void:
	if map_def != null and not map_def.supported_modes.has(_config.mode):
		# Mode/map mismatch is refused, and the button reflects the kept map.
		UiFx.play_sound(&"error", UiFx.CLICK_DB)
		_sync_map_buttons()
		return
	for button: Button in _map_buttons:
		button.button_pressed = StringName(button.get_meta(&"map_id")) == (map_def.id if map_def else &"")
	if map_def == null:
		_map_title.text = "RANGE — NO MAP DEFINITION"
		_briefing.text = "Drop a MapDef in data/maps to populate briefings, maps and mode support."
		_minimap.map_texture = null
		_refresh_summary()
		return
	_config.map_id = map_def.id
	_map_title.text = map_def.display_name if not map_def.display_name.is_empty() \
		else String(map_def.id).capitalize()
	_briefing.text = map_def.briefing if not map_def.briefing.is_empty() \
		else "No briefing authored for this contract."
	_minimap.map_texture = _load_minimap(map_def)
	_refresh_summary()

## Missing/unimported minimap textures are a content gap, not a crash.
func _load_minimap(map_def: MapDef) -> Texture2D:
	if map_def.minimap_path.is_empty() or not ResourceLoader.exists(map_def.minimap_path):
		return null
	return load(map_def.minimap_path) as Texture2D

func _sync_map_buttons() -> void:
	for button: Button in _map_buttons:
		var map_id := StringName(button.get_meta(&"map_id"))
		var def := _find_map(map_id)
		button.button_pressed = map_id == _config.map_id
		# Unsupported maps stay visible but dimmed: the mode is the constraint.
		# Modulate as well as `disabled`, because the theme's disabled plate is
		# only a subtle border change and players missed the constraint.
		var unsupported := def != null and not def.supported_modes.has(_config.mode)
		button.disabled = unsupported
		button.modulate.a = 0.42 if unsupported else 1.0

func _select_team(team: int) -> void:
	_config.player_team = team
	for button: Button in _faction_buttons:
		button.button_pressed = int(button.get_meta(&"team")) == team
	_update_faction_ui()
	_refresh_bot_labels()
	_refresh_summary()

func _update_faction_ui() -> void:
	var is_bastion := _config.player_team == Enums.Team.BASTION
	_faction_emblem.texture = load(EMBLEM_BASTION if is_bastion else EMBLEM_SIROCCO)
	_faction_name.text = "BASTION SECURITY GROUP" if is_bastion else "SIROCCO EXTRACTION CORPS"
	_faction_name.add_theme_color_override(&"font_color", KangurTheme.team_color(_config.player_team))
	for button: Button in _faction_buttons:
		button.button_pressed = int(button.get_meta(&"team")) == _config.player_team

func _select_class(class_def: ClassDef) -> void:
	var index := _classes.find(class_def)
	_config.player_class_id = class_def.id
	for button: Button in _class_buttons:
		button.button_pressed = int(button.get_meta(&"class_index")) == index
	_class_detail.text = "%s  ·  SPEED ×%.2f  ·  VEST %.0f  HELMET %.0f  ·  %d BANDAGES\n%s" % [
		class_def.display_name.to_upper(), class_def.speed_mult, class_def.armor_vest,
		class_def.armor_helmet, class_def.bandages, class_def.description,
	]
	_config.sidearm_id = class_def.sidearm_id
	_weapon_options = _primaries_for(class_def)
	_fill_picker(_primary_pick, _weapon_options, "PRIMARY")
	if not _weapon_options.is_empty():
		_config.primary_id = _weapon_options[0].id
	_fill_sidearm_picker(class_def)
	_fill_equipment_pickers(class_def)
	_refresh_summary()

func _apply_class_placeholders() -> void:
	_config.player_class_id = &"vanguard"
	_config.primary_id = &"kestrel"
	_config.sidearm_id = &"adder"
	_config.equipment_ids = [&"frag", &"flash"]
	_class_detail.text = "Squad default: Vanguard — AR · vest 60 · 3 bandages."
	_fill_picker(_primary_pick, [] as Array[WeaponDef], "PRIMARY")
	_fill_picker(_sidearm_pick, [] as Array[WeaponDef], "SIDEARM")
	for picker: OptionButton in _equip_picks:
		_fill_picker(picker, [] as Array[WeaponDef], "EQUIP")
	_refresh_summary()

func _primaries_for(class_def: ClassDef) -> Array[WeaponDef]:
	var list: Array[WeaponDef] = []
	for weapon_def: WeaponDef in Defs.all_weapons():
		if class_def.primary_categories.has(weapon_def.category):
			list.append(weapon_def)
	return list

func _fill_picker(picker: OptionButton, options: Array[WeaponDef], field: String) -> void:
	if picker == null:
		return
	picker.clear()
	if options.is_empty():
		picker.add_item("— no content —")
		picker.set_item_disabled(0, true)
		return
	for weapon_def: WeaponDef in options:
		var label := weapon_def.display_name if not weapon_def.display_name.is_empty() \
			else String(weapon_def.id).capitalize()
		if field == "PRIMARY":
			label += "  ·  %s" % String(weapon_def.category).to_upper()
		picker.add_item(label)
		picker.set_item_metadata(picker.item_count - 1, weapon_def.id)

func _fill_sidearm_picker(class_def: ClassDef) -> void:
	var sidearm := Defs.weapon(class_def.sidearm_id) if class_def.sidearm_id != &"" else null
	var list: Array[WeaponDef] = []
	if sidearm != null:
		list.append(sidearm)
	_fill_picker(_sidearm_pick, list, "SIDEARM")

func _fill_equipment_pickers(class_def: ClassDef) -> void:
	_config.equipment_ids.clear()
	var all_equipment := Defs.all_equipment()
	for i: int in _equip_picks.size():
		var picker := _equip_picks[i]
		picker.clear()
		if all_equipment.is_empty():
			picker.add_item("— no content —")
			picker.set_item_disabled(0, true)
			continue
		for equip: EquipmentDef in all_equipment:
			picker.add_item(equip.display_name if not equip.display_name.is_empty()
				else String(equip.id).capitalize())
			picker.set_item_metadata(picker.item_count - 1, equip.id)
		# Preselect the class kit slot when the id exists.
		var kit_id := class_def.equipment[i] if i < class_def.equipment.size() else &""
		var preferred := 0
		for idx: int in picker.item_count:
			if StringName(picker.get_item_metadata(idx)) == kit_id:
				preferred = idx
				break
		picker.select(preferred)
	_apply_equipment()

func _apply_equipment() -> void:
	_config.equipment_ids.clear()
	for picker: OptionButton in _equip_picks:
		if picker.item_count == 0 or picker.selected < 0:
			continue
		if picker.is_item_disabled(picker.selected):
			continue
		_config.equipment_ids.append(StringName(picker.get_item_metadata(picker.selected)))
	_refresh_summary()

func _on_primary_changed(index: int) -> void:
	if _primary_pick == null or index < 0:
		return
	_config.primary_id = StringName(_primary_pick.get_item_metadata(index))
	_refresh_summary()

func _on_sidearm_changed(index: int) -> void:
	if _sidearm_pick == null or index < 0:
		return
	_config.sidearm_id = StringName(_sidearm_pick.get_item_metadata(index))
	_refresh_summary()

func _on_bots_changed(team: int, count: int) -> void:
	if team == Enums.Team.BASTION:
		_config.bot_count_bastion = clampi(count, BOT_COUNT_MIN, BOT_COUNT_MAX)
	else:
		_config.bot_count_sirocco = clampi(count, BOT_COUNT_MIN, BOT_COUNT_MAX)
	_refresh_bot_labels()
	_refresh_summary()

func _refresh_bot_labels() -> void:
	if _bot_labels.size() < 2:
		return
	_bot_labels[0].text = _team_count_text(Enums.Team.BASTION)
	_bot_labels[1].text = _team_count_text(Enums.Team.SIROCCO)

func _on_difficulty_changed(index: int) -> void:
	if _difficulty_pick == null or index < 0:
		return
	_config.difficulty_id = StringName(_difficulty_pick.get_item_metadata(index))
	_refresh_summary()

func _on_time_changed(value: float) -> void:
	_config.time_limit_s = value
	_time_label.text = KangurTheme.format_clock(value)
	_refresh_summary()

func _on_tickets_changed(value: float) -> void:
	_config.attacker_tickets = int(value)
	_ticket_label.text = "%d" % _config.attacker_tickets
	_refresh_summary()

func _on_deploy() -> void:
	# Trust boundary: never hand Match a config it cannot honour.
	var map_def := _find_map(_config.map_id)
	if map_def != null and not map_def.supported_modes.has(_config.mode):
		_select_mode(Enums.Mode.ELIMINATION if map_def.supported_modes.is_empty()
			else map_def.supported_modes[0])
	if _config.mode == Enums.Mode.BATTLE and _config.attacker_tickets <= 0:
		_config.attacker_tickets = TICKET_RANGE.x
	UiFx.play_sound(&"deploy")
	Game.to_match(_config)

func _on_back() -> void:
	UiFx.back()
	Game.to_title()