extends GdUnitTestSuite
## Perception cone/LOS truth (static maths only — no physics frame needed) and
## Effects' event→decal bookkeeping. Fairness seams: cone angle/range per stance
## and focus, and the low-cover rule are pure functions the AI wave will rely on.

const PerceptionScript := preload("res://src/entities/perception.gd")
const EffectsScript := preload("res://src/entities/effects.gd")


func test_cone_angle_matches_design() -> void:
	assert_float(PerceptionScript.cone_angle_for(Enums.Stance.STAND, false, false)) \
		.is_equal(90.0 + 10.0)
	assert_float(PerceptionScript.cone_angle_for(Enums.Stance.CROUCH, false, false)) \
		.is_equal(100.0)
	assert_float(PerceptionScript.cone_angle_for(Enums.Stance.STAND, false, true)) \
		.is_equal(80.0)
	assert_float(PerceptionScript.cone_angle_for(Enums.Stance.STAND, true, false)) \
		.is_equal(70.0)
	# Focus wins over sprint: bracing is the tighter, longer look.
	assert_float(PerceptionScript.cone_angle_for(Enums.Stance.STAND, true, true)) \
		.is_equal(70.0)


func test_cone_range_matches_design() -> void:
	assert_float(PerceptionScript.range_for(Enums.Stance.STAND, false)) \
		.is_equal_approx(520.0, 0.001)
	assert_float(PerceptionScript.range_for(Enums.Stance.CROUCH, false)) \
		.is_equal_approx(420.0, 0.001)
	# Focus extends range by 15 %.
	assert_float(PerceptionScript.range_for(Enums.Stance.STAND, true)) \
		.is_equal_approx(520.0 * 1.15, 0.001)


## Pure cone test with a stand state, no physics queries involved.
func _perception() -> Node:
	var host := CharacterBody2D.new()
	host.set(&"aim_dir", Vector2.RIGHT)
	host.set(&"team", Enums.Team.BASTION)
	add_child(host)
	auto_free(host)
	var perception: Node = PerceptionScript.new()
	host.add_child(perception)
	auto_free(perception)
	perception.setup(host)
	perception.tick(0.0, Enums.Stance.STAND, false, false)
	return perception


func test_in_cone_accepts_ahead_and_rejects_behind() -> void:
	var p := _perception()
	assert_bool(p.in_cone(Vector2(120.0, 0.0))).is_true()
	assert_bool(p.in_cone(Vector2(-120.0, 0.0))).is_false()


func test_in_cone_edges_at_half_the_total_angle() -> void:
	var p := _perception()
	# 100° cone → ±50°. Just inside/outside that boundary.
	var inside := Vector2.RIGHT.rotated(deg_to_rad(48.0)) * 200.0
	var outside := Vector2.RIGHT.rotated(deg_to_rad(56.0)) * 200.0
	assert_bool(p.in_cone(inside)).is_true()
	assert_bool(p.in_cone(outside)).is_false()


func test_in_cone_rejects_beyond_range() -> void:
	var p := _perception()
	assert_bool(p.in_cone(Vector2(700.0, 0.0))).is_false()
	assert_bool(p.in_cone(Vector2(480.0, 0.0))).is_true()


func test_crouching_shrinks_range_but_keeps_the_angle() -> void:
	var p := _perception()
	p.tick(0.0, Enums.Stance.CROUCH, false, false)
	assert_float(p.cone_range).is_equal_approx(420.0, 0.001)
	assert_float(p.cone_angle_deg).is_equal_approx(100.0, 0.001)
	assert_bool(p.in_cone(Vector2(460.0, 0.0))).is_false()


func test_focus_narrows_and_extends() -> void:
	var p := _perception()
	p.tick(0.0, Enums.Stance.STAND, true, false)
	assert_float(p.cone_angle_deg).is_equal_approx(70.0, 0.001)
	assert_float(p.cone_range).is_equal_approx(598.0, 0.001)


func test_can_see_requires_the_host_in_a_physics_frame() -> void:
	var p := _perception()
	# The host IS in the tree here (auto_free keeps it parented), so LOS runs
	# with an empty physics space: no occluders → a clear line of sight.
	assert_bool(p.can_see(Vector2(100.0, 0.0), Enums.Stance.STAND)).is_true()
	# And behind is still rejected without touching the space state.
	assert_bool(p.can_see(Vector2(-100.0, 0.0), Enums.Stance.STAND)).is_false()


