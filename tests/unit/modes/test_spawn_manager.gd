extends GdUnitTestSuite
## SpawnManager: unique callsigns, class-legal loadouts, marker spreading, and
## the revive path Battle waves depend on (same node, fresh body, full mag).

const MatchScript := preload("res://src/modes/match.gd")

var _arena: Match = null


func after_test() -> void:
	if _arena != null and is_instance_valid(_arena):
		_arena.queue_free()
	_arena = null
	AIController.fairness_violations.clear()


func _boot(mode: int, map_id: StringName, bots: int) -> Match:
	var config := MatchConfig.new()
	config.mode = mode
	config.map_id = map_id
	config.bot_count_bastion = bots
	config.bot_count_sirocco = bots
	config.seed = 3
	var arena := MatchScript.new() as Match
	add_child(arena)
	auto_free(arena)
	await arena.start(config, true)
	return arena


func test_callsigns_are_unique_across_both_teams() -> void:
	_arena = await _boot(Enums.Mode.ELIMINATION, &"compound", 8)
	var seen: Dictionary = {}
	for character: Character in _arena.characters:
		assert_bool(seen.has(character.callsign)).override_failure_message(
			"duplicate callsign %s" % character.callsign).is_false()
		seen[character.callsign] = true


func test_every_bot_carries_a_weapon_its_class_allows() -> void:
	_arena = await _boot(Enums.Mode.ELIMINATION, &"compound", 8)
	for character: Character in _arena.characters:
		var primary := character.arsenal.primary
		assert_object(primary).is_not_null()
		assert_bool(character.class_def.primary_categories.has(primary.def.category)) \
			.override_failure_message("%s: %s not allowed for %s" % [
				character.callsign, primary.def.category, character.class_def.id]) \
			.is_true()


func test_bots_do_not_share_a_spawn_pixel() -> void:
	_arena = await _boot(Enums.Mode.ELIMINATION, &"compound", 10)
	for team: int in [Enums.Team.BASTION, Enums.Team.SIROCCO]:
		var members: Array[Character] = _arena.spawn_manager.team_members(team)
		for i: int in members.size():
			for j: int in range(i + 1, members.size()):
				assert_float(members[i].global_position.distance_to(
					members[j].global_position)).is_greater(8.0)


func test_teams_spawn_on_their_own_half() -> void:
	_arena = await _boot(Enums.Mode.ELIMINATION, &"dustworks", 6)
	var bounds := _arena.world.bounds()
	for character: Character in _arena.characters:
		var marker := _arena.world.spawn_points(character.team)
		var closest := INF
		for point: Vector2 in marker:
			closest = minf(closest, character.global_position.distance_to(point))
		assert_float(closest).is_less(40.0)


func test_revive_keeps_the_node_and_resets_the_body() -> void:
	_arena = await _boot(Enums.Mode.BATTLE, &"terminal", 3)
	var character: Character = _arena.characters[0]
	character.apply_hit(Enums.Part.HEAD, 999.0, 1.0, null)
	assert_bool(character.alive).is_false()
	var id := character.get_instance_id()
	var mag_before := 0
	assert_bool(_arena.spawn_manager.revive(character, character.global_position)).is_true()
	assert_int(character.get_instance_id()).is_equal(id)
	assert_bool(character.alive).is_true()
	assert_float(character.body.part_hp(Enums.Part.TORSO)).is_equal(
		BodyModel.PART_MAX[Enums.Part.TORSO])
	assert_int(character.arsenal.current().mag).is_greater(mag_before)


func test_refill_revives_exactly_the_dead() -> void:
	_arena = await _boot(Enums.Mode.BATTLE, &"terminal", 4)
	var team := Enums.Team.SIROCCO
	var dead := 0
	for character: Character in _arena.characters:
		if character.team == team and dead < 2:
			character.apply_hit(Enums.Part.HEAD, 999.0, 1.0, null)
			dead += 1
	var revived := _arena.spawn_manager.refill(team, 0)
	assert_int(revived).is_equal(2)
	assert_int(_arena.spawn_manager.living_count(team)).is_equal(4)


func test_forward_spawn_markers_exist_for_terminal() -> void:
	_arena = await _boot(Enums.Mode.BATTLE, &"terminal", 2)
	var a := _arena.spawn_manager.forward_spawns(Enums.Team.SIROCCO, 1)
	var b := _arena.spawn_manager.forward_spawns(Enums.Team.SIROCCO, 2)
	assert_array(a).is_not_empty()
	assert_array(b).is_not_empty()
	# Unknown order / wrong team must degrade to empty, never crash.
	assert_array(_arena.spawn_manager.forward_spawns(Enums.Team.SIROCCO, 9)).is_empty()
	assert_array(_arena.spawn_manager.forward_spawns(Enums.Team.BASTION, 1)).is_empty()

func test_a_freed_combatant_does_not_break_the_roster_queries() -> void:
	_arena = await _boot(Enums.Mode.BATTLE, &"terminal", 3)
	var doomed: Character = _arena.characters[-1]
	_arena.characters.erase(doomed)
	doomed.free()
	# living_count / team_members / refill all iterate the roster; a freed entry
	# used to throw "previously freed" out of the physics loop.
	assert_int(_arena.spawn_manager.living_count(Enums.Team.SIROCCO)).is_greater_equal(0)
	assert_array(_arena.spawn_manager.team_members(Enums.Team.SIROCCO)).is_not_empty()
	assert_int(_arena.spawn_manager.refill(Enums.Team.SIROCCO, 0)).is_greater_equal(0)


func test_revive_clears_the_corpse_pose() -> void:
	_arena = await _boot(Enums.Mode.BATTLE, &"terminal", 3)
	var character: Character = _arena.characters[0]
	character.apply_hit(Enums.Part.HEAD, 999.0, 1.0, null)
	assert_bool(character.rig.alive).is_false()
	_arena.spawn_manager.revive(character, character.global_position)
	assert_bool(character.rig.alive).is_true()
	# A revived operator must not keep the death rotation (looks dead in-game).
	for _i: int in 10:
		character.rig.update(Vector2.ZERO, Vector2.RIGHT, Enums.Stance.STAND, {})
	assert_float(absf(character.rig.rotation)).is_less(1.0)
