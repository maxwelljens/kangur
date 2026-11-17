extends MenuScreen
## Settings: Video / Audio / Controls / Gameplay tabs, all bound to
## `Settings.get_value` / `Settings.set_value` (src/core/settings.gd DEFAULTS).
## Controls does click→press-key rebinding through `Settings.rebind`, with
## conflict detection and a reset. No value is stored locally — the autoload is
## the single source of truth, so the config file is always the live state.

const HoloButtonScript := preload("res://src/ui/holo_button.gd")

const MARGIN := 44.0
const CONTENT_TOP := 132.0
const LABEL_W := 220.0
const CONTROL_W := 380.0
const TAB_NAMES: Array[String] = ["VIDEO", "AUDIO", "CONTROLS", "GAMEPLAY"]
const HUD_SCALE_RANGE := Vector2(0.8, 1.4)
const ZOOM_RANGE := Vector2(1.0, 2.4)
const CAMERA_LEAN_RANGE := Vector2(0.0, 1.0)
const CROSSHAIR_STYLES: Array[String] = ["BRACKETS", "CROSS", "DOT"]
## Actions offered for rebinding, in HUD/gameplay grouping order.
const REBIND_ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right", &"sprint", &"crouch",
	&"fire", &"focus", &"reload", &"bandage", &"use", &"slot_primary",
	&"slot_sidearm", &"cycle_mode", &"equip_1", &"equip_2", &"cook",
	&"scoreboard", &"pause", &"spectate_next",
]
const REBIND_LABELS: Dictionary[StringName, String] = {
	&"move_up": "move up", &"move_down": "move down", &"move_left": "move left",
	&"move_right": "move right", &"sprint": "sprint", &"crouch": "crouch",
	&"fire": "fire", &"focus": "focus / brace", &"reload": "reload",
	&"bandage": "bandage (hold)", &"use": "interact", &"slot_primary": "primary",
	&"slot_sidearm": "sidearm", &"cycle_mode": "fire mode", &"equip_1": "equipment 1",
	&"equip_2": "equipment 2", &"cook": "cook frag (hold)", &"scoreboard": "scoreboard",
	&"pause": "pause", &"spectate_next": "spectate next",
}

var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _tab_index := 0
var _rebind_buttons: Dictionary[StringName, Button] = {}
var _capturing: StringName = &""
var _conflict_label: Label = null
var _status_label: Label = null
var _crosshair_preview: HW.Crosshair = null
var _preview_rail: Control = null

func _build() -> void:
	_build_header()
	_build_tabs()
	_pages.clear()
	_rails.clear()
	_pages.append(_build_video_page())
	_rails.append(_build_preview_rail("RENDERER", [
		"GL Compatibility · 2D only",
		"Reference viewport 1600x900 · canvas_items stretch",
		"",
		"CAMERA ZOOM 1.0 – 2.4",
		" HUD SCALE 0.8 – 1.4 (design §11 accessibility range)",
		"",
		"Changes apply immediately and persist in user://settings.cfg.",
	], false))
	_pages.append(_build_audio_page())
	_rails.append(_build_preview_rail("BUS CHAIN", [
		"MASTER",
		" ├─ SFX  → SFX_Open / SFX_Light / SFX_Heavy / SFX_Muffled",
		" ├─ MUSIC",
		" └─ VOICE",
		"",
		"Occlusion counts walls between listener and source and picks the bus:",
		" 0 walls open · 1 light · 2 heavy · 3+ muffled.",
		"",
		"Buses are built by AudioDirector; these sliders stay valid before it boots.",
	], false))
	_pages.append(_build_controls_page())
	_rails.append(_build_preview_rail("HOW REBINDING WORKS", [
		"1  Click a binding to arm it (PRESS A KEY…)",
		"2  Press any key or mouse button",
		"3  Conflicts are refused, naming the action that owns the key",
		"",
		"Saved through Settings.rebind() → user://settings.cfg controls/rebinds.",
		"Mouse capture is released in menus, so mouse bindings work here.",
		"",
		"RESET ALL restores InputDefaults and clears the persisted rebinds.",
	], false))
	_pages.append(_build_gameplay_page())
	_rails.append(_build_preview_rail("CROSSHAIR PREVIEW", [
		"Sample at 2.2° bloom, same mapping as in-match.",
		"Gap = 6 px + (bloom degrees × 7 px).",
		"",
		"BRACKETS · expanding bracket arms",
		"CROSS · four ticks",
		"DOT · minimal centre dot",
	], true))
	for i: int in _pages.size():
		var page: Control = _pages[i]
		page.visible = false
		body.add_child(page)
		_rails[i].visible = false
	_show_tab(0)

