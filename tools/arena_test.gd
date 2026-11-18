extends Node2D
## Test arena fixture: flat floor, wall StaticBody2Ds, one player Character and
## one dummy target. Establishes the entity contract both interactively and
## headlessly.
##
## Interactive: DISPLAY=:0 tools/godot.sh --path . tools/arena_test.tscn
## Screenshot:  tools/godot.sh --path . -- --shot=res://tools/arena_test.tscn:20:reports/screenshots/arena.png
## Self-check:  tools/godot.sh --headless --path . -- --arena-selftest
##              (prints ARENA_SELFTEST_OK or ARENA_SELFTEST_FAIL <reason>)

const CharacterScene := preload("res://src/entities/character.tscn")

const FLOOR := Color(0.30, 0.31, 0.33)
const WALL := Color(0.19, 0.20, 0.22)
const GRID := Color(0.34, 0.35, 0.37, 0.5)
const ARENA_SIZE := Vector2(1200.0, 760.0)
const GRID_STEP := 64.0
const PLAYER_START := Vector2(300.0, 380.0)
## Camera framing: the whole arena at a 1.6 zoom reads as a gameplay view.
const CAMERA_ZOOM := 1.6
const CAMERA_CENTER := Vector2(600.0, 380.0)
const DUMMY_START := Vector2(820.0, 380.0)
## Wall directly right of the player's start: the collision probe pushes into it.
const BLOCKER_POS := Vector2(520.0, 380.0)
const BLOCKER_SIZE := Vector2(28.0, 150.0)
## Ticks allowed for the AI aim pipeline and the auto trigger to work.
const AIM_TICKS := 90
const FIRE_TICKS := 120

var player: Character = null
var dummy: Character = null
var _shots: int = 0
var _hits: int = 0

func _ready() -> void:
	_build_arena()
	var selftest := OS.get_cmdline_user_args().has("--arena-selftest")
	_add_camera()
	EventBus.shot_fired.connect(func(_s: Node, _w: StringName, _o: Vector2,
			_d: Vector2, _p: int) -> void: _shots += 1)
	EventBus.character_hit.connect(func(_v: Node, _a: Node, _part: int,
			_dmg: float, _f: bool, _pos: Vector2) -> void: _hits += 1)
	player = _spawn(&"bastion", Enums.Team.BASTION, PLAYER_START, not selftest)
	dummy = _spawn(&"sirocco", Enums.Team.SIROCCO, DUMMY_START, not selftest)
	if selftest:
		await get_tree().physics_frame
		_selftest()

func _add_camera() -> void:
	var camera := Camera2D.new()
	camera.position = CAMERA_CENTER
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	add_child(camera)
	camera.make_current()

func _draw() -> void:
	draw_rect(Rect2(-40.0, -40.0, ARENA_SIZE.x + 80.0, ARENA_SIZE.y + 80.0), FLOOR, true)
	var x := 0.0
	while x <= ARENA_SIZE.x:
		draw_line(Vector2(x, 0.0), Vector2(x, ARENA_SIZE.y), GRID, 1.0, true)
		x += GRID_STEP
	var y := 0.0
	while y <= ARENA_SIZE.y:
		draw_line(Vector2(0.0, y), Vector2(ARENA_SIZE.x, y), GRID, 1.0, true)
		y += GRID_STEP

func _build_arena() -> void:
	_wall(Vector2(600.0, 90.0), Vector2(320.0, 28.0))
	_wall(Vector2(600.0, 670.0), Vector2(320.0, 28.0))
	_wall(Vector2(1080.0, 380.0), Vector2(28.0, 240.0))
	_wall(BLOCKER_POS, BLOCKER_SIZE)

## Static wall on WORLD layer: blocks movement, bullets, vision and sound.
func _wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = Layers.WORLD_BIT
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var visual := WallVisual.new()
	visual.size = size
	body.add_child(visual)
	add_child(body)

