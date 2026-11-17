extends GdUnitTestSuite
## Controller wiring: the brain runs at 5–10 Hz (staggered), produces an Intent
## every tick, dispatches through UtilityAI, and talks to its squad. Also pins
## the anti-robot rules that are cheap to check headlessly: no conga line
## (spacing steering), check-six cadence, radio rate limit.

const CharacterScene := preload("res://src/entities/character.tscn")

var _bots: Array[Character] = []
var _radio_sink: Callable = Callable()


func after_test() -> void:
	for bot in _bots:
		if is_instance_valid(bot):
			var squad: Node = bot.controller.get(&"squad")
			if squad != null and is_instance_valid(squad):
				squad.call(&"unregister", bot.controller)
	_bots.clear()
	AIController.fairness_violations.clear()
	await await_idle_frame()


func _spawn(pos: Vector2, team: int = Enums.Team.BASTION,
		callsign: String = "Vuk", seed_value: int = 11) -> Character:
	var bot: Character = CharacterScene.instantiate()
	bot.position = pos
	add_child(bot)
	auto_free(bot)
	bot.setup({
		&"team": team, &"class_id": &"vanguard", &"callsign": callsign,
		&"is_player": false, &"ai": true, &"seed": seed_value,
		&"primary_id": &"kestrel", &"sidearm_id": &"adder",
	})
	_bots.append(bot)
	return bot


func _tick(bot: Character, count: int) -> void:
	for _i: int in count:
		bot.controller.call(&"fill_intent", bot.intent, 1.0 / 60.0)


func test_controller_builds_a_blackboard_with_a_rolled_personality() -> void:
	var bot := _spawn(Vector2(200, 200))
	var bb: Blackboard = bot.controller.get(&"bb")
	assert_object(bb).is_not_null()
	assert_object(bb.personality).is_not_null()
	assert_object(bb.memory).is_not_null()
	assert_str(bb.callsign).is_equal("Vuk")
	assert_int(bb.team).is_equal(Enums.Team.BASTION)


func test_decision_cadence_is_between_five_and_ten_hertz() -> void:
	var bot := _spawn(Vector2(200, 200))
	var period: float = bot.controller.get(&"_decision_period")
	assert_float(period).is_between(1.0 / Blackboard.DECISION_HZ_MAX,
		1.0 / Blackboard.DECISION_HZ_MIN + 0.0001)


func test_decisions_are_staggered_between_npcs() -> void:
	var a := _spawn(Vector2(200, 200), Enums.Team.BASTION, "Vuk", 1)
	var b := _spawn(Vector2(240, 200), Enums.Team.BASTION, "Marta", 2)
	var offset_a: float = a.controller.get(&"_decision_accum")
	var offset_b: float = b.controller.get(&"_decision_accum")
	assert_float(absf(offset_a - offset_b)).is_greater(0.0001) \
		.override_failure_message("NPCs must not decide on the same tick")


func test_every_tick_produces_an_intent() -> void:
	var bot := _spawn(Vector2(200, 200))
	bot.intent.move = Vector2(9, 9)
	bot.intent.fire = true
	_tick(bot, 1)
	# Held fields are rewritten, never left over from the previous consumer.
	assert_vector(bot.intent.move).is_not_equal(Vector2(9, 9))
	assert_bool(bot.intent.fire).is_false()


func test_the_brain_chooses_a_registered_action() -> void:
	var bot := _spawn(Vector2(200, 200))
	_tick(bot, 30)
	var action: StringName = bot.controller.get(&"bb").current_action
	assert_bool([&"advance", &"hold_angle", &"check_six", &"investigate",
		&"regroup", &"avoid_danger", &"use_equipment", &"reload", &"bandage",
		&"take_cover", &"peek", &"flank", &"engage", &"suppress", &"retreat",
		&"capture_objective", &"defend_objective"].has(action)).is_true() \
		.override_failure_message("unknown action '%s'" % action)


func test_same_seed_rolls_the_same_personality_and_actions() -> void:
	var a := _spawn(Vector2(200, 200), Enums.Team.BASTION, "Anouk", 77)
	var b := _spawn(Vector2(200, 200), Enums.Team.BASTION, "Anouk", 77)
	var pa: Personality = a.controller.get(&"bb").personality
	var pb: Personality = b.controller.get(&"bb").personality
	for name: StringName in Personality.TRAIT_NAMES:
		assert_float(pa.trait_value(name)).is_equal_approx(pb.trait_value(name), 0.0001)
	_tick(a, 40)
	_tick(b, 40)
	assert_str(String(a.controller.get(&"bb").current_action)).is_equal(
		String(b.controller.get(&"bb").current_action))


