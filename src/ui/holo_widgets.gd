extends RefCounted
## holographic widgets — custom `_draw` controls shared by the HUD and menus.
## Every colour and font is read from the theme (`src/ui/theme.gd` palette,
## `kangur_theme.tres`); only geometry constants live here.
##
##   const HW := preload("res://src/ui/holo_widgets.gd")
##   var panel := HW.Plate.new()
##
## Widgets never mutate gameplay: they render model state handed to them
## (BodyModel / WeaponModel getters) or plain data dictionaries.

const KangurTheme := preload("res://src/ui/theme.gd")

## Bracket corner arm length, px.
const BRACKET := 13.0
## Panel title strip height; content parents should start below it.
const TITLE_H := 24.0
## Crosshair spread (half-angle, degrees) → screen px at the default zoom.
const PX_PER_DEG := 7.0



# =============================================================================
class Plate extends Control:
	## Bevelled near-black plate with 1 px holo edges and bracket corners.
	var title: String = ""
	var accent: Color = KangurTheme.HOLO
	var fill: Color = KangurTheme.PANEL
	var brackets: bool = true
	var show_border: bool = true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(p_title: String, p_accent: Color = KangurTheme.HOLO) -> Plate:
		title = p_title
		accent = p_accent
		queue_redraw()
		return self

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, fill)
		if show_border:
			var edge := accent
			edge.a = 0.20
			draw_line(Vector2(0.0, 0.5), Vector2(size.x, 0.5), edge, 1.0, true)
			draw_line(Vector2(0.0, size.y - 0.5), Vector2(size.x, size.y - 0.5), edge, 1.0, true)
			draw_line(Vector2(0.5, 0.0), Vector2(0.5, size.y), edge, 1.0, true)
			draw_line(Vector2(size.x - 0.5, 0.0), Vector2(size.x - 0.5, size.y), edge, 1.0, true)
		if brackets:
			_draw_brackets()
		if not title.is_empty():
			_draw_title()

	func _draw_brackets() -> void:
		var arm := minf(BRACKET, minf(size.x, size.y) * 0.5)
		var bright := accent
		bright.a = 0.85
		var corners: Array[Vector2] = [
			Vector2(0.0, 0.0), Vector2(size.x, 0.0),
			Vector2(0.0, size.y), Vector2(size.x, size.y),
		]
		for corner: Vector2 in corners:
			var sx := 1.0 if corner.x <= 0.0 else -1.0
			var sy := 1.0 if corner.y <= 0.0 else -1.0
			draw_line(corner, corner + Vector2(arm * sx, 0.0), bright, 1.5, true)
			draw_line(corner, corner + Vector2(0.0, arm * sy), bright, 1.5, true)

	func _draw_title() -> void:
		var font := get_theme_font(&"font", &"Section")
		var font_size := get_theme_font_size(&"font_size", &"Section") - 4
		draw_string(font, Vector2(14.0, 17.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, accent)
		var rule := accent
		rule.a = 0.18
		draw_line(Vector2(0.0, TITLE_H), Vector2(size.x, TITLE_H), rule, 1.0, true)


# =============================================================================
class Bar extends Control:
	## Segmented progress/ratio bar (HP, tickets, capture progress, reload).
	var value: float = 1.0
	var color: Color = KangurTheme.HOLO
	var segments: int = 0
	var show_label: bool = false
	var label: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0.0, 8.0)

	func set_ratio(ratio: float) -> void:
		value = clampf(ratio, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var track := KangurTheme.PANEL_SOLID
		track.a = 0.75
		draw_rect(Rect2(Vector2.ZERO, size), track)
		var edge := KangurTheme.HOLO
		edge.a = 0.18
		draw_rect(Rect2(Vector2.ZERO, size), edge, false, 1.0)
		var fill_w := (size.x - 2.0) * value
		if fill_w > 0.0:
			var fill_color := color
			fill_color.a = 0.85
			draw_rect(Rect2(Vector2(1.0, 1.0), Vector2(fill_w, size.y - 2.0)), fill_color)
			# Bright leading edge keeps a nearly empty bar visible.
			draw_rect(Rect2(Vector2(1.0 + fill_w - 1.5, 1.0), Vector2(1.5, size.y - 2.0)), color)
		if segments > 1:
			var tick := KangurTheme.PANEL_SOLID
			tick.a = 0.9
			for i: int in range(1, segments):
				var x := size.x * float(i) / float(segments)
				draw_line(Vector2(x, 0.0), Vector2(x, size.y), tick, 1.0)
		if show_label:
			var font := get_theme_font(&"font", &"MonoSmall")
			draw_string(font, Vector2(0.0, -3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				get_theme_font_size(&"font_size", &"MonoSmall"), KangurTheme.TEXT_DIM)


# =============================================================================
class BodyDiagram extends Control:
	## Six-part humanoid: green / amber / red / black per part + bleed droplets.
	## Reads BodyModel directly; `bind(null)` renders an unwounded silhouette.
	const HEAD_R := 10.0

	var body: BodyModel = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(104.0, 132.0)

	func bind(model: BodyModel) -> void:
		body = model
		queue_redraw()

	func refresh() -> void:
		queue_redraw()

	func _ratio(part: int) -> float:
		return 1.0 if body == null else body.part_ratio(part)

	func _bleeding(part: int) -> bool:
		return body != null and body.is_bleeding(part)

	func _part_color(part: int) -> Color:
		if body != null and not body.alive:
			return KangurTheme.DEAD_PART
		return KangurTheme.part_color(_ratio(part))

	func _draw() -> void:
		var s := minf(size.x / 100.0, size.y / 130.0)
		if s <= 0.0:
			return
		var origin := Vector2((size.x - 100.0 * s) * 0.5, (size.y - 130.0 * s) * 0.5)
		draw_set_transform(origin, 0.0, Vector2(s, s))
		# Head
		var head_c := Vector2(50.0, 16.0)
		draw_circle(head_c, HEAD_R + 1.5, KangurTheme.PANEL_SOLID)
		draw_circle(head_c, HEAD_R, _part_color(Enums.Part.HEAD))
		# Torso (bevelled plate)
		var torso := PackedVector2Array([
			Vector2(39.0, 30.0), Vector2(61.0, 30.0), Vector2(64.0, 44.0),
			Vector2(62.0, 72.0), Vector2(38.0, 72.0), Vector2(36.0, 44.0),
		])
		draw_colored_polygon(torso, _part_color(Enums.Part.TORSO))
		# Arms / legs as tapered capsules.
		_limb(Vector2(37.0, 34.0), Vector2(24.0, 66.0), 6.5, Enums.Part.ARM_L)
		_limb(Vector2(63.0, 34.0), Vector2(76.0, 66.0), 6.5, Enums.Part.ARM_R)
		_limb(Vector2(43.0, 72.0), Vector2(41.0, 118.0), 7.5, Enums.Part.LEG_L)
		_limb(Vector2(57.0, 72.0), Vector2(59.0, 118.0), 7.5, Enums.Part.LEG_R)
		# Seams: a 1 px panel line makes the diagram read as a schematic.
		var seam := KangurTheme.PANEL_SOLID
		seam.a = 0.55
		draw_line(Vector2(50.0, 30.0), Vector2(50.0, 72.0), seam, 1.0)
		draw_line(Vector2(38.0, 50.0), Vector2(62.0, 50.0), seam, 1.0)
		if body != null and body.alive:
			_draw_bleed()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if body == null or not body.alive:
			_draw_dead_mark()

	func _limb(from: Vector2, to: Vector2, width: float, part: int) -> void:
		var color := _part_color(part)
		var outline := KangurTheme.PANEL_SOLID
		draw_line(from, to, outline, width + 2.5, true)
		draw_line(from, to, color, width, true)
		draw_circle(from, width * 0.5, color)
		draw_circle(to, width * 0.5, color)

	func _draw_bleed() -> void:
		for part: int in Enums.PART_COUNT:
			if not _bleeding(part):
				continue
			var at := _bleed_slot(part)
			draw_circle(at, 2.4, KangurTheme.DANGER)
			draw_circle(at + Vector2(0.0, -2.0), 1.2, Color(KangurTheme.DANGER, 1.0))

	## Droplet anchor just outside the part, so wounds stay countable.
	func _bleed_slot(part: int) -> Vector2:
		match part:
			Enums.Part.HEAD:
				return Vector2(64.0, 10.0)
			Enums.Part.TORSO:
				return Vector2(70.0, 56.0)
			Enums.Part.ARM_L:
				return Vector2(16.0, 70.0)
			Enums.Part.ARM_R:
				return Vector2(84.0, 70.0)
			Enums.Part.LEG_L:
				return Vector2(30.0, 112.0)
			_:
				return Vector2(70.0, 112.0)

	func _draw_dead_mark() -> void:
		var ink := KangurTheme.DANGER
		ink.a = 0.65
		var y := size.y * 0.5 - 6.0
		draw_line(Vector2(6.0, y), Vector2(size.x - 6.0, y + 12.0), ink, 2.0, true)
		draw_line(Vector2(size.x - 6.0, y), Vector2(6.0, y + 12.0), ink, 2.0, true)


# =============================================================================
class ArmorPips extends Control:
	## Four shield pips per armour slot; fill tracks remaining durability.
	var ratio: float = 0.0
	var pips: int = 4
	var color: Color = KangurTheme.HOLO
	var caption: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0.0, 12.0)

	func set_ratio(r: float) -> void:
		ratio = clampf(r, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var x := 0.0
		if not caption.is_empty():
			var font := get_theme_font(&"font", &"MonoSmall")
			draw_string(font, Vector2(0.0, 9.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				get_theme_font_size(&"font_size", &"MonoSmall"), KangurTheme.TEXT_MUTED)
			x = 26.0
		var step := 10.0
		for i: int in pips:
			var cell := Rect2(Vector2(x + i * step, 2.0), Vector2(6.0, 8.0))
			var filled := ratio > float(i) / float(pips)
			if filled:
				draw_rect(cell, color)
			else:
				draw_rect(cell, Color(color, 0.18), false, 1.0)


# =============================================================================
class MinimapFrame extends Control:
	## Holographic minimap frame + blip API. Rendering of the world/vision cone
	## arrives with VisionSystem; this widget owns the frame and the marker set.
	const GRID := 8

	## Normalised positions (0..1 in map space) — independent of widget size.
	var blips: Array[Dictionary] = []
	var objectives: Array[Dictionary] = []
	## {pos: Vector2, dir: Vector2, half_deg: float, dist: float}
	var cone: Dictionary = {}
	var map_texture: Texture2D = null
	var accent: Color = KangurTheme.HOLO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(200.0, 200.0)

	func set_blips(list: Array[Dictionary]) -> void:
		blips = list
		queue_redraw()

	func set_cone(data: Dictionary) -> void:
		cone = data
		queue_redraw()

	func set_objectives(list: Array[Dictionary]) -> void:
		objectives = list
		queue_redraw()

	func _draw() -> void:
		var inner := Rect2(Vector2(6.0, 6.0), size - Vector2(12.0, 12.0))
		draw_rect(inner, Color(KangurTheme.PANEL_SOLID, 0.92))
		if map_texture != null:
			draw_texture_rect(map_texture, inner, false, Color(1.0, 1.0, 1.0, 0.55))
		_draw_grid(inner)
		_draw_cone(inner)
		for obj: Dictionary in objectives:
			_draw_objective(inner, obj)
		for blip: Dictionary in blips:
			_draw_blip(inner, blip)
		_draw_frame()

	func _draw_grid(inner: Rect2) -> void:
		var line := accent
		line.a = 0.10
		for i: int in range(1, GRID):
			var x := inner.position.x + inner.size.x * float(i) / float(GRID)
			var y := inner.position.y + inner.size.y * float(i) / float(GRID)
			draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), line, 1.0)
			draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), line, 1.0)

	func _draw_cone(inner: Rect2) -> void:
		if cone.is_empty():
			return
		var pos: Vector2 = cone.get("pos", Vector2(0.5, 0.5))
		var dir: Vector2 = cone.get("dir", Vector2.RIGHT)
		var half_deg: float = cone.get("half_deg", 45.0)
		var dist: float = cone.get("dist", 0.4)
		var center := inner.position + inner.size * pos
		var radius := inner.size.length() * 0.5 * dist
		var base := dir.angle()
		var half := deg_to_rad(half_deg)
		var points := PackedVector2Array([center])
		for i: int in 9:
			var a := base - half + (2.0 * half) * float(i) / 8.0
			points.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(points, Color(accent, 0.12))
		draw_polyline(points, Color(accent, 0.35), 1.0, true)

	func _draw_objective(inner: Rect2, obj: Dictionary) -> void:
		var pos: Vector2 = obj.get("pos", Vector2.ZERO)
		var center := inner.position + inner.size * pos
		var color: Color = obj.get("color", accent)
		var contested: bool = obj.get("contested", false)
		draw_circle(center, 7.0, Color(KangurTheme.PANEL_SOLID, 0.9))
		draw_arc(center, 7.0, 0.0, TAU, 20, color, 1.5, true)
		if contested:
			draw_arc(center, 10.0, 0.0, TAU, 24, Color(KangurTheme.AMBER, 0.8), 1.0, true)
		var font := get_theme_font(&"font", &"MonoSmall")
		var letter: String = obj.get("letter", "?")
		draw_string(font, center + Vector2(-4.0, 4.0), letter, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, get_theme_font_size(&"font_size", &"MonoSmall"), color)

	func _draw_blip(inner: Rect2, blip: Dictionary) -> void:
		var pos: Vector2 = blip.get("pos", Vector2.ZERO)
		var center := inner.position + inner.size * pos
		var color: Color = blip.get("color", KangurTheme.DANGER)
		var kind: StringName = blip.get("kind", &"enemy")
		match kind:
			&"player":
				var dir: Vector2 = blip.get("dir", Vector2.UP)
				var fwd := dir.normalized() * 5.0
				var side := Vector2(-fwd.y, fwd.x) * 3.0
				draw_colored_polygon(PackedVector2Array([
					center + fwd, center - fwd + side, center - fwd - side,
				]), color)
			&"ally":
				draw_circle(center, 2.4, color)
			&"sound":
				draw_arc(center, 5.0, 0.0, TAU, 12, Color(color, 0.7), 1.0, true)
			_:
				draw_circle(center, 3.0, Color(KangurTheme.PANEL_SOLID, 0.8))
				draw_circle(center, 2.2, color)

	func _draw_frame() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var edge := accent
		edge.a = 0.55
		draw_rect(rect, edge, false, 1.0)
		var arm := 16.0
		var bright := accent
		bright.a = 0.9
		for corner: Vector2 in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
			var sx := 1.0 if corner.x <= 0.0 else -1.0
			var sy := 1.0 if corner.y <= 0.0 else -1.0
			draw_line(corner, corner + Vector2(arm * sx, 0.0), bright, 2.0, true)
			draw_line(corner, corner + Vector2(0.0, arm * sy), bright, 2.0, true)
		# Cardinal ticks: a compass feel without a rotating widget.
		var mid_top := Vector2(size.x * 0.5, 0.0)
		draw_line(mid_top, mid_top + Vector2(0.0, 6.0), bright, 1.0, true)


