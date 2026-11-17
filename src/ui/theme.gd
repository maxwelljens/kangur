extends Theme
class_name KangurTheme
## Kangur UI theme: palette constants + the one Theme resource every screen uses
## (`res://src/ui/kangur_theme.tres`). Restyle the game from this file only.
## Direction: docs/design/art-direction.md §4 (holo, thin lines, bracket corners,
## tabular numerals); HUD spec: game-design.md §11.

# --- Palette (art-direction §4) ---------------------------------------------
const HOLO := Color("7bebd4")
const HOLO_DIM := Color("3f7f78")
const AMBER := Color("f2a541")
const BASTION := Color("3e5c76")
const SIROCCO := Color("c4552d")
const PANEL := Color("0b0e14d9")          # #0B0E14 @ 85%
const PANEL_SOLID := Color("0b0e14")
const BACKDROP := Color("05070af2")
const TEXT := Color("dce7e4")
const TEXT_DIM := Color("7e8f92")
const TEXT_MUTED := Color("4c5a5e")
const DANGER := Color("e0524a")
const OK := Color("6fd08c")
const DEAD_PART := Color("232a30")
const LINE := Color("7bebd43d")           # holo line @ 24%
const SCANLINE := Color("7bebd40d")       # holo @ 5%

## Crosshair colour presets offered in Settings (gameplay/crosshair_color).
const CROSSHAIR_PRESETS: Array[Color] = [
	Color("7bebd4"), Color("f2a541"), Color("dce7e4"),
	Color("7dff6b"), Color("ff6b6b"), Color("8fa4ff"),
]

# --- Type scale (px at the 1600×900 reference viewport) ---------------------
const SIZE_DISPLAY := 46
const SIZE_TITLE := 28
const SIZE_SECTION := 18
const SIZE_BUTTON := 17
const SIZE_BODY := 15
const SIZE_SMALL := 13
const SIZE_MONO := 16
const SIZE_MONO_LARGE := 28
const SIZE_MONO_SMALL := 12

const FONT_UI: FontFile = preload("res://assets/ui/fonts/ChakraPetch-Medium.ttf")
const FONT_DISPLAY: FontFile = preload("res://assets/ui/fonts/ChakraPetch-Bold.ttf")
const FONT_SEMIBOLD: FontFile = preload("res://assets/ui/fonts/ChakraPetch-SemiBold.ttf")
const FONT_MONO: FontFile = preload("res://assets/ui/fonts/ShareTechMono-Regular.ttf")

# --- Motion (make-interfaces-feel-better: 120–180 ms eases) ------------------
const EASE_S := 0.14
const ENTRANCE_STAGGER_S := 0.045

func _init() -> void:
	default_font = FONT_UI
	default_font_size = SIZE_BODY
	_init_labels()
	_init_buttons()
	_init_containers()
	_init_scrollbars()

# --- Static helpers used by widgets (single palette source) -----------------
static func team_color(team: int) -> Color:
	if team == Enums.Team.BASTION:
		return BASTION
	if team == Enums.Team.SIROCCO:
		return SIROCCO
	return TEXT_DIM

## Body part state colour: green / amber / red / black (design §7).
static func part_color(ratio: float) -> Color:
	if ratio <= 0.0:
		return DEAD_PART
	if ratio >= 0.66:
		return OK
	# Amber floor == BodyModel.CRIPPLE_RATIO: crippled parts are always red.
	if ratio >= BodyModel.CRIPPLE_RATIO:
		return AMBER
	return DANGER

static func format_clock(seconds: float) -> String:
	var total := maxi(int(ceil(seconds)), 0)
	return "%02d:%02d" % [total / 60, total % 60]

## Percent without magic rounding repeated all over the HUD.
static func format_pct(ratio: float) -> String:
	return "%d%%" % int(round(clampf(ratio, 0.0, 1.0) * 100.0))

static func _pad(box: StyleBoxFlat, pad: int) -> StyleBoxFlat:
	box.content_margin_left = pad
	box.content_margin_right = pad
	box.content_margin_top = pad
	box.content_margin_bottom = pad
	return box

