extends MenuScreen
## Debrief: result banner, personal stats, team table, kill/objective timeline.
## Reads `Game.last_result` (MatchResult); renders an explicit "no contract"
## state when the screen is opened from the editor or a shot fixture.

const HoloButtonScript := preload("res://src/ui/holo_button.gd")

const MARGIN := 44.0
const TABLE_COLUMNS: Array[String] = [
	"CALLSIGN", "CLASS", "K", "D", "DMG", "ACC", "STATUS",
]

var _columns: Dictionary[StringName, VBoxContainer] = {}

func _build() -> void:
	var result := Game.last_result
	_build_header(result)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = MARGIN
	root.offset_right = -MARGIN
	root.offset_top = 96.0
	root.offset_bottom = -96.0
	root.add_theme_constant_override(&"separation", 22)
	body.add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 480.0
	left.add_theme_constant_override(&"separation", 12)
	root.add_child(left)
	left.add_child(_banner(result))
	left.add_child(_personal_card(result))
	left.add_child(_timeline_card(result))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 12)
	root.add_child(right)
	right.add_child(_team_table(result))

	_build_footer()

func _build_header(result: MatchResult) -> void:
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = MARGIN
	header.offset_right = -MARGIN
	header.offset_top = 22.0
	header.add_theme_constant_override(&"separation", 16)
	body.add_child(header)
	var title := Label.new()
	title.text = "AFTER-ACTION REPORT"
	title.add_theme_font_override(&"font", KangurTheme.FONT_DISPLAY)
	title.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_TITLE)
	header.add_child(title)
	var tag := Label.new()
	tag.text = "// CONTRACT CLOSED"
	tag.theme_type_variation = &"MonoSmall"
	tag.add_theme_color_override(&"font_color", KangurTheme.HOLO_DIM)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(tag)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	if result != null:
		var seed_label := Label.new()
		seed_label.text = "SEED %08X · %s · %s" % [Game.match_seed,
			_mode_name(result.mode), KangurTheme.format_clock(result.duration_s)]
		seed_label.theme_type_variation = &"MonoSmall"
		seed_label.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
		seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_child(seed_label)

func _banner(result: MatchResult) -> Control:
	var panel := HW.Plate.new()
	panel.custom_minimum_size = Vector2(480.0, 112.0)
	var winner := -1
	var reason := &""
	if result != null:
		winner = result.winner
		reason = result.reason
	var title := "CONTRACT VOID"
	var accent := KangurTheme.TEXT_DIM
	var subtitle := "No result recorded."
	if winner == Enums.Team.BASTION or winner == Enums.Team.SIROCCO:
		var won_by_player := Game.match_config != null and winner == Game.match_config.player_team
		title = "VICTORY" if won_by_player else "OPERATION FAILED"
		accent = KangurTheme.OK if won_by_player else KangurTheme.DANGER
		subtitle = "%s %s" % [_faction_name(winner), _reason_text(reason)]
	elif result != null:
		title = "DRAW"
		accent = KangurTheme.AMBER
		subtitle = _reason_text(reason)
	panel.accent = accent

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 22.0
	column.offset_right = -22.0
	column.offset_top = 18.0
	column.add_theme_constant_override(&"separation", 2)
	panel.add_child(column)
	var kicker := Label.new()
	kicker.text = "RESULT"
	kicker.theme_type_variation = &"MonoSmall"
	kicker.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	column.add_child(kicker)
	var headline := Label.new()
	headline.text = title
	headline.add_theme_font_override(&"font", KangurTheme.FONT_DISPLAY)
	headline.add_theme_font_size_override(&"font_size", 34)
	headline.add_theme_color_override(&"font_color", accent)
	column.add_child(headline)
	var sub := Label.new()
	sub.text = subtitle
	sub.theme_type_variation = &"MonoSmall"
	sub.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	column.add_child(sub)
	return panel

func _mode_name(mode: int) -> String:
	match mode:
		Enums.Mode.BATTLE:
			return "BATTLE"
		Enums.Mode.TRAINING:
			return "TRAINING"
		_:
			return "ELIMINATION"

func _faction_name(team: int) -> String:
	return "BASTION" if team == Enums.Team.BASTION else "SIROCCO"

func _reason_text(reason: StringName) -> String:
	match reason:
		&"elimination":
			return "won on elimination"
		&"timeout":
			return "won on time"
		&"objectives":
			return "won on objectives"
		&"tickets":
			return "won on tickets"
		&"surrender":
			return "opponent surrendered"
		_:
			return "no reason recorded"

