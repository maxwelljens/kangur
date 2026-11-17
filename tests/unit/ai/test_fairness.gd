extends GdUnitTestSuite
## THE fairness suite. An NPC may only fire with a first-hand perception
## provenance: LOS at fire (fresh sighting) or a Suppress on a personally seen
## contact. Radio, hearing and "I remember a shape" must never pull the trigger.
## Drives the real AIController against a real Character with a mocked
## Perception so no physics frame is needed.

const CharacterScene := preload("res://src/entities/character.tscn")


func after_test() -> void:
	AIController.fairness_violations.clear()


## A Character with a stubbed Perception: `sees` bypasses the raycast but emits
## the exact same `enemy_spotted` payload the real node emits. This is the only
## legal knowledge ingress, so it exercises the true code path.
func _spawn(callsign: String = "Vuk", sees: bool = true,
		class_id: StringName = &"vanguard",
		team: int = Enums.Team.BASTION) -> Character:
	var character: Character = CharacterScene.instantiate()
	add_child(character)
	auto_free(character)
	character.position = Vector2(400, 400)
	character.setup({
		&"team": team, &"class_id": class_id,
		&"callsign": callsign, &"is_player": false, &"ai": true,
		&"seed": 4242, &"primary_id": &"kestrel", &"sidearm_id": &"adder",
	})
	var stub: Node = character.get_node(^"Perception")
	stub.set_script(PerceptionStub)
	stub.set(&"sees", sees)
	stub.call(&"setup", character)
	return character


func _tick(character: Character, ticks: int = 1) -> void:
	for _i: int in ticks:
		character.controller.call(&"fill_intent", character.intent, 1.0 / 60.0)


## Stand-in for Perception: same signals/API, controllable truth.
class PerceptionStub:
	extends Node
	signal enemy_spotted(spotter: Node, enemy: Node, pos: Vector2)
	signal heard(pos: Vector2, loudness: float, kind: StringName, surface: int)
	var sees: bool = true
	var cone_angle_deg: float = 100.0
	var cone_range: float = 520.0
	var stance: Enums.Stance = Enums.Stance.STAND
	var focused: bool = false
	var sprinting: bool = false
	func setup(_host: Node) -> void:
		pass
	func tick(_dt: float, _s: Enums.Stance, _f: bool, _sp: bool) -> void:
		pass
	func can_see(_pos: Vector2, _stance: Enums.Stance) -> bool:
		return sees
	func in_cone(_pos: Vector2) -> bool:
		return sees
	func has_los(_pos: Vector2, _stance: Enums.Stance) -> bool:
		return sees


## Fire the sighting payload exactly as Perception would.
func _spot(spotter: Character, enemy_pos: Vector2) -> void:
	var perception: Node = spotter.get_node(^"Perception")
	var target := Node2D.new()
	target.set(&"team", Enums.Team.SIROCCO)
	target.set(&"alive", true)
	target.position = enemy_pos
	add_child(target)
	auto_free(target)
	perception.enemy_spotted.emit(spotter, target, enemy_pos)


func test_a_fresh_sighting_justifies_fire() -> void:
	var bot := _spawn()
	_spot(bot, bot.global_position + Vector2(300, 0))
	_tick(bot, 4)
	assert_bool(bot.intent.fire or bot.controller.call(&"_justified_fire")).is_true()


func test_no_sighting_blocks_every_trigger_pull() -> void:
	var bot := _spawn()
	# Radio knowledge alone: the team saw an enemy, we did not.
	var squad: SquadCoordinator = bot.controller.get(&"squad")
	squad.intel.report_sighting(777, Vector2(900, 400), Enums.Team.SIROCCO)
	squad.intel.tick(TeamIntel.DELAY_MAX_S + 0.01)
	assert_bool(squad.intel.knows(777)).is_true()
	_tick(bot, 30)
	assert_bool(bot.intent.fire).is_false().override_failure_message(
		"NPC fired on radio knowledge alone — wallhack")


func test_hearing_never_justifies_fire() -> void:
	var bot := _spawn()
	bot.perception.heard.emit(Vector2(700, 400), 300.0, &"gunshot", Enums.Surface.CONCRETE)
	_tick(bot, 30)
	assert_bool(bot.intent.fire).is_false().override_failure_message(
		"NPC fired at a sound — no provenance")


