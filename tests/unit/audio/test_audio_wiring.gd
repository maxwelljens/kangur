extends GdUnitTestSuite
## Sound-set wiring: weapon/impact streams come from `SoundSetDef` data
## (WeaponDef.sound_set → Defs.sound_set), not from the folder scan, which is
## only the fallback for kinds no set models. Headless-safe: resolution is pure
## data lookup, playback no-ops.

const AudioDirectorScript := preload("res://src/audio/audio_director.gd")
const ArsenalScript := preload("res://src/entities/arsenal.gd")
const WEAPON_COUNT := 12

var _director: Node


class StubHost extends Node2D:
	var arsenal: Node = null


func before_test() -> void:
	_director = AudioDirectorScript.new()
	_director.name = "AudioDirectorWiring"
	add_child(_director)
	_director._headless = false


func after_test() -> void:
	remove_child(_director)
	_director.free()


func test_every_weapon_has_a_sound_set_that_resolves() -> void:
	assert_int(Defs.all_weapons().size()).is_equal(WEAPON_COUNT)
	for def: WeaponDef in Defs.all_weapons():
		assert_that(def.sound_set).override_failure_message(
			"weapon %s has no sound_set" % def.id
		).is_not_equal(&"")
		assert_object(Defs.sound_set(def.sound_set)).override_failure_message(
			"weapon %s sound_set '%s' does not resolve" % [def.id, def.sound_set]
		).is_not_null()


func test_gunshot_resolves_from_the_weapons_own_set() -> void:
	# The invariant is data, not routing: the stream must be a fire variant of
	# the set the weapon def points at (308_bolt deliberately ships 308 files).
	for def: WeaponDef in Defs.all_weapons():
		var stream: AudioStream = _director._stream_for(
			StringName("gunshot:" + String(def.id)), Enums.Surface.CONCRETE)
		assert_object(stream).override_failure_message(
			"no gunshot stream for %s" % def.id).is_not_null()
		var fire := Defs.sound_set(def.sound_set).streams(&"fire")
		assert_bool(fire.has(stream)).override_failure_message(
			"%s resolved outside its set '%s': %s" % [def.id, def.sound_set, stream.resource_path]
		).is_true()


func test_reported_gaps_are_audible() -> void:
	# .357 shot, 20ga shotgun and the 5.56 rifle were the silent/short set.
	for pair: Array in [[&"judge", "weapons/357/"], [&"breve", "weapons/20ga/"],
			[&"kestrel", "weapons/556/"]]:
		var stream: AudioStream = _director._stream_for(
			StringName("gunshot:" + String(pair[0])), Enums.Surface.CONCRETE)
		assert_object(stream).override_failure_message("%s silent" % pair[0]).is_not_null()
		assert_str(stream.resource_path).override_failure_message(
			"%s did not use %s" % pair).contains(pair[1])


func test_action_kinds_resolve_from_the_set() -> void:
	for def: WeaponDef in Defs.all_weapons():
		for pair: Array in [[&"cycle", &"cycle"], [&"dry", &"dry"],
				[&"reload", &"reload_start"], [&"reload_end", &"reload_end"]]:
			var set := Defs.sound_set(def.sound_set)
			if set.streams(pair[1]).is_empty():
				continue  # full-auto sets ship no cycle foley; folder fallback
			var stream: AudioStream = _director._stream_for(
				StringName("%s:%s" % [pair[0], def.id]), Enums.Surface.CONCRETE)
			assert_bool(set.streams(pair[1]).has(stream)).override_failure_message(
				"%s %s resolved outside its set" % [def.id, pair[0]]).is_true()


func test_explicit_action_suffix_overrides_the_kind() -> void:
	var cycle: AudioStream = _director._stream_for(&"gunshot:breve:cycle", Enums.Surface.CONCRETE)
	assert_object(cycle).is_not_null()
	assert_bool(Defs.sound_set(&"20ga").streams(&"cycle").has(cycle)).is_true()


func test_reload_uses_the_source_characters_set() -> void:
	# Character is the emitter (arsenal.gd passes `_host`), so the source is
	# characterised by its `arsenal` property — stub it without a full scene.
	var host := StubHost.new()
	add_child(host)
	host.arsenal = ArsenalScript.new()
	host.add_child(host.arsenal)
	host.arsenal.setup(host, null, &"judge")
	var stream: AudioStream = _director._stream_for(&"reload", Enums.Surface.CONCRETE, host)
	assert_object(stream).is_not_null()
	assert_bool(Defs.sound_set(&"357").streams(&"reload_start").has(stream)).is_true()
	host.free()


