extends GdUnitTestSuite
## Regression for playtest AI fixes: dead-contact invalidation (stop shooting
## corpses). Live-aim tracking is covered by the battle sims (sensor live_pos).

func test_memory_forget_removes_contact() -> void:
	var m := MemoryModel.new(1)
	m.see(Vector2(10, 0), 42, Enums.Team.SIROCCO)
	assert_bool(m.last_seen(42).is_empty()).is_false()
	m.forget(42)
	assert_bool(m.last_seen(42).is_empty()).is_true()
	assert_float(m.contact_age(42)).is_equal(-1.0)

func test_memory_freshest_skips_forgotten() -> void:
	var m := MemoryModel.new(1)
	m.see(Vector2(10, 0), 42, Enums.Team.SIROCCO)
	m.forget(42)
	assert_bool(m.freshest().is_empty()).is_true()

func test_blackboard_remove_visible_drops_by_id() -> void:
	var bb := Blackboard.new(1)
	bb.visible_contacts = [
		{&"id": 1, &"pos": Vector2.ZERO, &"team": 1},
		{&"id": 2, &"pos": Vector2.ZERO, &"team": 1},
	]
	bb.remove_visible(1)
	assert_int(bb.visible_contacts.size()).is_equal(1)
	assert_int(int(bb.visible_contacts[0][&"id"])).is_equal(2)

func test_blackboard_remove_visible_unknown_id_noop() -> void:
	var bb := Blackboard.new(1)
	bb.visible_contacts = [{&"id": 1, &"pos": Vector2.ZERO, &"team": 1}]
	bb.remove_visible(999)
	assert_int(bb.visible_contacts.size()).is_equal(1)
