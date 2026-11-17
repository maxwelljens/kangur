extends GdUnitTestSuite
## AudioDirector headless behaviour: bus layout, routing, pooling, streams.
## Runs with the Dummy audio driver — the graph works, output is null.

const AudioDirectorScript := preload("res://src/audio/audio_director.gd")

var _director: Node


func before_test() -> void:
	_director = AudioDirectorScript.new()
	_director.name = "AudioDirectorUnderTest"
	add_child(_director)
	# The headless build skips playback; tests drive the routing path anyway.
	_director._headless = false


func after_test() -> void:
	remove_child(_director)
	_director.free()


func test_buses_from_layout_exist_with_effects() -> void:
	for i: int in OcclusionMath.BUS_NAMES.size():
		var bus_name: StringName = OcclusionMath.BUS_NAMES[i]
		var idx := AudioServer.get_bus_index(bus_name)
		assert_int(idx).override_failure_message("bus %s missing" % bus_name).is_greater_equal(0)
		var filter: AudioEffectLowPassFilter = null
		for e: int in AudioServer.get_bus_effect_count(idx):
			var effect := AudioServer.get_bus_effect(idx, e)
			if effect is AudioEffectLowPassFilter:
				filter = effect
			assert_int(AudioServer.get_bus_effect_count(idx)).is_greater_equal(1)
			assert_bool(AudioServer.is_bus_effect_enabled(idx, e)).is_true()
		assert_object(filter).override_failure_message("no lowpass on %s" % bus_name).is_not_null()
		assert_float(filter.cutoff_hz).is_equal(OcclusionMath.cutoff_for_walls(i))


func test_bus_sends_follow_architecture_9() -> void:
	for bus_name: StringName in [&"Music", &"SFX", &"Voice"]:
		var idx := AudioServer.get_bus_index(bus_name)
		assert_str(AudioServer.get_bus_send(idx)).is_equal("Master")
	for bus_name: StringName in OcclusionMath.BUS_NAMES:
		assert_str(AudioServer.get_bus_send(AudioServer.get_bus_index(bus_name))).is_equal("SFX")


func test_occlusion_gains_live_on_the_buses() -> void:
	# Gains are bus-level so a player never applies them twice.
	for i: int in OcclusionMath.BUS_NAMES.size():
		var idx := AudioServer.get_bus_index(OcclusionMath.BUS_NAMES[i])
		assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(
			OcclusionMath.volume_offset_for_walls(i), 0.01
		)


func test_sfx_has_a_limiter_and_voice_a_bandpass() -> void:
	assert_int(_effect_count(&"SFX", "AudioEffectHardLimiter")).is_equal(1)
	assert_int(_effect_count(&"Voice", "AudioEffectBandPassFilter")).is_equal(1)


func test_settings_volumes_land_on_the_buses() -> void:
	for pair: Array in [[&"Master", &"master"], [&"SFX", &"sfx"], [&"Music", &"music"], [&"Voice", &"voice"]]:
		var idx := AudioServer.get_bus_index(pair[0])
		var expected := linear_to_db(float(Settings.get_value(&"audio", pair[1], 1.0)))
		assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(expected, 0.01)


func test_pool_is_capped_and_ignores_area_bus_overrides() -> void:
	assert_int(_pool().size()).is_equal(AudioDirectorScript.POOL_SIZE)
	for p: AudioStreamPlayer2D in _pool():
		assert_int(p.area_mask).is_equal(0)
		assert_float(p.attenuation).is_equal_approx(AudioDirectorScript.ATTENUATION, 0.001)


func test_source_within_range_gets_mixed() -> void:
	_director.set_listener(Vector2.ZERO)
	_director._play_item(Vector2(300, 0), 1600.0, _any_stream())
	var p := _pool()[0]
	assert_bool(p.playing).is_true()
	assert_str(p.bus).is_equal("SFX_Open")
	assert_float(p.max_distance).is_equal(1600.0)
	assert_float(p.global_position.x).is_equal(300.0)