# =============================================================================
class ObjectiveChain extends Control:
	## A → B → C capture chain: state colours, per-node progress ring, tickets.
	const NODE_R := 9.0
	## [{letter: "A", state: "locked|neutral|active|owned", team: int,
	##    progress: float 0..1, contested: bool}]
	var nodes: Array[Dictionary] = []
	var accent: Color = KangurTheme.HOLO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(240.0, 28.0)

	func set_nodes(list: Array[Dictionary]) -> void:
		nodes = list
		queue_redraw()

	func update_progress(obj_id: StringName, team: int, progress: float, contested: bool) -> void:
		for node: Dictionary in nodes:
			if StringName(node.get("id", &"")) != obj_id:
				continue
			node["progress"] = progress
			node["contested"] = contested
			node["state"] = "active"
			node["team"] = team
		queue_redraw()

	func _draw() -> void:
		if nodes.is_empty():
			return
		var count := nodes.size()
		var step := size.x / float(count)
		var y := size.y * 0.5
		# Connector gives the chain its direction.
		var rail := Color(accent, 0.25)
		draw_line(Vector2(step * 0.5, y), Vector2(size.x - step * 0.5, y), rail, 1.0)
		for i: int in count:
			var node: Dictionary = nodes[i]
			var center := Vector2(step * (float(i) + 0.5), y)
			_draw_node(center, node)
			if i < count - 1:
				var next_center := Vector2(step * (float(i) + 1.5), y)
				var done: bool = String(node.get("state", "locked")) == "owned"
				draw_line(center + Vector2(NODE_R + 3.0, 0.0), next_center - Vector2(NODE_R + 3.0, 0.0),
					Color(accent, 0.7) if done else rail, 2.0 if done else 1.0)
		# Labels under the nodes.
		var font := get_theme_font(&"font", &"MonoSmall")
		var fsize := get_theme_font_size(&"font_size", &"MonoSmall")
		for i: int in count:
			var node: Dictionary = nodes[i]
			var label: String = node.get("letter", "?")
			var color: Color = node.get("color", KangurTheme.TEXT_DIM)
			var x := step * (float(i) + 0.5)
			draw_string(font, Vector2(x + NODE_R + 4.0, y + 4.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize, color)

	func _draw_node(center: Vector2, node: Dictionary) -> void:
		var state: String = node.get("state", "locked")
		var color: Color = node.get("color", KangurTheme.TEXT_MUTED)
		var fill := Color(KangurTheme.PANEL_SOLID, 0.95)
		draw_circle(center, NODE_R, fill)
		draw_arc(center, NODE_R, -PI * 0.5, PI * 1.5, 28, Color(color, 0.45), 1.5, true)
		if state == "owned" or state == "active":
			var node_team: int = int(node.get("team", -1))
			if node_team >= 0:
				color = KangurTheme.team_color(node_team)
		if state == "active" or state == "owned":
			var progress: float = node.get("progress", 0.0)
			if progress > 0.0:
				draw_arc(center, NODE_R, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0),
					28, color, 2.5, true)
			draw_circle(center, 2.5, color)
		else:
			draw_circle(center, 1.8, Color(color, 0.6))
		if node.get("contested", false):
			draw_arc(center, NODE_R + 4.0, 0.0, TAU, 28, Color(KangurTheme.AMBER, 0.85), 1.0, true)


