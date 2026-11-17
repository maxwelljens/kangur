extends Control
class_name PortDiorama
## Procedural vector dusk-port diorama for the title screen (art-direction §4):
## gradient dusk sky, crane/container silhouettes, control tower, wet-concrete
## reflection, holo grid. Slow motion + mouse parallax, no external art.
## Colours come from `src/ui/theme.gd` only.

const KangurTheme := preload("res://src/ui/theme.gd")

const HORIZON := 0.60          # fraction of height where sky meets water
const PARALLAX_PX := 14.0      # max layer shift from mouse
const GRID_ROWS := 9
const GRID_COLS := 16
const GRID_DRIFT_PX_S := 9.0
const BLINK_PERIOD_S := 2.6

var _time := 0.0
var _parallax := Vector2.ZERO
var _target_parallax := Vector2.ZERO

## Cached gradient so the sky is one textured quad, not 200 draw_rect strips.
var _sky: GradientTexture2D = null
var _water: GradientTexture2D = null
## Left scrim: the wordmark and menu sit over the skyline, so the backdrop fades
## to near-black behind them (readability beats an unobstructed diorama).
var _scrim: GradientTexture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky = _make_gradient([
		[0.0, Color("070a10")],
		[0.38, Color("141d2a")],
		[0.72, KangurTheme.BASTION.darkened(0.55)],
		[0.90, Color("6a4a33")],
		[1.0, KangurTheme.AMBER.darkened(0.62)],
	])
	_water = _make_gradient([
		[0.0, Color("1a2430")],
		[0.30, Color("101822")],
		[1.0, Color("05070a")],
	])
	_scrim = _make_gradient([
		[0.0, Color(0.02, 0.03, 0.045, 0.90)],
		[0.62, Color(0.02, 0.03, 0.045, 0.55)],
		[1.0, Color(0.02, 0.03, 0.045, 0.0)],
	], Vector2(0.0, 0.0), Vector2(1.0, 0.0))

func _make_gradient(stops: Array, from: Vector2 = Vector2(0.0, 0.0),
		to: Vector2 = Vector2(0.0, 1.0)) -> GradientTexture2D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop: Array in stops:
		offsets.append(stop[0])
		colors.append(stop[1])
	gradient.offsets = offsets
	gradient.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = from
	tex.fill_to = to
	# Axis-aligned gradients only need resolution along the fade.
	tex.width = 256 if from.y == to.y else 4
	tex.height = 4 if from.y == to.y else 256
	return tex

func _process(delta: float) -> void:
	_time += delta
	var vp := size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var mouse := get_viewport().get_mouse_position()
	_target_parallax = Vector2(
		(mouse.x / vp.x - 0.5) * 2.0,
		(mouse.y / vp.y - 0.5) * 2.0).limit_length(1.0)
	_parallax = _parallax.lerp(_target_parallax, minf(delta * 2.5, 1.0))
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var h := size.y
	var w := size.x
	var horizon := h * HORIZON
	# Sky + haze
	draw_texture_rect(_sky, Rect2(Vector2.ZERO, Vector2(w, horizon)), false)
	_draw_haze(Vector2(w * 0.68, horizon * 0.86))
	# Far harbour silhouettes (slowest parallax layer)
	_draw_skyline(horizon, w, 1.0, Color("0d141c"))
	# Cranes + stacks
	_draw_cranes(horizon, w, 2.4)
	_draw_stacks(horizon, w, 3.0)
	_draw_tower(horizon, w, 3.2)
	# Water + reflection
	draw_texture_rect(_water, Rect2(Vector2(0.0, horizon), Vector2(w, h - horizon)), false)
	_draw_reflection(horizon, w, h)
	_draw_hologrid(horizon, w, h)
	_draw_foreground(w, h)

func _draw_haze(center: Vector2) -> void:
	# Layered discs fake a soft dawn bloom without a shader.
	for i: int in 7:
		var radius := 300.0 - i * 36.0
		var alpha := 0.018 + i * 0.008
		draw_circle(center, radius, Color(KangurTheme.AMBER, alpha))

func _layer_offset(depth: float) -> float:
	return -_parallax.x * PARALLAX_PX * depth

