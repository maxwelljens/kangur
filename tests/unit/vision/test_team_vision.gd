extends GdUnitTestSuite
## TeamVision — the player's radio memory. The fairness seams:
## no instant omniscience (a report lands late), delayed positions are noisy,
## confidence fades to zero and the contact disappears, and only witnessed
## deaths leave danger hints.

const TeamVisionScript := preload("res://src/vision/team_vision.gd")

const TEAM := Enums.Team.BASTION
const SPOTTER_POS := Vector2(100.0, 100.0)
const ENEMY_POS := Vector2(400.0, 100.0)

var _vision: Node = null
var _spotter: Character = null
var _enemy: Character = null


func before_test() -> void:
	# A bot teammate does the spotting: the player's own eyes feed the fog, not
	# the radio (that rule has its own test).
	_spotter = _character(Enums.Team.BASTION, SPOTTER_POS, false, &"Marta")
	_enemy = _character(Enums.Team.SIROCCO, ENEMY_POS, false, &"Luca")
	_vision = TeamVisionScript.new()
	add_child(_vision)
	auto_free(_vision)
	_vision.setup(TEAM, [_spotter, _enemy] as Array[Character], 1234)


func after_test() -> void:
	if is_instance_valid(_spotter):
		_spotter.queue_free()
	if is_instance_valid(_enemy):
		_enemy.queue_free()
	await await_idle_frame()


func _character(team: int, pos: Vector2, is_player: bool,
		callsign: StringName) -> Character:
	var c := CharacterScene.instantiate()
	c.position = pos
	add_child(c)
	auto_free(c)
	c.setup({
		&"team": team, &"class_id": &"vanguard", &"callsign": String(callsign),
		&"is_player": is_player, &"ai": not is_player, &"seed": hash(callsign),
		&"primary_id": &"kestrel", &"sidearm_id": &"adder",
	})
	return c


const CharacterScene := preload("res://src/entities/character.tscn")


func _sighting(pos: Vector2 = ENEMY_POS) -> void:
	_spotter.perception.enemy_spotted.emit(_spotter, _enemy, pos)


func test_sighting_is_not_instant() -> void:
	_sighting()
	assert_int(_vision.shared_contacts(TEAM).size()).is_equal(0)
	assert_int(_vision.pending_reports().size()).is_equal(1)
	# Still pending before the minimum delay.
	_vision.tick(TeamVisionScript.REPORT_DELAY_MIN_S * 0.5)
	assert_int(_vision.shared_contacts(TEAM).size()).is_equal(0)


func test_contact_lands_within_the_design_delay_window() -> void:
	_sighting()
	_vision.tick(TeamVisionScript.REPORT_DELAY_MAX_S + 0.05)
	var contacts: Array[Dictionary] = _vision.shared_contacts(TEAM)
	assert_int(contacts.size()).is_equal(1)
	assert_int(int(contacts[0][&"entity_id"])).is_equal(_enemy.get_instance_id())
	assert_int(int(contacts[0][&"team"])).is_equal(TEAM)


func test_position_noise_is_bounded_and_actually_applied() -> void:
	_sighting()
	_vision.tick(TeamVisionScript.REPORT_DELAY_MAX_S + 0.05)
	var pos: Vector2 = _vision.shared_contacts(TEAM)[0][&"pos"]
	var error := pos.distance_to(ENEMY_POS)
	# Design §5: delayed AND imprecise, but never a wild leap.
	assert_float(error).is_greater(0.0)
	assert_float(error).is_less_equal(TeamVisionScript.POSITION_NOISE_PX * 2.0)