# =============================================================================
class Crosshair extends Control:
	## Four brackets expanding with live bloom (WeaponModel.current_spread_deg),
	## plus cross/dot presets. Colour from Settings (gameplay/crosshair_color).
	const STYLE_BRACKETS := 0
	const STYLE_CROSS := 1
	const STYLE_DOT := 2
	const BASE_GAP := 6.0
	const ARM := 5.0
	const DOT_R := 1.4

	var style: int = STYLE_BRACKETS
	var color: Color = KangurTheme.HOLO
	var spread_deg: float = 0.0
	var gap: float = BASE_GAP

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func set_spread_deg(deg: float) -> void:
		var clamped := clampf(deg, 0.0, 30.0)
		if is_equal_approx(clamped, spread_deg):
			return
		spread_deg = clamped
		gap = BASE_GAP + clamped * PX_PER_DEG
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var shadow := Color(0.0, 0.0, 0.0, 0.45)
		var col := color
		col.a = 0.95
		match style:
			STYLE_CROSS:
				for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					_stroke(c + dir * gap, c + dir * (gap + ARM), shadow, 3.0)
					_stroke(c + dir * gap, c + dir * (gap + ARM), col, 1.5)
			STYLE_DOT:
				draw_circle(c, DOT_R + 1.5, shadow)
				draw_circle(c, DOT_R, col)
			_:
				for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					var from := c + dir * gap
					var side := Vector2(-dir.y, dir.x) * ARM
					_stroke(from, from + dir * (ARM * 0.4) - side, shadow, 3.0)
					_stroke(from, from + dir * (ARM * 0.4) + side, shadow, 3.0)
					_stroke(from, from + dir * (ARM * 0.4) - side, col, 1.5)
					_stroke(from, from + dir * (ARM * 0.4) + side, col, 1.5)
		if style != STYLE_DOT:
			draw_circle(c, DOT_R + 1.2, shadow)
			draw_circle(c, DOT_R, col)

	func _stroke(from: Vector2, to: Vector2, col: Color, width: float) -> void:
		draw_line(from, to, col, width, true)


