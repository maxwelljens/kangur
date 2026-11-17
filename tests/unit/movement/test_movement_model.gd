extends GdUnitTestSuite
## MovementModel — Source friction/accel, stances, stamina, cripple scaling.
## Numbers: docs/design/game-design.md §3, docs/research/genre-mechanics.md §2.3.

const DT := 1.0 / 60.0

func _model() -> MovementModel:
	return MovementModel.new()

func _intent(move_dir: Vector2 = Vector2.RIGHT, sprint: bool = false,
		stance: Enums.Stance = Enums.Stance.STAND, focus: bool = false) -> Intent:
	var intent := Intent.new()
	intent.move = move_dir
	intent.sprint = sprint
	intent.stance = stance
	intent.focus = focus
	return intent

## Runs `seconds` of ticks and returns the model.
func _run(model: MovementModel, intent: Intent, seconds: float) -> MovementModel:
	var ticks := int(seconds / DT)
	for _i: int in ticks:
		model.tick(intent, DT)
	return model


func test_terminal_speed_walk() -> void:
	var m := _run(_model(), _intent(), 2.0)
	assert_float(m.current_speed()).is_equal_approx(130.0, 0.5)


func test_terminal_speed_sprint() -> void:
	var m := _run(_model(), _intent(Vector2.RIGHT, true), 2.0)
	assert_float(m.current_speed()).is_equal_approx(215.0, 0.5)


func test_terminal_speed_crouch() -> void:
	var m := _run(_model(), _intent(Vector2.RIGHT, false, Enums.Stance.CROUCH), 2.0)
	assert_float(m.current_speed()).is_equal_approx(65.0, 0.5)


func test_terminal_speed_focus_is_half_walk() -> void:
	var m := _run(_model(), _intent(Vector2.RIGHT, false, Enums.Stance.STAND, true), 2.0)
	assert_float(m.current_speed()).is_equal_approx(65.0, 0.5)


func test_terminal_speed_focus_crouch() -> void:
	var m := _run(_model(), _intent(Vector2.RIGHT, false, Enums.Stance.CROUCH, true), 2.0)
	assert_float(m.current_speed()).is_equal_approx(32.5, 0.5)


func test_crippled_speed_mult_applies_to_terminal() -> void:
	var m := _model()
	m.speed_mult = 0.55
	_run(m, _intent(), 2.0)
	assert_float(m.current_speed()).is_equal_approx(71.5, 0.5)


func test_terminal_speed_never_exceeds_stance_max() -> void:
	var m := _run(_model(), _intent(), 10.0)
	assert_float(m.current_speed()).is_less_equal(130.0 + 0.01)


func test_accel_reaches_90_percent_within_015s() -> void:
	# Research §2.3: walk t→90% = 0.20 s at 240 Hz; at 60 Hz still ~0.2 s.
	var m := _run(_model(), _intent(), 0.20)
	assert_float(m.current_speed()).is_greater_equal(115.0)


func test_accel_is_rate_based_not_constant() -> void:
	# Sprint accelerates harder than walk (accel ∝ wishspeed).
	var walk := _run(_model(), _intent(), 0.05)
	var sprint := _run(_model(), _intent(Vector2.RIGHT, true), 0.05)
	assert_float(sprint.current_speed()).is_greater(walk.current_speed())


func test_acceleration_never_overshoots_target() -> void:
	var m := _model()
	var intent := _intent()
	for _i: int in 120:
		m.tick(intent, DT)
		assert_float(m.current_speed()).is_less_equal(130.001)


func test_friction_stops_from_walk_quickly() -> void:
	var m := _run(_model(), _intent(), 1.0)
	var idle := _intent(Vector2.ZERO)
	_run(m, idle, 0.35)
	assert_float(m.current_speed()).is_less(1.0)


func test_friction_stop_distance_under_half_meter() -> void:
	var m := _run(_model(), _intent(), 1.0)
	var idle := _intent(Vector2.ZERO)
	var dist := 0.0
	for _i: int in 120:
		m.tick(idle, DT)
		dist += m.velocity.length() * DT
	# Research §2.3: ~0.33 m = 10.6 px from walk.
	assert_float(dist).is_less(20.0)


