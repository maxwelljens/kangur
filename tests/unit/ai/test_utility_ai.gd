extends GdUnitTestSuite
## Utility scoring + selection: right action for the situation, personality
## actually changes the choice, and hysteresis stops flip-flopping (design §9.2,
## kangur-ai skill "bots jitter → hysteresis too low").

const AdvanceScript := preload("res://src/ai/behaviors/advance.gd")
const EngageScript := preload("res://src/ai/behaviors/engage.gd")
const SuppressScript := preload("res://src/ai/behaviors/suppress.gd")
const TakeCoverScript := preload("res://src/ai/behaviors/take_cover.gd")
const RetreatScript := preload("res://src/ai/behaviors/retreat.gd")
const RegroupScript := preload("res://src/ai/behaviors/regroup.gd")
const ReloadScript := preload("res://src/ai/behaviors/reload.gd")
const BandageScript := preload("res://src/ai/behaviors/bandage.gd")
const CheckSixScript := preload("res://src/ai/behaviors/check_six.gd")
const CaptureScript := preload("res://src/ai/behaviors/capture_objective.gd")
const DefendScript := preload("res://src/ai/behaviors/defend_objective.gd")

var _advance := AdvanceScript.new()
var _engage := EngageScript.new()
var _suppress := SuppressScript.new()
var _cover := TakeCoverScript.new()
var _retreat := RetreatScript.new()
var _regroup := RegroupScript.new()
var _reload := ReloadScript.new()
var _bandage := BandageScript.new()
var _check_six := CheckSixScript.new()
var _capture := CaptureScript.new()
var _defend := DefendScript.new()


## A blackboard on a real Character so every model read is genuine, but with no
## physics: hostile state is injected through memory (the legal path).
func _bb(personality_override: Dictionary = {}, host: Node2D = null) -> Blackboard:
	var node: Node2D = host if host != null else _host()
	var bb := Blackboard.new(5)
	bb.host = node
	bb.team = Enums.Team.BASTION
	bb.intent = Intent.new()
	bb.memory = MemoryModel.new(3)
	bb.personality = Personality.new()
	for trait_name: StringName in personality_override:
		bb.personality.set(trait_name, personality_override[trait_name])
	return bb

func _host() -> Node2D:
	var node := Node2D.new()
	node.set(&"alive", true)
	add_child(node)
	auto_free(node)
	# A body stand-in so hp/bleed reads resolve through the same call sites.
	var body := Node.new()
	body.name = "Body"
	body.set_script(BodyStub)
	node.add_child(body)
	return node

## Minimal Body contract: alive, hp ratio, bleed, bandages.
class BodyStub:
	extends Node
	var torso := 1.0
	var bleeding := false
	var bandages_left := 3
	func torso_ratio() -> float:
		return torso
	func is_bleeding_any() -> bool:
		return bleeding
	func try_start_bandage() -> bool:
		return bandages_left > 0
	func is_bandaging() -> bool:
		return false


## Host with an Arsenal child reporting a given mag fill — exercises mag_ratio().
func _armed_host(mag_ratio: float) -> Node2D:
	var node := _host()
	var arsenal := Node.new()
	arsenal.name = "Arsenal"
	arsenal.set_script(ArsenalStub)
	arsenal.set(&"ratio", mag_ratio)
	node.add_child(arsenal)
	return node

class ArsenalStub:
	extends Node
	var ratio := 1.0
	func current() -> Variant:
		return null
	func is_reloading() -> bool:
		return false

func _see(bb: Blackboard, pos: Vector2, id: int = 1) -> void:
	bb.memory.see(pos, id, Enums.Team.SIROCCO)
	bb.visible_contacts = [bb.memory.last_seen(id)]


func test_engage_scores_high_with_a_visible_enemy() -> void:
	var bb := _bb()
	_see(bb, bb.host_pos() + Vector2(300, 0))
	assert_float(_engage.score(bb)).is_greater(0.5)
	assert_float(_engage.score(bb)).is_greater(_advance.score(bb))


func test_engage_scores_zero_without_line_of_sight() -> void:
	var bb := _bb()
	bb.memory.see(Vector2(500, 0), 1, Enums.Team.SIROCCO)
	# A remembered contact is not a visible one.
	assert_float(_engage.score(bb)).is_equal(0.0)


func test_advance_scores_higher_when_nothing_is_known() -> void:
	var bb := _bb()
	assert_float(_advance.score(bb)).is_greater(0.2)
	assert_float(_engage.score(bb)).is_equal(0.0)
	assert_float(_retreat.score(bb)).is_less(0.0)


func test_take_cover_rises_with_danger_and_wounds() -> void:
	var calm := _bb()
	calm.memory.see(Vector2(600, 0), 1, Enums.Team.SIROCCO)
	var hurt := _bb()
	hurt.memory.see(Vector2(600, 0), 1, Enums.Team.SIROCCO)
	(hurt.body() as BodyStub).torso = 0.2
	assert_float(_cover.score(hurt)).is_greater(_cover.score(calm))


