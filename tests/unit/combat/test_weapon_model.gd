extends GdUnitTestSuite
## WeaponModel — fire modes, RPM/cycle, burst pause, reload stages, ammo, bloom.
## Numbers: docs/design/game-design.md §6. Uses WeaponDef directly (already in
## src/core/data/weapon_def.gd) so tests exercise the real content schema.

const DT := 1.0 / 60.0

func _def(overrides: Dictionary = {}) -> WeaponDef:
	var def := WeaponDef.new()
	def.id = &"test"
	def.rpm = 600.0
	def.mag_size = 30
	def.reserve_mags = 5
	def.reload_time = 2.4
	def.equip_time = 0.0
	def.damage = 30.0
	def.bullet_speed = 6200.0
	def.spread_base = 0.5
	def.bloom_per_shot = 0.4
	def.bloom_max = 5.0
	def.bloom_recovery = 4.0
	def.recoil_kick = 1.4
	def.recoil_recovery = 3.5
	def.fire_modes = [Enums.FireMode.AUTO]
	def.falloff_start = 500.0
	def.falloff_end = 1400.0
	def.min_mult = 0.6
	def.pellets = 1
	for key: StringName in overrides:
		# Array[int] props reject an untyped literal from a Dictionary.
		if key == &"fire_modes":
			def.fire_modes.assign(overrides[key])
		else:
			def.set(key, overrides[key])
	return def

func _weapon(overrides: Dictionary = {}) -> WeaponModel:
	return WeaponModel.new(_def(overrides))

func _intent(fire: bool = true, press: bool = false) -> Intent:
	var intent := Intent.new()
	intent.fire = fire
	intent.fire_press = press
	return intent

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _ctx(vel: float = 0.0, focus: bool = false, stance: int = Enums.Stance.STAND,
		arm: float = 1.0, rng: RandomNumberGenerator = null) -> Dictionary:
	return {
		"vel": vel, "vmax": 215.0, "stance": stance, "focus": focus,
		"arm_mult": arm, "rng": rng,
	}

## Advances `seconds` of ticks, firing every tick, returns total shots.
func _fire_for(w: WeaponModel, intent: Intent, seconds: float, ctx: Dictionary) -> int:
	var shots := 0
	for _i: int in int(seconds / DT):
		w.tick(DT, ctx)
		shots += w.try_fire(intent, Vector2.ZERO, Vector2.RIGHT).size()
	return shots


func test_initial_state_full_mag_and_reserve() -> void:
	var w := _weapon()
	assert_int(w.mag).is_equal(30)
	assert_int(w.reserve_rounds).is_equal(150)
	assert_int(w.reserve_mags()).is_equal(5)


func test_fire_interval_from_rpm() -> void:
	assert_float(_weapon().fire_interval()).is_equal_approx(0.1, 0.0001)
	assert_float(_weapon({"rpm": 45.0}).fire_interval()).is_equal_approx(1.333333, 0.0001)


func test_auto_fire_respects_rpm_cap() -> void:
	var w := _weapon()
	var shots := _fire_for(w, _intent(true), 1.0, _ctx())
	assert_int(shots).is_equal(10)


func test_auto_fire_600rpm_shoots_on_first_tick() -> void:
	var w := _weapon()
	w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(1)


func test_auto_fire_stops_when_trigger_released() -> void:
	var w := _weapon()
	var shots := _fire_for(w, _intent(false), 0.5, _ctx())
	assert_int(shots).is_equal(0)


func test_semi_requires_press_edge() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.SEMI]})
	w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true, false), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)


func test_semi_fires_once_per_press() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.SEMI]})
	w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(1)


func test_semi_held_trigger_does_not_repeat() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.SEMI]})
	var shots := 0
	for _i: int in 30:
		w.tick(DT, _ctx())
		shots += w.try_fire(_intent(true, false), Vector2.ZERO, Vector2.RIGHT).size()
	assert_int(shots).is_equal(0)


func test_semi_rpm_cap_blocks_mashing() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.SEMI], "rpm": 420.0})
	w.tick(DT, _ctx())
	w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT)
	w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)


func test_semi_allows_second_shot_after_interval() -> void:
	# 420 RPM → 0.1429 s: 9 ticks at 60 Hz is the first legal trigger.
	var w := _weapon({"fire_modes": [Enums.FireMode.SEMI], "rpm": 420.0})
	w.tick(DT, _ctx())
	w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT)
	for _i: int in 9:
		w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(1)