func _build_header() -> void:
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = MARGIN
	header.offset_right = -MARGIN
	header.offset_top = 24.0
	header.add_theme_constant_override(&"separation", 16)
	body.add_child(header)
	var title := Label.new()
	title.text = "SYSTEM CONFIG"
	title.add_theme_font_override(&"font", KangurTheme.FONT_DISPLAY)
	title.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_TITLE)
	header.add_child(title)
	var tag := Label.new()
	tag.text = "// USER PROFILE · user://settings.cfg"
	tag.theme_type_variation = &"MonoSmall"
	tag.add_theme_color_override(&"font_color", KangurTheme.HOLO_DIM)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(tag)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_status_label = Label.new()
	_status_label.theme_type_variation = &"MonoSmall"
	_status_label.add_theme_color_override(&"font_color", KangurTheme.OK)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_status_label)
	var back := HoloButtonScript.new() as HoloButton
	back.text = "BACK"
	back.custom_minimum_size = Vector2(120.0, 36.0)
	back.pressed.connect(_on_back)
	header.add_child(back)

func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.name = "Tabs"
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	row.offset_left = MARGIN
	row.offset_top = 78.0
	row.add_theme_constant_override(&"separation", 8)
	body.add_child(row)
	for i: int in TAB_NAMES.size():
		var button := HoloButtonScript.new() as HoloButton
		button.text = TAB_NAMES[i]
		button.custom_minimum_size = Vector2(168.0, 38.0)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: _show_tab(i))
		row.add_child(button)
		_tabs.append(button)

var _rails: Array[Control] = []

func _show_tab(index: int) -> void:
	_tab_index = index
	for rail: Control in _rails:
		rail.visible = _rails.find(rail) == index
	for i: int in _tabs.size():
		_tabs[i].button_pressed = i == index
		if i < _pages.size():
			_pages[i].visible = i == index

## Page shell: a framed settings card plus a preview rail on the right. The
## rail carries a live crosshair/HUD sample so a control's effect is visible
## where it is changed, instead of only in match.
func _page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	page.offset_left = MARGIN
	page.offset_top = CONTENT_TOP
	page.custom_minimum_size.x = 720.0
	page.add_theme_constant_override(&"separation", 8)
	return page

func _build_preview_rail(caption: String, lines: PackedStringArray,
		with_crosshair: bool) -> Control:
	var rail := VBoxContainer.new()
	rail.anchor_left = 1.0
	rail.anchor_right = 1.0
	rail.offset_left = -MARGIN - 460.0
	rail.offset_right = -MARGIN
	rail.offset_top = CONTENT_TOP
	rail.offset_bottom = CONTENT_TOP + 420.0
	rail.add_theme_constant_override(&"separation", 10)
	body.add_child(rail)
	rail.add_child(_heading(caption))

	var plate := HW.Plate.new()
	plate.custom_minimum_size = Vector2(460.0, 300.0 if with_crosshair else 300.0)
	rail.add_child(plate)

	if with_crosshair:
		# Crosshair centres on its own size, so it needs a fixed-size frame that
		# is NOT a container child (containers would resize it every layout pass).
		var frame := Control.new()
		frame.position = Vector2(98.0, 18.0)
		frame.size = Vector2(264.0, 264.0)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(frame)
		var preview := HW.Crosshair.new()
		preview.style = int(Settings.get_value(&"gameplay", &"crosshair_style", 0))
		preview.color = Settings.get_value(&"gameplay", &"crosshair_color", KangurTheme.HOLO)
		preview.set_spread_deg(2.2)
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.add_child(preview)
		_crosshair_preview = preview

	# Text goes beside a text-only plate, or beneath a square crosshair sample.
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	if with_crosshair:
		rail.add_child(column)
	else:
		column.position = Vector2(22.0, 18.0)
		column.custom_minimum_size = Vector2(416.0, 264.0)
		plate.add_child(column)
	for line: String in lines:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 416.0
		label.theme_type_variation = &"MonoSmall"
		label.add_theme_color_override(&"font_color",
			KangurTheme.TEXT_DIM if line.begins_with(" ") else KangurTheme.TEXT_MUTED)
		column.add_child(label)
	return rail