func test_squad_coordinator_is_shared_per_team() -> void:
	var a := _spawn(Vector2(200, 200), Enums.Team.BASTION, "Vuk", 1)
	var b := _spawn(Vector2(240, 200), Enums.Team.BASTION, "Marta", 2)
	var enemy := _spawn(Vector2(900, 200), Enums.Team.SIROCCO, "Luca", 3)
	assert_bool(a.controller.get(&"squad") == b.controller.get(&"squad")).is_true()
	assert_object(a.controller.get(&"squad")).is_not_same(enemy.controller.get(&"squad"))
	assert_bool(a.controller.get(&"bb").team_intel
		== b.controller.get(&"bb").team_intel).is_true()


func test_squad_assigns_loose_roles() -> void:
	var a := _spawn(Vector2(200, 200), Enums.Team.BASTION, "Vuk", 1)
	var b := _spawn(Vector2(240, 200), Enums.Team.BASTION, "Marta", 2)
	var c := _spawn(Vector2(280, 200), Enums.Team.BASTION, "Dries", 3)
	var squad: SquadCoordinator = a.controller.get(&"squad")
	squad.call(&"_assign_roles")
	var roles := {
		squad.call(&"role_for", a.controller): true,
		squad.call(&"role_for", b.controller): true,
		squad.call(&"role_for", c.controller): true,
	}
	assert_bool(roles.has(&"point") or roles.has(&"flank")).is_true()
	assert_bool(roles.has(&"support") or roles.has(&"flank")).is_true()


func test_spacing_steering_pushes_bots_apart() -> void:
	# A mate 8 px to our right must bend a rightward move away from them.
	var mate := _spawn(Vector2(408, 400), Enums.Team.BASTION, "Marta", 2)
	var bot := _spawn(Vector2(400, 400), Enums.Team.BASTION, "Vuk", 1)
	var squad: SquadCoordinator = bot.controller.get(&"squad")
	squad.call(&"register", mate.controller)
	squad.call(&"register", bot.controller)
	# Teammates are refreshed on the decision tick, so let a few cadences pass.
	_tick(bot, 60)
	var bb: Blackboard = bot.controller.get(&"bb")
	assert_int(bb.teammates.size()).is_greater(0)
	var probe := Intent.new()
	probe.move = Vector2.RIGHT
	bot.controller.call(&"_apply_spacing", probe)
	assert_float(probe.move.length()).is_greater(0.0)
	# Repulsion (mate to the right) must steer the heading left of RIGHT.
	assert_float(probe.move.normalized().angle_to(Vector2.RIGHT)).is_less(0.0) \
		.override_failure_message("no spacing repulsion: bots would conga")
	# Far apart: the raw move is untouched.
	var far := _spawn(Vector2(1200, 400), Enums.Team.BASTION, "Dries", 3)
	squad.call(&"register", far.controller)
	var clean := Intent.new()
	clean.move = Vector2.RIGHT
	far.controller.call(&"_apply_spacing", clean)
	assert_vector(clean.move).is_equal(Vector2.RIGHT)


func test_radio_is_rate_limited() -> void:
	var bot := _spawn(Vector2(200, 200))
	var messages: Array[String] = []
	EventBus.radio_message.connect(func(_t: int, _f: String, text: String,
			_p: int) -> void: messages.append(text))
	bot.controller.call(&"say", &"contact", 1)
	bot.controller.call(&"say", &"contact", 1)
	bot.controller.call(&"say", &"contact", 1)
	for _i: int in 60:
		bot.controller.call(&"fill_intent", bot.intent, 1.0 / 60.0)
	assert_int(messages.size()).is_equal(1).override_failure_message(
		"radio spam: %d lines inside one second" % messages.size())
	# After the throttle window the queue drains, one line per 1.5 s.
	for _i: int in 95:
		bot.controller.call(&"fill_intent", bot.intent, 1.0 / 60.0)
	assert_int(messages.size()).is_equal(2).override_failure_message(
		"second line should leave after the 1.5 s throttle")
	for _i: int in 95:
		bot.controller.call(&"fill_intent", bot.intent, 1.0 / 60.0)
	assert_int(messages.size()).is_equal(3)


