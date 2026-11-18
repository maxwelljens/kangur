extends GdUnitTestSuite
## BattleRules: tickets, the ordered capture chain, contest pause, defender
## recapture at 2×, ticket grants, and the three win conditions.

const CAPTURE_A := 20.0
const CAPTURE_B := 24.0
const CAPTURE_C := 28.0


func _rules(tickets: int = 36) -> BattleRules:
	var rules := BattleRules.new()
	rules.setup(_defs(), tickets)
	rules.time_limit_s = 900.0
	return rules


func _defs() -> Array[Dictionary]:
	return [
		{&"id": &"a", &"order": 1, &"capture_time": CAPTURE_A, &"pos": Vector2(100, 100)},
		{&"id": &"b", &"order": 2, &"capture_time": CAPTURE_B, &"pos": Vector2(200, 100)},
		{&"id": &"c", &"order": 3, &"capture_time": CAPTURE_C, &"pos": Vector2(300, 100)},
	]


## `present` is [bastion, sirocco] living bodies in the zone.
func _snapshot(present: Array, alive: Array = [6, 6], elapsed: float = 0.0,
		deaths: Array = [0, 0], tickets: int = -1) -> MatchSnapshot:
	var snap := MatchSnapshot.new()
	snap.elapsed = elapsed
	snap.alive_per_team.assign(alive)
	snap.deaths_this_tick.assign(deaths)
	if tickets >= 0:
		snap.tickets_per_team.assign([0, tickets])
	for def: Dictionary in _defs():
		snap.objective_states.append({
			&"id": def[&"id"], &"order": def[&"order"],
			&"capture_time": def[&"capture_time"], &"pos": def[&"pos"],
			&"locked": false, &"owner": -1, &"progress": 0.0, &"contested": false,
			&"present": present if def[&"id"] == &"a" else [0, 0],
		})
	return snap


func _tick(rules: BattleRules, snap: MatchSnapshot, seconds: float) -> void:
	var steps := int(round(seconds * 60.0))
	for _i: int in steps:
		snap.elapsed += 1.0 / 60.0
		rules.tick(snap, 1.0 / 60.0)


func _event(events: Array[RuleEvent], type: StringName) -> RuleEvent:
	for event: RuleEvent in events:
		if event.type == type:
			return event
	return null


# --- chain ------------------------------------------------------------------

func test_only_the_first_objective_is_active_initially() -> void:
	var rules := _rules()
	assert_that(StringName(rules.active_objective()[&"id"])).is_equal(StringName("a"))
	assert_int(rules.last_captured_order()).is_equal(0)


func test_attackers_alone_capture_after_the_zone_capture_time() -> void:
	var rules := _rules()
	var snap := _snapshot([0, 3])
	_tick(rules, snap, CAPTURE_A + 0.5)
	assert_bool(rules.objective_rows()[0]["state"] == "owned").is_true()
	assert_int(rules.last_captured_order()).is_equal(1)
	assert_that(StringName(rules.active_objective()[&"id"])).is_equal(StringName("b"))


func test_capture_grants_eight_tickets() -> void:
	var rules := _rules(10)
	var snap := _snapshot([0, 2])
	_tick(rules, snap, CAPTURE_A + 0.5)
	assert_int(rules.tickets_left()).is_equal(10 + BattleRules.CAPTURE_TICKETS)


func test_each_attacker_death_costs_one_ticket() -> void:
	var rules := _rules(10)
	rules.tick(_snapshot([0, 0], [6, 6], 0.0, [0, 3]), 1.0 / 60.0)
	assert_int(rules.tickets_left()).is_equal(7)


func test_tickets_never_go_negative() -> void:
	var rules := _rules(2)
	rules.tick(_snapshot([0, 0], [6, 0], 0.0, [0, 5]), 1.0 / 60.0)
	assert_int(rules.tickets_left()).is_equal(0)


func test_contested_zone_pauses_capture_progress() -> void:
	var rules := _rules()
	var snap := _snapshot([0, 2])
	_tick(rules, snap, CAPTURE_A * 0.5)
	var half := _progress(rules, &"a")
	assert_float(half).is_between(0.4, 0.6)
	snap.objective_states[0][&"present"] = [2, 2]
	_tick(rules, snap, CAPTURE_A)
	assert_float(_progress(rules, &"a")).is_equal_approx(half, 0.001)