func test_confidence_fades_then_the_contact_expires() -> void:
	_sighting()
	_vision.tick(TeamVisionScript.REPORT_DELAY_MAX_S + 0.05)
	var first: Dictionary = _vision.shared_contacts(TEAM)[0]
	var ttl := float(first[&"ttl"])
	# 6–12 s window plus the spotter's Pathfinder bonus (0 here).
	assert_float(ttl).is_greater_equal(TeamVisionScript.FADE_MIN_S)
	assert_float(ttl).is_less_equal(TeamVisionScript.FADE_MAX_S)
	_vision.tick(ttl * 0.5)
	var faded: Dictionary = _vision.shared_contacts(TEAM)[0]
	assert_float(float(faded[&"confidence"])).is_less(1.0)
	assert_float(float(faded[&"confidence"])).is_greater(0.0)
	_vision.tick(ttl)
	assert_int(_vision.shared_contacts(TEAM).size()).is_equal(0)


func test_perception_refresh_does_not_stack_reports() -> void:
	# Perception re-emits a seen enemy every 0.5 s; the radio must coalesce.
	_sighting()
	_spotter.perception.enemy_spotted.emit(_spotter, _enemy, ENEMY_POS)
	assert_int(_vision.pending_reports().size()).is_equal(1)


func test_contacts_are_scoped_to_the_player_team() -> void:
	_sighting()
	_vision.tick(TeamVisionScript.REPORT_DELAY_MAX_S + 0.05)
	assert_int(_vision.shared_contacts(TEAM).size()).is_equal(1)
	assert_int(_vision.shared_contacts(Enums.Team.SIROCCO).size()).is_equal(0)


func test_player_spottings_do_not_echo_back_to_the_minimap() -> void:
	# The player's own eyes already drive the fog; a radio copy would be a noisy
	# duplicate of something they can see live.
	_spotter.is_player = true
	_sighting()
	assert_int(_vision.pending_reports().size()).is_equal(0)
	assert_int(_vision.shared_contacts(TEAM).size()).is_equal(0)


func test_pathfinder_perk_extends_contact_persistence() -> void:
	var scout := _character(Enums.Team.BASTION, SPOTTER_POS, false, &"Anouk")
	scout.setup({
		&"team": Enums.Team.BASTION, &"class_id": &"pathfinder", &"callsign": "Anouk",
		&"is_player": false, &"ai": true, &"seed": 3,
		&"primary_id": &"kestrel", &"sidearm_id": &"adder",
	})
	var fresh := TeamVisionScript.new()
	add_child(fresh)
	auto_free(fresh)
	fresh.setup(TEAM, [scout, _enemy] as Array[Character], 99)
	scout.perception.enemy_spotted.emit(scout, _enemy, ENEMY_POS)
	fresh.tick(TeamVisionScript.REPORT_DELAY_MAX_S + 0.05)
	var ttl := float(fresh.shared_contacts(TEAM)[0][&"ttl"])
	# Base TTL is 6–12 s; Pathfinder adds a flat bonus on top of it.
	assert_float(scout.spot_persist_bonus_s()).is_greater(0.0)
	assert_float(ttl).is_greater_equal(
		TeamVisionScript.FADE_MIN_S + scout.spot_persist_bonus_s())
	assert_float(ttl).is_less_equal(
		TeamVisionScript.FADE_MAX_S + scout.spot_persist_bonus_s())


func test_unseen_teammate_death_leaves_no_danger_hint() -> void:
	# Enemy 300 px behind the spotter: outside the cone, no danger mark.
	_spotter.aim_dir = Vector2.RIGHT
	_spotter.perception.tick(0.0, Enums.Stance.STAND, false, false)
	EventBus.character_died.emit(_spotter, _enemy, &"kestrel", SPOTTER_POS, 10.0)
	assert_int(_vision.danger_marks().size()).is_equal(1)
	# The spotter is the victim standing in their own cone → witnessed.
	# An enemy teammate dying out of sight must not be marked.
	var far := _character(Enums.Team.BASTION, SPOTTER_POS + Vector2(-4000.0, 0.0),
		false, &"Noor")
	EventBus.character_died.emit(far, null, &"", SPOTTER_POS + Vector2(-4000.0, 0.0), 0.0)
	assert_int(_vision.danger_marks().size()).is_equal(1)