extends GdUnitTestSuite
## UI theme + widget logic. Visual appearance is verified by screenshots
## (`tools/shot_ui_all.sh`); these tests pin the behaviour that breaks silently:
## palette/theme wiring, body-diagram colour states, crosshair bloom mapping,
## progress clamps, and the numeric formatters the HUD relies on.

const KangurTheme := preload("res://src/ui/theme.gd")
const HW := preload("res://src/ui/holo_widgets.gd")

const THEME_PATH := "res://src/ui/kangur_theme.tres"
const EPSILON := 0.001


func test_theme_resource_loads_with_palette_and_fonts() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_object(theme).is_not_null()
	assert_bool(theme.default_font != null).is_true()
	assert_int(theme.default_font_size).is_equal(KangurTheme.SIZE_BODY)
	# The palette must stay in sync with the design doc (art-direction §4).
	assert_that(KangurTheme.HOLO).is_equal(Color("7bebd4"))
	assert_that(KangurTheme.AMBER).is_equal(Color("f2a541"))
	assert_that(KangurTheme.BASTION).is_equal(Color("3e5c76"))
	assert_that(KangurTheme.SIROCCO).is_equal(Color("c4552d"))
	assert_that(KangurTheme.PANEL).is_equal(Color("0b0e14d9"))
	assert_float(KangurTheme.PANEL.a).is_equal_approx(0.85, EPSILON)


func test_theme_button_states_are_distinct() -> void:
	var theme := load(THEME_PATH) as Theme
	var normal := theme.get_stylebox(&"normal", &"Button") as StyleBoxFlat
	var hover := theme.get_stylebox(&"hover", &"Button") as StyleBoxFlat
	var pressed := theme.get_stylebox(&"pressed", &"Button") as StyleBoxFlat
	assert_object(normal).is_not_null()
	assert_object(hover).is_not_null()
	assert_object(pressed).is_not_null()
	assert_bool(normal.bg_color != hover.bg_color).is_true()
	assert_bool(hover.bg_color != pressed.bg_color).is_true()
	# Hover must read brighter than rest; pressed fills with the accent.
	assert_bool(hover.border_color != normal.border_color).is_true()
	assert_float(pressed.border_color.r).is_greater(0.3)


func test_theme_label_variations_resolve() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_object(theme.get_font(&"font", &"Mono")).is_not_null()
	assert_int(theme.get_font_size(&"font_size", &"MonoLarge")).is_greater(
		theme.get_font_size(&"font_size", &"Mono"))
	var display: Font = theme.get_font(&"font", &"Display")
	var ui: Font = theme.get_font(&"font", &"Label")
	assert_bool(display != null and ui != null).is_true()
	assert_bool(display != ui).is_true()