func test_defenders_recapture_a_partial_bar_at_double_speed() -> void:
	var rules := _rules()
	var snap := _snapshot([0, 2])
	_tick(rules, snap, CAPTURE_A * 0.5)
	var half := _progress(rules, &"a")
	snap.objective_states[0][&"present"] = [2, 0]
	# Half the bar at 2× speed means a quarter of the capture time.
	_tick(rules, snap, CAPTURE_A * 0.25)
	assert_float(_progress(rules, &"a")).is_between(0.0, half)
	assert_bool(_is_locked(rules, &"a")).is_false()


func test_a_lock_keeps_the_objective_even_under_defender_occupation() -> void:
	var rules := _rules()
	var snap := _snapshot([0, 2])
	_tick(rules, snap, CAPTURE_A + 0.5)
	snap.objective_states[0][&"present"] = [4, 0]
	_tick(rules, snap, CAPTURE_A * 2.0)
	assert_bool(_is_locked(rules, &"a")).is_true()
	assert_int(rules.last_captured_order()).is_equal(1)


func test_objectives_out_of_order_cannot_be_taken() -> void:
	var rules := _rules()
	var snap := _snapshot([0, 0])
	snap.objective_states[2][&"present"] = [0, 4]  # attackers sit on C
	_tick(rules, snap, CAPTURE_C + 1.0)
	assert_bool(_is_locked(rules, &"c")).is_false()


func test_final_objective_capture_wins_for_the_attackers() -> void:
	var rules := _rules()
	var snap := _snapshot([0, 2])
	_tick(rules, snap, CAPTURE_A + 0.5)
	snap.objective_states[1][&"present"] = [0, 2]
	_tick(rules, snap, CAPTURE_B + 0.5)
	snap.objective_states[2][&"present"] = [0, 2]
	_tick(rules, snap, CAPTURE_C + 0.5)
	var events := rules.tick(snap, 1.0 / 60.0)
	var end := _event(events, RuleEvent.MATCH_END)
	assert_object(end).is_not_null()
	assert_int(end.data[&"winner"]).is_equal(Enums.Team.SIROCCO)
	assert_that(end.data[&"reason"]).is_equal(StringName("objectives"))


# --- defeat / timeout -------------------------------------------------------

func test_defenders_win_when_tickets_are_spent_and_attackers_are_dead() -> void:
	var rules := _rules(1)
	var events := rules.tick(_snapshot([0, 0], [4, 0], 0.0, [0, 1]), 1.0 / 60.0)
	var end := _event(events, RuleEvent.MATCH_END)
	assert_object(end).is_not_null()
	assert_int(end.data[&"winner"]).is_equal(Enums.Team.BASTION)
	assert_that(end.data[&"reason"]).is_equal(StringName("tickets"))


func test_out_of_tickets_with_a_living_attacker_does_not_end_the_match() -> void:
	var rules := _rules(0)
	var events := rules.tick(_snapshot([0, 2], [4, 2]), 1.0 / 60.0)
	assert_object(_event(events, RuleEvent.MATCH_END)).is_null()


func test_timeout_gives_the_defenders_the_match() -> void:
	var rules := _rules()
	var snap := _snapshot([0, 2], [6, 6], rules.time_limit_s)
	var end := _event(rules.tick(snap, 1.0 / 60.0), RuleEvent.MATCH_END)
	assert_object(end).is_not_null()
	assert_int(end.data[&"winner"]).is_equal(Enums.Team.BASTION)
	assert_that(end.data[&"reason"]).is_equal(StringName("timeout"))


func test_a_live_contest_at_the_horn_gets_the_grace_window() -> void:
	var rules := _rules()
	var snap := _snapshot([2, 2], [6, 6], rules.time_limit_s)
	var events := rules.tick(snap, 1.0 / 60.0)
	assert_object(_event(events, RuleEvent.MATCH_END)).is_null()
	snap.elapsed = rules.time_limit_s + MatchRules.GRACE_S
	assert_object(_event(rules.tick(snap, 1.0 / 60.0), RuleEvent.MATCH_END)).is_not_null()


# --- waves / phase ----------------------------------------------------------

func test_attacker_wave_fires_every_six_seconds_while_tickets_remain() -> void:
	var rules := _rules()
	var out: Array[RuleEvent] = []
	var snap := _snapshot([0, 0])
	for _i: int in int(BattleRules.ATTACKER_WAVE_S * 60.0) + 1:
		snap.elapsed += 1.0 / 60.0
		for event: RuleEvent in rules.tick(snap, 1.0 / 60.0):
			if event.type == RuleEvent.SPAWN and int(event.data[&"team"]) == Enums.Team.SIROCCO:
				out.append(event)
	assert_int(out.size()).is_equal(1)