func test_burst_fires_exact_burst_count() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.BURST], "burst_count": 3})
	var shots := 0
	w.tick(DT, _ctx())
	# One edge press starts the burst; the held trigger carries the rest.
	shots += w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT).size()
	for _i: int in 20:
		w.tick(DT, _ctx())
		shots += w.try_fire(_intent(true, false), Vector2.ZERO, Vector2.RIGHT).size()
	assert_int(shots).is_equal(3)


func test_burst_enforces_pause_after_round_count() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.BURST], "burst_count": 2})
	w.tick(DT, _ctx())
	w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT)
	for _i: int in 10:
		w.tick(DT, _ctx())
		w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT)
	# 2 rounds at 0.1 s interval + 0.25 s pause → next burst not before ~0.45 s.
	assert_int(w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)


func test_burst_does_not_restart_on_a_held_trigger() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.BURST], "burst_count": 2})
	var shots := _fire_for(w, _intent(true, false), 1.0, _ctx())
	assert_int(shots).is_equal(0)


func test_burst_resumes_on_a_new_press_after_pause() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.BURST], "burst_count": 2})
	var shots := _fire_for(w, _intent(true, true), 1.0, _ctx())
	assert_int(shots).is_greater(2)


func test_burst_press_does_not_skip_pause() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.BURST], "burst_count": 3})
	w.tick(DT, _ctx())
	w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT)
	assert_int(w.burst_left).is_equal(2)


func test_bolt_requires_cycle_between_shots() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.BOLT], "rpm": 45.0})
	w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(1)
	w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)


func test_bolt_fires_again_after_cycle_time() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.BOLT], "rpm": 45.0})
	w.tick(DT, _ctx())
	w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT)
	for _i: int in 85:
		w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(1)


func test_pump_uses_the_same_cycle_rule_as_bolt() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.PUMP], "rpm": 70.0})
	w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(1)
	w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)


func test_shotgun_spawns_one_shot_per_pellet() -> void:
	var w := _weapon({"pellets": 8, "damage": 12.0})
	w.tick(DT, _ctx())
	var shots := w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	assert_int(shots.size()).is_equal(8)


func test_shotgun_pellets_cost_one_round() -> void:
	var w := _weapon({"pellets": 8})
	w.tick(DT, _ctx())
	w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	assert_int(w.mag).is_equal(29)


func test_pellets_share_the_shot_damage_stat() -> void:
	var w := _weapon({"pellets": 6, "damage": 10.0})
	w.tick(DT, _ctx())
	var shots := w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	for shot: ShotRequest in shots:
		assert_float(shot.damage).is_equal(10.0)


func test_pellets_spread_apart() -> void:
	var w := _weapon({"pellets": 8, "spread_base": 4.0})
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	w.tick(DT, _ctx(0.0, false, Enums.Stance.STAND, 1.0, rng))
	var shots := w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	var distinct := {}
	for shot: ShotRequest in shots:
		distinct[shot.dir.snappedf(0.001)] = true
	assert_int(distinct.size()).is_greater(1)


func test_shot_request_carries_weapon_data() -> void:
	var w := _weapon({"id": &"kestrel", "damage": 30.0, "bullet_speed": 6200.0,
		"penetration": 1.2, "falloff_start": 500.0, "falloff_end": 1400.0, "min_mult": 0.6})
	w.tick(DT, _ctx())
	var shot: ShotRequest = w.try_fire(_intent(true), Vector2(10.0, 20.0), Vector2.RIGHT)[0]
	assert_vector(shot.origin).is_equal(Vector2(10.0, 20.0))
	assert_float(shot.damage).is_equal(30.0)
	assert_float(shot.speed).is_equal(6200.0)
	assert_float(shot.penetration).is_equal(1.2)
	assert_float(shot.min_mult).is_equal(0.6)
	assert_str(String(shot.weapon_id)).is_equal("kestrel")


func test_dry_fire_sets_flag_on_empty_mag() -> void:
	var w := _weapon()
	w.mag = 0
	w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)
	assert_bool(w.dry_fire).is_true()