func test_radio_substitutes_grid_and_callsign() -> void:
	var bot := _spawn(Vector2(200, 200))
	var lines: Array[String] = []
	EventBus.radio_message.connect(func(_t: int, from: String, text: String,
			_p: int) -> void: lines.append("%s|%s" % [from, text]))
	bot.controller.call(&"say", &"contact", 1)
	for _i: int in 10:
		bot.controller.call(&"fill_intent", bot.intent, 1.0 / 60.0)
	assert_int(lines.size()).is_equal(1)
	assert_bool(lines[0].begins_with("Vuk|")).is_true()
	assert_bool(lines[0].contains("{grid}")).is_false().override_failure_message(
		"unsubstituted placeholder leaked into radio: %s" % lines[0])


func test_danger_map_wiring_is_live_and_avoid_danger_wins_in_a_killzone() -> void:
	var bot := _spawn(Vector2(400, 400), Enums.Team.BASTION, "Vuk", 1)
	var bb: Blackboard = bot.controller.get(&"bb")
	assert_object(bb.danger_map).is_not_null().override_failure_message(
		"blackboard has no danger map: AvoidDanger can never fire")
	# Two witnessed teammate deaths right where this NPC stands.
	bb.danger_map.add_death(bot.global_position)
	bb.danger_map.add_death(bot.global_position + Vector2(30, 0))
	assert_float(bb.danger_at(bot.global_position)).is_greater(0.05)
	assert_float(bb.killzone_at(bot.global_position)).is_greater(0.0)
	_tick(bot, 60)
	assert_str(String(bb.current_action)).is_equal("avoid_danger") \
		.override_failure_message("NPC stayed in a killzone (action=%s)"
			% bb.current_action)


func test_killzone_radio_warning_is_emitted_by_the_squad() -> void:
	var spot := Vector2(1700, 1400)
	var bot := _spawn(spot, Enums.Team.BASTION, "Vuk", 1)
	var witness := _spawn(spot + Vector2(60, 0), Enums.Team.BASTION, "Marta", 2)
	var squad: SquadCoordinator = bot.controller.get(&"squad")
	var urgent: Array[String] = []
	_radio_sink = func(_t: int, from: String, text: String, priority: int) -> void:
		if priority >= 2:
			urgent.append("%s|%s" % [from, text])
	EventBus.radio_message.connect(_radio_sink)
	EventBus.character_died.emit(bot, null, &"kestrel", bot.global_position, 40.0)
	EventBus.character_died.emit(witness, null, &"kestrel",
		witness.global_position, 40.0)
	for _i: int in 140:
		bot.controller.call(&"fill_intent", bot.intent, 1.0 / 60.0)
		witness.controller.call(&"fill_intent", witness.intent, 1.0 / 60.0)
	assert_bool(squad.danger.killzones().is_empty()).is_false() \
		.override_failure_message("2 deaths in 6 s / 150 px produced no killzone")
	EventBus.radio_message.disconnect(_radio_sink)
	assert_int(urgent.size()).is_greater(0).override_failure_message(
		"killzone produced no urgent radio line")


func test_check_six_schedules_inside_the_designed_window() -> void:
	var bot := _spawn(Vector2(200, 200))
	var bb: Blackboard = bot.controller.get(&"bb")
	for _i: int in 20:
		var delay := bb.roll_check_six()
		assert_float(delay).is_between(Blackboard.CHECK_SIX_MIN_S,
			Blackboard.CHECK_SIX_MAX_S)
		var hold := bb.roll_check_six_hold()
		assert_float(hold).is_between(Blackboard.CHECK_SIX_HOLD_MIN_S,
			Blackboard.CHECK_SIX_HOLD_MAX_S)


func test_advance_goals_carry_a_personal_offset() -> void:
	var a := _spawn(Vector2(400, 400), Enums.Team.BASTION, "Vuk", 5)
	var b := _spawn(Vector2(400, 400), Enums.Team.BASTION, "Marta", 6)
	_tick(a, 40)
	_tick(b, 40)
	var ga: Blackboard = a.controller.get(&"bb")
	var gb: Blackboard = b.controller.get(&"bb")
	assert_bool(ga.has_nav_target).is_true()
	assert_bool(gb.has_nav_target).is_true()
	# Same spawn, different people: Advance plans different patrol goals.
	assert_float(ga.goal.distance_to(gb.goal)).is_greater(1.0) \
		.override_failure_message("bots share one goal: conga line")
	# And each goal is a patrol leg (260 px) plus a bounded personal offset.
	var leg := ga.goal.distance_to(ga.host_pos())
	assert_float(leg).is_between(200.0, 260.0 + Blackboard.GOAL_OFFSET_PX * 1.5 + 1.0)