func test_stale_sighting_expires_the_fire_justification() -> void:
	var bot := _spawn()
	_spot(bot, bot.global_position + Vector2(400, 0))
	_tick(bot, 2)
	assert_bool(bot.controller.call(&"_justified_fire")).is_true()
	# Let the contact age past the suppress window without any new sighting.
	bot.controller.get(&"bb").memory.tick(AIController.SUPPRESS_WINDOW_S + 0.5)
	assert_bool(bot.controller.call(&"_justified_fire")).is_false()


func test_fresh_sighting_of_someone_else_does_not_license_the_shot() -> void:
	# Two contacts: A is fresh, but the NPC is aiming at a forgotten B. Firing at
	# where B *was* must still be denied — provenance is per entity, not per NPC.
	var bot := _spawn()
	var bb: Blackboard = bot.controller.get(&"bb")
	bb.memory.see(bot.global_position + Vector2(300, 0), 1111, Enums.Team.SIROCCO)
	bot.controller.set(&"_aim_key", 2222)
	assert_bool(bot.controller.call(&"_justified_fire")).is_false() \
		.override_failure_message("fresh contact A licensed a shot at unknown B")
	bot.controller.set(&"_aim_key", 1111)
	assert_bool(bot.controller.call(&"_justified_fire")).is_true()


func test_justified_fire_is_false_with_an_empty_memory() -> void:
	var bot := _spawn()
	assert_bool(bot.controller.call(&"_justified_fire")).is_false()


func test_debug_guard_flags_visible_contacts_without_memory() -> void:
	var bot := _spawn()
	var bb: Blackboard = bot.controller.get(&"bb")
	# Forge a "visible" contact that never entered memory: the guard must catch it.
	bb.visible_contacts = [{&"id": 999, &"pos": Vector2(10, 10)}]
	bot.controller.call(&"_audit_fairness")
	assert_bool(AIController.fairness_violations.is_empty()).is_false()
	assert_str(AIController.fairness_violations[-1]).contains("without memory")


func test_simulation_reads_no_enemy_node_positions() -> void:
	# Structural guard: the AI source must not touch enemy nodes. Only the
	# sighting handler may receive one, and it copies pos/id then drops it.
	var source := FileAccess.get_file_as_string("res://src/ai/ai_controller.gd")
	assert_bool(source.contains("enemy.global_position")).is_false() \
		.override_failure_message("AI reads an enemy's live position")
	assert_bool(source.contains("get_nodes_in_group(&\"characters\")")).is_false() \
		.override_failure_message("AI enumerates enemy characters directly")
	# The sighting handler is the one legal consumer of the spy node.
	assert_bool(source.contains("func _on_enemy_spotted")).is_true()


func test_suppression_raises_aim_error_only_while_under_fire() -> void:
	var bot := _spawn()
	_spot(bot, bot.global_position + Vector2(300, 0))
	_tick(bot, 2)
	var aim: Node = bot.get_node(^"Aim")
	var base: float = aim.get(&"error_floor_deg")
	var shooter := _spawn("Bulwark", false, &"bulwark", Enums.Team.SIROCCO)
	assert_float(shooter.suppression_error_deg()).is_greater(0.0)
	EventBus.shot_fired.emit(shooter, &"mule", shooter.global_position,
		Vector2.LEFT, 1)
	EventBus.bullet_impact.emit(bot.global_position + Vector2(30, 0),
		Vector2.LEFT, Enums.Surface.CONCRETE, false)
	bot.controller.call(&"_tick_suppression", 0.0)
	var suppressed: float = aim.get(&"error_floor_deg")
	assert_float(suppressed).is_greater(base).override_failure_message(
		"Bulwark suppression never reached the Aim pipeline")


func test_suppression_wears_off() -> void:
	var bot := _spawn()
	_spot(bot, bot.global_position + Vector2(300, 0))
	_tick(bot, 2)
	var aim: Node = bot.get_node(^"Aim")
	var base: float = aim.get(&"error_floor_deg")
	bot.controller.set(&"_suppress_deg", 1.5)
	bot.controller.set(&"_suppress_left", 0.05)
	bot.controller.call(&"_tick_suppression", 0.0)
	assert_float(aim.get(&"error_floor_deg")).is_greater(base)
	bot.controller.call(&"_tick_suppression", 1.0)
	assert_float(aim.get(&"error_floor_deg")).is_equal_approx(base, 0.0001)