func test_dry_fire_clears_on_successful_shot() -> void:
	var w := _weapon()
	w.mag = 0
	w.tick(DT, _ctx())
	w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	w.mag = 5
	for _i: int in 10:
		w.tick(DT, _ctx())
	w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	assert_bool(w.dry_fire).is_false()


func test_dry_fire_does_not_consume_ammo() -> void:
	var w := _weapon()
	w.mag = 0
	w.tick(DT, _ctx())
	w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	assert_int(w.mag).is_equal(0)


func test_mag_decrements_per_trigger_pull() -> void:
	# 600 RPM = 0.1 s interval; 0.35 s of held fire = shots at 0, .1, .2, .3.
	var w := _weapon()
	_fire_for(w, _intent(true), 0.35, _ctx())
	assert_int(w.mag).is_equal(26)


func test_cannot_fire_while_reloading() -> void:
	var w := _weapon()
	w.mag = 10
	w.start_reload()
	w.tick(DT, _ctx())
	assert_int(w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)


func test_reload_starts_only_when_mag_is_not_full() -> void:
	var w := _weapon()
	assert_bool(w.start_reload()).is_false()
	w.mag = 20
	assert_bool(w.start_reload()).is_true()


func test_reload_refused_without_reserve() -> void:
	var w := _weapon()
	w.mag = 0
	w.reserve_rounds = 0
	assert_bool(w.start_reload()).is_false()


func test_reload_progress_reaches_one_and_refills() -> void:
	var w := _weapon()
	w.mag = 0
	w.start_reload()
	for _i: int in 150:
		w.tick(DT, _ctx())
	assert_bool(w.is_reloading()).is_false()
	assert_int(w.mag).is_equal(30)


func test_reload_conserves_total_rounds() -> void:
	var w := _weapon()
	w.mag = 0
	var total_before := w.mag + w.reserve_rounds
	w.start_reload()
	for _i: int in 150:
		w.tick(DT, _ctx())
	assert_int(w.mag + w.reserve_rounds).is_equal(total_before)


func test_reload_from_partial_mag_only_tops_up() -> void:
	var w := _weapon()
	w.mag = 25
	w.start_reload()
	for _i: int in 150:
		w.tick(DT, _ctx())
	assert_int(w.mag).is_equal(30)
	assert_int(w.reserve_rounds).is_equal(145)


func test_partial_reload_with_scarce_reserve_takes_what_exists() -> void:
	var w := _weapon()
	w.mag = 0
	w.reserve_rounds = 12
	w.start_reload()
	for _i: int in 150:
		w.tick(DT, _ctx())
	assert_int(w.mag).is_equal(12)
	assert_int(w.reserve_rounds).is_equal(0)


func test_reload_walks_through_three_stages() -> void:
	var w := _weapon()
	w.mag = 0
	w.start_reload()
	var seen := {}
	for _i: int in 150:
		w.tick(DT, _ctx())
		if w.is_reloading():
			seen[w.reload_stage] = true
	assert_bool(seen.has(WeaponModel.STAGE_MAG_OUT)).is_true()
	assert_bool(seen.has(WeaponModel.STAGE_MAG_IN)).is_true()
	assert_bool(seen.has(WeaponModel.STAGE_BOLT)).is_true()


func test_reload_cancel_leaves_ammo_untouched() -> void:
	var w := _weapon()
	w.mag = 0
	w.start_reload()
	for _i: int in 60:
		w.tick(DT, _ctx())
	w.cancel_reload()
	assert_int(w.mag).is_equal(0)
	assert_int(w.reserve_rounds).is_equal(150)
	assert_bool(w.is_reloading()).is_false()


func test_reload_progress_is_zero_when_idle() -> void:
	assert_float(_weapon().reload_progress()).is_equal(0.0)


func test_reload_progress_is_monotonic() -> void:
	var w := _weapon()
	w.mag = 0
	w.start_reload()
	var last := -1.0
	for _i: int in 140:
		w.tick(DT, _ctx())
		if w.is_reloading():
			var progress := w.reload_progress()
			assert_float(progress).is_greater_equal(last)
			last = progress


func test_crippled_arm_slows_the_reload() -> void:
	var w := _weapon()
	w.mag = 0
	w.reload_mult = BodyModel.CRIPPLED_ARM_RELOAD_MULT
	assert_float(w.effective_reload_time()).is_equal_approx(2.4 * 1.3, 0.001)