func test_retreat_triggers_on_impossible_odds() -> void:
	var bb := _bb()
	for i: int in RetreatScript.IMPOSSIBLE_ENEMIES:
		var pos := bb.host_pos() + Vector2(200 + i, 0)
		bb.memory.see(pos, i + 1, Enums.Team.SIROCCO)
		bb.visible_contacts.append(bb.memory.last_seen(i + 1))
	assert_float(_retreat.score(bb)).is_greater(0.3).override_failure_message(
		"3+ visible enemies must break contact")


func test_retreat_ignores_clean_one_on_one() -> void:
	var bb := _bb()
	_see(bb, Vector2(200, 0))
	assert_float(_retreat.score(bb)).is_less(0.2)


func test_critical_hp_against_one_enemy_retreats() -> void:
	var bb := _bb()
	_see(bb, Vector2(200, 0))
	(bb.body() as BodyStub).torso = 0.2
	assert_float(_retreat.score(bb)).is_greater(_advance.score(bb))


func test_suppress_needs_a_recent_first_hand_sighting() -> void:
	var bb := _bb()
	var silent := 0.0
	assert_float(_suppress.score(bb)).is_equal(silent)
	bb.memory.see(Vector2(400, 0), 1, Enums.Team.SIROCCO)
	bb.memory.tick(1.0)
	assert_float(_suppress.score(bb)).is_greater(0.2)
	assert_float(_suppress.score(bb)).is_greater(_advance.score(bb))


func test_suppress_fades_once_the_sighting_is_stale() -> void:
	var bb := _bb()
	bb.memory.see(Vector2(400, 0), 1, Enums.Team.SIROCCO)
	bb.memory.tick(SuppressScript.MAX_AGE_S + 0.5)
	assert_float(_suppress.score(bb)).is_equal(0.0)


func test_reload_rises_with_a_dry_mag_in_cover() -> void:
	var bb := _bb({}, _armed_host(0.05))
	bb.in_cover = true
	assert_float(_reload.score(bb)).is_greater(0.0)
	assert_float(_reload.score(bb)).is_greater(0.5)
	var calm := _bb({}, _armed_host(1.0))
	assert_float(_reload.score(calm)).is_equal(0.0)


func test_bandage_requires_bleeding_and_safety() -> void:
	var bb := _bb()
	assert_float(_bandage.score(bb)).is_equal(0.0)
	(bb.body() as BodyStub).bleeding = true
	(bb.body() as BodyStub).torso = 0.5
	assert_float(_bandage.score(bb)).is_greater(0.0)
	_see(bb, bb.host_pos() + Vector2(80, 0))
	assert_float(_bandage.score(bb)).is_equal(0.0).override_failure_message(
		"never bandage with an enemy in your face")


func test_check_six_builds_up_as_the_timer_runs_out() -> void:
	var bb := _bb({&"caution": 0.9})
	bb.check_six_timer = 5.0
	assert_float(_check_six.score(bb)).is_equal(0.0)
	bb.check_six_timer = 0.0
	assert_float(_check_six.score(bb)).is_greater(0.0)


func test_capture_and_defend_are_exclusive_per_side() -> void:
	var attack := _bb()
	attack.objective_info[&"mode"] = Enums.Mode.BATTLE
	attack.objective_info[&"obj_pos"] = Vector2(600, 400)
	attack.objective_info[&"attacking"] = true
	assert_float(_capture.score(attack)).is_greater(0.0)
	assert_float(_defend.score(attack)).is_equal(0.0)
	var defend := _bb()
	defend.objective_info[&"mode"] = Enums.Mode.BATTLE
	defend.objective_info[&"obj_pos"] = Vector2(600, 400)
	defend.objective_info[&"attacking"] = false
	assert_float(_defend.score(defend)).is_greater(0.0)
	assert_float(_capture.score(defend)).is_equal(0.0)


func test_capture_is_inert_outside_battle() -> void:
	var bb := _bb()
	assert_float(_capture.score(bb)).is_equal(0.0)
	assert_float(_defend.score(bb)).is_equal(0.0)


## Attackers must prefer taking the zone over camping a corner (sims: Battle
## never captured because HoldAngle beat CaptureObjective for every body).
func test_attackers_prefer_the_objective_over_holding_a_corner() -> void:
	var attack := _bb()
	attack.objective_info[&"mode"] = Enums.Mode.BATTLE
	attack.objective_info[&"obj_pos"] = Vector2(600, 400)
	attack.objective_info[&"attacking"] = true
	attack.objective_info[&"phase"] = &"push"
	var hold := preload("res://src/ai/behaviors/hold_angle.gd").new()
	assert_float(_capture.score(attack)).is_greater(hold.score(attack)) \
		.override_failure_message("attacker camps instead of capturing")
	# A contested zone is worth more than an idle one: bodies stop the bar.
	var calm := _capture.score(attack)
	attack.objective_info[&"obj_contested"] = true
	assert_float(_capture.score(attack)).is_greater(calm)