func _draw_skyline(horizon: float, w: float, depth: float, col: Color) -> void:
	var off := _layer_offset(depth)
	var base := horizon - 2.0
	var i := -1
	while i < 15:
		var x := off + float(i) * 140.0 + sin(float(i) * 2.3) * 26.0
		var bw := 74.0 + fmod(float(i) * 37.0, 40.0)
		var bh := 22.0 + absf(sin(float(i) * 1.7)) * 46.0
		draw_rect(Rect2(Vector2(x, base - bh), Vector2(bw, bh + 4.0)), col)
		i += 1

func _draw_cranes(horizon: float, w: float, depth: float) -> void:
	var off := _layer_offset(depth)
	# One gantry pair + one extra mast: enough structure to read as a port.
	_gantry(off + w * 0.46, horizon, 150.0, 118.0, Color("0a1119"))
	_gantry(off + w * 0.68, horizon, 186.0, 96.0, Color("0a1119"))
	for i: int in 3:
		var x := off + w * 0.14 + float(i) * 34.0
		_crane_leg(x, horizon, 70.0 + float(i) * 16.0)

func _gantry(x: float, horizon: float, height: float, reach: float, col: Color) -> void:
	var base_y := horizon - 4.0
	var top_y := base_y - height
	# Legs (A-frame)
	draw_line(Vector2(x, base_y), Vector2(x - 26.0, top_y + 26.0), col, 5.0, true)
	draw_line(Vector2(x + 44.0, base_y), Vector2(x + 26.0, top_y + 26.0), col, 5.0, true)
	draw_line(Vector2(x - 26.0, top_y + 26.0), Vector2(x + 26.0, top_y + 26.0), col, 5.0, true)
	# Boom + counter-jib
	draw_line(Vector2(x - 30.0, top_y), Vector2(x + reach, top_y), col, 5.0, true)
	draw_line(Vector2(x - 30.0, top_y), Vector2(x + 26.0, top_y + 26.0), col, 3.0, true)
	# Trolley slides with time — the diorama's main motion beat.
	var slide := 0.5 + 0.5 * sin(_time * 0.22 + x * 0.01)
	var trolley_x := x + reach * (0.25 + 0.7 * slide)
	draw_rect(Rect2(Vector2(trolley_x - 6.0, top_y - 3.0), Vector2(12.0, 8.0)), col)
	draw_line(Vector2(trolley_x, top_y + 4.0), Vector2(trolley_x, top_y + 42.0),
		Color(col.lightened(0.08), 0.9), 1.0, true)
	draw_rect(Rect2(Vector2(trolley_x - 9.0, top_y + 42.0), Vector2(18.0, 7.0)),
		Color(KangurTheme.AMBER, 0.30))

func _crane_leg(x: float, horizon: float, height: float) -> void:
	var col := Color("0a1119")
	var base_y := horizon - 2.0
	draw_line(Vector2(x, base_y), Vector2(x, base_y - height), col, 3.0, true)
	draw_line(Vector2(x, base_y - height), Vector2(x + 26.0, base_y - height), col, 3.0, true)
	draw_line(Vector2(x, base_y - height), Vector2(x + 26.0, base_y - height + 16.0), col, 2.0, true)

func _draw_stacks(horizon: float, w: float, depth: float) -> void:
	var off := _layer_offset(depth)
	var col_a := Color("0b121a")
	var col_b := Color("111a24")
	var x := off + w * 0.06
	var i := 0
	while i < 9:
		var stack_w := 96.0 + fmod(float(i) * 61.0, 54.0)
		var rows := 1 + i % 3
		var tint := col_a if i % 2 == 0 else col_b
		for r: int in rows:
			var y := horizon - 20.0 - float(r) * 19.0
			var rect := Rect2(Vector2(x + float(r) * 4.0, y - 18.0), Vector2(stack_w, 18.0))
			draw_rect(rect, tint)
			# Corrugation ribs: cheap, sells the container read.
			var ribs := int(stack_w / 12.0)
			for rib: int in ribs:
				var rx := rect.position.x + 6.0 + float(rib) * 12.0
				draw_line(Vector2(rx, rect.position.y + 2.0), Vector2(rx, rect.end.y - 2.0),
					Color(col_b.lightened(0.10), 0.5), 1.0)
		x += stack_w + 14.0
		i += 1

