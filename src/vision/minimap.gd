extends Control
## Minimap — fixed north-up tactical map for the HUD (design §5).
##
## Draws, back to front:
##   baked map silhouette (World.minimap_path) → explored shading → grid overlay
##   (A–H × 1–8, toggleable) → objectives (status colours) → teammates (live) →
##   shared enemy contacts (fading, from TeamVision) → witnessed-death skulls →
##   player arrow (rotates) → player cone wedge.
## Reads state only: TeamVision contacts, EventBus objective/death states, and
## the VisionSystem's cone polygon. Never mutates gameplay.
##
## Placement contract for the HUD: add it as a child, call `bind(...)` once, then
## `refresh()` at HUD cadence (it also self-refreshes at REFRESH_HZ).

## Minimap grid columns/rows for the A–H × 1–8 overlay (design §5).
const GRID_COLS := 8
const GRID_ROWS := 8
const REFRESH_HZ := 10.0
const PLAYER_ARROW := 6.0
const ALLY_BLIP := 3.0
const CONTACT_BLIP := 3.2
const OBJECTIVE_RADIUS := 6.0
## Contacts older than this are not drawn even if TeamVision still holds them.
const MIN_CONTACT_CONFIDENCE := 0.02
## Padding inside the widget so bracket corners do not collide with blips.
const INSET := 6.0

const PALETTE := preload("res://src/ui/theme.gd")

var _world_bounds: Rect2 = Rect2()
var _map_texture: Texture2D = null
var _team_vision: Node = null
var _vision: Node = null
var _player: Character = null
var _team: int = Enums.Team.BASTION
var _characters: Array[Character] = []
var _objectives: Array[Dictionary] = []
var _danger: Array[Dictionary] = []
var show_grid: bool = true

var _accum: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not EventBus.objective_captured.is_connected(_on_objective_captured):
		EventBus.objective_captured.connect(_on_objective_captured)
	EventBus.objective_progress.connect(_on_objective_progress)


func _process(dt: float) -> void:
	_accum += dt
	if _accum < 1.0 / REFRESH_HZ:
		return
	_accum = 0.0
	refresh()


## One-shot wiring. `vision` may be any node exposing player_cone_world();
## it is optional (minimap still works without the fog system).
func bind(world: World, characters: Array[Character], player: Character,
		team_vision: Node = null, vision: Node = null) -> void:
	_characters = characters
	_player = player
	_team_vision = team_vision
	_vision = vision
	if player != null:
		_team = player.team
	_world_bounds = world.bounds() if world != null else Rect2()
	var path := ""
	if world != null:
		# World.minimap_path() keys off a map id; the World node only knows the
		# scene path, so derive the id the same way MapDef does.
		var scene_path := world.map_scene_path
		var map_id := StringName(scene_path.get_base_dir().get_file())
		path = world.minimap_path(map_id)
	if not path.is_empty():
		_map_texture = load(path) as Texture2D
	_objectives.clear()
	if world != null:
		for zone: ObjectiveZone in world.objectives():
			_objectives.append({
				&"obj_id": zone.obj_id, &"pos": zone.global_position,
				&"order": zone.order, &"team": -1, &"progress": 0.0,
				&"contested": false,
			})
	refresh()


## Grid labels toggle (HUD binding: M or a settings switch).
func toggle_grid() -> void:
	show_grid = not show_grid
	queue_redraw()


## Blip list in normalised map space, for the HUD's own MinimapFrame widget if
## the host prefers to render elsewhere. Same content as this widget draws.
func blips() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Character in _characters:
		if c == null or not is_instance_valid(c):
			continue
		var kind: StringName = &"player" if c == _player else &"ally"
		if not c.alive and c != _player:
			continue
		out.append({
			&"pos": world_to_norm(c.global_position), &"kind": kind,
			&"dir": c.aim_dir,
			&"color": PALETTE.team_color(c.team),
		})
	if _team_vision != null:
		for contact: Dictionary in _team_vision.shared_contacts(_team):
			if float(contact[&"confidence"]) < MIN_CONTACT_CONFIDENCE:
				continue
			out.append({
				&"pos": world_to_norm(contact[&"pos"]), &"kind": &"enemy",
				&"color": Color(PALETTE.DANGER, float(contact[&"confidence"])),
			})
	return out


