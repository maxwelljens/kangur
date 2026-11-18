extends MenuScreen
## Credits: EUPL notice, engine/addon licences, and the full attribution text
## parsed from `docs/credits.md` + `docs/research/music-attribution.md`.
## Incompetech tracks are credited one title at a time (licence requirement);
## those lines live in the markdown and are rendered verbatim.

const HoloButtonScript := preload("res://src/ui/holo_button.gd")
## Table blocks need a fixed-width face for the column padding to line up.
const MONO_FONT := "res://assets/ui/fonts/ShareTechMono-Regular.ttf"

const CREDITS_DOC := "res://docs/credits.md"
const MUSIC_DOC := "res://docs/research/music-attribution.md"
const EMBLEM_BUILD := "res://assets/ui/art/bastion_emblem.svg"

const INTRO := """[font_size=15][color=#7bebd4]KANGUR[/color] — singleplayer topdown tactical shooter.
Game code and original content: [color=#dce7e4]EUPL-1.2[/color] (see LICENSE).
Copyright © the Kangur contributors.

Third-party assets below keep their own licences; each shipped pack was checked
against a licence file or the original distribution page. Unverifiable packs are
not shipped.

[color=#f2a541]ENGINE & TOOLS[/color]
Godot Engine 4.7.2 — MIT (godotengine.org)
gdUnit4 — MIT © 2023 Mike Schulze
@icons — MIT © 2026 Valentin Fossati (Voxybuns) & contributors
Vision Cone 2D — Apache-2.0 © sirdorius
SIL Open Font License 1.1 fonts: Chakra Petch (© 2018 The Chakra Petch Project
Authors), Share Tech Mono (© 2012 Carrois Type Design). Full OFL texts ship in
assets/ui/fonts/.
[/font_size]"""

var _scroll: ScrollContainer = null
var _column: VBoxContainer = null

func _build() -> void:
	_build_header()
	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 44.0
	layout.offset_right = -44.0
	layout.offset_top = 88.0
	layout.offset_bottom = -28.0
	layout.add_theme_constant_override(&"separation", 24)
	body.add_child(layout)

	var rail := VBoxContainer.new()
	rail.custom_minimum_size.x = 250.0
	rail.add_theme_constant_override(&"separation", 8)
	layout.add_child(rail)
	rail.add_child(_rail_block("LICENCE", "EUPL-1.2", "Source available, share-alike.\nCommercial use permitted."))
	rail.add_child(_rail_block("FONTS", "OFL 1.1", "Chakra Petch + Share Tech Mono.\nDesigners: Cadson Demak, Carrois."))
	rail.add_child(_rail_block("AUDIO", "CC0 / CC BY", "Packs listed title by title.\nAttribution kept verbatim."))
	var emblem := TextureRect.new()
	emblem.texture = load(EMBLEM_BUILD)
	emblem.custom_minimum_size = Vector2(88.0, 88.0)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.modulate = Color(1.0, 1.0, 1.0, 0.55)
	rail.add_child(emblem)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(_scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override(&"separation", 12)
	_scroll.add_child(_column)

	_column.add_child(_rich(INTRO, 14))
	_column.add_child(_rule())
	_add_document(CREDITS_DOC)
	_column.add_child(_rule())
	_add_document(MUSIC_DOC)

func _build_header() -> void:
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 44.0
	header.offset_right = -44.0
	header.offset_top = 24.0
	header.add_theme_constant_override(&"separation", 16)
	body.add_child(header)
	var title := Label.new()
	title.text = "CREDITS"
	title.add_theme_font_override(&"font", KangurTheme.FONT_DISPLAY)
	title.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_TITLE)
	header.add_child(title)
	var tag := Label.new()
	tag.text = "// ATTRIBUTION & LICENCES"
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