# =============================================================================
class Hitmarker extends Control:
	## White X on hit, red on kill (art-direction §2), 120 ms.
	const SIZE := 7.0
	const KILL_SIZE := 10.0

	var lethal: bool = false
	var _fade := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		modulate.a = 0.0

	func flash(kill: bool) -> void:
		lethal = kill
		modulate.a = 1.0
		queue_redraw()
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.18).set_delay(0.06)

	func _draw() -> void:
		var c := size * 0.5
		var arm := KILL_SIZE if lethal else SIZE
		var col := KangurTheme.DANGER if lethal else KangurTheme.TEXT
		for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var outer := c + dir.normalized() * arm
			var inner := c + dir.normalized() * (arm * 0.45)
			draw_line(inner, outer, Color(0.0, 0.0, 0.0, 0.5), 3.0, true)
			draw_line(inner, outer, col, 2.0, true)


# =============================================================================
class DamageArcs extends Control:
	## Red arcs at the screen edge pointing at recent damage sources.
	const LIFE_S := 0.6
	const WIDTH := 7.0

	## {angle: float (radians, screen space), t: float remaining}
	var _arcs: Array[Dictionary] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func add_source(angle: float) -> void:
		_arcs.append({"angle": angle, "t": LIFE_S})

	func clear() -> void:
		_arcs.clear()
		queue_redraw()

	func _process(delta: float) -> void:
		if _arcs.is_empty():
			return
		for arc: Dictionary in _arcs:
			arc["t"] = float(arc["t"]) - delta
		_arcs = _arcs.filter(func(a: Dictionary) -> bool: return float(a["t"]) > 0.0)
		queue_redraw()

	func _draw() -> void:
		if _arcs.is_empty():
			return
		var c := size * 0.5
		var radius := minf(size.x, size.y) * 0.42
		for arc: Dictionary in _arcs:
			var alpha := clampf(float(arc["t"]) / LIFE_S, 0.0, 1.0)
			var angle: float = arc["angle"]
			draw_arc(c, radius, angle - 0.30, angle + 0.30, 20,
				Color(KangurTheme.DANGER, alpha * 0.9), WIDTH, true)