func test_stop_speed_floor_prevents_infinite_tail() -> void:
	# control = max(speed, 60) → last stretch decelerates linearly, not asymptotically.
	var m := _model()
	m.velocity = Vector2(59.0, 0.0)
	var idle := _intent(Vector2.ZERO)
	m.tick(idle, DT)
	assert_float(m.velocity.length()).is_less(59.0)


func test_counter_strafe_stops_faster_than_coasting() -> void:
	var coasting := _run(_model(), _intent(), 1.0)
	coasting.tick(_intent(Vector2.ZERO), DT)
	var counter := _run(_model(), _intent(), 1.0)
	counter.tick(_intent(Vector2.LEFT), DT)
	assert_float(counter.current_speed()).is_less(coasting.current_speed())


func test_reversal_crosses_zero_within_100ms() -> void:
	var m := _run(_model(), _intent(), 1.0)
	var back := _intent(Vector2.LEFT)
	var crossed := false
	for _i: int in 6:
		m.tick(back, DT)
		if m.velocity.x < 0.0:
			crossed = true
	assert_bool(crossed).is_true()


func test_diagonal_input_is_not_faster() -> void:
	var straight := _run(_model(), _intent(Vector2.RIGHT), 2.0)
	var diagonal := _run(_model(), _intent(Vector2(1.0, 1.0)), 2.0)
	assert_float(diagonal.current_speed()).is_equal_approx(straight.current_speed(), 0.5)


func test_analog_input_scales_speed() -> void:
	var m := _run(_model(), _intent(Vector2(0.5, 0.0)), 2.0)
	assert_float(m.current_speed()).is_equal_approx(65.0, 1.0)


func test_zero_move_keeps_velocity_direction_while_coasting() -> void:
	var m := _run(_model(), _intent(Vector2(1.0, 1.0)), 1.0)
	var heading := m.velocity.normalized()
	_run(m, _intent(Vector2.ZERO), 0.05)
	assert_vector(m.velocity.normalized()).is_equal_approx(heading, Vector2(0.001, 0.001))


func test_sprint_requires_intent_sprint() -> void:
	var m := _run(_model(), _intent(Vector2.RIGHT, false), 2.0)
	assert_bool(m.sprinting).is_false()


func test_sprint_refused_while_crouched() -> void:
	var m := _run(_model(), _intent(Vector2.RIGHT, true, Enums.Stance.CROUCH), 1.0)
	assert_bool(m.sprinting).is_false()
	assert_float(m.current_speed()).is_less_equal(65.0 + 0.5)


func test_sprint_refused_without_move_input() -> void:
	var m := _model()
	m.tick(_intent(Vector2.ZERO, true), DT)
	assert_bool(m.sprinting).is_false()


func test_sprint_refused_when_can_sprint_false() -> void:
	var m := _model()
	m.can_sprint = false
	_run(m, _intent(Vector2.RIGHT, true), 1.0)
	assert_bool(m.sprinting).is_false()
	assert_float(m.current_speed()).is_less_equal(130.5)


func test_stamina_drains_18_per_second_while_sprinting() -> void:
	var m := _run(_model(), _intent(Vector2.RIGHT, true), 1.0)
	assert_float(m.stamina).is_equal_approx(82.0, 0.6)


func test_stamina_does_not_drain_while_walking() -> void:
	var m := _run(_model(), _intent(Vector2.RIGHT, false), 1.0)
	assert_float(m.stamina).is_equal_approx(100.0, 0.01)


func test_stamina_regen_waits_one_second() -> void:
	var m := _model()
	m.stamina = 50.0
	_run(m, _intent(Vector2.ZERO), 0.9)
	assert_float(m.stamina).is_equal_approx(50.0, 0.01)
	_run(m, _intent(Vector2.ZERO), 1.1)
	assert_float(m.stamina).is_greater(50.0)