func test_crippled_reload_still_refills() -> void:
	var w := _weapon()
	w.mag = 0
	w.reload_mult = 1.3
	w.start_reload()
	for _i: int in 200:
		w.tick(DT, _ctx())
	assert_int(w.mag).is_equal(30)


func test_mode_switch_cycles_supported_modes() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.AUTO, Enums.FireMode.BURST, Enums.FireMode.SEMI]})
	assert_int(w.fire_mode()).is_equal(Enums.FireMode.AUTO)
	assert_bool(w.switch_mode()).is_true()
	assert_int(w.fire_mode()).is_equal(Enums.FireMode.BURST)
	w.switch_mode()
	assert_int(w.fire_mode()).is_equal(Enums.FireMode.SEMI)


func test_mode_switch_wraps_to_first() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.SEMI, Enums.FireMode.AUTO]})
	var seen: Array[int] = []
	for _i: int in 4:
		seen.append(w.fire_mode())
		w.switch_mode()
	assert_array(seen).contains_exactly([Enums.FireMode.SEMI, Enums.FireMode.AUTO,
		Enums.FireMode.SEMI, Enums.FireMode.AUTO])


func test_mode_switch_refused_for_single_mode_weapon() -> void:
	assert_bool(_weapon().switch_mode()).is_false()


func test_mode_switch_clears_pending_burst() -> void:
	var w := _weapon({"fire_modes": [Enums.FireMode.BURST, Enums.FireMode.SEMI], "burst_count": 3})
	w.tick(DT, _ctx())
	w.try_fire(_intent(true, true), Vector2.ZERO, Vector2.RIGHT)
	w.switch_mode()
	assert_int(w.burst_left).is_equal(0)


func test_bloom_accumulates_per_shot() -> void:
	var w := _weapon({"rpm": 100000.0})
	w.tick(DT, _ctx())
	w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	assert_float(w.bloom).is_equal_approx(0.4, 0.001)


func test_bloom_climbs_under_sustained_fire() -> void:
	var w := _weapon({"rpm": 650.0, "bloom_per_shot": 0.4, "bloom_recovery": 0.0})
	var first := 0.0
	for i: int in 10:
		w.tick(0.2, _ctx())
		w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
		if i == 0:
			first = w.bloom
	assert_float(w.bloom).is_greater(first)


func test_bloom_capped_by_def_bloom_max() -> void:
	# WeaponDef.bloom_max is the absolute cone cap: bloom budget = max - base.
	var w := _weapon({"rpm": 100000.0, "bloom_per_shot": 2.0, "bloom_max": 3.0,
		"spread_base": 0.5, "bloom_recovery": 0.0})
	for _i: int in 20:
		w.tick(DT, _ctx())
		w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	assert_float(w.bloom).is_equal_approx(2.5, 0.001)
	assert_float(w.current_spread_deg()).is_equal_approx(3.0, 0.001)


func test_bloom_recovers_when_not_firing() -> void:
	var w := _weapon()
	w.bloom = 4.0
	for _i: int in 60:
		w.tick(DT, _ctx())
	assert_float(w.bloom).is_less(4.0)


func test_bloom_fully_recovers_after_a_second() -> void:
	var w := _weapon({"bloom_recovery": 12.0})
	w.bloom = 5.0
	for _i: int in 60:
		w.tick(DT, _ctx())
	assert_float(w.bloom).is_equal(0.0)


func test_first_shot_from_rest_has_base_spread() -> void:
	var w := _weapon()
	w.tick(DT, _ctx())
	assert_float(w.current_spread_deg()).is_equal_approx(0.5, 0.001)


func test_spread_grows_with_movement() -> void:
	var rest := _weapon()
	rest.tick(DT, _ctx(0.0))
	var running := _weapon()
	running.tick(DT, _ctx(215.0))
	assert_float(running.current_spread_deg()).is_greater(rest.current_spread_deg())


func test_spread_shrinks_when_crouched() -> void:
	var stand := _weapon()
	stand.tick(DT, _ctx())
	var crouch := _weapon()
	crouch.tick(DT, _ctx(0.0, false, Enums.Stance.CROUCH))
	assert_float(crouch.current_spread_deg()).is_less(stand.current_spread_deg())


func test_spread_shrinks_when_focusing() -> void:
	var hip := _weapon()
	hip.tick(DT, _ctx())
	var focus := _weapon()
	focus.tick(DT, _ctx(0.0, true))
	assert_float(focus.current_spread_deg()).is_less(hip.current_spread_deg())