# =============================================================================
class LowHpVignette extends Control:
	## Red edge falloff driven by torso HP; zero intensity hides it entirely.
	var intensity: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func set_intensity(value: float) -> void:
		var clamped := clampf(value, 0.0, 1.0)
		if is_equal_approx(clamped, intensity):
			return
		intensity = clamped
		queue_redraw()

	func _draw() -> void:
		if intensity <= 0.001:
			return
		var bands := 10
		var band := minf(size.x, size.y) * 0.02
		for i: int in bands:
			var alpha := intensity * 0.05 * (1.0 - float(i) / float(bands))
			var inset := band * float(i)
			var rect := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
			draw_rect(rect, Color(KangurTheme.DANGER, alpha), false, band + 1.0)


# =============================================================================
class KillfeedEntry extends Control:
	## `KILLER  [glyph]  VICTIM`, faction-coloured, player rows accented.
	var killer: String = ""
	var victim: String = ""
	var killer_team: int = -1
	var victim_team: int = -1
	var player_involved: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(260.0, 18.0)

	func setup(p_killer: String, p_victim: String, k_team: int, v_team: int, player: bool) -> KillfeedEntry:
		killer = p_killer
		victim = p_victim
		killer_team = k_team
		victim_team = v_team
		player_involved = player
		queue_redraw()
		return self

	func _draw() -> void:
		var font := get_theme_font(&"font", &"MonoSmall")
		var fsize := get_theme_font_size(&"font_size", &"MonoSmall")
		var mid := size.x * 0.5
		var y := size.y * 0.5 + fsize * 0.36
		if player_involved:
			draw_rect(Rect2(Vector2.ZERO, Vector2(2.0, size.y)), KangurTheme.HOLO)
		draw_string(font, Vector2(8.0, y), killer, HORIZONTAL_ALIGNMENT_RIGHT,
			mid - 22.0, fsize, KangurTheme.team_color(killer_team))
		draw_string(font, Vector2(mid + 14.0, y), victim, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - mid - 20.0, fsize, KangurTheme.team_color(victim_team))
		# Generic weapon glyph: per-weapon silhouettes arrive with WeaponDef icons.
		var c := Vector2(mid - 3.0, size.y * 0.5)
		draw_line(c - Vector2(5.0, 2.0), c + Vector2(6.0, -2.0), KangurTheme.TEXT_DIM, 3.0, true)
		draw_line(c + Vector2(1.0, 0.5), c + Vector2(2.0, 4.0), KangurTheme.TEXT_DIM, 2.0, true)