static func _style(bg: Color, border: Color, pad: int, border_w: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(2)
	return _pad(box, pad)

func _init_labels() -> void:
	set_color(&"font_color", &"Label", TEXT)
	set_font(&"font", &"Label", FONT_UI)
	set_font_size(&"font_size", &"Label", SIZE_BODY)
	set_type_variation(&"Display", &"Label")
	set_font(&"font", &"Display", FONT_DISPLAY)
	set_font_size(&"font_size", &"Display", SIZE_DISPLAY)
	set_color(&"font_color", &"Display", TEXT)
	set_type_variation(&"Title", &"Label")
	set_font(&"font", &"Title", FONT_SEMIBOLD)
	set_font_size(&"font_size", &"Title", SIZE_TITLE)
	set_type_variation(&"Section", &"Label")
	set_font(&"font", &"Section", FONT_SEMIBOLD)
	set_font_size(&"font_size", &"Section", SIZE_SECTION)
	set_color(&"font_color", &"Section", HOLO)
	set_type_variation(&"Dim", &"Label")
	set_font_size(&"font_size", &"Dim", SIZE_SMALL)
	set_color(&"font_color", &"Dim", TEXT_DIM)
	set_type_variation(&"Mono", &"Label")
	set_font(&"font", &"Mono", FONT_MONO)
	set_font_size(&"font_size", &"Mono", SIZE_MONO)
	set_type_variation(&"MonoLarge", &"Mono")
	set_font_size(&"font_size", &"MonoLarge", SIZE_MONO_LARGE)
	set_color(&"font_color", &"MonoLarge", TEXT)
	set_type_variation(&"MonoSmall", &"Mono")
	set_font_size(&"font_size", &"MonoSmall", SIZE_MONO_SMALL)
	set_color(&"font_color", &"MonoSmall", TEXT_DIM)

func _init_buttons() -> void:
	# HoloButton draws itself; these states also serve plain Buttons (credits,
	# rebind rows) so both read as the same control family.
	for type: StringName in [&"Button", &"OptionButton"]:
		set_font(&"font", type, FONT_UI)
		set_font_size(&"font_size", type, SIZE_BUTTON)
		set_color(&"font_color", type, TEXT)
		set_color(&"font_hover_color", type, HOLO)
		set_color(&"font_pressed_color", type, TEXT)
		set_color(&"font_disabled_color", type, TEXT_MUTED)
		set_stylebox(&"normal", type, _style(Color("101720a6"), LINE, 12))
		set_stylebox(&"hover", type, _style(Color("16222bb3"), Color("7bebd4a6"), 12))
		set_stylebox(&"pressed", type, _style(Color(0.48, 0.92, 0.83, 0.20), HOLO, 12))
		set_stylebox(&"disabled", type, _style(Color("0b0e1480"), Color("7e8f9226"), 12))
		set_stylebox(&"focus", type, _style(Color(0, 0, 0, 0), Color("7bebd480"), 12))

func _init_containers() -> void:
	set_stylebox(&"panel", &"PanelContainer", _style(PANEL, LINE, 16))
	set_stylebox(&"panel", &"Panel", _style(PANEL, LINE, 16))
	set_stylebox(&"panel", &"PopupPanel", _style(PANEL_SOLID, HOLO_DIM, 10))
	set_font(&"normal_font", &"RichTextLabel", FONT_UI)
	set_font_size(&"normal_font_size", &"RichTextLabel", SIZE_BODY)
	set_color(&"default_color", &"RichTextLabel", TEXT)
	set_stylebox(&"normal", &"RichTextLabel", _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	set_stylebox(&"panel", &"PopupMenu", _style(PANEL_SOLID, HOLO_DIM, 8))
	set_color(&"font_color", &"PopupMenu", TEXT)
	set_color(&"font_hover_color", &"PopupMenu", HOLO)
	set_stylebox(&"hover", &"PopupMenu", _style(Color("16222b"), HOLO, 6))

func _init_scrollbars() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("7bebd40f")
	track.content_margin_left = 2
	track.content_margin_right = 2
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("7bebd480")
	grabber.content_margin_left = 2
	grabber.content_margin_right = 2
	for type: StringName in [&"VScrollBar", &"HScrollBar"]:
		set_stylebox(&"scroll", type, track)
		set_stylebox(&"grabber", type, grabber)
		set_stylebox(&"grabber_highlight", type, grabber)
		set_stylebox(&"grabber_pressed", type, grabber)