func test_stamina_regens_12_per_second_after_delay() -> void:
	var m := _model()
	m.stamina = 40.0
	_run(m, _intent(Vector2.ZERO), 2.0)   # 1 s delay + 1 s regen
	assert_float(m.stamina).is_equal_approx(52.0, 1.0)


func test_stamina_caps_at_100() -> void:
	var m := _model()
	_run(m, _intent(Vector2.ZERO), 30.0)
	assert_float(m.stamina).is_equal(100.0)


func test_exhaustion_triggers_at_zero_stamina() -> void:
	var m := _model()
	m.stamina = 0.5
	_run(m, _intent(Vector2.RIGHT, true), 0.1)
	assert_bool(m.exhausted).is_true()


func test_exhausted_forces_walk_even_when_sprinting() -> void:
	var m := _model()
	m.stamina = 1.0
	_run(m, _intent(Vector2.RIGHT, true), 0.5)
	assert_bool(m.sprinting).is_false()
	assert_float(m.current_speed()).is_less_equal(130.5)


func test_exhaustion_lockout_lifts_at_30_stamina() -> void:
	var m := _model()
	m.stamina = 0.0
	m.exhausted = true
	# 1 s rest delay + enough regen to reach 30 at 12/s → ~3.5 s total.
	_run(m, _intent(Vector2.ZERO), 3.0)
	assert_float(m.stamina).is_less(30.0)
	assert_bool(m.exhausted).is_true()
	_run(m, _intent(Vector2.ZERO), 0.8)
	assert_bool(m.exhausted).is_false()


func test_exhausted_flag_does_not_clear_early() -> void:
	var m := _model()
	m.stamina = 0.0
	m.exhausted = true
	_run(m, _intent(Vector2.ZERO), 3.4)
	assert_bool(m.exhausted).is_true()


func test_sprint_resumes_after_recovery() -> void:
	var m := _model()
	m.stamina = 0.0
	m.exhausted = true
	_run(m, _intent(Vector2.ZERO), 4.0)
	_run(m, _intent(Vector2.RIGHT, true), 0.5)
	assert_bool(m.sprinting).is_true()


func test_eating_a_sprint_cycle_returns_stamina_when_stopped() -> void:
	var m := _run(_model(), _intent(Vector2.RIGHT, true), 2.0)
	var drained := m.stamina
	_run(m, _intent(Vector2.ZERO), 3.0)
	assert_float(m.stamina).is_greater(drained)


func test_stance_getter_tracks_intent() -> void:
	var m := _model()
	m.tick(_intent(Vector2.ZERO, false, Enums.Stance.CROUCH), DT)
	assert_int(m.stance).is_equal(Enums.Stance.CROUCH)


func test_stamina_ratio_is_zero_to_one() -> void:
	var m := _model()
	assert_float(m.stamina_ratio()).is_equal(1.0)
	_run(m, _intent(Vector2.RIGHT, true), 5.5)
	assert_float(m.stamina_ratio()).is_between(0.0, 1.0)


func test_zero_dt_is_a_noop() -> void:
	var m := _model()
	m.velocity = Vector2(100.0, 0.0)
	m.tick(_intent(), 0.0)
	assert_vector(m.velocity).is_equal(Vector2(100.0, 0.0))


func test_negative_dt_is_a_noop() -> void:
	var m := _model()
	m.velocity = Vector2(50.0, 0.0)
	m.tick(_intent(), -0.1)
	assert_vector(m.velocity).is_equal(Vector2(50.0, 0.0))


func test_target_speed_reports_stance_max() -> void:
	var m := _model()
	assert_float(m.target_speed(_intent())).is_equal_approx(130.0, 0.01)
	assert_float(m.target_speed(_intent(Vector2.RIGHT, true))).is_equal_approx(215.0, 0.01)
	var crouch := m.target_speed(_intent(Vector2.RIGHT, false, Enums.Stance.CROUCH))
	assert_float(crouch).is_equal_approx(65.0, 0.01)