func test_fonts_load_with_expected_family_names() -> void:
	var ui_font := load("res://assets/ui/fonts/ChakraPetch-Medium.ttf") as FontFile
	var mono_font := load("res://assets/ui/fonts/ShareTechMono-Regular.ttf") as FontFile
	assert_object(ui_font).is_not_null()
	assert_object(mono_font).is_not_null()
	assert_str(ui_font.get_font_name()).contains("Chakra Petch")
	assert_str(mono_font.get_font_name()).contains("Share Tech Mono")
	# Mono numerals must be a fixed advance or tabular HUD columns drift.
	var one := mono_font.get_string_size("1", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var eight := mono_font.get_string_size("8", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	assert_float(one).is_equal_approx(eight, EPSILON)


func test_part_colour_thresholds_match_body_model() -> void:
	# Design §7: green above 66%, amber above 33%, red below, black at zero.
	assert_that(KangurTheme.part_color(1.0)).is_equal(KangurTheme.OK)
	assert_that(KangurTheme.part_color(BodyModel.CRIPPLE_RATIO)).is_equal(KangurTheme.AMBER)
	assert_that(KangurTheme.part_color(0.1)).is_equal(KangurTheme.DANGER)
	assert_that(KangurTheme.part_color(0.0)).is_equal(KangurTheme.DEAD_PART)


func test_team_colour_maps_faction_and_rejects_unknown() -> void:
	assert_that(KangurTheme.team_color(Enums.Team.BASTION)).is_equal(KangurTheme.BASTION)
	assert_that(KangurTheme.team_color(Enums.Team.SIROCCO)).is_equal(KangurTheme.SIROCCO)
	assert_that(KangurTheme.team_color(-1)).is_equal(KangurTheme.TEXT_DIM)


func test_format_clock_rounds_up_and_pads() -> void:
	assert_str(KangurTheme.format_clock(0.0)).is_equal("00:00")
	assert_str(KangurTheme.format_clock(59.2)).is_equal("01:00")
	assert_str(KangurTheme.format_clock(480.0)).is_equal("08:00")
	assert_str(KangurTheme.format_clock(-5.0)).is_equal("00:00")


func test_format_pct_clamps() -> void:
	assert_str(KangurTheme.format_pct(0.456)).is_equal("46%")
	assert_str(KangurTheme.format_pct(1.7)).is_equal("100%")
	assert_str(KangurTheme.format_pct(-0.2)).is_equal("0%")


func test_bar_clamps_ratio() -> void:
	var bar := HW.Bar.new()
	bar.set_ratio(1.8)
	assert_float(bar.value).is_equal(1.0)
	bar.set_ratio(-0.4)
	assert_float(bar.value).is_equal(0.0)
	bar.free()


func test_crosshair_bloom_expands_gap_and_clamps() -> void:
	var crosshair := HW.Crosshair.new()
	crosshair.set_spread_deg(0.0)
	assert_float(crosshair.gap).is_equal_approx(HW.Crosshair.BASE_GAP, EPSILON)
	crosshair.set_spread_deg(3.0)
	assert_float(crosshair.gap).is_equal_approx(
		HW.Crosshair.BASE_GAP + 3.0 * HW.PX_PER_DEG, EPSILON)
	# A wild bloom value must not blow the crosshair off the screen.
	crosshair.set_spread_deg(400.0)
	assert_float(crosshair.spread_deg).is_equal(30.0)
	# Shrinking bloom returns to the base gap (no ratchet).
	crosshair.set_spread_deg(0.0)
	assert_float(crosshair.gap).is_equal_approx(HW.Crosshair.BASE_GAP, EPSILON)
	crosshair.free()


func test_body_diagram_binds_model_and_reports_bleed_state() -> void:
	var diagram := HW.BodyDiagram.new()
	assert_object(diagram.body).is_null()  # unbound renders a healthy silhouette
	var body := BodyModel.new(true, true)
	diagram.bind(body)
	assert_object(diagram.body).is_same(body)
	# Crippling the left arm must change its colour state. 18 base dmg × 0.75
	# arm multiplier leaves 4.5/18 HP — under the cripple threshold.
	body.apply_hit(Enums.Part.ARM_L, 18.0, 1.0)
	assert_bool(body.part_ratio(Enums.Part.ARM_L) < BodyModel.CRIPPLE_RATIO).is_true()
	assert_that(KangurTheme.part_color(body.part_ratio(Enums.Part.ARM_L))).is_equal(
		KangurTheme.DANGER)
	diagram.free()


func test_objective_chain_progress_targets_named_node_only() -> void:
	var chain := HW.ObjectiveChain.new()
	chain.set_nodes([
		{"id": &"a", "letter": "A", "state": "owned", "team": Enums.Team.BASTION, "progress": 1.0},
		{"id": &"b", "letter": "B", "state": "locked", "team": -1, "progress": 0.0},
	])
	chain.update_progress(&"b", Enums.Team.SIROCCO, 0.4, true)
	assert_str(str(chain.nodes[1].get("state"))).is_equal("active")
	assert_float(float(chain.nodes[1].get("progress"))).is_equal_approx(0.4, EPSILON)
	assert_bool(bool(chain.nodes[1].get("contested"))).is_true()
	# 'a' is untouched: a stray progress event must not rewrite owned nodes.
	assert_str(str(chain.nodes[0].get("state"))).is_equal("owned")
	chain.update_progress(&"missing", Enums.Team.BASTION, 0.9, false)
	assert_float(float(chain.nodes[0].get("progress"))).is_equal_approx(1.0, EPSILON)
	chain.free()


func test_minimap_rejects_nothing_and_stores_markers() -> void:
	var map := HW.MinimapFrame.new()
	map.set_blips([{"pos": Vector2(0.5, 0.5), "kind": &"enemy"}])
	assert_int(map.blips.size()).is_equal(1)
	map.set_cone({"pos": Vector2(0.2, 0.2), "dir": Vector2.UP, "half_deg": 40.0, "dist": 0.3})
	assert_bool(map.cone.is_empty()).is_false()
	map.free()


func test_killfeed_entry_truncation_keeps_newest() -> void:
	# The HUD caps the feed; this pins the widget-level invariant that a stale
	# entry cannot resurrect after the cap trims it.
	var feed := VBoxContainer.new()
	for i: int in 7:
		var entry := HW.KillfeedEntry.new()
		entry.setup("K%d" % i, "V%d" % i, Enums.Team.BASTION, Enums.Team.SIROCCO, false)
		feed.add_child(entry)
	while feed.get_child_count() > 5:
		var oldest := feed.get_child(0)
		feed.remove_child(oldest)
		oldest.free()
	assert_int(feed.get_child_count()).is_equal(5)
	assert_str((feed.get_child(0) as HW.KillfeedEntry).killer).is_equal("K2")
	feed.free()


func test_hud_scale_setting_stays_in_designed_range() -> void:
	# Accessibility range is design §11: 0.8×–1.4×.
	var low := float(Settings.DEFAULTS[&"video"][&"hud_scale"])
	assert_float(low).is_equal_approx(1.0, EPSILON)
	var range := Vector2(0.8, 1.4)
	assert_float(Settings.DEFAULTS[&"video"][&"hud_scale"]).is_between(range.x, range.y)
	assert_float(Settings.DEFAULTS[&"video"][&"zoom"]).is_between(1.0, 2.4)


func test_credits_markdown_converts_without_leaking_syntax() -> void:
	var credits_script: GDScript = load("res://src/ui/menus/credits_screen.gd")
	var bbcode: String = credits_script.markdown_to_bbcode(
		"## 1. Audio\n\n### Pack — **CC0**\n- `file.wav` by **Author**\n")
	assert_str(bbcode).contains("[font_size=17]")
	assert_str(bbcode).contains("Audio")
	assert_bool(bbcode.contains("##")).is_false()
	# Backticks and markdown bold markers must not survive into the rendered text.
	assert_bool(bbcode.contains("`")).is_false()
	assert_str(bbcode).contains("[b]")
	# Per-title music credit lines (Incompetech requirement) stay verbatim.
	var music: String = credits_script.markdown_to_bbcode(
		"\"Static Motion\" Kevin MacLeod (incompetech.com) / Licensed under Creative Commons")
	assert_str(music).contains("\"Static Motion\"")
	assert_str(music).contains("incompetech.com")

func test_music_credits_name_every_incompetech_title() -> void:
	# CC BY 4.0 and the Incompetech FAQ require each track by its actual title,
	# plus a statement that the files were edited. This is a licence obligation,
	# so it is asserted rather than eyeballed.
	var credits_script: GDScript = load("res://src/ui/menus/credits_screen.gd")
	var source := FileAccess.get_file_as_string("res://docs/research/music-attribution.md")
	var rendered: String = credits_script.markdown_to_bbcode(source)
	for title: String in ["Static Motion", "Industrial Cinematic",
			"Controlled Chaos - no percussion", "Controlled Chaos", "Oppressive Gloom",
			"Peaceful Desolation", "Lost Time"]:
		assert_bool(rendered.contains(title)).override_failure_message(
			"missing Incompetech title: %s" % title).is_true()
	assert_bool(rendered.contains("Licensed under Creative Commons: By Attribution 4.0")).is_true()
	assert_bool(rendered.contains("converted to Ogg Vorbis and edited for looping")).is_true()

func test_credits_tables_render_as_aligned_columns() -> void:
	# A collapsed one-line-per-row table loses the licence mapping (which file
	# belongs to which author). Columns are padded for the mono face, so a
	# shared left edge is the observable contract.
	var credits_script: GDScript = load("res://src/ui/menus/credits_screen.gd")
	var bbcode: String = credits_script.markdown_to_bbcode(
		"| File | Author | Licence |\n|---|---|---|\n| `a.wav` | Ann | CC0 |\n| `bb.ogg` | Bob | CC BY |\n")
	var rows: PackedStringArray = []
	for line: String in bbcode.split("\n"):
		if line.contains(".wav") or line.contains(".ogg"):
			rows.append(line)
	assert_array(rows).has_size(2)
	# Same column count is not enough: the second column must start at the same
	# offset in both rows, which is what the padding buys.
	assert_int(rows[0].find("Ann")).is_equal(rows[1].find("Bob"))
	assert_bool(bbcode.contains("---")).is_false()
