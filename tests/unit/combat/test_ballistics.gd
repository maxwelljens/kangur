extends GdUnitTestSuite
## Ballistics — spread cone, bloom, recoil, falloff, penetration, determinism.
## Formula: docs/design/game-design.md §6; docs/research/genre-mechanics.md §7.3.

const VMAX := 215.0   # sprint speed: the movement-penalty reference


func _rng(seed_value: int = 12345) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _spread(vel: float = 0.0, bloom: float = 0.0, stance: int = Enums.Stance.STAND,
		focus: bool = false, arm: float = 1.0) -> float:
	return Ballistics.spread_deg(1.0, bloom, vel, VMAX, stance, focus, arm)


func test_spread_at_rest_equals_base_plus_bloom() -> void:
	assert_float(_spread(0.0, 0.0)).is_equal_approx(1.0, 0.0001)
	assert_float(_spread(0.0, 2.0)).is_equal_approx(3.0, 0.0001)


func test_spread_is_monotonic_in_velocity() -> void:
	var last := -1.0
	for v: int in [0, 20, 50, 100, 150, 200, 215]:
		var spread := _spread(float(v))
		assert_float(spread).is_greater_equal(last)
		last = spread


func test_spread_at_full_speed_is_quadruple_base() -> void:
	# 1 + 3.0·1^1.5 = 4.0
	assert_float(_spread(VMAX)).is_equal_approx(4.0, 0.0001)


func test_spread_at_half_speed_matches_curve() -> void:
	# 1 + 3.0·0.5^1.5 = 1 + 3·0.353553 = 2.060660
	assert_float(_spread(VMAX * 0.5)).is_equal_approx(2.060660, 0.0001)


func test_spread_velocity_is_clamped_above_vmax() -> void:
	# Overspeed (knockback, water) must not blow the cone past the sprint value.
	assert_float(_spread(VMAX * 3.0)).is_equal_approx(_spread(VMAX), 0.0001)


func test_spread_zero_vmax_is_safe() -> void:
	var spread := Ballistics.spread_deg(1.0, 0.0, 100.0, 0.0, Enums.Stance.STAND, false, 1.0)
	assert_float(spread).is_equal_approx(1.0, 0.0001)


func test_crouch_multiplies_spread_by_075() -> void:
	assert_float(_spread(0.0, 0.0, Enums.Stance.CROUCH)).is_equal_approx(0.75, 0.0001)


func test_focus_multiplies_spread_by_055() -> void:
	assert_float(_spread(0.0, 0.0, Enums.Stance.STAND, true)).is_equal_approx(0.55, 0.0001)


func test_crouch_and_focus_stack() -> void:
	assert_float(_spread(0.0, 0.0, Enums.Stance.CROUCH, true)).is_equal_approx(0.4125, 0.0001)


func test_crippled_arm_multiplies_spread_by_16() -> void:
	assert_float(_spread(0.0, 0.0, Enums.Stance.STAND, false, 1.6)).is_equal_approx(1.6, 0.0001)


func test_arm_multiplier_composes_with_stance_and_focus() -> void:
	# 1.0 × 0.75 × 0.55 × 1.6 = 0.66
	assert_float(_spread(0.0, 0.0, Enums.Stance.CROUCH, true, 1.6)).is_equal_approx(0.66, 0.0001)


func test_spread_scales_linearly_with_bloom() -> void:
	var a := _spread(0.0, 1.0)
	var b := _spread(0.0, 2.0)
	assert_float(b - a).is_equal_approx(1.0, 0.0001)


func test_spread_never_negative() -> void:
	assert_float(_spread(0.0, 0.0)).is_greater_equal(0.0)


func test_sample_dir_is_normalized() -> void:
	var dir := Ballistics.sample_dir(_rng(), Vector2.RIGHT, 3.0)
	assert_float(dir.length()).is_equal_approx(1.0, 0.0001)


func test_sample_dir_zero_spread_is_exact_aim() -> void:
	var dir := Ballistics.sample_dir(_rng(), Vector2(0.0, 1.0), 0.0)
	assert_vector(dir).is_equal_approx(Vector2(0.0, 1.0), Vector2(0.0001, 0.0001))


