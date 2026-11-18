extends GdUnitTestSuite
## RulesRunner: snapshot construction from live characters, objective occupancy
## (living bodies only, not corpses), and event application. Uses the real
## Dustworks map, so the navigation bake and ObjectiveZones are the authored
## ones — a rules runner that only works on a fake tree is worthless.

const MatchScript := preload("res://src/modes/match.gd")

var _arena: Match = null


func after_test() -> void:
	if _arena != null and is_instance_valid(_arena):
		_arena.queue_free()
	_arena = null
	AIController.fairness_violations.clear()


func _boot(mode: int, map_id: StringName, bots: int = 2) -> Match:
	var config := MatchConfig.new()
	config.mode = mode
	config.map_id = map_id
	config.bot_count_bastion = bots
	config.bot_count_sirocco = bots
	config.seed = 11
	var arena := MatchScript.new() as Match
	add_child(arena)
	auto_free(arena)
	await arena.start(config, true)
	return arena


func test_headless_match_spawns_the_whole_roster() -> void:
	var arena := await _boot(Enums.Mode.ELIMINATION, &"dustworks", 2)
	assert_int(arena.characters.size()).is_equal(4)
	assert_object(arena.player).is_null()
	for character: Character in arena.characters:
		assert_bool(character.is_player).is_false()
		assert_object(character.body.model).is_not_null()


func test_snapshot_counts_living_characters_and_torso_hp() -> void:
	var arena := await _boot(Enums.Mode.ELIMINATION, &"dustworks", 2)
	arena.rules_runner.tick(1.0 / 60.0)
	var snap := arena.rules_runner.snapshot
	assert_int(snap.alive(Enums.Team.BASTION)).is_equal(2)
	assert_int(snap.alive(Enums.Team.SIROCCO)).is_equal(2)
	assert_float(snap.total_hp(Enums.Team.BASTION)).is_greater(0.0)


func test_snapshot_reports_deaths_since_the_previous_tick() -> void:
	var arena := await _boot(Enums.Mode.ELIMINATION, &"dustworks", 2)
	arena.rules_runner.tick(1.0 / 60.0)
	var victim := arena.characters[0]
	victim.die(null)
	arena.rules_runner.tick(1.0 / 60.0)
	assert_int(arena.rules_runner.snapshot.deaths_this_tick[Enums.Team.BASTION]) \
		.is_equal(1)


func test_a_corpse_in_the_zone_does_not_capture() -> void:
	var arena := await _boot(Enums.Mode.BATTLE, &"terminal", 2)
	var zone := arena.world.objective(&"a")
	assert_object(zone).is_not_null()
	var rect := zone.capture_rect()
	var attacker := _first_of_team(arena, Enums.Team.SIROCCO)
	var defender := _first_of_team(arena, Enums.Team.BASTION)
	attacker.global_position = rect.get_center()
	defender.global_position = rect.get_center() + Vector2(40.0, 0.0)
	attacker.die(null)
	# Tick once so the snapshot sees the corpse, then read the zone state: the
	# attacker must count zero even though the Area2D body is still registered.
	arena.rules_runner.tick(1.0 / 60.0)
	var state := arena.rules_runner.snapshot.objective(&"a")
	var present: Array = state[&"present"]
	assert_int(int(present[Enums.Team.SIROCCO])).is_equal(0)
	assert_int(int(present[Enums.Team.BASTION])).is_equal(1)


func test_battle_rows_expose_the_chain_and_tickets() -> void:
	var arena := await _boot(Enums.Mode.BATTLE, &"terminal", 2)
	arena.rules_runner.tick(1.0 / 60.0)
	var rows := arena.rules_runner.objective_rows
	assert_int(rows.size()).is_equal(3)
	assert_str(rows[0]["letter"]).is_equal("A")
	# HUD-normalised positions only (0..1), never raw world pixels.
	var pos: Vector2 = rows[0]["pos"]
	assert_float(pos.x).is_between(0.0, 1.0)
	assert_float(pos.y).is_between(0.0, 1.0)


func test_tickets_start_at_the_config_value() -> void:
	var arena := await _boot(Enums.Mode.BATTLE, &"terminal", 2)
	assert_bool(arena.rules is BattleRules).is_true()
	assert_int((arena.rules as BattleRules).tickets_left()).is_equal(MatchConfig.new().attacker_tickets)


func test_match_ends_when_one_team_is_wiped() -> void:
	var arena := await _boot(Enums.Mode.ELIMINATION, &"dustworks", 2)
	for character: Character in arena.characters:
		if character.team == Enums.Team.SIROCCO:
			character.die(null)
	arena.rules_runner.tick(1.0 / 60.0)
	assert_bool(arena.rules_runner.is_finished()).is_true()
	assert_int(arena.result.winner).is_equal(Enums.Team.BASTION)
	assert_that(arena.result.reason).is_equal(&"elimination")


func test_result_rows_carry_stats_for_every_character() -> void:
	var arena := await _boot(Enums.Mode.ELIMINATION, &"dustworks", 2)
	arena.force_finish(Enums.Team.BASTION, &"verification")
	assert_int(arena.result.characters.size()).is_equal(arena.characters.size())
	for row: Dictionary in arena.result.characters:
		assert_bool(row.has("callsign")).is_true()
		assert_bool(row.has("kills")).is_true()
		assert_bool(row.has("survived")).is_true()


func test_sim_rules_tick_is_idempotent_after_the_end() -> void:
	var arena := await _boot(Enums.Mode.ELIMINATION, &"dustworks", 2)
	arena.force_finish(Enums.Team.BASTION, &"verification")
	var duration := arena.result.duration_s
	for _i: int in 30:
		arena.sim_tick(1.0 / 60.0)
	assert_float(arena.result.duration_s).is_equal_approx(duration, 0.0001)


# --- helpers ----------------------------------------------------------------

func _first_of_team(arena: Match, team: int) -> Character:
	for character: Character in arena.characters:
		if character.team == team:
			return character
	return null


func _tick_for(arena: Match, seconds: float) -> Array[RuleEvent]:
	var out: Array[RuleEvent] = []
	var sink := func(event: RuleEvent) -> void: out.append(event)
	arena.rules_runner.rule_event.connect(sink)
	for _i: int in int(seconds * 60.0):
		arena.rules_runner.tick(1.0 / 60.0)
	arena.rules_runner.rule_event.disconnect(sink)
	return out

func test_an_unshaped_zone_has_no_occupants() -> void:
	var arena := await _boot(Enums.Mode.BATTLE, &"terminal", 2)
	# A zone with no Rectangle collision shape reports a zero-size rect. It must
	# count nobody (not everybody): otherwise it captures from across the map.
	var zone := arena.world.objective(&"a")
	var shape := zone.get_node_or_null(^"CollisionShape2D")
	assert_object(shape).is_not_null()
	shape.queue_free()
	await get_tree().process_frame
	arena.rules_runner.tick(1.0 / 60.0)
	var state := arena.rules_runner.snapshot.objective(&"a")
	var present: Array = state[&"present"]
	assert_int(int(present[0])).is_equal(0)
	assert_int(int(present[1])).is_equal(0)
