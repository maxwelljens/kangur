extends Node2D
## Vision screenshot fixture (design §5 visual check).
##   DISPLAY=:0 tools/godot.sh --path . -- --shot=res://tools/shot_vision.tscn:30:reports/screenshots/vision_fog.png
##
## Uses a real map (dustworks) at a hand-picked open spot: the player faces east
## with an enemy in the open cone, another behind a wall, a third on low cover
## (crouched → hidden), and a teammate behind. The point of the shot is the fog:
## dark outside the cone, dim explored ring where the player has looked, enemies
## gated exactly as Perception says, and the minimap panel on the right.

const CharacterScene := preload("res://src/entities/character.tscn")
const VisionSystemScript := preload("res://src/vision/vision_system.gd")
const TeamVisionScript := preload("res://src/vision/team_vision.gd")
const MinimapScript := preload("res://src/vision/minimap.gd")
const PassiveController := preload("res://tests/unit/vision/passive_controller.gd")

## From tools/_probe: open depot floor with a wall 328 px east and low cover
## just south-east (maps/dustworks/map.tscn).
const PLAYER_POS := Vector2(192.0, 352.0)
const CONE_ENEMY := Vector2(372.0, 352.0)
const WALL_ENEMY := Vector2(592.0, 352.0)
## Behind the crate block (x 256–352, y 396–492): crouched → hidden by §5.
const COVER_ENEMY := Vector2(320.0, 528.0)
const PERIPHERAL_ENEMY := Vector2(192.0, 306.0)
const TEAMMATE := Vector2(132.0, 412.0)
const CAMERA_ZOOM := 1.5

var vision: VisionSystem = null
var minimap: Control = null
var _characters: Array[Character] = []
var _player: Character = null


func _ready() -> void:
	var world := World.new()
	world.map_scene_path = "res://maps/dustworks/map.tscn"
	add_child(world)

	_player = _spawn(Enums.Team.BASTION, PLAYER_POS, true, &"Vuk")
	_add_enemies()

	vision = VisionSystemScript.new()
	vision.name = "VisionSystem"
	add_child(vision)
	vision.setup(_characters, _player, world, 20261117, true)

	_camera()
	_build_minimap(world)
	_face_east()
	await _warm_up()
	_pose_scene()


## The rig only draws through the character's own _physics_process; pose the
## intent so the aim is stable for the shot (no mouse in a fixture).
func _face_east() -> void:
	_player.aim_dir = Vector2.RIGHT
	_player.intent.aim = Vector2.RIGHT


func _add_enemies() -> void:
	var open := _spawn(Enums.Team.SIROCCO, CONE_ENEMY, false, &"Luca")
	open.aim_dir = Vector2.LEFT
	open.intent.aim = Vector2.LEFT
	var walled := _spawn(Enums.Team.SIROCCO, WALL_ENEMY, false, &"Elena")
	walled.aim_dir = Vector2.LEFT
	walled.intent.aim = Vector2.LEFT
	# Crouched behind low cover: must NOT render even though it is in the cone.
	var covered := _spawn(Enums.Team.SIROCCO, COVER_ENEMY, false, &"Rui")
	covered.intent.stance = Enums.Stance.CROUCH
	covered.aim_dir = Vector2.LEFT
	covered.intent.aim = Vector2.LEFT
	# Peripheral ring: 46 px north, outside the 100° cone but inside 70 px.
	_spawn(Enums.Team.SIROCCO, PERIPHERAL_ENEMY, false, &"Ines")
	# Teammate: always visible, shows the ally blip on the minimap.
	var mate := _spawn(Enums.Team.BASTION, TEAMMATE, false, &"Marta")
	mate.aim_dir = Vector2.RIGHT
	mate.intent.aim = Vector2.RIGHT


func _spawn(team: int, pos: Vector2, is_player: bool, callsign: StringName) -> Character:
	var c: Character = CharacterScene.instantiate()
	c.position = pos
	add_child(c)
	c.setup({
		&"team": team, &"class_id": &"vanguard", &"callsign": String(callsign),
		&"is_player": is_player, &"ai": not is_player, &"seed": hash(callsign),
		&"primary_id": &"kestrel", &"sidearm_id": &"adder",
	})
	# A shot fixture has no mouse: a passive controller keeps the pose we set
	# instead of the PlayerController steering the aim at the screen corner.
	c.controller.set_script(PassiveController)
	c.controller.call(&"setup", c)
	_characters.append(c)
	return c


func _camera() -> void:
	var camera := Camera2D.new()
	camera.position = PLAYER_POS + Vector2(140.0, 10.0)
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	add_child(camera)
	camera.make_current()


func _build_minimap(world: World) -> void:
	# HUD layer: must sit above the fog (layer 1) and not be darkened by it.
	var hud := CanvasLayer.new()
	hud.name = "HudLayer"
	hud.layer = 10
	add_child(hud)
	minimap = MinimapScript.new()
	minimap.name = "Minimap"
	minimap.size = Vector2(260.0, 208.0)
	minimap.position = Vector2(1600.0 - 260.0 - 24.0, 24.0)
	hud.add_child(minimap)
	minimap.theme = load("res://src/ui/kangur_theme.tres")
	minimap.bind(world, _characters, _player, vision.team_vision, vision)
	minimap.show_grid = true


## Let perception scan (12 Hz) so enemy_spotted radio reports go out, then land
## them: the minimap must show delayed contacts, not live omniscience.
func _warm_up() -> void:
	for _i: int in 40:
		await get_tree().physics_frame
	vision.team_vision.tick(TeamVisionScript.REPORT_DELAY_MAX_S + 0.1)
	minimap.refresh()
	# Evidence for the shot: which rigs the gate left visible, and how many radio
	# contacts landed on the minimap. Written next to the PNG by the caller.
	var state := report_state()
	print("SHOT_VISION_STATE gating=%s contacts=%d" % [
		str(state), vision.team_vision.shared_contacts(_player.team).size()])
	var cost: Dictionary = await measure_cost(30)
	print("SHOT_VISION_COST %s" % str(cost))


func _pose_scene() -> void:
	# A smoke cloud east of the player, past the open enemy: the cone polygon and
	# the fog mask both stop at it (both teams blinded).
	vision.deploy_smoke(PLAYER_POS + Vector2(260.0, -40.0), 46.0, 30.0)
	vision.refresh_now()


## Assertions printed for the harness log; the PNG is the real check.
func report_state() -> Dictionary:
	var state := {}
	for c: Character in _characters:
		state[String(c.callsign)] = c.rig.visible
	return state


## Physics cost of one vision step (cone fan + gating). Time spent only inside
## refresh_now(), never the frame wait — that would measure the vsync, not us.
func measure_cost(frames: int = 60) -> Dictionary:
	if vision == null:
		return {}
	var total := 0
	for _i: int in frames:
		await get_tree().physics_frame
		var start := Time.get_ticks_usec()
		vision.refresh_now()
		total += Time.get_ticks_usec() - start
	return {
		&"frames": frames,
		&"ms_per_step": float(total) / 1000.0 / float(frames),
		&"cone_rays": vision.CONE_RAY_COUNT + 1,
		&"disc_rays": vision.DISC_RAY_COUNT + 1,
		&"rate_hz": vision.GATE_HZ,
	}