func test_no_attacker_wave_once_tickets_are_gone() -> void:
	var rules := _rules(0)
	var snap := _snapshot([0, 0])
	var attackers := 0
	for _i: int in int(BattleRules.ATTACKER_WAVE_S * 60.0) + 1:
		snap.elapsed += 1.0 / 60.0
		for event: RuleEvent in rules.tick(snap, 1.0 / 60.0):
			if event.type == RuleEvent.SPAWN and int(event.data[&"team"]) == Enums.Team.SIROCCO:
				attackers += 1
	assert_int(attackers).is_equal(0)


func test_defenders_get_a_wave_on_their_own_cadence_without_tickets() -> void:
	var rules := _rules(0)
	var snap := _snapshot([0, 0])
	var defenders := 0
	for _i: int in int(BattleRules.DEFENDER_WAVE_S * 60.0) + 1:
		snap.elapsed += 1.0 / 60.0
		for event: RuleEvent in rules.tick(snap, 1.0 / 60.0):
			if event.type == RuleEvent.SPAWN and int(event.data[&"team"]) == Enums.Team.BASTION:
				defenders += 1
	assert_int(defenders).is_equal(1)


func test_phase_event_marks_the_active_objective_and_contest() -> void:
	var rules := _rules()
	var events := rules.tick(_snapshot([2, 2]), 1.0 / 60.0)
	var phase := _event(events, RuleEvent.PHASE)
	assert_object(phase).is_not_null()
	assert_that(StringName(phase.data[&"obj_id"])).is_equal(StringName("a"))
	assert_bool(phase.data[&"contested"]).is_true()
	assert_int(phase.data[&"obj_order"]).is_equal(1)


# --- HUD rows ---------------------------------------------------------------

func test_objective_rows_expose_letter_state_and_team() -> void:
	var rules := _rules()
	var rows := rules.objective_rows()
	assert_int(rows.size()).is_equal(3)
	assert_str(rows[0]["letter"]).is_equal("A")
	assert_str(rows[0]["state"]).is_equal("active")
	assert_int(rows[0]["team"]).is_equal(Enums.Team.SIROCCO)
	assert_str(rows[1]["state"]).is_equal("locked")


# --- helpers ----------------------------------------------------------------

func _progress(rules: BattleRules, id: StringName) -> float:
	for row: Dictionary in rules.objective_rows():
		if StringName(row["id"]) == id:
			return float(row["progress"])
	return -1.0


func _is_locked(rules: BattleRules, id: StringName) -> bool:
	for row: Dictionary in rules.objective_rows():
		if StringName(row["id"]) == id:
			return String(row["state"]) == "owned"
	return false

# --- regressions from the fragility probe -----------------------------------

func test_capture_locks_on_the_exact_capture_time_not_a_tick_late() -> void:
	var rules := _rules()
	var snap := _snapshot([0, 3])
	# 24 s is not a power of two: float accumulation alone lands 3e-15 short and
	# used to need one extra tick (1441 instead of 1440).
	snap.objective_states[0][&"present"] = [0, 0]
	snap.objective_states[1][&"present"] = [0, 3]
	snap.objective_states[0][&"present"] = [0, 3]
	var ticks := int(round(CAPTURE_A * 60.0))
	for _i: int in ticks:
		snap.elapsed += 1.0 / 60.0
		rules.tick(snap, 1.0 / 60.0)
	assert_bool(_is_locked(rules, &"a")).is_true()


func test_a_capture_emits_progress_of_exactly_one() -> void:
	var rules := _rules()
	var snap := _snapshot([0, 2])
	var final_progress := -1.0
	for _i: int in int(round(CAPTURE_A * 60.0)) + 1:
		snap.elapsed += 1.0 / 60.0
		for event: RuleEvent in rules.tick(snap, 1.0 / 60.0):
			if event.type == RuleEvent.OBJECTIVE_PROGRESS \
					and StringName(event.data[&"id"]) == &"a":
				final_progress = float(event.data[&"progress"])
	assert_float(final_progress).is_equal(1.0)


func test_one_death_tick_emits_a_single_tickets_event() -> void:
	var rules := _rules(10)
	var emitted := 0
	for event: RuleEvent in rules.tick(
			_snapshot([0, 0], [6, 6], 0.0, [0, 4]), 1.0 / 60.0):
		if event.type == RuleEvent.TICKETS:
			emitted += 1
			assert_int(event.data[&"tickets"]).is_equal(6)
	assert_int(emitted).is_equal(1)