func test_sound_emitted_out_of_range_is_dropped() -> void:
	_director.set_listener(Vector2.ZERO)
	EventBus.sound_emitted.emit(Vector2(5000, 0), OcclusionMath.LOUDNESS_CROUCH_STEP, &"footstep", null, Enums.Surface.CONCRETE)
	_director._physics_process(0.0)
	for p: AudioStreamPlayer2D in _pool():
		assert_bool(p.playing).is_false()


func test_sound_emitted_in_range_is_queued_then_played() -> void:
	_director.set_listener(Vector2.ZERO)
	var before := _pool().filter(func(p: AudioStreamPlayer2D) -> bool: return p.playing).size()
	EventBus.sound_emitted.emit(Vector2(200, 0), OcclusionMath.LOUDNESS_GUNSHOT, &"gunshot:kestrel", null, Enums.Surface.CONCRETE)
	_director._physics_process(0.0)
	var after := _pool().filter(func(p: AudioStreamPlayer2D) -> bool: return p.playing).size()
	assert_int(after).is_equal(before + 1)


func test_no_walls_between_adjacent_points() -> void:
	_director.set_listener(Vector2.ZERO)
	assert_int(_director.count_walls(Vector2.ZERO, Vector2(100, 0))).is_equal(0)
	assert_that(_director.bus_for_source(Vector2(100, 0))).is_equal(&"SFX_Open")


func test_walls_are_counted_through_physics() -> void:
	# Real StaticBody2Ds on the WORLD layer, not a mocked count.
	_director.set_listener(Vector2.ZERO)
	for count: int in [1, 2, 3, 4]:
		var walls := _add_walls(count)
		await get_tree().physics_frame
		var source := Vector2(100.0 * count + 100.0, 0.0)
		assert_int(_director.count_walls(Vector2.ZERO, source)).override_failure_message(
			"%d walls" % count
		).is_equal(mini(count, OcclusionMath.MAX_WALLS))
		for wall: Node2D in walls:
			wall.free()


func test_routing_follows_the_wall_count() -> void:
	_director.set_listener(Vector2.ZERO)
	var walls := _add_walls(2)
	await get_tree().physics_frame
	var source := Vector2(300, 0)
	assert_int(_director.count_walls(Vector2.ZERO, source)).is_equal(2)
	assert_that(_director.bus_for_source(source)).is_equal(&"SFX_Heavy")
	_director._play_item(source, 1600.0, _any_stream())
	assert_str(_pool()[0].bus).is_equal("SFX_Heavy")
	for wall: Node2D in walls:
		wall.free()


func test_thick_wall_counts_as_one() -> void:
	# Map wall tiles are far thicker than RAY_SKIN; a ray restarting inside the
	# shape must not count the same wall twice.
	_director.set_listener(Vector2.ZERO)
	var body := StaticBody2D.new()
	body.collision_layer = Layers.WORLD_BIT
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(128, 400)
	shape.shape = rect
	body.add_child(shape)
	body.global_position = Vector2(150, 0)
	add_child(body)
	await get_tree().physics_frame
	assert_int(_director.count_walls(Vector2.ZERO, Vector2(400, 0))).is_equal(1)
	body.free()


func test_headless_guard_blocks_playback_but_not_buses() -> void:
	var guarded: Node = AudioDirectorScript.new()
	add_child(guarded)
	guarded._headless = true
	guarded.set_listener(Vector2.ZERO)
	guarded._play_item(Vector2(10, 0), 1600.0, _any_stream())
	assert_bool(guarded._pool[0].playing).is_false()
	assert_int(AudioServer.get_bus_index(&"SFX_Heavy")).is_greater_equal(0)
	remove_child(guarded)
	guarded.free()


func test_occlusion_off_forces_open_bus() -> void:
	var saved: Variant = Settings.get_value(&"audio", &"occlusion", true)
	Settings.set_value(&"audio", &"occlusion", false)
	_director.set_listener(Vector2.ZERO)
	assert_that(_director.bus_for_source(Vector2(100, 0))).is_equal(&"SFX_Open")
	Settings.set_value(&"audio", &"occlusion", saved)


func test_gunshot_kinds_resolve_to_a_stream() -> void:
	for kind: StringName in [&"gunshot", &"gunshot:kestrel", &"gunshot:adder", &"gunshot:judge", &"gunshot:nonexistent"]:
		assert_object(_director._stream_for(kind, Enums.Surface.CONCRETE)).override_failure_message(
			"no stream for %s" % kind
		).is_not_null()