## Normalised (0..1) map position used by both this widget and the HUD blips.
func world_to_norm(pos: Vector2) -> Vector2:
	if _world_bounds.size.x <= 0.0 or _world_bounds.size.y <= 0.0:
		return Vector2(0.5, 0.5)
	return ((pos - _world_bounds.position) / _world_bounds.size).clamp(Vector2.ZERO, Vector2.ONE)


func refresh() -> void:
	if _team_vision != null:
		_danger = _team_vision.danger_marks()
	queue_redraw()


func _draw() -> void:
	var inner := Rect2(Vector2(INSET, INSET), size - Vector2(INSET, INSET) * 2.0)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(PALETTE.PANEL_SOLID, 0.92))
	if _map_texture != null:
		draw_texture_rect(_map_texture, inner, false, Color(1.0, 1.0, 1.0, 0.62))
	if show_grid:
		_draw_grid(inner)
	for obj: Dictionary in _objectives:
		_draw_objective(inner, obj)
	_draw_allies(inner)
	_draw_contacts(inner)
	_draw_danger(inner)
	_draw_player(inner)
	_draw_frame()


func _draw_grid(inner: Rect2) -> void:
	var line := Color(PALETTE.HOLO, 0.13)
	var font := get_theme_font(&"font", &"MonoSmall")
	var font_size := get_theme_font_size(&"font_size", &"MonoSmall")
	for i: int in range(1, GRID_COLS):
		var x := inner.position.x + inner.size.x * float(i) / float(GRID_COLS)
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), line, 1.0)
	for i: int in range(1, GRID_ROWS):
		var y := inner.position.y + inner.size.y * float(i) / float(GRID_ROWS)
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), line, 1.0)
	if font == null:
		return
	for i: int in GRID_COLS:
		var label := String.chr(65 + i)
		var at := Vector2(inner.position.x + inner.size.x * (float(i) + 0.5) / GRID_COLS
			- 3.0, inner.position.y + 9.0)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
			Color(PALETTE.HOLO, 0.35))
	for i: int in GRID_ROWS:
		var at := Vector2(inner.position.x + 2.0,
			inner.position.y + inner.size.y * (float(i) + 0.5) / GRID_ROWS + 4.0)
		draw_string(font, at, str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
			Color(PALETTE.HOLO, 0.35))


func _draw_objective(inner: Rect2, obj: Dictionary) -> void:
	var center := inner.position + inner.size * world_to_norm(obj[&"pos"])
	var team: int = obj[&"team"]
	var color: Color = PALETTE.TEXT_DIM if team < 0 else PALETTE.team_color(team)
	draw_circle(center, OBJECTIVE_RADIUS, Color(PALETTE.PANEL_SOLID, 0.9))
	draw_arc(center, OBJECTIVE_RADIUS, 0.0, TAU, 20, color, 1.5, true)
	if bool(obj[&"contested"]):
		draw_arc(center, OBJECTIVE_RADIUS + 3.0, 0.0, TAU, 24,
			Color(PALETTE.AMBER, 0.85), 1.0, true)
	var progress: float = obj[&"progress"]
	if progress > 0.0:
		draw_arc(center, OBJECTIVE_RADIUS + 1.0, -PI / 2.0,
			-PI / 2.0 + TAU * clampf(progress, 0.0, 1.0), 20, color, 1.0, true)
	var font := get_theme_font(&"font", &"MonoSmall")
	if font != null:
		draw_string(font, center + Vector2(-3.0, 3.5), String(obj[&"obj_id"]).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, get_theme_font_size(&"font_size", &"MonoSmall"),
			color)


