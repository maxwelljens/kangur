extends GdUnitTestSuite
## VisionSystem gating — the CS2D feel, asserted without rendering:
## in-cone+LOS visible, behind a wall hidden, crouched behind low cover hidden
## from a standing observer only when crouched, peripheral ring visible, ghosts
## age out, corpses persist once discovered, teammates always visible.

const CharacterScene := preload("res://src/entities/character.tscn")
const VisionSystemScript := preload("res://src/vision/vision_system.gd")
const EquipmentSystemScript := preload("res://src/combat/equipment_system.gd")
const PassiveController := preload("res://tests/unit/vision/passive_controller.gd")

const PLAYER_POS := Vector2(200.0, 400.0)
const OPEN_TARGET := Vector2(360.0, 400.0)
const BEHIND_WALL := Vector2(700.0, 400.0)
const COVER_TARGET := Vector2(420.0, 400.0)
const WALL_X := 520.0
const COVER_X := 380.0

var _vision: Node = null
var _characters: Array[Character] = []
var _player: Character = null


func before_test() -> void:
	_build_world()


func after_test() -> void:
	# Free the whole fixture before the next test builds its own physics space.
	if is_instance_valid(_vision):
		_vision.queue_free()
	for c: Character in _characters.duplicate():
		if is_instance_valid(c):
			c.queue_free()
	_characters.clear()
	await await_idle_frame()


## Player at (200,400) facing +X. A wall at x=520 (full-height) and a low-cover
## strip at x=380 covering only the southern lane (y 380..430).
func _build_world() -> void:
	_characters.clear()
	var root := Node2D.new()
	root.name = "Fixture"
	add_child(root)
	auto_free(root)
	_wall(root, Vector2(WALL_X, 400.0), Vector2(24.0, 700.0), Layers.WORLD_BIT)
	_wall(root, Vector2(COVER_X, 405.0), Vector2(24.0, 60.0), Layers.LOW_COVER_BIT)
	_player = _spawn(root, Enums.Team.BASTION, PLAYER_POS, true, &"Vuk")
	_characters.append(_player)

	_vision = VisionSystemScript.new()
	_vision.name = "Vision"
	root.add_child(_vision)
	_vision.setup(_characters, _player, null, 7, true)


func _spawn(root: Node2D, team: int, pos: Vector2, is_player: bool,
		callsign: StringName) -> Character:
	var character: Character = CharacterScene.instantiate()
	character.position = pos
	root.add_child(character)
	character.setup({
		&"team": team, &"class_id": &"vanguard", &"callsign": String(callsign),
		&"is_player": is_player, &"ai": not is_player, &"seed": hash(callsign),
		&"primary_id": &"kestrel", &"sidearm_id": &"adder",
	})
	# Swap in a passive controller so live AI/player input cannot move the fixture
	# mid-test (the vision contract is independent of who writes the Intent).
	character.controller.set_script(PassiveController)
	character.controller.call(&"setup", character)
	return character


func _wall(root: Node2D, pos: Vector2, size: Vector2, layer: int) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	root.add_child(body)


func _enemy(pos: Vector2, stance: Enums.Stance = Enums.Stance.STAND) -> Character:
	var e := _spawn(_player.get_parent() as Node2D, Enums.Team.SIROCCO, pos, false, &"Luca")
	e.stance = stance
	_characters.append(e)
	return e


## Pose the player deterministically (no controller input in headless tests).
## The Intent is set too: Character copies stance/aim from it every physics tick.
func _pose_player(aim: Vector2, stance: Enums.Stance = Enums.Stance.STAND) -> void:
	_player.aim_dir = aim.normalized()
	_player.stance = stance
	_player.intent.aim = _player.aim_dir
	_player.intent.stance = stance
	_player.perception.tick(0.0, stance, false, false)


## Physics frame first: intersect_ray is only legal inside/after physics.
## Aim/stance are posed AFTER the frame because the controller (AI/player) runs
## during _physics_process and would otherwise overwrite the fixture's intent.
func _refresh() -> void:
	await get_tree().physics_frame
	_pose_player(_player.aim_dir, _player.stance)
	_vision.refresh_now()