func test_sample_dir_stays_inside_cone() -> void:
	var rng := _rng(7)
	var aim := Vector2.RIGHT
	for _i: int in 500:
		var dir := Ballistics.sample_dir(rng, aim, 5.0)
		var angle := rad_to_deg(absf(aim.angle_to(dir)))
		assert_float(angle).is_less_equal(5.001)


func test_sample_dir_covers_both_sides_of_the_cone() -> void:
	var rng := _rng(99)
	var positive := false
	var negative := false
	for _i: int in 200:
		var dir := Ballistics.sample_dir(rng, Vector2.RIGHT, 10.0)
		if dir.y > 0.0:
			positive = true
		elif dir.y < 0.0:
			negative = true
	assert_bool(positive and negative).is_true()


func test_sample_dir_handles_zero_aim() -> void:
	assert_vector(Ballistics.sample_dir(_rng(), Vector2.ZERO, 0.0)).is_equal(Vector2.RIGHT)


func test_sample_dir_is_deterministic_for_a_seed() -> void:
	var a := Ballistics.sample_dir(_rng(42), Vector2.RIGHT, 4.0)
	var b := Ballistics.sample_dir(_rng(42), Vector2.RIGHT, 4.0)
	assert_vector(a).is_equal(b)


func test_sample_dir_differs_across_seeds() -> void:
	var a := Ballistics.sample_dir(_rng(1), Vector2.RIGHT, 6.0)
	var b := Ballistics.sample_dir(_rng(2), Vector2.RIGHT, 6.0)
	assert_vector(a).is_not_equal(b)


func test_bloom_add_accumulates() -> void:
	assert_float(Ballistics.bloom_add(0.0, 0.35, 6.0)).is_equal_approx(0.35, 0.0001)
	assert_float(Ballistics.bloom_add(0.35, 0.35, 6.0)).is_equal_approx(0.70, 0.0001)


func test_bloom_add_caps_at_max() -> void:
	assert_float(Ballistics.bloom_add(5.9, 0.5, 6.0)).is_equal(6.0)


func test_bloom_add_with_zero_per_shot_is_flat() -> void:
	assert_float(Ballistics.bloom_add(2.0, 0.0, 6.0)).is_equal(2.0)


func test_bloom_decay_is_exponential() -> void:
	# rate 4/s, dt 0.25 s → e^-1 ≈ 0.3679
	assert_float(Ballistics.bloom_decay(4.0, 0.25, 4.0)).is_equal_approx(1.4715, 0.001)


func test_bloom_decay_recovers_95_percent_in_three_over_rate() -> void:
	assert_float(Ballistics.bloom_decay(6.0, 0.75, 4.0)).is_less(0.4)


func test_bloom_decay_snaps_to_zero_below_epsilon() -> void:
	assert_float(Ballistics.bloom_decay(0.005, 0.016, 4.0)).is_equal(0.0)


func test_bloom_decay_from_zero_is_zero() -> void:
	assert_float(Ballistics.bloom_decay(0.0, 1.0, 4.0)).is_equal(0.0)


func test_bloom_decay_zero_rate_holds() -> void:
	assert_float(Ballistics.bloom_decay(3.0, 0.1, 0.0)).is_equal_approx(3.0, 0.0001)


func test_bloom_decay_is_monotonic() -> void:
	var bloom := 6.0
	for _i: int in 20:
		var next := Ballistics.bloom_decay(bloom, 0.05, 4.0)
		assert_float(next).is_less_equal(bloom)
		bloom = next


func test_recoil_kick_moves_aim() -> void:
	var offset := Ballistics.recoil_kick(Vector2.RIGHT, _rng(), 1.4)
	assert_float(offset.length()).is_greater(0.0)


func test_recoil_kick_is_deterministic() -> void:
	var a := Ballistics.recoil_kick(Vector2.RIGHT, _rng(5), 1.4)
	var b := Ballistics.recoil_kick(Vector2.RIGHT, _rng(5), 1.4)
	assert_vector(a).is_equal(b)


