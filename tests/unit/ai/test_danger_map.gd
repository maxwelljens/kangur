extends GdUnitTestSuite
## DangerMap: heat from teammate deaths, ~20 s decay, killzone trigger exactly
## once per 6 s / 150 px window, and the avoid-zone query the overlay uses.

func _map() -> DangerMap:
	return DangerMap.new()


func test_death_adds_heat_at_the_cell() -> void:
	var map := _map()
	map.add_death(Vector2(640, 320))
	assert_float(map.danger_at(Vector2(640, 320))).is_greater(0.5)
	assert_float(map.danger_at(Vector2(2000, 2000))).is_equal(0.0)


func test_heat_decays_over_about_twenty_seconds() -> void:
	var map := _map()
	map.add_death(Vector2(100, 100))
	var initial := map.danger_at(Vector2(100, 100))
	map.tick(DangerMap.HALF_LIFE_S)
	var halved := map.danger_at(Vector2(100, 100))
	assert_float(halved).is_between(initial * 0.3, initial * 0.7)
	map.tick(DangerMap.HALF_LIFE_S * 4.0)
	assert_float(map.danger_at(Vector2(100, 100))).is_less(0.05)


func test_heat_spills_to_neighbour_cells() -> void:
	var map := _map()
	map.add_death(Vector2(320, 320))
	var centre := DangerMap.cell_of(Vector2(320, 320))
	assert_float(map.danger_at(Vector2(320, 320))).is_greater(
		map.danger_at(Vector2(384, 320)))
	assert_int(centre.x).is_equal(DangerMap.cell_of(Vector2(383, 320)).x)


func test_two_deaths_in_window_and_range_trigger_a_killzone() -> void:
	var map := _map()
	assert_object(map.add_death(Vector2(400, 400))).is_null()
	map.tick(1.0)
	var zone: Variant = map.add_death(Vector2(430, 420))
	assert_object(zone).is_not_null()
	assert_vector(zone).is_equal(Vector2(430, 420))
	assert_int(map.killzones().size()).is_equal(1)
	assert_float(map.killzone_at(Vector2(415, 410))).is_greater(0.0)


func test_one_death_is_not_a_killzone() -> void:
	var map := _map()
	assert_object(map.add_death(Vector2(100, 100))).is_null()
	assert_int(map.killzones().size()).is_equal(0)


func test_deaths_outside_the_window_do_not_trigger() -> void:
	var map := _map()
	map.add_death(Vector2(100, 100))
	map.tick(DangerMap.KILLZONE_WINDOW_S + 0.5)
	assert_object(map.add_death(Vector2(110, 100))).is_null()


func test_deaths_far_apart_do_not_trigger() -> void:
	var map := _map()
	map.add_death(Vector2(100, 100))
	map.tick(0.5)
	assert_object(map.add_death(Vector2(900, 100))).is_null()


func test_killzone_does_not_retrigger_inside_its_cooldown() -> void:
	var map := _map()
	map.add_death(Vector2(600, 600))
	map.tick(0.3)
	assert_object(map.add_death(Vector2(610, 600))).is_not_null()
	map.tick(0.3)
	assert_object(map.add_death(Vector2(620, 600))).is_null() \
		.override_failure_message("killzone spam: cooldown must suppress retriggers")


func test_killzone_expires_and_can_trigger_again() -> void:
	var map := _map()
	map.add_death(Vector2(600, 600))
	map.tick(0.3)
	map.add_death(Vector2(610, 600))
	map.tick(DangerMap.KILLZONE_COOLDOWN_S + 1.0)
	assert_int(map.killzones().size()).is_equal(0)
	map.add_death(Vector2(605, 600))
	map.tick(0.2)
	assert_object(map.add_death(Vector2(615, 600))).is_not_null()
