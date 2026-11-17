extends MenuScreen
## Title screen: procedural dusk-port diorama + KANGUR wordmark + main menu.
## Path is fixed by Game.TITLE_SCENE.

const Diorama := preload("res://src/ui/title/port_diorama.gd")
const HoloButtonScript := preload("res://src/ui/holo_button.gd")

const EMBLEM_BASTION := "res://assets/ui/art/bastion_emblem.svg"
const EMBLEM_SIROCCO := "res://assets/ui/art/sirocco_emblem.svg"
const MENU_W := 320.0

func _build() -> void:
	# Background goes into `body` first: a child added straight to the screen
	# root would paint over the wordmark and buttons.
	var diorama: Control = Diorama.new()
	body.add_child(diorama)
	_build_top_bar()
	_build_wordmark()
	_build_menu()
	_build_footer()
	UiFx.play_sound(&"start", -20.0)

func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 40.0
	bar.offset_right = -40.0
	bar.offset_top = 26.0
	bar.add_theme_constant_override(&"separation", 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_tag("// KANGUR OPERATIONS"))
	bar.add_child(_spacer())
	bar.add_child(_tag("EUROPE 2041 · BUILD %s" % "0.1.0"))
	body.add_child(bar)

func _tag(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"MonoSmall"
	label.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	return label

func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer

func _build_wordmark() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	box.offset_left = 92.0
	box.offset_top = 132.0
	box.add_theme_constant_override(&"separation", 2)
	body.add_child(box)

	var kicker := Label.new()
	kicker.text = "PRIVATE MILITARY CONTRACT // SECTOR VII"
	kicker.theme_type_variation = &"MonoSmall"
	kicker.add_theme_color_override(&"font_color", KangurTheme.AMBER)
	box.add_child(kicker)

	var title := Label.new()
	title.text = "KANGUR"
	title.add_theme_font_override(&"font", KangurTheme.FONT_DISPLAY)
	title.add_theme_font_size_override(&"font_size", 96)
	title.add_theme_color_override(&"font_color", KangurTheme.TEXT)
	box.add_child(title)

	var rule := HW.Rule.new()
	rule.caption = "herbivore that boxes"
	rule.custom_minimum_size = Vector2(360.0, 16.0)
	box.add_child(rule)

	var sub := Label.new()
	sub.text = "TWO CONTRACTORS. ONE PIECE OF INFRASTRUCTURE.\n"
	sub.text += "NOBODY SIGNS OFF ON A REFUND."
	sub.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_SMALL)
	sub.add_theme_color_override(&"font_color", KangurTheme.TEXT_DIM)
	box.add_child(sub)

func _build_menu() -> void:
	var menu := VBoxContainer.new()
	menu.name = "Menu"
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu.offset_left = 92.0
	menu.offset_top = 400.0
	menu.custom_minimum_size.x = MENU_W
	menu.add_theme_constant_override(&"separation", 8)
	body.add_child(menu)

	var deploy := _button("DEPLOY", &"deploy", true)
	deploy.pressed.connect(_on_deploy)
	menu.add_child(deploy)
	var training := _button("TRAINING RANGE", &"start")
	training.pressed.connect(_on_training)
	menu.add_child(training)
	var settings := _button("SETTINGS", &"click")
	settings.pressed.connect(_on_settings)
	menu.add_child(settings)
	var credits := _button("CREDITS", &"click")
	credits.pressed.connect(_on_credits)
	menu.add_child(credits)
	var quit := _button("QUIT", &"back")
	quit.pressed.connect(_on_quit)
	menu.add_child(quit)

	var gaps: Array[Control] = []
	for child: Node in menu.get_children():
		gaps.append(child as Control)
	UiFx.stagger(gaps, 0.12)
	deploy.grab_focus()

func _button(text: String, sound: StringName, primary: bool = false) -> HoloButton:
	var button := HoloButtonScript.new() as HoloButton
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.primary = primary
	button.custom_minimum_size = Vector2(MENU_W, 44.0)
	button.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_BUTTON)
	button.pressed.connect(func() -> void: UiFx.play_sound(sound, UiFx.CLICK_DB))
	return button

func _build_footer() -> void:
	var emblems := HBoxContainer.new()
	emblems.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	emblems.offset_right = -84.0
	emblems.offset_bottom = -70.0
	emblems.offset_left = -420.0
	emblems.offset_top = -250.0
	emblems.alignment = BoxContainer.ALIGNMENT_END
	emblems.add_theme_constant_override(&"separation", 26)
	emblems.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblems.add_child(_emblem(EMBLEM_BASTION, "BASTION", KangurTheme.BASTION, "SECURITY GROUP"))
	emblems.add_child(_emblem(EMBLEM_SIROCCO, "SIROCCO", KangurTheme.SIROCCO, "EXTRACTION CORPS"))
	body.add_child(emblems)

	var footer := Label.new()
	footer.text = "v0.1.0 · EUPL-1.2 · click a contractor to review the contract"
	footer.theme_type_variation = &"MonoSmall"
	footer.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 92.0
	footer.offset_bottom = -30.0
	footer.offset_top = -46.0
	body.add_child(footer)

func _emblem(path: String, name: String, color: Color, role: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 6)
	var tex := TextureRect.new()
	tex.texture = load(path)
	tex.custom_minimum_size = Vector2(104.0, 104.0)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.modulate = Color(1.0, 1.0, 1.0, 0.86)
	box.add_child(tex)
	var title := Label.new()
	title.text = name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", color.lightened(0.25))
	title.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_SECTION)
	box.add_child(title)
	var sub := Label.new()
	sub.text = role
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.theme_type_variation = &"MonoSmall"
	sub.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	box.add_child(sub)
	return box

func _on_deploy() -> void:
	Game.to_lobby()

func _on_training() -> void:
	# Training is a range map under the same config path; no separate screen.
	var config := MatchConfig.new()
	config.mode = Enums.Mode.TRAINING
	config.map_id = &"range"
	var maps := Defs.all_maps()
	var chosen := _map_for_mode(Enums.Mode.TRAINING)
	if chosen != null:
		config.map_id = chosen.id
	elif not maps.is_empty():
		config.map_id = maps[0].id
	config.player_team = Enums.Team.BASTION
	config.difficulty_id = StringName(Settings.get_value(&"gameplay", &"difficulty", &"operator"))
	Game.to_match(config)

func _map_for_mode(mode: int) -> MapDef:
	var candidates := Defs.maps_for_mode(mode)
	return candidates[0] if not candidates.is_empty() else null

func _on_settings() -> void:
	Game.to_settings()

func _on_credits() -> void:
	Game.to_credits()

func _on_quit() -> void:
	Game.quit()

func _on_back() -> void:
	pass