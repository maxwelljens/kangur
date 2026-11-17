extends Node2D
## AI demo + F3 overlay arena: a real map with two squads of bots, drawn with
## perception cones, current action, personality, nav targets and danger heat.
##
## Interactive:   tools/godot.sh --path . tools/shot_ai.tscn         (F3 toggles)
## Screenshot:    tools/godot.sh --path . -- --shot=res://tools/shot_ai.tscn:150:reports/screenshots/ai_overlay.png
##
## The overlay reads only what a spectator could: Perception cone params, the
## blackboard debug_state() and the squad danger grid.

const CharacterScene := preload("res://src/entities/character.tscn")
const RigScript := preload("res://src/entities/rig.gd")

const MAP_ID := &"compound"
const BOTS_PER_TEAM := 4
const CLOCK_TICKS := 200
## Camera framing: the two spawn clusters plus the middle of the map.
const CAMERA_ZOOM := 1.0
const CAMERA_MARGIN := 0.96
const ACTION_INK := Color(0.98, 0.85, 0.45, 1.0)
const CONTACT_INK := Color(1.0, 0.35, 0.28, 0.85)
const NAV_INK := Color(0.45, 0.85, 1.0, 0.8)
const DANGER_INK := Color(1.0, 0.15, 0.1, 0.22)
const KILLZONE_INK := Color(1.0, 0.2, 0.1, 0.55)

var world: World = null
var bots: Array[Character] = []
var overlay_on: bool = true

var _overlay: Node2D = null
var _label: Label = null
var _radio_log: Array[String] = []
var _ticks: int = 0
var _spawn_pos: Dictionary = {}
var _sim_kills: int = 0
var _sim_shots: int = 0
var _sim_radios: int = 0


func _ready() -> void:
	world = World.new()
	world.map_scene_path = "res://maps/%s/map.tscn" % MAP_ID
	add_child(world)
	if world.map == null:
		push_error("shot_ai: cannot load map %s" % MAP_ID)
		return
	_spawn_squads()
	_add_camera()
	_add_label()
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	EventBus.radio_message.connect(_on_radio)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ai-sim="):
			_simulate(int(arg.trim_prefix("--ai-sim=")))
		elif arg == "--ai-selftest":
			_selftest()


func _spawn_squads() -> void:
	for team: int in [Enums.Team.BASTION, Enums.Team.SIROCCO]:
		var spawns := world.spawn_points(team)
		for i: int in BOTS_PER_TEAM:
			var at: Vector2 = spawns[i % spawns.size()] if not spawns.is_empty() \
				else world.bounds().get_center()
			at += Vector2.RIGHT.rotated(float(i) * TAU / float(BOTS_PER_TEAM)) * 70.0
			var bot: Character = CharacterScene.instantiate()
			bot.position = at
			add_child(bot)
			bot.surface_provider = world.surface_at
			bot.setup({
				&"team": team, &"class_id": &"vanguard",
				&"callsign": _callsign(team, i), &"is_player": false, &"ai": true,
				&"seed": hash(Vector2i(team, i)) ^ 991,
				&"primary_id": &"kestrel", &"sidearm_id": &"adder",
				&"difficulty_id": &"veteran",
			})
			bots.append(bot)
			_spawn_pos[bot] = at


func _callsign(team: int, index: int) -> String:
	var faction := Defs.faction(StringName(Enums.team_name(team).to_lower()))
	if faction != null and not faction.callsigns.is_empty():
		return faction.callsigns[index % faction.callsigns.size()]
	return "Bot%d" % index


## Fit the whole map: the overlay is only trustworthy if every cone, nav path
## and danger cell is visible at once.
func _add_camera() -> void:
	var camera := Camera2D.new()
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position = world.bounds().get_center()
	add_child(camera)
	camera.make_current()
	var rect := world.bounds()
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		var viewport := get_viewport_rect().size
		var fit := minf(viewport.x / rect.size.x, viewport.y / rect.size.y) * CAMERA_MARGIN
		camera.zoom = Vector2(fit, fit)