func test_spread_widens_with_crippled_arm() -> void:
	var healthy := _weapon()
	healthy.tick(DT, _ctx())
	var crippled := _weapon()
	crippled.tick(DT, _ctx(0.0, false, Enums.Stance.STAND, 1.6))
	assert_float(crippled.current_spread_deg()).is_greater(healthy.current_spread_deg())


func test_recoil_offset_grows_per_shot() -> void:
	var w := _weapon({"rpm": 100000.0, "recoil_recovery": 0.0})
	w.tick(DT, _ctx())
	w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	assert_float(w.recoil_offset.length()).is_greater(0.0)


func test_recoil_recovers_when_not_firing() -> void:
	var w := _weapon()
	w.recoil_offset = Vector2(0.2, 0.0)
	for _i: int in 60:
		w.tick(DT, _ctx())
	assert_float(w.recoil_offset.length()).is_less(0.2)


func test_focus_dampens_recoil_kick() -> void:
	# Same seed → same lateral jitter, so only the 0.7 damper differs.
	var hip := _weapon({"rpm": 100000.0, "recoil_recovery": 0.0})
	hip.tick(DT, _ctx(0.0, false, Enums.Stance.STAND, 1.0, _rng(11)))
	hip.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	var focus := _weapon({"rpm": 100000.0, "recoil_recovery": 0.0})
	focus.tick(DT, _ctx(0.0, true, Enums.Stance.STAND, 1.0, _rng(11)))
	focus.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	assert_float(focus.recoil_offset.length()).is_less(hip.recoil_offset.length())


func test_crouch_dampens_recoil_kick() -> void:
	var stand := _weapon({"rpm": 100000.0, "recoil_recovery": 0.0})
	stand.tick(DT, _ctx(0.0, false, Enums.Stance.STAND, 1.0, _rng(11)))
	stand.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	var crouch := _weapon({"rpm": 100000.0, "recoil_recovery": 0.0})
	crouch.tick(DT, _ctx(0.0, false, Enums.Stance.CROUCH, 1.0, _rng(11)))
	crouch.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT)
	assert_float(crouch.recoil_offset.length()).is_less(stand.recoil_offset.length())


func test_equip_blocks_firing_until_done() -> void:
	var w := _weapon({"equip_time": 0.6})
	w.equip()
	w.tick(DT, _ctx())
	assert_bool(w.is_equipped()).is_false()
	assert_int(w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)


func test_equip_allows_firing_after_equip_time() -> void:
	var w := _weapon({"equip_time": 0.3})
	w.equip()
	for _i: int in 20:
		w.tick(DT, _ctx())
	assert_bool(w.is_equipped()).is_true()
	assert_int(w.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(1)


func test_equip_blocks_reload_start() -> void:
	var w := _weapon({"equip_time": 0.6})
	w.mag = 0
	w.equip()
	assert_bool(w.start_reload()).is_false()


func test_deterministic_fire_with_seeded_rng() -> void:
	var dirs_a := _fire_dirs(4242)
	var dirs_b := _fire_dirs(4242)
	assert_array(dirs_a).is_equal(dirs_b)


func test_different_seeds_give_different_pellets() -> void:
	assert_array(_fire_dirs(1)).is_not_equal(_fire_dirs(2))


func _fire_dirs(seed_value: int) -> Array:
	var w := _weapon({"pellets": 4, "spread_base": 5.0, "fire_modes": [Enums.FireMode.SEMI],
		"rpm": 600.0})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var intent := _intent(true, true)
	w.tick(DT, _ctx(0.0, false, Enums.Stance.STAND, 1.0, rng))
	var out: Array = []
	for shot: ShotRequest in w.try_fire(intent, Vector2.ZERO, Vector2.RIGHT):
		out.append(shot.dir)
	return out


func test_mag_zero_after_full_auto_dump() -> void:
	var w := _weapon({"rpm": 600.0, "mag_size": 10})
	_fire_for(w, _intent(true), 2.0, _ctx())
	assert_int(w.mag).is_equal(0)


func test_reserve_mags_pips_track_reserve() -> void:
	var w := _weapon()
	w.reserve_rounds = 60
	assert_int(w.reserve_mags()).is_equal(2)