func test_footstep_kinds_resolve_per_surface() -> void:
	for surface: int in [Enums.Surface.CONCRETE, Enums.Surface.SAND, Enums.Surface.METAL,
			Enums.Surface.GRASS, Enums.Surface.WOOD, Enums.Surface.GLASS, Enums.Surface.WATER]:
		assert_object(_director._stream_for(&"footstep", surface)).override_failure_message(
			"no footstep stream for surface %d" % surface
		).is_not_null()


func test_foley_kinds_resolve() -> void:
	for kind: StringName in [&"reload", &"reload:adder", &"bandage", &"bodyfall", &"explosion", &"impact"]:
		assert_object(_director._stream_for(kind, Enums.Surface.CONCRETE)).is_not_null()


func test_unknown_kind_stays_audible() -> void:
	assert_object(_director._stream_for(&"something_new", Enums.Surface.METAL)).is_not_null()


func test_music_crossfade_switches_the_playing_player() -> void:
	_director.play_music(&"title_theme")
	assert_that(_director._music_track).is_equal(&"title_theme")
	var first: AudioStreamPlayer = _director._music_a if _director._music_on_a else _director._music_b
	assert_bool(first.playing).is_true()
	_director.play_music(&"lobby_deploy")
	assert_bool((_director._music_b if _director._music_on_a else _director._music_a).playing).is_true()


func test_tension_maps_to_the_adaptive_pair() -> void:
	_director.set_tension(&"engaged")
	assert_that(_director._music_track).is_equal(&"match_engaged")
	_director.set_tension(&"calm")
	assert_that(_director._music_track).is_equal(&"match_calm")
	_director.set_tension(&"clutch")
	assert_that(_director._music_track).is_equal(&"clutch")


func test_missing_track_does_not_crash() -> void:
	_director.play_music(&"no_such_track")
	assert_bool(_director._music_a.playing or _director._music_b.playing).is_false()


func test_ui_names_resolve_from_credits_listing() -> void:
	for name: StringName in [&"click", &"hover", &"confirm", &"back", &"error", &"notify"]:
		_director.play_ui(name)
		assert_object(_director._ui.stream).override_failure_message("ui %s" % name).is_not_null()


func test_voice_categories_resolve() -> void:
	for category: StringName in [&"contact", &"affirmative", &"warning", &"denied", &"status"]:
		_director.play_radio(Enums.Team.BASTION, category)
		assert_object(_director._voice.stream).override_failure_message("voice %s" % category).is_not_null()


func test_ambience_loops() -> void:
	_director.play_ambience(&"wind")
	assert_bool(_director._ambience.playing).is_true()
	assert_float(_director._ambience.volume_db).is_equal(AudioDirectorScript.AMBIENCE_DB)
	_director.stop_ambience()
	assert_bool(_director._ambience.playing).is_false()


func test_pool_recycles_when_exhausted() -> void:
	_director.set_listener(Vector2.ZERO)
	var stream := _any_stream()
	for i: int in AudioDirectorScript.POOL_SIZE * 3:
		_director._play_item(Vector2(i, 0), 1600.0, stream)
	assert_bool(_pool()[0].playing).is_true()


func _pool() -> Array[AudioStreamPlayer2D]:
	return _director._pool


func _effect_count(bus: StringName, class_name_: String) -> int:
	var idx := AudioServer.get_bus_index(bus)
	var count := 0
	for e: int in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, e).get_class() == class_name_:
			count += 1
	return count


func _any_stream() -> AudioStream:
	return load("res://assets/audio/ui/click.ogg")


## `count` thin WORLD-layer walls spaced 100 px apart, starting at x=50.
func _add_walls(count: int) -> Array[Node2D]:
	var walls: Array[Node2D] = []
	for i: int in count:
		var body := StaticBody2D.new()
		body.collision_layer = Layers.WORLD_BIT
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 400)
		shape.shape = rect
		body.add_child(shape)
		body.global_position = Vector2(50.0 + i * 100.0, 0.0)
		add_child(body)
		walls.append(body)
	return walls