func _rail_block(caption: String, value: String, body_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	var cap := Label.new()
	cap.text = caption
	cap.theme_type_variation = &"MonoSmall"
	cap.add_theme_color_override(&"font_color", KangurTheme.HOLO)
	box.add_child(cap)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override(&"font_size", KangurTheme.SIZE_SECTION)
	box.add_child(val)
	var text := Label.new()
	text.text = body_text
	text.theme_type_variation = &"MonoSmall"
	text.add_theme_color_override(&"font_color", KangurTheme.TEXT_MUTED)
	box.add_child(text)
	return box

func _rule() -> HW.Rule:
	var rule := HW.Rule.new()
	rule.custom_minimum_size = Vector2(0.0, 16.0)
	return rule

func _rich(text: String, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = text
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size.x = 0.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override(&"normal_font_size", font_size)
	label.add_theme_font_size_override(&"bold_font_size", font_size)
	label.add_theme_color_override(&"default_color", KangurTheme.TEXT)
	return label

func _add_document(path: String) -> void:
	if not FileAccess.file_exists(path):
		# Exported builds may strip .md; keep the licence notice readable anyway.
		var missing := Label.new()
		missing.text = "Attribution source not packaged: %s" % path
		missing.theme_type_variation = &"MonoSmall"
		missing.add_theme_color_override(&"font_color", KangurTheme.AMBER)
		_column.add_child(missing)
		return
	var text := FileAccess.get_file_as_string(path)
	_column.add_child(_rich(markdown_to_bbcode(text), 13))

## Minimal markdown → BBCode: headings, bold, inline code, lists, tables.
## Only what `docs/credits.md` and the music attribution doc actually use.
## Table rows are buffered and padded into aligned columns; the mono font makes
## the padding hold (the body font is proportional, so spaces would not line up).
static func markdown_to_bbcode(md: String) -> String:
	var out: PackedStringArray = []
	var table: Array[PackedStringArray] = []
	for raw_line: String in md.split("\n"):
		var line := raw_line.strip_edges(false, true)
		if line.begins_with("|"):
			var cells := line.trim_prefix("|").trim_suffix("|").split("|")
			var cleaned := PackedStringArray()
			for cell: String in cells:
				cleaned.append(cell.strip_edges().replace("**", ""))
			table.append(cleaned)
			continue
		if not table.is_empty():
			out.append(_table_block(table))
			table.clear()
		if line.begins_with("```"):
			continue
		if line.begins_with("### "):
			out.append("\n[font_size=14][color=#7bebd4]%s[/color][/font_size]" % _inline(line.substr(4)))
		elif line.begins_with("## "):
			out.append("\n\n[font_size=17][color=#dce7e4]%s[/color][/font_size]" % _inline(line.substr(3)))
		elif line.begins_with("# "):
			out.append("\n[font_size=19][color=#f2a541]%s[/color][/font_size]" % _inline(line.substr(2)))
		elif line.begins_with("---"):
			out.append("\n[color=#7bebd43d]────────────────[/color]")
		elif line.begins_with("- ") or line.begins_with("* "):
			out.append("  [color=#4c5a5e]·[/color] %s" % _inline(line.substr(2)))
		elif line.is_empty():
			out.append("")
		else:
			out.append(_inline(line))
	if not table.is_empty():
		out.append(_table_block(table))
	return "\n".join(out)

## One markdown table as aligned mono columns inside a tinted block. Cells are
## plain text (no inline BBCode): the mono font makes space padding hold, which
## link/bold colour tags inside a cell would break.
static func _table_block(rows: Array[PackedStringArray]) -> String:
	var widths: PackedInt32Array = PackedInt32Array()
	var kept: Array[PackedStringArray] = []
	for row: PackedStringArray in rows:
		# The `|---|` separator row carries no content.
		var joined := "".join(row)
		if joined.replace("-", "").replace(":", "").replace(" ", "").is_empty():
			continue
		var plain: PackedStringArray = []
		for cell: String in row:
			plain.append(cell.replace("`", "").replace("[", "(").replace("]", ")"))
		kept.append(plain)
		for i: int in plain.size():
			if i >= widths.size():
				widths.append(0)
			widths[i] = maxi(widths[i], plain[i].length())
	var lines: PackedStringArray = []
	for row: PackedStringArray in kept:
		var padded: PackedStringArray = []
		for i: int in row.size():
			padded.append(row[i] + " ".repeat(widths[i] - row[i].length()))
		lines.append(" ".join(padded).strip_edges(false, true))
	return "\n[font_size=12][font=%s][color=#7e8f92]%s[/color][/font][/font_size]" % [MONO_FONT,
		"\n".join(lines)]

## Inline span conversion: **bold**, `code`, [label](url), <autolink>.
## Link runs are pulled out BEFORE brackets are escaped, otherwise the BBCode
## inserted here would be escaped by our own safety pass.
static func _inline(text: String) -> String:
	var tokens: Array[String] = []
	var with_links := ""
	var cursor := 0
	while true:
		var open := text.find("](", cursor)
		var label_start := text.rfind("[", open - 1) if open >= 0 else -1
		if open < 0 or label_start < cursor:
			with_links += text.substr(cursor)
			break
		var close := text.find(")", open + 2)
		if close < 0:
			with_links += text.substr(cursor)
			break
		var label := text.substr(label_start + 1, open - label_start - 1).replace("`", "")
		var url := text.substr(open + 2, close - open - 2)
		with_links += text.substr(cursor, label_start - cursor)
		with_links += "\u0001%d\u0001" % tokens.size()
		# Relative repo links (../LICENSE) are meaningless in-game: show the
		# label only; external URLs show the target so the credit is verifiable.
		tokens.append("[color=#7bebd4]%s[/color]" % url if label.begins_with("http")
			else "[color=#7bebd4]%s[/color]" % label)
		cursor = close + 1
	# Remaining brackets/angle quotes are literal text: BBCode would parse them.
	var escaped := with_links.replace("[", "(").replace("]", ")").replace("`", "")
	escaped = escaped.replace("<", "").replace(">", "")
	var parts := escaped.split("**")
	var out := ""
	for i: int in parts.size():
		out += parts[i] if i % 2 == 0 else "[b][color=#dce7e4]%s[/color][/b]" % parts[i]
	for i: int in tokens.size():
		out = out.replace("\u0001%d\u0001" % i, tokens[i])
	return out