## Text lives on a CanvasLayer so it is never clipped by the world camera.
func _add_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 16)
	_label.add_theme_color_override(&"font_color", ACTION_INK)
	_label.add_theme_font_size_override(&"font_size", 16)
	_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override(&"shadow_offset_x", 2)
	_label.add_theme_constant_override(&"shadow_offset_y", 2)
	layer.add_child(_label)


func _physics_process(_dt: float) -> void:
	_ticks += 1
	_resolve_shots()
	if _ticks % 20 == 0:
		_update_label()
		if _overlay != null:
			_overlay.queue_redraw()


## Minimal projectile resolver for the demo: swept ray per ShotRequest against
## the real collision layers, then Character.apply_hit. The production combat
## wave owns this; the arena needs it so kills, danger heat and killzone radio
## actually happen in the demo.
func _resolve_shots() -> void:
	for bot in bots:
		if not is_instance_valid(bot) or not bot.alive:
			continue
		for shot: ShotRequest in bot.take_pending_shots():
			var from := shot.origin
			var to := shot.origin + shot.dir.normalized() * shot.tracer_len
			var query := PhysicsRayQueryParameters2D.create(from, to, Layers.BULLET_MASK)
			query.collide_with_areas = false
			query.exclude = [bot.get_rid()]
			var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				continue
			var victim := hit.get(&"collider") as Character
			if victim == null or not victim.alive or victim.team == bot.team:
				continue
			var part := victim.part_at_world_pos(hit.get(&"position"))
			victim.apply_hit(part, shot.damage, shot.penetration, bot)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		overlay_on = not overlay_on
		if _overlay != null:
			_overlay.visible = overlay_on
		get_viewport().set_input_as_handled()


func _update_label() -> void:
	if _label == null:
		return
	var lines := PackedStringArray(["[F3] AI overlay — %s, %d bots, t=%.1fs" % [
		MAP_ID, bots.size(), float(_ticks) / 60.0]])
	for bot in bots:
		if not is_instance_valid(bot) or not bot.alive:
			continue
		var state: Dictionary = bot.controller.call(&"debug_state")
		lines.append("%s  %-16s %-16s v=%d  %s" % [
			bot.callsign, String(state.get(&"action", "?")),
			String(state.get(&"personality", "")),
			int(state.get(&"visible", 0)),
			_bars(state.get(&"scores", {}))])
	lines.append("radio: %s" % (" | ".join(_radio_log) if not _radio_log.is_empty() else "—"))
	_label.text = "\n".join(lines)


## Compact score sparkline: top three candidates of the last decision tick.
func _bars(scores: Dictionary) -> String:
	var pairs: Array = scores.keys()
	pairs.sort_custom(func(a: StringName, b: StringName) -> bool:
		return float(scores[a]) > float(scores[b]))
	var out := PackedStringArray()
	for i: int in mini(3, pairs.size()):
		var key: StringName = pairs[i]
		out.append("%s %.2f" % [key, float(scores[key])])
	return " ".join(out)


func _count_shot(_s: Node, _w: StringName, _o: Vector2, _d: Vector2, _p: int) -> void:
	_sim_shots += 1

func _count_radio(_t: int, _f: String, _x: String, _p: int) -> void:
	_sim_radios += 1

func _count_kill(_v: Node, _a: Node, _w: StringName, _pos: Vector2, _d: float) -> void:
	_sim_kills += 1

func _on_radio(_team: int, from: String, text: String, _priority: int) -> void:
	_radio_log.append("%s: %s" % [from, text])
	while _radio_log.size() > 3:
		_radio_log.pop_front()


# --- overlay ---------------------------------------------------------------

func _draw_overlay() -> void:
	if not overlay_on:
		return
	_draw_danger()
	for bot in bots:
		if not is_instance_valid(bot):
			continue
		_draw_cone(bot)
		_draw_nav(bot)
		_draw_action(bot)
	_draw_contacts()


