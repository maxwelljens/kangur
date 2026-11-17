extends GdUnitTestSuite
## MemoryModel: sighting storage (position copied, no node identity), decay
## 6–12 s, heard-sound window, freshest-contact selection. These are the pure
## fairness primitives: AI knowledge must be memory, never a live enemy feed.

func _memory(seed_value: int = 7) -> MemoryModel:
	return MemoryModel.new(seed_value)


func test_sighting_copies_position_and_identity() -> void:
	var memory := _memory()
	var contact := memory.see(Vector2(120, 40), 99, Enums.Team.SIROCCO)
	assert_int(contact[&"id"]).is_equal(99)
	assert_int(contact[&"team"]).is_equal(Enums.Team.SIROCCO)
	assert_vector(contact[&"pos"]).is_equal(Vector2(120, 40))
	assert_float(contact[&"confidence"]).is_equal_approx(MemoryModel.CONFIDENCE_FIRST, 0.001)


func test_contacts_decay_between_six_and_twelve_seconds() -> void:
	var memory := _memory()
	memory.see(Vector2(100, 0), 1, Enums.Team.SIROCCO)
	var ttl: float = float(memory.last_seen(1)[&"ttl"])
	assert_float(ttl).is_between(MemoryModel.CONTACT_TTL_MIN, MemoryModel.CONTACT_TTL_MAX)
	# Still remembered just before the shortest possible lifetime…
	memory.tick(MemoryModel.CONTACT_TTL_MIN - 0.1)
	assert_bool(memory.last_seen(1).is_empty()).is_false()
	# …and gone once the rolled lifetime has passed.
	memory.tick(MemoryModel.CONTACT_TTL_MAX)
	assert_bool(memory.last_seen(1).is_empty()).is_true()


func test_resighting_refreshes_time_and_raises_confidence() -> void:
	var memory := _memory()
	memory.see(Vector2(10, 10), 5, Enums.Team.BASTION)
	memory.tick(2.0)
	memory.see(Vector2(50, 10), 5, Enums.Team.BASTION)
	var contact := memory.last_seen(5)
	assert_float(contact[&"confidence"]).is_equal_approx(
		minf(1.0, MemoryModel.CONFIDENCE_FIRST + MemoryModel.CONFIDENCE_GAIN), 0.001)
	assert_vector(contact[&"pos"]).is_equal(Vector2(50, 10))
	assert_float(memory.contact_age(5)).is_equal_approx(0.0, 0.0001)


func test_contact_age_is_negative_when_never_seen() -> void:
	var memory := _memory()
	assert_float(memory.contact_age(1234)).is_equal(-1.0)


func test_hearing_stores_position_and_loudness_only() -> void:
	var memory := _memory()
	memory.hear(Vector2(300, 200), 180.0, &"gunshot")
	var heard := memory.last_heard()
	assert_vector(heard[&"pos"]).is_equal(Vector2(300, 200))
	assert_float(heard[&"loudness"]).is_equal(180.0)
	assert_bool(heard.has(&"id")).is_false().override_failure_message(
		"hearing must not invent an identity")
	assert_int(memory.contacts.size()).is_equal(0).override_failure_message(
		"hearing must not create a contact")


func test_heard_sounds_expire() -> void:
	var memory := _memory()
	memory.hear(Vector2.ZERO, 200.0, &"footstep")
	memory.tick(MemoryModel.SOUND_TTL - 0.2)
	assert_bool(memory.last_heard().is_empty()).is_false()
	memory.tick(0.5)
	assert_bool(memory.last_heard().is_empty()).is_true()


func test_freshest_prefers_the_latest_sighting() -> void:
	var memory := _memory()
	memory.see(Vector2(100, 0), 1, Enums.Team.SIROCCO)
	memory.tick(1.0)
	memory.see(Vector2(500, 500), 2, Enums.Team.SIROCCO)
	assert_int(memory.freshest()[&"id"]).is_equal(2)


func test_contact_cap_keeps_the_newest() -> void:
	var memory := _memory()
	for i: int in MemoryModel.MAX_CONTACTS + 4:
		memory.see(Vector2(i, 0), 1000 + i, Enums.Team.SIROCCO)
		memory.tick(0.01)
	assert_int(memory.contacts.size()).is_equal(MemoryModel.MAX_CONTACTS)
	assert_bool(memory.last_seen(1000).is_empty()).is_true()