# --- Video -------------------------------------------------------------------
func _build_video_page() -> Control:
	var page := _page()
	page.add_child(_heading("DISPLAY"))
	_toggle_row(page, &"video", &"fullscreen", "Fullscreen", "Borderless on supported monitors")
	_toggle_row(page, &"video", &"vsync", "V-Sync", "Match the display refresh rate")
	_slider_row(page, &"video", &"zoom", "Camera zoom", ZOOM_RANGE.x, ZOOM_RANGE.y, 0.1,
		func(v: float) -> String: return "×%.1f" % v)
	page.add_child(_heading("COMFORT"))
	_toggle_row(page, &"video", &"screen_shake", "Screen shake", "Explosions and heavy hits")
	_slider_row(page, &"video", &"hud_scale", "HUD scale", HUD_SCALE_RANGE.x,
		HUD_SCALE_RANGE.y, 0.05, func(v: float) -> String: return "×%.2f" % v)
	return page

# --- Audio -------------------------------------------------------------------
func _build_audio_page() -> Control:
	var page := _page()
	page.add_child(_heading("MIX"))
	for key: StringName in [&"master", &"sfx", &"music", &"voice"]:
		_slider_row(page, &"audio", key, String(key).capitalize(), 0.0, 1.0, 0.05,
			func(v: float) -> String: return "%d%%" % int(round(v * 100.0)))
	page.add_child(_heading("OCCLUSION"))
	_toggle_row(page, &"audio", &"occlusion", "Wall occlusion",
		"Lowpass + attenuation for sounds behind walls")
	var note := Label.new()
	note.text = "Buses are created by AudioDirector; sliders are safe before it boots."
	note.theme_type_variation = &"MonoSmall"
	note.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	page.add_child(note)
	return page

# --- Controls ----------------------------------------------------------------
func _build_controls_page() -> Control:
	var page := _page()
	page.add_child(_heading("BINDINGS"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560.0, 620.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 3)
	scroll.add_child(list)
	for action: StringName in REBIND_ACTIONS:
		list.add_child(_rebind_row(action))
	list.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 10)
	list.add_child(footer)
	var reset := HoloButtonScript.new() as HoloButton
	reset.text = "RESET ALL"
	reset.custom_minimum_size = Vector2(160.0, 34.0)
	reset.pressed.connect(_on_reset_controls)
	footer.add_child(reset)
	_conflict_label = Label.new()
	_conflict_label.theme_type_variation = &"MonoSmall"
	_conflict_label.add_theme_color_override(&"font_color", KangurTheme.DANGER)
	_conflict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conflict_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_conflict_label)
	return page