func test_recoil_kick_zero_kick_is_zero_offset() -> void:
	assert_vector(Ballistics.recoil_kick(Vector2.RIGHT, _rng(), 0.0)).is_equal(Vector2.ZERO)


func test_recoil_kick_magnitude_tracks_kick_deg() -> void:
	var small := Ballistics.recoil_kick(Vector2.RIGHT, _rng(3), 0.5).length()
	var large := Ballistics.recoil_kick(Vector2.RIGHT, _rng(3), 2.0).length()
	assert_float(large).is_greater(small)


func test_recoil_recovery_shrinks_offset() -> void:
	var recovered := Ballistics.recoil_recover(Vector2(0.1, 0.0), 0.1, 3.5)
	assert_float(recovered.length()).is_less(0.1)


func test_recoil_recovery_reaches_negligible_after_one_second() -> void:
	var recovered := Ballistics.recoil_recover(Vector2(1.0, 0.0), 1.0, 3.5)
	assert_float(recovered.length()).is_less(0.1)


func test_recoil_recovery_zero_offset_is_zero() -> void:
	assert_vector(Ballistics.recoil_recover(Vector2.ZERO, 0.1, 3.5)).is_equal(Vector2.ZERO)


func test_falloff_inside_start_is_full_damage() -> void:
	assert_float(Ballistics.falloff(30.0, 100.0, 500.0, 1400.0, 0.6)).is_equal(30.0)


func test_falloff_at_start_is_full_damage() -> void:
	assert_float(Ballistics.falloff(30.0, 500.0, 500.0, 1400.0, 0.6)).is_equal(30.0)


func test_falloff_midpoint_is_linear() -> void:
	assert_float(Ballistics.falloff(30.0, 950.0, 500.0, 1400.0, 0.6)).is_equal_approx(24.0, 0.001)


func test_falloff_at_end_is_min_mult() -> void:
	assert_float(Ballistics.falloff(30.0, 1400.0, 500.0, 1400.0, 0.6)).is_equal_approx(18.0, 0.001)


func test_falloff_beyond_end_clamps() -> void:
	assert_float(Ballistics.falloff(30.0, 9999.0, 500.0, 1400.0, 0.6)).is_equal_approx(18.0, 0.001)


func test_falloff_never_below_min_mult() -> void:
	for d: int in [0, 400, 500, 900, 1400, 5000]:
		var dmg := Ballistics.falloff(30.0, float(d), 500.0, 1400.0, 0.6)
		assert_float(dmg).is_greater_equal(18.0 - 0.001)


func test_falloff_is_monotonic_decreasing() -> void:
	var last := 999.0
	for d: int in [0, 200, 500, 700, 900, 1100, 1400, 2000]:
		var dmg := Ballistics.falloff(30.0, float(d), 500.0, 1400.0, 0.6)
		assert_float(dmg).is_less_equal(last)
		last = dmg


func test_falloff_degenerate_range_is_safe() -> void:
	# Zero-length falloff window: inside `start` is still full damage.
	assert_float(Ballistics.falloff(30.0, 100.0, 500.0, 500.0, 0.6)).is_equal_approx(30.0, 0.001)
	assert_float(Ballistics.falloff(30.0, 900.0, 500.0, 500.0, 0.6)).is_equal_approx(18.0, 0.001)


func test_pen_damage_scales_by_multiplier() -> void:
	assert_float(Ballistics.pen_damage(30.0, 0.55)).is_equal_approx(16.5, 0.001)
	assert_float(Ballistics.pen_damage(30.0, 0.35)).is_equal_approx(10.5, 0.001)


func test_pen_damage_full_mult_is_unchanged() -> void:
	assert_float(Ballistics.pen_damage(30.0, 1.0)).is_equal(30.0)


func test_pen_damage_zero_mult_is_zero() -> void:
	assert_float(Ballistics.pen_damage(30.0, 0.0)).is_equal(0.0)


func test_pen_damage_negative_mult_clamps_to_zero() -> void:
	assert_float(Ballistics.pen_damage(30.0, -1.0)).is_equal(0.0)