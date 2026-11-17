extends GdUnitTestSuite
## Footsteps — cadence from speed and per-surface sample selection.


func test_stationary_is_slow_but_finite() -> void:
	assert_float(Footsteps.step_interval(0.0)).is_equal(Footsteps.MAX_INTERVAL)


func test_cadence_tightens_with_speed() -> void:
	var walk := Footsteps.step_interval(130.0)
	var sprint := Footsteps.step_interval(215.0)
	var crouch := Footsteps.step_interval(65.0)
	assert_float(sprint).is_less(walk)
	assert_float(walk).is_less(crouch)
	assert_float(walk).is_equal_approx(0.46, 0.01)


func test_cadence_stays_inside_bounds() -> void:
	for speed: float in [0.0, 1.0, 65.0, 130.0, 5000.0]:
		var interval := Footsteps.step_interval(speed)
		assert_float(interval).is_greater_equal(Footsteps.MIN_INTERVAL)
		assert_float(interval).is_less_equal(Footsteps.MAX_INTERVAL)


func test_every_surface_has_samples() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for surface: int in Footsteps.SURFACE_DIRS.size():
		assert_object(Footsteps.surface_stream(surface, rng)).override_failure_message(
			"no samples for surface %d" % surface
		).is_not_null()


func test_out_of_range_surface_does_not_crash() -> void:
	var rng := RandomNumberGenerator.new()
	assert_object(Footsteps.surface_stream(-3, rng)).is_not_null()
	assert_object(Footsteps.surface_stream(99, rng)).is_not_null()


func test_selection_is_rng_driven_but_repeatable() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 42
	b.seed = 42
	assert_object(Footsteps.surface_stream(Enums.Surface.CONCRETE, a)).is_same(
		Footsteps.surface_stream(Enums.Surface.CONCRETE, b)
	)