func _draw_allies(inner: Rect2) -> void:
	for c: Character in _characters:
		if c == null or not is_instance_valid(c) or not c.alive or c == _player:
			continue
		if c.team != _team:
			continue
		draw_circle(inner.position + inner.size * world_to_norm(c.global_position),
			ALLY_BLIP, PALETTE.team_color(c.team))


## Shared contacts: teammates' eyes, delayed + noisy, fading — minimap only.
func _draw_contacts(inner: Rect2) -> void:
	if _team_vision == null:
		return
	for contact: Dictionary in _team_vision.shared_contacts(_team):
		var confidence := float(contact[&"confidence"])
		if confidence < MIN_CONTACT_CONFIDENCE:
			continue
		var center := inner.position + inner.size * world_to_norm(contact[&"pos"])
		# Fade the fill, keep the ring: a stale contact reads as "last seen there".
		draw_circle(center, CONTACT_BLIP, Color(PALETTE.DANGER, confidence))
		draw_arc(center, CONTACT_BLIP + 2.0, 0.0, TAU, 12,
			Color(PALETTE.DANGER, confidence * 0.45), 1.0, true)


func _draw_danger(inner: Rect2) -> void:
	for mark: Dictionary in _danger:
		var center := inner.position + inner.size * world_to_norm(mark[&"pos"])
		var color := Color(PALETTE.AMBER, 0.75)
		var r := 3.0
		# Tiny skull: two eye sockets inside a rounded mark.
		draw_circle(center, r, color)
		draw_circle(center + Vector2(-1.2, -0.6), 0.8, PALETTE.PANEL_SOLID)
		draw_circle(center + Vector2(1.2, -0.6), 0.8, PALETTE.PANEL_SOLID)


func _draw_player(inner: Rect2) -> void:
	if _player == null:
		return
	var center := inner.position + inner.size * world_to_norm(_player.global_position)
	if _vision != null:
		var cone: PackedVector2Array = _vision.player_cone_world()
		if cone.size() > 2:
			var points := PackedVector2Array()
			for p: Vector2 in cone:
				points.append(inner.position + inner.size * world_to_norm(p))
			draw_colored_polygon(points, Color(PALETTE.HOLO, 0.10))
			points.append(points[0])
			draw_polyline(points, Color(PALETTE.HOLO, 0.30), 1.0, true)
	var dir := _player.aim_dir.normalized() if _player.aim_dir.length() > 0.01 else Vector2.UP
	var fwd := dir * PLAYER_ARROW
	var side := Vector2(-fwd.y, fwd.x) * 0.6
	draw_colored_polygon(PackedVector2Array([
		center + fwd, center - fwd + side, center - fwd - side,
	]), PALETTE.HOLO)


func _draw_frame() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(PALETTE.HOLO, 0.55), false, 1.0)
	var arm := 14.0
	var bright := Color(PALETTE.HOLO, 0.9)
	for corner: Vector2 in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y),
			Vector2(size.x, size.y)]:
		var sx := 1.0 if corner.x <= 0.0 else -1.0
		var sy := 1.0 if corner.y <= 0.0 else -1.0
		draw_line(corner, corner + Vector2(arm * sx, 0.0), bright, 2.0, true)
		draw_line(corner, corner + Vector2(0.0, arm * sy), bright, 2.0, true)


# --- objectives state -------------------------------------------------------

func publish_objectives() -> Array[Dictionary]:
	return _objectives


func _on_objective_progress(obj_id: StringName, team: int, progress: float,
		contested: bool) -> void:
	for obj: Dictionary in _objectives:
		if obj[&"obj_id"] != obj_id:
			continue
		obj[&"team"] = team
		obj[&"progress"] = progress
		obj[&"contested"] = contested
		queue_redraw()
		return


func _on_objective_captured(obj_id: StringName, team: int) -> void:
	for obj: Dictionary in _objectives:
		if obj[&"obj_id"] == obj_id:
			obj[&"team"] = team
			obj[&"progress"] = 1.0
			obj[&"contested"] = false
			queue_redraw()
			return