func test_enemy_in_cone_and_los_is_visible() -> void:
	var e := _enemy(OPEN_TARGET)
	_pose_player(Vector2.RIGHT)
	await _refresh()
	assert_bool(e.rig.visible).is_true()
	assert_bool(_vision.is_visible_to_player(e)).is_true()


func test_enemy_behind_a_wall_is_hidden() -> void:
	var e := _enemy(BEHIND_WALL)
	_pose_player(Vector2.RIGHT)
	await _refresh()
	assert_bool(e.rig.visible).is_false()


func test_enemy_outside_the_cone_angle_is_hidden() -> void:
	var e := _enemy(PLAYER_POS + Vector2(-160.0, 0.0))
	_pose_player(Vector2.RIGHT)
	await _refresh()
	assert_bool(e.rig.visible).is_false()


func test_teammates_are_always_visible() -> void:
	var mate := _spawn(_player.get_parent() as Node2D, Enums.Team.BASTION,
		PLAYER_POS + Vector2(-300.0, 0.0), false, &"Marta")
	_characters.append(mate)
	_pose_player(Vector2.RIGHT)
	await _refresh()
	assert_bool(mate.rig.visible).is_true()


func test_crouched_behind_low_cover_is_hidden_from_a_standing_observer() -> void:
	var e := _enemy(COVER_TARGET, Enums.Stance.CROUCH)
	_pose_player(Vector2.RIGHT, Enums.Stance.STAND)
	await _refresh()
	assert_bool(e.rig.visible).is_false()


func test_standing_behind_low_cover_is_visible_to_a_standing_observer() -> void:
	var e := _enemy(COVER_TARGET, Enums.Stance.STAND)
	_pose_player(Vector2.RIGHT, Enums.Stance.STAND)
	await _refresh()
	assert_bool(e.rig.visible).is_true()


func test_crouched_observer_cannot_see_over_low_cover() -> void:
	var e := _enemy(COVER_TARGET, Enums.Stance.STAND)
	_pose_player(Vector2.RIGHT, Enums.Stance.CROUCH)
	await _refresh()
	assert_bool(e.rig.visible).is_false()


func test_peripheral_ring_shows_an_enemy_behind_the_cone() -> void:
	# 60 px behind the player: outside the 100° cone, inside the 70 px ring.
	var e := _enemy(PLAYER_POS + Vector2(-60.0, 0.0))
	_pose_player(Vector2.RIGHT)
	await _refresh()
	assert_bool(e.rig.visible).is_true()


func test_peripheral_ring_still_respects_walls() -> void:
	var e := _enemy(PLAYER_POS + Vector2(-60.0, 0.0))
	# Wall at 30 px behind the player, so the ring has no line to the target.
	_wall(_player.get_parent() as Node2D, PLAYER_POS + Vector2(-30.0, 0.0),
		Vector2(8.0, 300.0), Layers.WORLD_BIT)
	_pose_player(Vector2.RIGHT)
	await _refresh()
	assert_bool(e.rig.visible).is_false()


func test_ghost_ages_out_and_target_disappears() -> void:
	var e := _enemy(OPEN_TARGET)
	_pose_player(Vector2.RIGHT)
	await _refresh()
	assert_bool(e.rig.visible).is_true()
	# Look away: the rig hides immediately, the ghost keeps the last position.
	_pose_player(Vector2.LEFT)
	await _refresh()
	assert_bool(e.rig.visible).is_false()
	assert_int(_vision._ghosts.size()).is_equal(1)
	# Advance the gate clock just past the ghost life.
	var step := 1.0 / VisionSystemScript.GATE_HZ
	for _i: int in int(ceil(VisionSystemScript.GHOST_S / step)) + 2:
		_pose_player(Vector2.LEFT)
		_vision.refresh_now()
		_vision.advance(step)
	assert_int(_vision._ghosts.size()).is_equal(0)


func test_corpse_is_hidden_until_discovered_then_persists() -> void:
	var e := _enemy(OPEN_TARGET)
	_pose_player(Vector2.RIGHT)
	await _refresh()
	assert_bool(e.rig.visible).is_true()
	e.die(null, &"")
	# Still in view: the corpse stays on screen (discovered).
	await _refresh()
	assert_bool(e.rig.visible).is_true()
	# Look away: discovered corpses remain visible (design §5).
	_pose_player(Vector2.LEFT)
	await _refresh()
	assert_bool(e.rig.visible).is_true()