## `human` = PlayerController (cursor aim); otherwise the AI stub, which the
## headless self-test drives through its setters.
func _spawn(id: StringName, team: int, pos: Vector2, human: bool) -> Character:
	var character: Character = CharacterScene.instantiate()
	character.position = pos
	add_child(character)
	character.setup({
		&"team": team,
		&"class_id": &"vanguard",
		&"callsign": String(id).capitalize(),
		&"is_player": human,
		&"ai": not human,
		&"seed": hash(id),
		&"primary_id": &"kestrel",
		&"sidearm_id": &"adder",
	})
	return character

# --- headless contract probe ------------------------------------------------

func _selftest() -> void:
	var problem := ""
	var ai: Node = player.controller
	if not ai.has_method(&"set_fire"):
		problem = "AI controller interface missing"
	elif player.arsenal.current() == null:
		problem = "setup did not equip a primary"
	elif player.team != Enums.Team.BASTION or player.intent == null:
		problem = "identity/intent not initialised"
	else:
		ai.call(&"set_aim_target", Vector2.DOWN)
		for _i: int in AIM_TICKS:
			await get_tree().physics_frame
		if player.aim_dir.dot(Vector2.DOWN) < 0.95:
			problem = "aim did not converge on the target (dot=%.3f)" \
				% player.aim_dir.dot(Vector2.DOWN)
	if problem.is_empty():
		problem = await _check_wall_collision(ai)
	if problem.is_empty():
		problem = await _check_fire()
	if problem.is_empty():
		problem = _check_damage()
	if problem.is_empty():
		print("ARENA_SELFTEST_OK")
		get_tree().quit(0)
	else:
		print("ARENA_SELFTEST_FAIL %s" % problem)
		get_tree().quit(1)

func _check_wall_collision(ai: Node) -> String:
	ai.call(&"set_stance", Enums.Stance.STAND)
	ai.call(&"set_move_target", Vector2.RIGHT)
	for _i: int in 120:
		await get_tree().physics_frame
	ai.call(&"set_move_target", Vector2.ZERO)
	# Player radius 10 + wall half-width 14 → must stop before x = 506.
	if player.global_position.x >= 500.0:
		return "move_and_slide passed through the wall (x=%.1f)" \
			% player.global_position.x
	return ""

func _check_fire() -> String:
	var before := _shots
	var spread_before := player.spread_deg()
	ai_call_fire(true)
	for _i: int in FIRE_TICKS:
		await get_tree().physics_frame
	ai_call_fire(false)
	var spread := player.spread_deg()
	if _shots <= before:
		return "trigger produced no shot_fired"
	if player.pending_shots.is_empty() and player.arsenal.current().mag >= 30:
		return "magazine did not deplete"
	if spread < 0.0 or spread > 90.0:
		return "spread_deg out of sane range (%.2f)" % spread
	if spread_before < 0.0:
		return "spread_deg negative before firing"
	return ""

func ai_call_fire(on: bool) -> void:
	player.controller.call(&"set_fire", on)

func _check_damage() -> String:
	var before := dummy.body.part_hp(Enums.Part.TORSO)
	var hits_before := _hits
	var result := dummy.apply_hit(Enums.Part.TORSO, 30.0, 1.0, player)
	if dummy.body.part_hp(Enums.Part.TORSO) >= before:
		return "apply_hit did not reduce part HP"
	if _hits <= hits_before:
		return "character_hit was not emitted"
	if result.absorbed < 0.0 or not dummy.alive:
		return "unexpected hit result (absorbed=%.1f)" % result.absorbed
	return ""

## Simple wall quad, drawn by the wall body itself.
class WallVisual extends Node2D:
	var size: Vector2 = Vector2.ZERO

	func _draw() -> void:
		draw_rect(Rect2(-size * 0.5, size), WALL, true)
		draw_rect(Rect2(-size * 0.5, size), WALL.lightened(0.12), false, 1.0)