# =============================================================================
class RadioLine extends Control:
	## `CALLSIGN // text`, priority-coloured, fades after its TTL.
	const TTL_S := 6.0
	const FADE_S := 0.8

	var callsign: String = ""
	var text: String = ""
	var priority: int = 0
	var _age := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(280.0, 16.0)
		set_process(false)

	func setup(p_callsign: String, p_text: String, p_priority: int = 0) -> RadioLine:
		callsign = p_callsign
		text = p_text
		priority = p_priority
		_age = 0.0
		modulate.a = 1.0
		set_process(true)
		queue_redraw()
		return self

	func _process(delta: float) -> void:
		_age += delta
		if _age > TTL_S:
			queue_free()
			return
		var left := TTL_S - _age
		modulate.a = clampf(left / FADE_S, 0.0, 1.0)

	func _draw() -> void:
		var font := get_theme_font(&"font", &"MonoSmall")
		var fsize := get_theme_font_size(&"font_size", &"MonoSmall")
		var y := size.y * 0.5 + fsize * 0.36
		var color := KangurTheme.TEXT
		match priority:
			2:
				color = KangurTheme.AMBER
			1:
				color = KangurTheme.HOLO
		var head := "%s //" % callsign
		var head_w := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize).x
		draw_string(font, Vector2(0.0, y), head, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize,
			KangurTheme.TEXT_MUTED)
		draw_string(font, Vector2(head_w + 5.0, y), text, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - head_w - 5.0, fsize, color)