## Defenders must want the zone, not a patrol leg, and contention sharpens it.
func test_defenders_prefer_the_contested_objective() -> void:
	var defend := _bb()
	defend.objective_info[&"mode"] = Enums.Mode.BATTLE
	defend.objective_info[&"obj_pos"] = Vector2(600, 400)
	defend.objective_info[&"attacking"] = false
	defend.objective_info[&"phase"] = &"hold"
	var calm := _defend.score(defend)
	defend.objective_info[&"obj_contested"] = true
	assert_float(_defend.score(defend)).is_greater(calm)
	var advance := preload("res://src/ai/behaviors/advance.gd").new()
	assert_float(_defend.score(defend)).is_greater(advance.score(defend)) \
		.override_failure_message("defender wanders instead of defending")


## Battle attackers push the zone instead of farming a distant duel, and a
## fresh kill makes the objective (and the move) more attractive.
func test_battle_attacker_does_not_farm_a_long_range_duel() -> void:
	var bb := _bb()
	bb.objective_info[&"mode"] = Enums.Mode.BATTLE
	bb.objective_info[&"obj_pos"] = Vector2(700, 400)
	bb.objective_info[&"attacking"] = true
	_see(bb, bb.host_pos() + Vector2(900, 0))
	assert_float(_engage.score(bb)).is_less(
		preload("res://src/ai/behaviors/engage.gd").BASE) \
		.override_failure_message("attacker farms a long duel instead of pushing")
	# Same duel, but now the objective is right here: shooting is fine again.
	bb.objective_info[&"obj_pos"] = bb.host_pos() + Vector2(120, 0)
	assert_float(_engage.score(bb)).is_greater(0.5)
	# A kill opens a push window: the objective goes up in priority.
	bb.objective_info[&"obj_pos"] = Vector2(700, 400)
	var capture_before := _capture.score(bb)
	bb.note_kill()
	assert_bool(bb.pushing()).is_true()
	assert_float(_capture.score(bb)).is_greater(capture_before)


## --- selection --------------------------------------------------------------

func test_choose_prefers_the_visible_enemy_over_patrolling() -> void:
	var bb := _bb()
	_see(bb, bb.host_pos() + Vector2(240, 0))
	var chosen := UtilityAI.choose([UtilityAI.Action.new(&"advance", _advance.score(bb)),
		UtilityAI.Action.new(&"engage", _engage.score(bb))], bb)
	assert_str(String(chosen.id)).is_equal("engage")


func test_personality_changes_the_choice_on_identical_intel() -> void:
	# Same intel, opposite temperaments: one presses, one camps.
	var aggressive := _bb({&"aggression": 0.95, &"campiness": 0.05, &"caution": 0.1})
	var campy := _bb({&"aggression": 0.05, &"campiness": 0.95, &"caution": 0.9})
	_see(aggressive, aggressive.host_pos() + Vector2(240, 0))
	_see(campy, campy.host_pos() + Vector2(240, 0))
	var hold := preload("res://src/ai/behaviors/hold_angle.gd").new()
	assert_float(_engage.score(aggressive)).is_greater(_engage.score(campy))
	assert_float(hold.score(campy)).is_greater(hold.score(aggressive))


func test_hysteresis_keeps_the_running_action_on_a_tie() -> void:
	var bb := _bb()
	bb.current_action = &"advance"
	bb.action_time = 5.0
	var chosen := UtilityAI.choose([
		UtilityAI.Action.new(&"advance", 0.40),
		UtilityAI.Action.new(&"hold_angle", 0.40),
	], bb)
	assert_str(String(chosen.id)).is_equal("advance")


func test_hysteresis_is_beaten_by_a_clearly_better_action() -> void:
	var bb := _bb()
	bb.current_action = &"advance"
	bb.action_time = 5.0
	var chosen := UtilityAI.choose([
		UtilityAI.Action.new(&"advance", 0.40),
		UtilityAI.Action.new(&"retreat", 0.90),
	], bb)
	assert_str(String(chosen.id)).is_equal("retreat")


func test_a_just_entered_action_gets_a_bigger_hold() -> void:
	var bb := _bb()
	bb.current_action = &"advance"
	bb.action_time = 0.0
	var chosen := UtilityAI.choose([
		UtilityAI.Action.new(&"advance", 0.41),
		UtilityAI.Action.new(&"hold_angle", 0.42),
	], bb)
	assert_str(String(chosen.id)).is_equal("advance")


func test_doctrine_weights_shift_the_winner() -> void:
	var bb := _bb()
	bb.doctrine = {&"hold_angle": 3.0}
	var chosen := UtilityAI.choose([
		UtilityAI.Action.new(&"advance", 0.5),
		UtilityAI.Action.new(&"hold_angle", 0.4),
	], bb)
	assert_str(String(chosen.id)).is_equal("hold_angle")


func test_choose_is_deterministic() -> void:
	var bb := _bb()
	var a := UtilityAI.choose([UtilityAI.Action.new(&"advance", 0.3),
		UtilityAI.Action.new(&"hold_angle", 0.31)], bb)
	var b := UtilityAI.choose([UtilityAI.Action.new(&"advance", 0.3),
		UtilityAI.Action.new(&"hold_angle", 0.31)], bb)
	assert_str(String(a.id)).is_equal(String(b.id))