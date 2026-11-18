extends GdUnitTestSuite
## MatchRules: the pure elimination ladder (wipe, timeout, HP tie-break, draw).

const RULES_LIMIT := 60.0

func _snapshot(alive_bastion: int, alive_sirocco: int, elapsed: float = 0.0,
		hp_bastion: float = 80.0, hp_sirocco: float = 80.0) -> MatchSnapshot:
	var snap := MatchSnapshot.new()
	snap.elapsed = elapsed
	snap.alive_per_team.assign([alive_bastion, alive_sirocco])
	snap.total_hp_per_team.assign([hp_bastion, hp_sirocco])
	return snap


func _rules() -> EliminationRules:
	var rules := EliminationRules.new()
	rules.time_limit_s = RULES_LIMIT
	return rules


func test_no_event_while_both_teams_have_lives() -> void:
	var events := _rules().tick(_snapshot(3, 4), 1.0 / 60.0)
	assert_array(events).is_empty()


func test_wipe_ends_the_match_for_the_surviving_team() -> void:
	var events := _rules().tick(_snapshot(0, 2), 0.016)
	assert_int(events.size()).is_equal(1)
	assert_that(events[0].type).is_equal(RuleEvent.MATCH_END)
	assert_int(events[0].data[&"winner"]).is_equal(Enums.Team.SIROCCO)
	assert_that(events[0].data[&"reason"]).is_equal(StringName("elimination"))


func test_mutual_wipe_is_a_draw_not_a_win() -> void:
	var events := _rules().tick(_snapshot(0, 0), 0.016)
	assert_int(events[0].data[&"winner"]).is_equal(-1)
	assert_that(events[0].data[&"reason"]).is_equal(StringName("elimination"))


func test_timeout_awards_the_team_with_more_survivors() -> void:
	var events := _rules().tick(_snapshot(2, 5, RULES_LIMIT), 0.016)
	assert_int(events[0].data[&"winner"]).is_equal(Enums.Team.SIROCCO)
	assert_that(events[0].data[&"reason"]).is_equal(StringName("timeout"))


func test_timeout_tie_breaks_on_summed_torso_hp() -> void:
	var events := _rules().tick(_snapshot(3, 3, RULES_LIMIT, 190.0, 120.0), 0.016)
	assert_int(events[0].data[&"winner"]).is_equal(Enums.Team.BASTION)


func test_timeout_with_equal_survivors_and_hp_is_a_draw() -> void:
	var events := _rules().tick(_snapshot(2, 2, RULES_LIMIT, 150.0, 150.0), 0.016)
	assert_int(events[0].data[&"winner"]).is_equal(-1)
	assert_that(events[0].data[&"reason"]).is_equal(StringName("timeout"))


func test_timeout_only_fires_at_the_limit_not_before() -> void:
	assert_array(_rules().tick(_snapshot(2, 2, RULES_LIMIT - 0.5), 0.016)).is_empty()
	assert_array(_rules().tick(_snapshot(2, 2, RULES_LIMIT), 0.016)).is_not_empty()


func test_elimination_has_no_objective_chain() -> void:
	assert_array(_rules().objective_rows()).is_empty()
	assert_int(_rules().attacker_team()).is_equal(-1)