# =============================================================================
class WeaponGlyph extends Control:
	## Procedural weapon silhouette by category (WeaponDef.category).
	var category: StringName = &"ar"
	var color: Color = KangurTheme.TEXT

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(84.0, 26.0)

	func set_category(cat: StringName) -> void:
		category = cat
		queue_redraw()

	func _draw() -> void:
		var ink := color
		ink.a = 0.85
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		match category:
			&"pistol":
				_bar(c + Vector2(-14, -3), Vector2(16, 4), ink)
				_bar(c + Vector2(-8, 1), Vector2(5, 10), ink)
			&"smg":
				_bar(c + Vector2(-20, -3), Vector2(28, 4), ink)
				_bar(c + Vector2(6, -2), Vector2(10, 2), ink)
				_bar(c + Vector2(-8, 1), Vector2(5, 9), ink)
			&"shotgun":
				_bar(c + Vector2(-24, -3), Vector2(40, 4), ink)
				_bar(c + Vector2(4, 0), Vector2(10, 3), ink)
			&"sniper":
				_bar(c + Vector2(-30, -3), Vector2(52, 4), ink)
				_bar(c + Vector2(-6, -8), Vector2(16, 4), ink)
				_bar(c + Vector2(-12, 1), Vector2(6, 8), ink)
			&"lmg":
				_bar(c + Vector2(-26, -4), Vector2(44, 6), ink)
				_bar(c + Vector2(8, 1), Vector2(10, 8), ink)
				_bar(c + Vector2(-14, 2), Vector2(10, 8), ink)
			&"dmr", &"br":
				_bar(c + Vector2(-26, -3), Vector2(42, 4), ink)
				_bar(c + Vector2(-8, -8), Vector2(18, 4), ink)
				_bar(c + Vector2(-12, 1), Vector2(5, 8), ink)
			_:
				_bar(c + Vector2(-24, -3), Vector2(36, 4), ink)
				_bar(c + Vector2(-10, 1), Vector2(6, 9), ink)
				_bar(c + Vector2(2, -1), Vector2(14, 2), ink)

	func _bar(origin: Vector2, dims: Vector2, col: Color) -> void:
		draw_rect(Rect2(origin, dims), col)