func _rebind_row(action: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var label := Label.new()
	label.text = REBIND_LABELS.get(action, String(action))
	label.custom_minimum_size.x = LABEL_W - 40.0
	label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	row.add_child(label)
	var button := HoloButtonScript.new() as HoloButton
	button.custom_minimum_size = Vector2(240.0, 30.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = _binding_text(action)
	button.pressed.connect(func() -> void: _start_capture(action))
	row.add_child(button)
	_rebind_buttons[action] = button
	return row

func _binding_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "— unbound —"
	var parts: PackedStringArray = []
	for event: InputEvent in events:
		parts.append(_event_name(event))
	return " / ".join(parts)

func _event_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		return OS.get_keycode_string(key.physical_keycode if key.physical_keycode != KEY_NONE
			else key.keycode)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
			_:
				return "MOUSE %d" % (event as InputEventMouseButton).button_index
	return "?"

func _start_capture(action: StringName) -> void:
	_capturing = action
	_conflict_label.text = ""
	for key: StringName in _rebind_buttons:
		(_rebind_buttons[key] as Button).text = "PRESS A KEY…" if key == action \
			else _binding_text(key)
	UiFx.play_sound(&"notify")

func _input(event: InputEvent) -> void:
	if _capturing == &"":
		return
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	var binding := InputDefaults.binding_from(event)
	if binding.is_empty():
		return
	# Ignore the key/mouse that opened the capture so Enter/Space don't self-bind.
	var pressed := event.is_pressed()
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_commit_rebind(_capturing, binding)

func _commit_rebind(action: StringName, binding: Dictionary) -> void:
	var conflict := _find_conflict(action, binding)
	if not conflict.is_empty():
		# Conflicts are refused rather than silently stolen: the player must see
		# which action would lose its key.
		_conflict_label.text = "%s is already bound to %s — press another key." % [
			_event_name(InputDefaults.event_from(binding)),
			REBIND_LABELS.get(conflict, String(conflict)),
		]
		UiFx.play_sound(&"error")
		var button := _rebind_buttons[action] as Button
		if button != null:
			button.text = _binding_text(action)
		_capturing = &""
		return
	Settings.rebind(action, binding)
	_capturing = &""
	UiFx.play_sound(&"confirm")
	_conflict_label.text = ""
	_status_label.text = "saved"
	for key: StringName in _rebind_buttons:
		(_rebind_buttons[key] as Button).text = _binding_text(key)
	_flash_status()

func _find_conflict(action: StringName, binding: Dictionary) -> StringName:
	for other: StringName in REBIND_ACTIONS:
		if other == action:
			continue
		for event: InputEvent in InputMap.action_get_events(other):
			if _same_binding(InputDefaults.binding_from(event), binding):
				return other
	return &""

func _same_binding(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if a.get(&"type") != b.get(&"type"):
		return false
	if a.get(&"type") == &"key":
		return int(a.get(&"physical", 0)) == int(b.get(&"physical", 0))
	return int(a.get(&"button", 0)) == int(b.get(&"button", 0))

func _on_reset_controls() -> void:
	Settings.reset_controls()
	UiFx.play_sound(&"confirm")
	_status_label.text = "bindings reset"
	_conflict_label.text = ""
	for key: StringName in _rebind_buttons:
		(_rebind_buttons[key] as Button).text = _binding_text(key)
	_flash_status()

# --- Gameplay ----------------------------------------------------------------
func _build_gameplay_page() -> Control:
	var page := _page()
	page.add_child(_heading("DIFFICULTY DEFAULT"))
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override(&"separation", 10)
	page.add_child(diff_row)
	var diff_label := Label.new()
	diff_label.text = "Bot skill"
	diff_label.custom_minimum_size.x = LABEL_W
	diff_label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	diff_row.add_child(diff_label)
	var difficulty_pick := OptionButton.new()
	difficulty_pick.custom_minimum_size = Vector2(CONTROL_W, 32.0)
	var difficulties := Defs.all_difficulties()
	for def: DifficultyDef in difficulties:
		difficulty_pick.add_item(def.display_name if not def.display_name.is_empty()
			else String(def.id))
		difficulty_pick.set_item_metadata(difficulty_pick.item_count - 1, def.id)
	if difficulties.is_empty():
		for fallback: String in ["Recruit", "Operator", "Veteran", "Elite"]:
			difficulty_pick.add_item(fallback)
			difficulty_pick.set_item_metadata(difficulty_pick.item_count - 1,
				StringName(fallback.to_lower()))
	var current := StringName(str(Settings.get_value(&"gameplay", &"difficulty", &"operator")))
	for idx: int in difficulty_pick.item_count:
		if StringName(difficulty_pick.get_item_metadata(idx)) == current:
			difficulty_pick.select(idx)
			break
	difficulty_pick.item_selected.connect(func(idx: int) -> void:
		Settings.set_value(&"gameplay", &"difficulty", StringName(difficulty_pick.get_item_metadata(idx)))
		_flash_status())
	diff_row.add_child(difficulty_pick)

	page.add_child(_heading("CROSSHAIR"))
	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override(&"separation", 10)
	page.add_child(style_row)
	var style_label := Label.new()
	style_label.text = "Style"
	style_label.custom_minimum_size.x = LABEL_W
	style_label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	style_row.add_child(style_label)
	var style_pick := OptionButton.new()
	style_pick.custom_minimum_size = Vector2(CONTROL_W, 32.0)
	for i: int in CROSSHAIR_STYLES.size():
		style_pick.add_item(CROSSHAIR_STYLES[i])
		style_pick.set_item_metadata(i, i)
	var style_current := int(Settings.get_value(&"gameplay", &"crosshair_style", 0))
	if style_current >= 0 and style_current < CROSSHAIR_STYLES.size():
		style_pick.select(style_current)
	style_pick.item_selected.connect(func(idx: int) -> void:
		Settings.set_value(&"gameplay", &"crosshair_style", idx)
		_refresh_crosshair_preview()
		_flash_status())
	style_row.add_child(style_pick)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override(&"separation", 10)
	page.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "Colour"
	color_label.custom_minimum_size.x = LABEL_W
	color_label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	color_row.add_child(color_label)
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override(&"separation", 6)
	color_row.add_child(swatches)
	var current_color: Color = Settings.get_value(&"gameplay", &"crosshair_color",
		KangurTheme.HOLO)
	for preset: Color in KangurTheme.CROSSHAIR_PRESETS:
		swatches.add_child(_swatch(preset, current_color))
	var picker := ColorPickerButton.new()
	picker.color = current_color
	picker.custom_minimum_size = Vector2(52.0, 28.0)
	picker.edit_alpha = false
	picker.color_changed.connect(func(c: Color) -> void:
		Settings.set_value(&"gameplay", &"crosshair_color", c)
		_refresh_crosshair_preview()
		_flash_status())
	swatches.add_child(picker)

	page.add_child(_heading("FEEL"))
	_slider_row(page, &"gameplay", &"camera_lean", "Camera lean", CAMERA_LEAN_RANGE.x,
		CAMERA_LEAN_RANGE.y, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100.0)))
	_toggle_row(page, &"gameplay", &"gore", "Gore", "Blood decals; off = gray sparks")
	_toggle_row(page, &"gameplay", &"crouch_toggle", "Crouch toggle", "Off = hold to crouch")
	_toggle_row(page, &"gameplay", &"focus_toggle", "Focus toggle", "Off = hold to brace")
	_toggle_row(page, &"gameplay", &"sprint_toggle", "Sprint toggle", "Off = hold to sprint")
	_toggle_row(page, &"gameplay", &"show_radio", "Radio text", "Subtitle-style chatter lines")
	return page

func _swatch(color: Color, selected: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(26.0, 26.0)
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_border_width_all(2)
	box.border_color = KangurTheme.TEXT if color.is_equal_approx(selected) \
		else Color(color, 0.35)
	button.add_theme_stylebox_override(&"normal", box)
	var hot := box.duplicate() as StyleBoxFlat
	hot.border_color = KangurTheme.TEXT
	button.add_theme_stylebox_override(&"hover", hot)
	button.add_theme_stylebox_override(&"pressed", hot)
	button.pressed.connect(func() -> void:
		Settings.set_value(&"gameplay", &"crosshair_color", color)
		_refresh_crosshair_preview()
		UiFx.click()
		_flash_status())
	return button

# --- Row builders ------------------------------------------------------------
func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"MonoSmall"
	label.add_theme_color_override(&"font_color", KangurTheme.HOLO)
	return label

func _toggle_row(parent: VBoxContainer, section: StringName, key: StringName,
		caption: String, hint: String) -> CheckButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = LABEL_W
	label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	row.add_child(label)
	var toggle := CheckButton.new()
	toggle.button_pressed = bool(Settings.get_value(section, key, false))
	toggle.text = "ON" if toggle.button_pressed else "OFF"
	toggle.toggled.connect(func(on: bool) -> void:
		Settings.set_value(section, key, on)
		toggle.text = "ON" if on else "OFF"
		_flash_status())
	row.add_child(toggle)
	if not hint.is_empty():
		var hint_label := Label.new()
		hint_label.text = hint
		hint_label.theme_type_variation = &"MonoSmall"
		hint_label.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
		row.add_child(hint_label)
	return toggle

func _slider_row(parent: VBoxContainer, section: StringName, key: StringName,
		caption: String, min_v: float, max_v: float, step: float,
		format: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = LABEL_W
	label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = float(Settings.get_value(section, key, min_v))
	slider.custom_minimum_size = Vector2(CONTROL_W, 18.0)
	row.add_child(slider)
	var readout := Label.new()
	readout.theme_type_variation = &"Mono"
	readout.custom_minimum_size.x = 84.0
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.text = format.call(slider.value)
	row.add_child(readout)
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = format.call(v)
		Settings.set_value(section, key, v))
	return slider

func _refresh_crosshair_preview() -> void:
	if _crosshair_preview == null:
		return
	_crosshair_preview.style = int(Settings.get_value(&"gameplay", &"crosshair_style", 0))
	_crosshair_preview.color = Settings.get_value(&"gameplay", &"crosshair_color",
		KangurTheme.HOLO)
	_crosshair_preview.queue_redraw()

func _flash_status() -> void:
	if _status_label == null:
		return
	_status_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.7)
	tween.tween_property(_status_label, "modulate:a", 0.0, 0.3)

func _on_back() -> void:
	UiFx.back()
	# Settings is reachable from title and pause; pause is not a Game scene, so
	# the title is the safe parent when no match is running.
	if Game.match_config != null:
		Game.to_lobby()
	else:
		Game.to_title()