func _personal_card(result: MatchResult) -> Control:
	var panel := HW.Plate.new()
	panel.title = "PERSONAL"
	panel.custom_minimum_size = Vector2(480.0, 208.0)
	var stats := result.player_stats() if result != null else {}
	var grid := GridContainer.new()
	grid.columns = 3
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.offset_left = 22.0
	grid.offset_right = -22.0
	grid.offset_top = 38.0
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 10)
	panel.add_child(grid)

	var accuracy := 0.0
	if not stats.is_empty() and int(stats.get("shots_fired", 0)) > 0:
		accuracy = float(stats.get("shots_hit", 0)) / float(stats.get("shots_fired", 1))
	_add_stat(grid, "KILLS", "%d" % int(stats.get("kills", 0)), KangurTheme.TEXT)
	_add_stat(grid, "DEATHS", "%d" % int(stats.get("deaths", 0)), KangurTheme.TEXT)
	_add_stat(grid, "K/D", _kd(stats), KangurTheme.HOLO)
	_add_stat(grid, "DAMAGE", "%d" % int(float(stats.get("damage", 0.0))), KangurTheme.TEXT)
	_add_stat(grid, "ACCURACY", KangurTheme.format_pct(accuracy), KangurTheme.TEXT)
	_add_stat(grid, "BANDAGES", "%d" % int(stats.get("bandages_used", 0)), KangurTheme.TEXT)
	if stats.is_empty():
		var empty := Label.new()
		empty.text = "no personal telemetry for this contract"
		empty.theme_type_variation = &"MonoSmall"
		empty.add_theme_color_override(&"font_color", KangurTheme.AMBER)
		grid.add_child(empty)
	return panel

func _kd(stats: Dictionary) -> String:
	if stats.is_empty():
		return "—"
	var deaths := int(stats.get("deaths", 0))
	var kills := int(stats.get("kills", 0))
	return "%.2f" % (float(kills) / float(maxi(deaths, 1)))

func _add_stat(grid: GridContainer, caption: String, value: String, color: Color) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	var cap := Label.new()
	cap.text = caption
	cap.theme_type_variation = &"MonoSmall"
	cap.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	box.add_child(cap)
	var val := Label.new()
	val.text = value
	val.add_theme_font_override(&"font", KangurTheme.FONT_MONO)
	val.add_theme_font_size_override(&"font_size", 26)
	val.add_theme_color_override(&"font_color", color)
	box.add_child(val)
	grid.add_child(box)

func _timeline_card(result: MatchResult) -> Control:
	var panel := HW.Plate.new()
	panel.title = "TIMELINE"
	panel.custom_minimum_size = Vector2(480.0, 250.0)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 18.0
	scroll.offset_right = -18.0
	scroll.offset_top = 34.0
	scroll.offset_bottom = -14.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(list)

	if result == null or result.timeline.is_empty():
		var placeholder := Label.new()
		placeholder.text = "Timeline populates from MatchResult.timeline\n" \
			+ "({t, kind, text, team} rows written by the match runtime)."
		placeholder.theme_type_variation = &"MonoSmall"
		placeholder.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
		list.add_child(placeholder)
		return panel
	var shown := 0
	for row: Dictionary in result.timeline:
		if shown >= 40:
			break
		shown += 1
		list.add_child(_timeline_row(row))
	return panel

func _timeline_row(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 10)
	var stamp := Label.new()
	stamp.text = KangurTheme.format_clock(float(row.get("t", 0.0)))
	stamp.custom_minimum_size.x = 58.0
	stamp.theme_type_variation = &"MonoSmall"
	stamp.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	line.add_child(stamp)
	var kind: StringName = StringName(str(row.get("kind", "")))
	var tag := Label.new()
	tag.text = String(kind).to_upper()
	tag.custom_minimum_size.x = 110.0
	tag.theme_type_variation = &"MonoSmall"
	tag.add_theme_color_override(&"font_color", _kind_color(kind, int(row.get("team", -1))))
	line.add_child(tag)
	var text := Label.new()
	text.text = str(row.get("text", ""))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.theme_type_variation = &"MonoSmall"
	line.add_child(text)
	return line

func _kind_color(kind: StringName, team: int) -> Color:
	if kind == &"objective" or kind == &"capture":
		return KangurTheme.AMBER
	if team == Enums.Team.BASTION or team == Enums.Team.SIROCCO:
		return KangurTheme.team_color(team)
	return KangurTheme.HOLO_DIM