# =============================================================================
class EquipIcon extends Control:
	## Frag / flash / smoke glyph with a count badge.
	var kind: int = Enums.EquipKind.FRAG
	var count: int = 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(30.0, 24.0)

	func setup(p_kind: int, p_count: int) -> EquipIcon:
		kind = p_kind
		count = p_count
		queue_redraw()
		return self

	func _draw() -> void:
		var c := Vector2(11.0, size.y * 0.5)
		var ink := KangurTheme.AMBER
		match kind:
			Enums.EquipKind.FLASH:
				for i: int in 8:
					var a := TAU * float(i) / 8.0
					draw_line(c, c + Vector2(cos(a), sin(a)) * 7.0, ink, 1.5, true)
			Enums.EquipKind.SMOKE:
				draw_circle(c + Vector2(-3, 1), 4.0, Color(ink, 0.6))
				draw_circle(c + Vector2(3, -1), 4.5, Color(ink, 0.45))
				draw_circle(c + Vector2(0, 3), 3.5, Color(ink, 0.55))
			_:
				draw_circle(c, 5.0, Color(ink, 0.35))
				draw_arc(c, 6.0, 0.0, TAU, 18, ink, 1.5, true)
				draw_line(c + Vector2(0, -6), c + Vector2(0, -9), ink, 1.5, true)
		var font := get_theme_font(&"font", &"MonoSmall")
		draw_string(font, Vector2(20.0, size.y * 0.5 + 4.0), "x%d" % count,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, get_theme_font_size(&"font_size", &"MonoSmall"), KangurTheme.TEXT_DIM)


# =============================================================================
class Rule extends Control:
	## 1 px holo rule with an optional caption; used between menu sections.
	var caption: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0.0, 10.0)

	func _draw() -> void:
		var y := size.y * 0.5
		var col := KangurTheme.HOLO
		col.a = 0.16
		if caption.is_empty():
			draw_line(Vector2(0.0, y), Vector2(size.x, y), col, 1.0, true)
			return
		var font := get_theme_font(&"font", &"MonoSmall")
		var fsize := get_theme_font_size(&"font_size", &"MonoSmall")
		var w := font.get_string_size(caption.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize).x
		draw_line(Vector2(0.0, y), Vector2(6.0, y), col, 1.0, true)
		draw_string(font, Vector2(12.0, y + 4.0), caption.to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, fsize, KangurTheme.TEXT_MUTED)
		draw_line(Vector2(w + 22.0, y), Vector2(size.x, y), col, 1.0, true)