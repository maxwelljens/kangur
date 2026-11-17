extends GdUnitTestSuite
## Personality: same seed → identical squad, different seeds → different NPCs,
## and the difficulty bias only nudges (never drives) temperament. Design §9.2:
## never hardcode a trait response; traits weight scores.

func _roll(seed_value: int, difficulty: DifficultyDef = null) -> Personality:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Personality.roll(rng, difficulty)


func test_same_seed_is_deterministic() -> void:
	var a := _roll(1234)
	var b := _roll(1234)
	for name: StringName in Personality.TRAIT_NAMES:
		assert_float(a.trait_value(name)).override_failure_message(
			"trait %s drifted on the same seed" % name) \
			.is_equal_approx(b.trait_value(name), 0.0001)


func test_different_seeds_roll_different_npcs() -> void:
	var a := _roll(1)
	var b := _roll(2)
	var differences := 0
	for name: StringName in Personality.TRAIT_NAMES:
		if absf(a.trait_value(name) - b.trait_value(name)) > 0.05:
			differences += 1
	assert_int(differences).is_greater_equal(3).override_failure_message(
		"two seeds should differ on most traits, got %d/8" % differences)


func test_all_traits_stay_in_range() -> void:
	for seed_value: int in 40:
		var p := _roll(seed_value)
		for name: StringName in Personality.TRAIT_NAMES:
			assert_float(p.trait_value(name)).is_between(0.0, 1.0)


func test_a_squad_of_rolls_is_not_uniform() -> void:
	# Twelve bots per match: they must not all score the same on key traits.
	var aggression: Array[float] = []
	var caution: Array[float] = []
	for i: int in 12:
		var p := _roll(500 + i)
		aggression.append(p.aggression)
		caution.append(p.caution)
	assert_float(aggression.max() - aggression.min()).is_greater(0.2)
	assert_float(caution.max() - caution.min()).is_greater(0.2)


func test_difficulty_bias_moves_aggression_and_discipline_only() -> void:
	var elite := DifficultyDef.new()
	elite.aggression_bias = 0.6
	elite.discipline_bias = 0.6
	var average_elite := 0.0
	var average_plain := 0.0
	for seed_value: int in 60:
		average_elite += _roll(seed_value, elite).discipline
		average_plain += _roll(seed_value).discipline
	assert_float(average_elite / 60.0).is_greater(average_plain / 60.0)
	# Caution is temperament, not difficulty: statistically unchanged.
	var caution_elite := 0.0
	var caution_plain := 0.0
	for seed_value: int in 60:
		caution_elite += _roll(seed_value, elite).caution
		caution_plain += _roll(seed_value).caution
	assert_float(absf(caution_elite - caution_plain) / 60.0).is_less(0.02)


func test_label_summarises_extremes() -> void:
	var p := Personality.new()
	p.aggression = 0.9
	p.campiness = 0.9
	var label := p.label()
	assert_bool(label.contains("push")).is_true()
	assert_bool(label.contains("camp")).is_true()