## Effects owns decal caps; check the FIFO limits without rendering.
func _effects() -> Node2D:
	var effects: Node2D = EffectsScript.new()
	add_child(effects)
	auto_free(effects)
	return effects


func test_effects_caps_brass_fifo() -> void:
	var effects := _effects()
	var def := WeaponDef.new()
	def.id = &"cap"
	def.category = &"ar"
	def.falloff_end = 600.0
	effects.call(&"_eject_brass", Vector2.ZERO, Vector2.RIGHT, def)
	for _i: int in EffectsScript.MAX_BRASS + 40:
		effects.call(&"_eject_brass", Vector2.ZERO, Vector2.RIGHT, def)
	var brass: Array = effects.get(&"_brass")
	assert_int(brass.size()).is_equal(EffectsScript.MAX_BRASS)


func test_effects_caps_blood_and_uses_gray_sparks_when_gore_off() -> void:
	var original: bool = bool(Settings.get_value(&"gameplay", &"gore", true))
	Settings.set_value(&"gameplay", &"gore", false)
	var effects := _effects()
	# Gore off → each hit appends one gray chip, capped by MAX_CHIPS.
	for _i: int in EffectsScript.MAX_CHIPS + 40:
		effects.call(&"_on_character_hit", null, null, Enums.Part.TORSO, 30.0, false,
			Vector2.ZERO)
	var blood: Array = effects.get(&"_blood")
	var chips: Array = effects.get(&"_chips")
	assert_int(blood.size()).is_equal(0)
	assert_int(chips.size()).is_equal(EffectsScript.MAX_CHIPS)
	Settings.set_value(&"gameplay", &"gore", original)


func test_effects_shot_spawns_flash_tracer_and_brass() -> void:
	var effects := _effects()
	var shooter := Node2D.new()
	shooter.set(&"arsenal", null)
	add_child(shooter)
	auto_free(shooter)
	effects.call(&"_on_shot_fired", shooter, &"kestrel", Vector2.ZERO, Vector2.RIGHT, 1)
	assert_int((effects.get(&"_flashes") as Array).size()).is_equal(1)
	assert_int((effects.get(&"_tracers") as Array).size()).is_equal(1)
	assert_int((effects.get(&"_brass") as Array).size()).is_equal(1)

func test_hitmarker_spawns_and_expires() -> void:
	var effects := _effects()
	effects.call(&"_on_character_hit", null, null, Enums.Part.TORSO, 30.0, false,
		Vector2.ZERO)
	effects.call(&"_on_character_hit", null, null, Enums.Part.HEAD, 90.0, true,
		Vector2.ZERO)
	var markers: Array = effects.get(&"_markers")
	assert_int(markers.size()).is_equal(2)
	# Fatal hit is red (r >> g), non-fatal is near-white (r ≈ g).
	var hit_color := Color(markers[0][&"color"])
	var kill_color := Color(markers[1][&"color"])
	assert_float(hit_color.r).is_equal_approx(hit_color.g, 0.02)
	assert_bool(kill_color.r > kill_color.g + 0.5).is_true()
	effects.call(&"_tick_transients", 1.0)
	assert_int((effects.get(&"_markers") as Array).size()).is_equal(0)


func test_muzzle_light_pool_is_fixed_and_recycles() -> void:
	var effects := _effects()
	var lights: Array = effects.get(&"_lights")
	assert_int(lights.size()).is_equal(EffectsScript.LIGHT_POOL)
	var shooter := Node2D.new()
	shooter.set(&"arsenal", null)
	add_child(shooter)
	auto_free(shooter)
	for _i: int in EffectsScript.LIGHT_POOL + 3:
		effects.call(&"_on_shot_fired", shooter, &"kestrel", Vector2.ZERO, Vector2.RIGHT, 1)
	assert_int((effects.get(&"_lights") as Array).size()).is_equal(EffectsScript.LIGHT_POOL)
	# Pool never grows, and the lights switch off once the flash has faded.
	effects.call(&"_tick_transients", EffectsScript.FLASH_TIME * 2.0)
	for light: PointLight2D in lights:
		assert_bool(light.enabled).is_false()
