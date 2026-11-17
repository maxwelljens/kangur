extends GdUnitTestSuite
## ShotProvenance — the fairness ledger (tests/simulation/README.md).
## Docs assert: every NPC kill had LOS or a prior sighting, and no damage
## through a non-penetrable wall. These tests pin the record the sim reads.

const ProvenanceScript := preload("res://src/vision/shot_provenance.gd")
const CharacterScene := preload("res://src/entities/character.tscn")

const SHOOTER_POS := Vector2(100.0, 100.0)
const TARGET_POS := Vector2(400.0, 100.0)
const WALL_X := 250.0

var _prov: Node = null
var _shooter: Character = null
var _target: Character = null
var _fixture: Node2D = null


func before_test() -> void:
	_fixture = Node2D.new()
	add_child(_fixture)
	auto_free(_fixture)
	_shooter = _character(Enums.Team.SIROCCO, SHOOTER_POS, &"Luca")
	_target = _character(Enums.Team.BASTION, TARGET_POS, &"Vuk")
	_prov = ProvenanceScript.new()
	add_child(_prov)
	auto_free(_prov)
	_prov.setup([_shooter, _target] as Array[Character], null,
		Callable(self, "_no_smoke"))
	_prov.enabled = true


func after_test() -> void:
	await await_idle_frame()


func _no_smoke(_from: Vector2, _to: Vector2) -> bool:
	return false


func _character(team: int, pos: Vector2, callsign: StringName) -> Character:
	var c: Character = CharacterScene.instantiate()
	c.position = pos
	_fixture.add_child(c)
	c.setup({
		&"team": team, &"class_id": &"vanguard", &"callsign": String(callsign),
		&"is_player": false, &"ai": true, &"seed": hash(callsign),
		&"primary_id": &"kestrel", &"sidearm_id": &"adder",
	})
	return c


func _wall(layer: int = Layers.WORLD_BIT) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(WALL_X, 100.0)
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16.0, 300.0)
	shape.shape = rect
	body.add_child(shape)
	_fixture.add_child(body)


## Aim at the target and let Perception settle on a physics frame.
func _aim_and_see() -> void:
	_shooter.aim_dir = (TARGET_POS - SHOOTER_POS).normalized()
	_shooter.stance = Enums.Stance.STAND
	_shooter.perception.tick(0.0, Enums.Stance.STAND, false, false)
	_target.stance = Enums.Stance.STAND


func _fire() -> Dictionary:
	EventBus.shot_fired.emit(_shooter, &"kestrel", SHOOTER_POS, Vector2.RIGHT, 1)
	return _prov.provenance_log.back()


func test_clear_los_shot_is_recorded_with_los() -> void:
	_aim_and_see()
	await get_tree().physics_frame
	var entry := _fire()
	assert_bool(entry[&"had_los_at_fire"]).is_true()
	assert_int(int(entry[&"target_id"])).is_equal(_target.get_instance_id())
	assert_int(int(entry[&"shooter_id"])).is_equal(_shooter.get_instance_id())
	assert_str(String(entry[&"weapon_id"])).is_equal("kestrel")
	assert_float(float(entry[&"prior_sighting_age"])).is_greater_equal(0.0)
	assert_bool(entry[&"suppressing"]).is_false()
	assert_bool(entry[&"wall_penetrated"]).is_false()


func test_shot_through_a_wall_has_no_los_and_reports_the_wall() -> void:
	_wall(Layers.WORLD_BIT)
	_aim_and_see()
	await get_tree().physics_frame
	var entry := _fire()
	assert_bool(entry[&"had_los_at_fire"]).is_false()
	assert_float(float(entry[&"prior_sighting_age"])).is_less(0.0)
	# No sighting ever, so this is a blind shot the sim must flag.
	assert_bool(entry[&"suppressing"]).is_false()
	assert_bool(entry[&"wall_penetrated"]).is_true()
	assert_bool(entry[&"pen_surface_penetrable"]).is_false()


func test_prior_sighting_makes_a_suppressing_shot_legitimate() -> void:
	# Target is behind a wall (no fresh LOS), but was confirmed a moment ago:
	# firing at that memory is suppression, which is allowed and marked.
	_wall(Layers.WORLD_BIT)
	_aim_and_see()
	await get_tree().physics_frame
	_prov.note_sighting(_shooter.get_instance_id(), _target.get_instance_id())
	_prov.tick(0.5)
	var entry := _fire()
	assert_bool(entry[&"had_los_at_fire"]).is_false()
	assert_float(float(entry[&"prior_sighting_age"])).is_greater(0.0)
	assert_bool(entry[&"suppressing"]).is_true()


func test_player_shots_are_not_audited() -> void:
	_shooter.is_player = true
	_aim_and_see()
	await get_tree().physics_frame
	EventBus.shot_fired.emit(_shooter, &"kestrel", SHOOTER_POS, Vector2.RIGHT, 1)
	assert_int(_prov.provenance_log.size()).is_equal(0)


func test_provenance_is_disabled_when_stripped() -> void:
	_prov.enabled = false
	_aim_and_see()
	await get_tree().physics_frame
	EventBus.shot_fired.emit(_shooter, &"kestrel", SHOOTER_POS, Vector2.RIGHT, 1)
	assert_int(_prov.provenance_log.size()).is_equal(0)


func test_sighting_age_uses_sim_time_not_wall_clock() -> void:
	_prov.note_sighting(_shooter.get_instance_id(), _target.get_instance_id())
	_prov.tick(1.5)
	assert_float(_prov.age_of_sighting(_shooter.get_instance_id(),
		_target.get_instance_id())).is_equal_approx(1.5, 0.001)
	assert_float(_prov.age_of_sighting(1, 2)).is_equal(-1.0)


func test_log_is_capped() -> void:
	_aim_and_see()
	await get_tree().physics_frame
	for _i: int in ProvenanceScript.MAX_LOG + 5:
		_prov._record(_shooter, _target, &"kestrel", true, 0.0, false, false, false)
	assert_int(_prov.provenance_log.size()).is_equal(ProvenanceScript.MAX_LOG)