func _draw_tower(horizon: float, w: float, depth: float) -> void:
	var off := _layer_offset(depth)
	var x := off + w * 0.855
	var base_y := horizon
	var body_w := 54.0
	var body_h := 132.0
	var col := Color("0c131b")
	# Tapered shaft + wide cab
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 12.0, base_y),
		Vector2(x + body_w + 12.0, base_y),
		Vector2(x + body_w + 2.0, base_y - body_h),
		Vector2(x + 2.0, base_y - body_h),
	]), col)
	draw_rect(Rect2(Vector2(x - 10.0, base_y - body_h - 26.0),
		Vector2(body_w + 20.0, 26.0)), col)
	# Lit windows (amber; some dark) + blinking beacon on the roof.
	for row: int in 3:
		for col_idx: int in 3:
			var lit := (row * 3 + col_idx) % 4 != 0
			var wc := Color(KangurTheme.AMBER, 0.55) if lit else Color(0.05, 0.07, 0.09, 0.9)
			draw_rect(Rect2(Vector2(x + 2.0 + float(col_idx) * 20.0,
				base_y - body_h - 20.0 + float(row) * 7.0), Vector2(11.0, 4.0)), wc)
	var pulse := 0.5 + 0.5 * sin(_time * TAU / BLINK_PERIOD_S)
	var beacon := Vector2(x + body_w * 0.5, base_y - body_h - 33.0)
	draw_circle(beacon, 8.0 + pulse * 3.0, Color(KangurTheme.DANGER, 0.10 + 0.12 * pulse))
	draw_circle(beacon, 2.2, Color(1.0, 0.45, 0.38, 0.85))

func _draw_reflection(horizon: float, w: float, h: float) -> void:
	var water_h := h - horizon
	# Mirrored warm window feedback stretching into the water.
	for i: int in 5:
		var x := w * 0.80 + float(i) * 13.0
		var streak_h := water_h * (0.18 + 0.05 * float(i))
		var wobble := sin(_time * 0.9 + float(i)) * 2.5
		draw_rect(Rect2(Vector2(x + wobble, horizon + 2.0), Vector2(3.0, streak_h)),
			Color(KangurTheme.AMBER, 0.10 - 0.012 * float(i)))
	# Horizontal shimmer lines, denser near the horizon.
	var rows := 22
	for r: int in rows:
		var t := float(r) / float(rows)
		var y := horizon + t * water_h
		var alpha := (1.0 - t) * 0.07
		var jitter := sin(_time * 1.6 + float(r) * 0.7) * (2.0 + t * 6.0)
		var seg_w := w * (0.10 + 0.16 * fmod(float(r) * 0.37, 1.0))
		var x0 := fmod(float(r) * 271.0 + _time * 12.0, w + seg_w) - seg_w
		draw_line(Vector2(x0 + jitter, y), Vector2(x0 + seg_w + jitter, y),
			Color(KangurTheme.HOLO, alpha), 1.0, true)

func _draw_hologrid(horizon: float, w: float, h: float) -> void:
	var water_h := h - horizon
	var drift := fmod(_time * GRID_DRIFT_PX_S, 1.0)
	# Perspective converging lines toward a vanishing point under the harbour.
	var vanish := Vector2(w * 0.5, horizon - h * 0.06)
	for c: int in GRID_COLS + 1:
		var base_x := w * float(c) / float(GRID_COLS)
		var t := (float(c) / float(GRID_COLS) - 0.5) * 2.0
		var from := Vector2(vanish.x + t * w * 0.12, horizon)
		draw_line(from, Vector2(base_x, h), Color(KangurTheme.HOLO, 0.07), 1.0, true)
	for r: int in GRID_ROWS:
		var t := (float(r) + drift) / float(GRID_ROWS)
		var y := horizon + t * t * water_h
		draw_line(Vector2(0.0, y), Vector2(w, y), Color(KangurTheme.HOLO, 0.06 + t * 0.03),
			1.0, true)

func _draw_foreground(w: float, h: float) -> void:
	draw_texture_rect(_scrim, Rect2(Vector2.ZERO, Vector2(w * 0.42, h)), false)
	# Bottom band + vignette keeps menu text legible over the water.
	var veil := Color("05070a")
	draw_rect(Rect2(Vector2(0.0, h * 0.78), Vector2(w, h * 0.22)), Color(veil, 0.55))
	for i: int in 6:
		var a := 0.05 + float(i) * 0.02
		var inset := -float(i) * 10.0
		draw_rect(Rect2(Vector2(inset, inset), Vector2(w - inset * 2.0, h - inset * 2.0)),
			Color(veil, a), false, 18.0)