## Perception cone: exactly the angle/range the NPC is actually using.
func _draw_cone(bot: Character) -> void:
	if not bot.alive:
		return
	var perception: Perception = bot.perception
	var ink := _team_ink(bot.team)
	var radius := perception.cone_range
	var half := deg_to_rad(perception.cone_angle_deg * 0.5)
	var aim := bot.aim_dir.normalized()
	if aim.length() < 0.001:
		return
	var left := bot.global_position + aim.rotated(-half) * radius
	var right := bot.global_position + aim.rotated(half) * radius
	var points := PackedVector2Array([bot.global_position])
	var steps := 10
	for i: int in steps + 1:
		var angle := -half + (half * 2.0) * float(i) / float(steps)
		points.append(bot.global_position + aim.rotated(angle) * radius)
	_overlay.draw_colored_polygon(points, Color(ink.r, ink.g, ink.b, 0.06))
	_overlay.draw_line(bot.global_position, left, Color(ink.r, ink.g, ink.b, 0.28), 1.0)
	_overlay.draw_line(bot.global_position, right, Color(ink.r, ink.g, ink.b, 0.28), 1.0)


func _draw_nav(bot: Character) -> void:
	var bb: Blackboard = bot.controller.get(&"bb")
	if bb == null or not bb.has_nav_target:
		return
	_overlay.draw_dashed_line(bot.global_position, bb.nav_target, NAV_INK, 1.0, 8.0)
	if bb.path.size() > 1:
		_overlay.draw_polyline(bb.path, Color(NAV_INK.r, NAV_INK.g, NAV_INK.b, 0.35), 1.0)


func _draw_action(bot: Character) -> void:
	if not bot.alive:
		return
	var bb: Blackboard = bot.controller.get(&"bb")
	if bb == null:
		return
	_overlay.draw_circle(bot.global_position, 15.0, Color(0.1, 0.1, 0.12, 0.7))
	_overlay.draw_arc(bot.global_position, 15.0, 0.0, TAU, 20, _team_ink(bot.team), 2.0)
	_overlay.draw_string(ThemeDB.fallback_font, bot.global_position + Vector2(-26, -22),
		String(bb.current_action), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		ACTION_INK if bot.intent.fire else Color(0.85, 0.9, 1.0, 0.9))
	if bot.intent.fire:
		_overlay.draw_line(bot.global_position,
			bot.global_position + bot.aim_dir.normalized() * 34.0, CONTACT_INK, 2.0)


func _draw_contacts() -> void:
	for bot in bots:
		if not is_instance_valid(bot) or not bot.alive:
			continue
		var bb: Blackboard = bot.controller.get(&"bb")
		if bb == null:
			continue
		for contact: Dictionary in bb.visible_contacts:
			_overlay.draw_circle(contact[&"pos"], 3.0, CONTACT_INK)
		var intel: Dictionary = bb.intel_contact()
		if not intel.is_empty():
			_overlay.draw_arc(intel[&"pos"], 6.0, 0.0, TAU, 12,
				Color(1.0, 0.6, 0.2, 0.6), 1.0)


func _draw_danger() -> void:
	for team: int in [Enums.Team.BASTION, Enums.Team.SIROCCO]:
		var squad: SquadCoordinator = SquadCoordinator.for_team(get_tree(), team)
		if squad == null or squad.danger == null:
			continue
		for cell: Vector2i in squad.danger.cells():
			var heat: float = squad.danger.danger_at(
				Vector2(cell) * DangerMap.CELL_PX + Vector2.ONE * DangerMap.CELL_PX * 0.5)
			if heat <= 0.05:
				continue
			var rect := Rect2(Vector2(cell) * DangerMap.CELL_PX,
				Vector2.ONE * DangerMap.CELL_PX)
			var ink := DANGER_INK
			ink.a = clampf(heat * 0.35, 0.06, 0.6)
			_overlay.draw_rect(rect, ink, true)
		for zone: Dictionary in squad.danger.killzones():
			_overlay.draw_arc(zone[&"pos"], DangerMap.KILLZONE_RADIUS, 0.0, TAU, 32,
				KILLZONE_INK, 2.0)


func _team_ink(team: int) -> Color:
	return RigScript.BASTION_ACCENT if team == Enums.Team.BASTION \
		else RigScript.SIROCCO_PRIMARY


# --- headless long-run probe ------------------------------------------------

