extends GdUnitTestSuite
## TeamIntel: radio is the anti-omniscience seam. Sightings arrive 0.4–1.5 s
## later with 8–40 px position noise, and they are LOWER confidence than
## first-hand memory. No instant wallhack, no exact positions.

func _intel(seed_value: int = 11) -> TeamIntel:
	return TeamIntel.new(Enums.Team.BASTION, seed_value)


func test_nothing_is_known_before_the_radio_delay() -> void:
	var intel := _intel()
	intel.report_sighting(42, Vector2(500, 500), Enums.Team.SIROCCO)
	assert_bool(intel.knows(42)).is_false().override_failure_message(
		"radio delivered instantly: omniscience")
	intel.tick(TeamIntel.DELAY_MIN_S * 0.9)
	assert_bool(intel.knows(42)).is_false()


func test_contact_arrives_within_the_delay_window() -> void:
	var intel := _intel()
	intel.report_sighting(42, Vector2(500, 500), Enums.Team.SIROCCO)
	intel.tick(TeamIntel.DELAY_MAX_S + 0.01)
	assert_bool(intel.knows(42)).is_true()
	assert_float(intel.best_contact()[&"confidence"]).is_less(
		MemoryModel.CONFIDENCE_FIRST)


func test_position_is_noisy_but_near_the_truth() -> void:
	var near := 0
	for seed_value: int in 30:
		var intel := _intel(seed_value)
		var truth := Vector2(800, 400)
		intel.report_sighting(7, truth, Enums.Team.SIROCCO)
		intel.tick(TeamIntel.DELAY_MAX_S + 0.01)
		var pos: Vector2 = intel.best_contact()[&"pos"]
		var error := pos.distance_to(truth)
		assert_float(error).is_between(TeamIntel.NOISE_MIN_PX - 0.001,
			TeamIntel.NOISE_MAX_PX + 0.001)
		if error > 1.0:
			near += 1
	assert_int(near).is_greater(25).override_failure_message(
		"radio should almost always be off by the rolled noise")


func test_contacts_fade_after_the_memory_ttl() -> void:
	var intel := _intel()
	intel.report_sighting(3, Vector2(100, 100), Enums.Team.SIROCCO)
	intel.tick(TeamIntel.DELAY_MAX_S + 0.01)
	assert_bool(intel.knows(3)).is_true()
	intel.tick(MemoryModel.CONTACT_TTL_MAX + 0.5)
	assert_bool(intel.knows(3)).is_false()


func test_multiple_sightings_keep_the_freshest() -> void:
	var intel := _intel()
	intel.report_sighting(1, Vector2(100, 0), Enums.Team.SIROCCO)
	intel.report_sighting(2, Vector2(900, 0), Enums.Team.SIROCCO)
	intel.tick(TeamIntel.DELAY_MAX_S + 0.01)
	var best := intel.best_contact()
	assert_int(best[&"id"]).is_equal(2).override_failure_message(
		"later sighting should be the freshest contact")


func test_both_reported_enemies_become_known() -> void:
	var intel := _intel()
	intel.report_sighting(1, Vector2(100, 0), Enums.Team.SIROCCO)
	intel.report_sighting(2, Vector2(200, 0), Enums.Team.SIROCCO)
	intel.tick(TeamIntel.DELAY_MAX_S + 0.01)
	assert_int(intel.contacts.size()).is_equal(2)


func test_delay_is_seeded_and_reproducible() -> void:
	var a := _intel(99)
	var b := _intel(99)
	a.report_sighting(5, Vector2(300, 300), Enums.Team.SIROCCO)
	b.report_sighting(5, Vector2(300, 300), Enums.Team.SIROCCO)
	assert_float(a.inbox[0][&"arrival"]).is_equal_approx(float(b.inbox[0][&"arrival"]), 0.0001)
	assert_vector(a.inbox[0][&"pos"]).is_equal(b.inbox[0][&"pos"])