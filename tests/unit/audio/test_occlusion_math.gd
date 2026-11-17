extends GdUnitTestSuite
## OcclusionMath — the numbers in architecture §9 / design §12, asserted.
## Pure static class: no nodes, no AudioServer, runs anywhere.

const LEVELS := 4


func test_bus_names_are_the_contract_order() -> void:
	assert_array(OcclusionMath.BUS_NAMES).contains_exactly(
		[&"SFX_Open", &"SFX_Light", &"SFX_Heavy", &"SFX_Muffled"]
	)


func test_cutoffs_match_architecture_9() -> void:
	assert_float(OcclusionMath.cutoff_for_walls(0)).is_equal(20500.0)
	assert_float(OcclusionMath.cutoff_for_walls(1)).is_equal(4200.0)
	assert_float(OcclusionMath.cutoff_for_walls(2)).is_equal(1300.0)
	assert_float(OcclusionMath.cutoff_for_walls(3)).is_equal(550.0)


func test_gains_match_architecture_9() -> void:
	assert_float(OcclusionMath.volume_offset_for_walls(0)).is_equal(0.0)
	assert_float(OcclusionMath.volume_offset_for_walls(1)).is_equal(-4.0)
	assert_float(OcclusionMath.volume_offset_for_walls(2)).is_equal(-9.0)
	assert_float(OcclusionMath.volume_offset_for_walls(3)).is_equal(-14.0)


func test_more_walls_never_brighter_or_louder() -> void:
	for level: int in LEVELS - 1:
		assert_float(OcclusionMath.cutoff_for_walls(level)).is_greater(
			OcclusionMath.cutoff_for_walls(level + 1)
		)
		assert_float(OcclusionMath.volume_offset_for_walls(level)).is_greater(
			OcclusionMath.volume_offset_for_walls(level + 1)
		)


func test_wall_count_saturates_at_muffled() -> void:
	for walls: int in [3, 4, 17, 999]:
		assert_int(OcclusionMath.occlusion_level(walls)).is_equal(OcclusionMath.MAX_WALLS)
		assert_that(OcclusionMath.bus_name_for_walls(walls)).is_equal(&"SFX_Muffled")


func test_negative_wall_count_is_open_air() -> void:
	assert_int(OcclusionMath.occlusion_level(-5)).is_equal(0)
	assert_that(OcclusionMath.bus_name_for_walls(-1)).is_equal(&"SFX_Open")


func test_for_walls_returns_the_contract_shape() -> void:
	var result := OcclusionMath.for_walls(2)
	assert_that(result).contains_keys(["bus", "volume_db", "cutoff"])
	assert_int(result["bus"]).is_equal(2)
	assert_float(result["volume_db"]).is_equal(-9.0)
	assert_float(result["cutoff"]).is_equal(1300.0)


func test_loudness_constants_match_design_12() -> void:
	assert_float(OcclusionMath.LOUDNESS_GUNSHOT).is_equal(1600.0)
	assert_float(OcclusionMath.LOUDNESS_SPRINT_STEP).is_equal(420.0)
	assert_float(OcclusionMath.LOUDNESS_WALK_STEP).is_equal(260.0)
	assert_float(OcclusionMath.LOUDNESS_CROUCH_STEP).is_equal(120.0)
	assert_float(OcclusionMath.LOUDNESS_RELOAD).is_equal(200.0)
	assert_float(OcclusionMath.LOUDNESS_BANDAGE).is_equal(140.0)
	assert_float(OcclusionMath.LOUDNESS_EXPLOSION).is_equal(2000.0)
	assert_float(OcclusionMath.LOUDNESS_BODYFALL).is_equal(180.0)


func test_max_distance_is_the_loudness_it_was_given() -> void:
	assert_float(OcclusionMath.max_distance(OcclusionMath.LOUDNESS_GUNSHOT)).is_equal(1600.0)
	assert_float(OcclusionMath.max_distance(OcclusionMath.LOUDNESS_CROUCH_STEP)).is_equal(120.0)
	assert_float(OcclusionMath.max_distance(0.0)).is_equal(0.0)
	assert_float(OcclusionMath.max_distance(-50.0)).is_equal(0.0)


func test_max_distance_clamps_absurd_loudness() -> void:
	assert_float(OcclusionMath.max_distance(99999.0)).is_equal(
		OcclusionMath.MAX_RENDER_DISTANCE
	)


func test_occluded_loudness_decays_with_walls() -> void:
	var previous := INF
	for walls: int in LEVELS:
		var reach := OcclusionMath.occluded_loudness(OcclusionMath.LOUDNESS_GUNSHOT, walls)
		assert_float(reach).is_less(previous)
		previous = reach


func test_occluded_loudness_open_air_is_unchanged() -> void:
	assert_float(OcclusionMath.occluded_loudness(800.0, 0)).is_equal_approx(800.0, 0.001)


func test_occluded_loudness_matches_the_render_gain() -> void:
	for walls: int in LEVELS:
		var expected := 1000.0 * db_to_linear(OcclusionMath.volume_offset_for_walls(walls))
		assert_float(OcclusionMath.occluded_loudness(1000.0, walls)).is_equal_approx(expected, 0.001)


func test_occluded_loudness_saturates_past_three_walls() -> void:
	var muffled := OcclusionMath.occluded_loudness(1000.0, 3)
	assert_float(OcclusionMath.occluded_loudness(1000.0, 12)).is_equal(muffled)