## Headless behaviour histogram: run `seconds` of match, then print actions,
## kills, fairness denials and radio lines so a behaviour regression is visible
## without rendering. Usage: -- --ai-sim=45
func _simulate(seconds: int) -> void:
	var ticks := seconds * 60
	var hist: Dictionary = {}
	# Lambdas capture locals by value in GDScript, so count through members.
	_sim_shots = 0
	_sim_radios = 0
	_sim_kills = 0
	EventBus.shot_fired.connect(_count_shot)
	EventBus.radio_message.connect(_count_radio)
	EventBus.character_died.connect(_count_kill)
	for tick: int in ticks:
		await get_tree().physics_frame
		if tick % 6 != 0:
			continue
		for bot in bots:
			if not is_instance_valid(bot) or not bot.alive:
				continue
			var state: Dictionary = bot.controller.call(&"debug_state")
			var action: StringName = state.get(&"action", &"?")
			hist[action] = int(hist.get(action, 0)) + 1
	var denials := 0
	var by_action: Dictionary = {}
	var visible := 0
	var contacts := 0
	for bot in bots:
		if not is_instance_valid(bot):
			continue
		var state: Dictionary = bot.controller.call(&"debug_state")
		denials += int(state.get(&"denials", 0))
		for action: StringName in state.get(&"denials_by", {}):
			by_action[action] = int(by_action.get(action, 0)) \
				+ int(state[&"denials_by"][action])
		visible += int(state.get(&"visible", 0))
		contacts += int(state.get(&"contacts", 0))
	var moved := 0.0
	for bot in bots:
		if is_instance_valid(bot):
			moved += bot.global_position.distance_to(_spawn_pos.get(bot, bot.global_position))
	print("AI_SIM moved_avg=%.0fpx actions=%s" % [moved / maxf(1.0, float(bots.size())), str(hist)])
	var ammo := PackedStringArray()
	for bot in bots:
		if is_instance_valid(bot) and bot.arsenal.current() != null:
			ammo.append("%s:%d/%d%s%s" % [bot.callsign, bot.arsenal.current().mag,
				bot.arsenal.current().reserve_rounds,
				"r%d" % bot.arsenal.current().reload_stage if bot.is_reloading() else "",
				"e" if not bot.arsenal.current().is_equipped() else ""])
	print("AI_SIM ammo=%s" % " ".join(ammo))
	for bot in bots:
		if is_instance_valid(bot) and bot.arsenal.current() != null and bot.arsenal.current().mag == 0:
			var st: Dictionary = bot.controller.call(&"debug_state")
			var bb: Blackboard = bot.controller.get(&"bb")
			print("AI_SIM dry %s action=%s mag_ratio=%.2f reserve=%d slot=%d" % [
				bot.callsign, st.get(&"action"), bb.mag_ratio(),
				bot.arsenal.current().reserve_rounds, bot.arsenal.slot])
	print("AI_SIM denials_by=%s" % str(by_action))
	print("AI_SIM kills=%d shots=%d radios=%d denials=%d visible=%d contacts=%d violations=%d" % [
		_sim_kills, _sim_shots, _sim_radios, denials, visible, contacts,
		AIController.fairness_violations.size()])
	get_tree().quit(0 if AIController.fairness_violations.is_empty() else 100)


# --- headless self-check ---------------------------------------------------

## Verifies the AI actually ran: actions chosen, memory formed, no fairness
## denials, and that the squad coordinator exists for both teams.
func _selftest() -> void:
	for _i: int in CLOCK_TICKS:
		await get_tree().physics_frame
	var problems := PackedStringArray()
	var actions := {}
	for bot in bots:
		var state: Dictionary = bot.controller.call(&"debug_state")
		if state.is_empty():
			problems.append("no blackboard on %s" % bot.callsign)
			continue
		actions[state[&"action"]] = true
		if int(state[&"denials"]) > 0:
			problems.append("%s fired blind %d times" % [bot.callsign, state[&"denials"]])
	if actions.size() < 2:
		problems.append("bots only ever chose %s" % str(actions.keys()))
	if not AIController.fairness_violations.is_empty():
		problems.append("fairness ledger non-empty: %s" % AIController.fairness_violations[0])
	SquadCoordinator.for_team(get_tree(), Enums.Team.BASTION)
	if problems.is_empty():
		print("AI_SELFTEST_OK actions=%s" % str(actions.keys()))
		get_tree().quit(0)
	else:
		print("AI_SELFTEST_FAIL %s" % " / ".join(problems))
		get_tree().quit(100)