func test_reload_without_a_source_still_resolves() -> void:
	assert_object(_director._stream_for(&"reload", Enums.Surface.CONCRETE)).is_not_null()


func test_impact_maps_surface_to_its_recording() -> void:
	for pair: Array in [[Enums.Surface.GLASS, "glass_shatter"],
			[Enums.Surface.CONCRETE, "concrete_"], [Enums.Surface.METAL, "metal_"],
			[Enums.Surface.WOOD, "wood_"], [AudioDirectorScript.IMPACT_FLESH, "flesh_"]]:
		var stream: AudioStream = _director._stream_for(&"impact", pair[0])
		assert_object(stream).override_failure_message("surface %s silent" % pair[0]).is_not_null()
		assert_str(stream.resource_path).override_failure_message(
			"surface %s played %s" % [pair[0], stream.resource_path]).contains(pair[1])


func test_unknown_kind_and_weapon_fall_back() -> void:
	for kind: StringName in [&"something_new", &"gunshot:nonexistent",
			&"reload:nonexistent", &"impact"]:
		assert_object(_director._stream_for(kind, Enums.Surface.SAND)).override_failure_message(
			"no fallback for %s" % kind).is_not_null()


func test_shot_fired_is_the_gunshot_audio_source() -> void:
	# No entity emits `gunshot:<id>`; shot_fired is what actually fires, so the
	# director must render it — that is what makes .357 audible at all.
	_director.set_listener(Vector2.ZERO)
	_director._headless = false
	EventBus.shot_fired.emit(null, &"judge", Vector2(200, 0), Vector2.RIGHT, 1)
	_director._physics_process(0.0)
	var playing: Array = _director._pool.filter(
		func(p: AudioStreamPlayer2D) -> bool: return p.playing)
	assert_int(playing.size()).is_equal(1)
	assert_str(playing[0].stream.resource_path).contains("weapons/357/")


func test_bolt_and_pump_shots_add_a_cycle() -> void:
	for weapon_id: StringName in [&"lynx", &"breve"]:
		_director._pending.clear()
		EventBus.shot_fired.emit(null, weapon_id, Vector2(200, 0), Vector2.RIGHT, 1)
		assert_int(_director._pending.size()).override_failure_message(
			"%s: no cycle queued" % weapon_id).is_equal(2)


func test_automatic_shots_queue_no_cycle() -> void:
	# The Judge (semi revolver) cocks inside the trigger pull: no extra cycle.
	for weapon_id: StringName in [&"kestrel", &"adder", &"mule", &"judge"]:
		_director._pending.clear()
		EventBus.shot_fired.emit(null, weapon_id, Vector2(200, 0), Vector2.RIGHT, 1)
		assert_int(_director._pending.size()).override_failure_message(
			"%s queued a cycle" % weapon_id).is_equal(1)


func test_bullet_impact_queues_an_impact_sound() -> void:
	_director.set_listener(Vector2.ZERO)
	_director._headless = false
	EventBus.bullet_impact.emit(Vector2(200, 0), Vector2.LEFT, Enums.Surface.GLASS, false)
	_director._physics_process(0.0)
	var playing: Array = _director._pool.filter(
		func(p: AudioStreamPlayer2D) -> bool: return p.playing)
	assert_int(playing.size()).is_equal(1)
	assert_str(playing[0].stream.resource_path).contains("glass_shatter")


func test_impact_out_of_range_is_dropped() -> void:
	_director.set_listener(Vector2.ZERO)
	_director._headless = false
	EventBus.bullet_impact.emit(Vector2(8000, 0), Vector2.LEFT, Enums.Surface.CONCRETE, false)
	_director._physics_process(0.0)
	for p: AudioStreamPlayer2D in _director._pool:
		assert_bool(p.playing).is_false()


func test_headless_resolution_does_not_crash() -> void:
	_director._headless = true
	_director.set_listener(Vector2.ZERO)
	EventBus.sound_emitted.emit(Vector2(10, 0), OcclusionMath.LOUDNESS_GUNSHOT,
		&"gunshot:judge", null, Enums.Surface.CONCRETE)
	EventBus.bullet_impact.emit(Vector2(10, 0), Vector2.LEFT, Enums.Surface.METAL, false)
	_director._physics_process(0.0)
	assert_int(_director._pending.size()).is_equal(0)
	assert_object(_director._stream_for(&"gunshot:judge", Enums.Surface.GLASS)).is_not_null()