func test_undiscovered_corpse_stays_hidden() -> void:
	var e := _enemy(BEHIND_WALL)
	_pose_player(Vector2.RIGHT)
	await _refresh()
	e.die(null, &"")
	await _refresh()
	assert_bool(e.rig.visible).is_false()


func test_smoke_blocks_gating_even_with_clear_los() -> void:
	var e := _enemy(OPEN_TARGET)
	_pose_player(Vector2.RIGHT)
	await _refresh()
	assert_bool(e.rig.visible).is_true()
	_vision.deploy_smoke(PLAYER_POS + Vector2(80.0, 0.0), 60.0, 5.0)
	await _refresh()
	assert_bool(e.rig.visible).is_false()


func test_smoke_expires_and_vision_returns() -> void:
	var e := _enemy(OPEN_TARGET)
	_pose_player(Vector2.RIGHT)
	_vision.deploy_smoke(PLAYER_POS + Vector2(80.0, 0.0), 60.0, 0.5)
	await _refresh()
	assert_bool(e.rig.visible).is_false()
	_vision.advance(0.6)  # expire the cloud
	await _refresh()
	assert_bool(e.rig.visible).is_true()
	assert_int(_vision.smoke_circles().size()).is_equal(0)


func test_smoke_deployed_signal_is_consumed_when_present() -> void:
	# The concurrent EquipmentSystem ships `smoke_deployed`; absent is legal.
	if not EventBus.has_signal(&"smoke_deployed"):
		return
	EventBus.emit_signal(&"smoke_deployed", PLAYER_POS, 55.0, 4.0)
	assert_int(_vision.smoke_circles().size()).is_equal(1)


## End-to-end with the real EquipmentSystem: a smoke grenade landing between the
## player and the target must blind the next vision step, and its own cloud list
## must be the one VisionSystem consults (no duplicated clouds).
func test_equipment_system_smoke_blinds_the_player() -> void:
	var e := _enemy(OPEN_TARGET)
	_pose_player(Vector2.RIGHT)
	await _refresh()
	assert_bool(e.rig.visible).is_true()

	var equipment: Node = EquipmentSystemScript.new()
	equipment.name = "Equipment"
	add_child(equipment)
	_vision.setup_equipment(equipment)
	equipment.call(&"_detonate_smoke", _smoke_def(), Vector2(200.0 + 90.0, 400.0))
	await _refresh()
	assert_bool(e.rig.visible).is_false()
	# The cloud list is the EquipmentSystem's, not a mirrored local copy.
	assert_int(equipment.call(&"smoke_clouds").size()).is_equal(1)
	assert_int(_vision.smoke_circles().size()).is_equal(1)
	equipment.queue_free()


func _smoke_def() -> EquipmentDef:
	var def := EquipmentDef.new()
	def.id = &"smoke"
	def.kind = Enums.EquipKind.SMOKE
	def.radius = 140.0
	def.vision_block_time = 12.0
	return def


func test_smoke_blocks_segment_geometry_is_inclusive() -> void:
	var cloud: Array[Dictionary] = [{&"pos": Vector2(100.0, 0.0), &"radius": 20.0}]
	assert_bool(VisionSystemScript.smoke_blocks_segment(
		Vector2.ZERO, Vector2(200.0, 0.0), cloud)).is_true()
	assert_bool(VisionSystemScript.smoke_blocks_segment(
		Vector2.ZERO, Vector2(0.0, 200.0), cloud)).is_false()
	# Endpoint inside the cloud counts (smoke on your face blinds you).
	assert_bool(VisionSystemScript.smoke_blocks_segment(
		Vector2(95.0, 0.0), Vector2(140.0, 0.0), cloud)).is_true()


func test_segment_hits_circle_edge_cases() -> void:
	assert_bool(VisionSystemScript.segment_hits_circle(
		Vector2.ZERO, Vector2(10.0, 0.0), Vector2(5.0, 5.0), 5.0)).is_true()
	assert_bool(VisionSystemScript.segment_hits_circle(
		Vector2.ZERO, Vector2(10.0, 0.0), Vector2(5.0, 5.1), 5.0)).is_false()