func _team_table(result: MatchResult) -> Control:
	var panel := HW.Plate.new()
	panel.title = "ROSTER"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 18.0
	scroll.offset_right = -18.0
	scroll.offset_top = 34.0
	scroll.offset_bottom = -14.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 2)
	scroll.add_child(column)
	column.add_child(_table_row(TABLE_COLUMNS, KangurTheme.TEXT_MUTED, true))

	if result == null or result.characters.is_empty():
		var placeholder := Label.new()
		placeholder.text = "MatchResult.characters is empty — no roster recorded."
		placeholder.theme_type_variation = &"MonoSmall"
		placeholder.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
		column.add_child(placeholder)
		return panel

	# Group by team (player's faction first), then kills, then damage. Sorting
	# by kills alone interleaves factions and repeats the group headers.
	var rows := result.characters.duplicate()
	var player_team := Enums.Team.BASTION
	if result.player_index >= 0 and result.player_index < result.characters.size():
		player_team = int(result.characters[result.player_index].get("team", Enums.Team.BASTION))
	var sort_team := player_team
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta := 0 if int(a.get("team", -1)) == sort_team else 1
		var tb := 0 if int(b.get("team", -1)) == sort_team else 1
		if ta != tb:
			return ta < tb
		var sa := int(a.get("kills", 0)) * 100000 + int(float(a.get("damage", 0.0)))
		var sb := int(b.get("kills", 0)) * 100000 + int(float(b.get("damage", 0.0)))
		if sa != sb:
			return sa > sb
		return str(a.get("callsign", "")) < str(b.get("callsign", "")))
	var last_team := -99
	for row: Dictionary in rows:
		var row_team := int(row.get("team", -1))
		if row_team != last_team:
			last_team = row_team
			column.add_child(_team_header(row_team))
		column.add_child(_table_row(_row_cells(row, result), KangurTheme.TEXT, false,
			row_team, result.characters.find(row) == result.player_index))
	return panel

## Faction band between roster groups; gives 12-row tables a scannable shape.
func _team_header(team: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var bar := ColorRect.new()
	bar.color = KangurTheme.team_color(team)
	bar.custom_minimum_size = Vector2(3.0, 14.0)
	row.add_child(bar)
	var label := Label.new()
	label.text = "%s CONTRACT" % _faction_name(team) if team >= 0 else "UNATTACHED"
	label.theme_type_variation = &"MonoSmall"
	label.add_theme_color_override(&"font_color", KangurTheme.team_color(team).lightened(0.2))
	row.add_child(label)
	var rule := HW.Rule.new()
	rule.custom_minimum_size = Vector2(0.0, 14.0)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rule)
	return row

func _row_cells(row: Dictionary, _result: MatchResult) -> Array[String]:
	var fired := int(row.get("shots_fired", 0))
	var hit := int(row.get("shots_hit", 0))
	var acc := 0.0 if fired <= 0 else float(hit) / float(fired)
	var survived: bool = bool(row.get("survived", false))
	var cells: Array[String] = [
		str(row.get("callsign", "—")),
		String(row.get("class_id", "—")).to_upper(),
		"%d" % int(row.get("kills", 0)),
		"%d" % int(row.get("deaths", 0)),
		"%d" % int(float(row.get("damage", 0.0))),
		KangurTheme.format_pct(acc),
		"ALIVE" if survived else "KIA",
	]
	return cells

func _table_row(cells: Array, tint: Color, header: bool = false,
		team: int = -1, highlight: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var widths: Array[float] = [168.0, 120.0, 48.0, 48.0, 72.0, 64.0, 70.0]
	if header:
		var bg := ColorRect.new()
		bg.color = Color(KangurTheme.HOLO, 0.05)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_child(bg)
	for i: int in cells.size():
		var label := Label.new()
		label.text = str(cells[i])
		label.custom_minimum_size.x = widths[i] if i < widths.size() else 60.0
		label.theme_type_variation = &"MonoSmall"
		label.add_theme_color_override(&"font_color",
			tint if header else (KangurTheme.TEXT if not highlight else KangurTheme.HOLO))
		if i == 0 and not header:
			label.add_theme_color_override(&"font_color",
				KangurTheme.HOLO if highlight else (KangurTheme.team_color(team) if team >= 0
					else KangurTheme.TEXT))
		row.add_child(label)
	return row

func _build_footer() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = MARGIN
	bar.offset_right = -MARGIN
	bar.offset_top = -84.0
	bar.offset_bottom = -24.0
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override(&"separation", 12)
	body.add_child(bar)
	var note := Label.new()
	note.text = "contract archived · result kept until the next deploy"
	note.theme_type_variation = &"MonoSmall"
	note.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(note)
	for spec: Array in [["REMATCH", _rematch, true], ["LOBBY", _to_lobby, false],
			["TITLE", _to_title, false]]:
		var button := HoloButtonScript.new() as HoloButton
		button.text = spec[0]
		button.primary = bool(spec[2])
		button.custom_minimum_size = Vector2(168.0, 48.0)
		button.pressed.connect(spec[1])
		bar.add_child(button)
	UiFx.play_sound(&"confirm" if _player_won() else &"defeat", -12.0)

func _player_won() -> bool:
	var result := Game.last_result
	if result == null or Game.match_config == null:
		return false
	return result.winner == Game.match_config.player_team

func _rematch() -> void:
	var config := Game.match_config
	if config == null:
		Game.to_lobby()
		return
	config.seed = 0
	Game.to_match(config)

func _to_lobby() -> void:
	UiFx.back()
	Game.to_lobby()

func _to_title() -> void:
	UiFx.back()
	Game.to_title()

func _on_back() -> void:
	_to_lobby()