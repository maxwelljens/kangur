extends GdUnitTestSuite
## BodyModel — part HP, armor gradient, bleed, regen, bandage, cripple zones.
## Numbers: docs/design/game-design.md §6/§7; part mults: Enums.PART_DAMAGE_MULT.

const DT := 1.0 / 60.0

## Design §6 roster damage (single-projectile weapons).
const ADDER_DMG := 24.0
const KESTREL_DMG := 30.0
const LYNX_DMG := 110.0

func _body(vest: bool = true, helmet: bool = true) -> BodyModel:
	return BodyModel.new(vest, helmet)

func _run(body: BodyModel, seconds: float) -> BodyModel:
	for _i: int in int(seconds / DT):
		body.tick(DT)
	return body

## Applies `count` hits and returns the last HitResult.
func _hits(body: BodyModel, part: int, dmg: float, count: int, pen: float = 1.0) -> HitResult:
	var last := HitResult.new()
	for _i: int in count:
		last = body.apply_hit(part, dmg, pen)
	return last


func test_part_hp_defaults_match_design() -> void:
	var b := _body()
	assert_float(b.part_hp(Enums.Part.HEAD)).is_equal(35.0)
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal(80.0)
	assert_float(b.part_hp(Enums.Part.ARM_L)).is_equal(18.0)
	assert_float(b.part_hp(Enums.Part.ARM_R)).is_equal(18.0)
	assert_float(b.part_hp(Enums.Part.LEG_L)).is_equal(22.0)
	assert_float(b.part_hp(Enums.Part.LEG_R)).is_equal(22.0)


func test_body_starts_alive_and_unhurt() -> void:
	var b := _body()
	assert_bool(b.alive).is_true()
	assert_bool(b.is_bleeding_any()).is_false()
	assert_float(b.bleed_rate_total()).is_equal(0.0)


func test_head_zone_multiplies_damage_by_three() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.HEAD, 10.0, 1.0)
	assert_float(b.part_hp(Enums.Part.HEAD)).is_equal(5.0)


func test_torso_zone_multiplies_damage_by_one() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.TORSO, 30.0, 1.0)
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal(50.0)


func test_arm_zone_multiplies_damage_by_075() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	assert_float(b.part_hp(Enums.Part.ARM_L)).is_equal_approx(18.0 - 15.0, 0.001)


func test_leg_zone_multiplies_damage_by_08() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.LEG_L, 20.0, 1.0)
	assert_float(b.part_hp(Enums.Part.LEG_L)).is_equal_approx(22.0 - 16.0, 0.001)


func test_unprotected_head_is_lethal_from_any_weapon() -> void:
	# Design §6: head 35 × 3.0 → even a 12 dmg shotgun pellet (36) kills.
	var b := _body(false, false)
	var result := b.apply_hit(Enums.Part.HEAD, 12.0, 1.0)
	assert_bool(result.died).is_true()
	assert_bool(b.alive).is_false()


func test_unprotected_head_headshot_kills_with_pistol() -> void:
	var b := _body(false, false)
	var result := b.apply_hit(Enums.Part.HEAD, ADDER_DMG, 1.0)
	assert_bool(result.died).is_true()
	assert_int(result.fatal_part).is_equal(Enums.Part.HEAD)


func test_helmet_survives_one_pistol_headshot() -> void:
	# 24 × 3.0 = 72 raw; helmet absorbs 60% → 28.8; head 35 − 28.8 = 6.2.
	var b := _body(false, true)
	var result := b.apply_hit(Enums.Part.HEAD, ADDER_DMG, 1.0)
	assert_bool(result.died).is_false()
	assert_float(b.part_hp(Enums.Part.HEAD)).is_equal_approx(6.2, 0.01)


func test_helmet_dies_to_rifle_headshot() -> void:
	# 30 × 3.0 = 90 raw; absorbs 54 → 36 ≥ 35.
	var b := _body(false, true)
	var result := b.apply_hit(Enums.Part.HEAD, KESTREL_DMG, 1.0)
	assert_bool(result.died).is_true()


func test_helmet_durability_decreases_per_hit() -> void:
	var b := _body(false, true)
	var before := b.helmet_durability
	b.apply_hit(Enums.Part.HEAD, ADDER_DMG, 1.0)
	assert_float(b.helmet_durability).is_less(before)


func test_helmet_breaks_after_enough_hits() -> void:
	var b := _body(false, true)
	_hits(b, Enums.Part.HEAD, ADDER_DMG, 4)
	assert_float(b.helmet_durability).is_equal(0.0)


func test_broken_helmet_stops_absorbing() -> void:
	var b := _body(false, true)
	b.helmet_durability = 0.0
	var result := b.apply_hit(Enums.Part.HEAD, ADDER_DMG, 1.0)
	assert_float(result.absorbed).is_equal(0.0)
	assert_bool(result.died).is_true()


func test_vest_absorbs_40_percent_of_torso_damage() -> void:
	var b := _body(true, false)
	var result := b.apply_hit(Enums.Part.TORSO, KESTREL_DMG, 1.0)
	assert_float(result.absorbed).is_equal_approx(12.0, 0.001)
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal_approx(62.0, 0.001)


func test_vest_extends_torso_hits_to_kill() -> void:
	# Unarmored: 3 × 30 = 90 ≥ 80. Vested: 18/hit → 5 hits.
	var unarmored := _body(false, false)
	assert_bool(_hits(unarmored, Enums.Part.TORSO, KESTREL_DMG, 3).died).is_true()
	var vested := _body(true, false)
	assert_bool(_hits(vested, Enums.Part.TORSO, KESTREL_DMG, 4).died).is_false()
	assert_bool(vested.apply_hit(Enums.Part.TORSO, KESTREL_DMG, 1.0).died).is_true()


func test_vest_does_not_protect_limbs() -> void:
	var b := _body(true, true)
	var result := b.apply_hit(Enums.Part.ARM_L, 10.0, 1.0)
	assert_float(result.absorbed).is_equal(0.0)


func test_vest_durability_decreases_per_hit() -> void:
	var b := _body(true, false)
	var before := b.vest_durability
	b.apply_hit(Enums.Part.TORSO, KESTREL_DMG, 1.0)
	assert_float(b.vest_durability).is_less(before)


func test_penetration_multiplier_applies_before_armor() -> void:
	# 30 × 1 × 0.55 = 16.5 raw, vest absorbs 6.6 → 9.9.
	var b := _body(true, false)
	b.apply_hit(Enums.Part.TORSO, KESTREL_DMG, 0.55)
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal_approx(80.0 - 9.9, 0.01)


func test_torso_zero_is_death() -> void:
	var b := _body(false, false)
	var result := _hits(b, Enums.Part.TORSO, KESTREL_DMG, 3)
	assert_bool(result.died).is_true()
	assert_int(result.fatal_part).is_equal(Enums.Part.TORSO)


func test_head_zero_is_death() -> void:
	var b := _body(false, false)
	assert_bool(b.apply_hit(Enums.Part.HEAD, KESTREL_DMG, 1.0).died).is_true()


func test_limb_zero_does_not_kill() -> void:
	var b := _body()
	_hits(b, Enums.Part.ARM_L, 40.0, 3)
	assert_bool(b.alive).is_true()
	assert_float(b.part_hp(Enums.Part.ARM_L)).is_equal(0.0)


func test_hits_on_a_dead_body_are_ignored() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.HEAD, KESTREL_DMG, 1.0)
	var result := b.apply_hit(Enums.Part.TORSO, KESTREL_DMG, 1.0)
	assert_bool(result.died).is_false()
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal(80.0)


func test_part_hp_never_goes_negative() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 500.0, 1.0)
	assert_float(b.part_hp(Enums.Part.ARM_L)).is_equal(0.0)


func test_limb_below_half_starts_bleeding() -> void:
	var b := _body()
	var result := b.apply_hit(Enums.Part.LEG_L, 20.0, 1.0)   # 16 dmg → 6/22
	assert_float(result.bleed_added).is_equal(BodyModel.LIMB_BLEED_RATE)
	assert_float(b.bleed_rate_total()).is_equal(1.5)


func test_limb_above_half_does_not_bleed() -> void:
	var b := _body()
	var result := b.apply_hit(Enums.Part.LEG_L, 5.0, 1.0)   # 4 dmg → 18/22
	assert_float(result.bleed_added).is_equal(0.0)
	assert_bool(b.is_bleeding(Enums.Part.LEG_L)).is_false()


func test_torso_below_35_percent_starts_bleeding_harder() -> void:
	var b := _body(false, false)
	var result := _hits(b, Enums.Part.TORSO, KESTREL_DMG, 2)   # 20/80 = 25%
	assert_float(result.bleed_added).is_equal(BodyModel.TORSO_BLEED_RATE)
	assert_float(b.bleed_rate_total()).is_equal(2.5)


func test_bleed_stacks_across_parts() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	b.apply_hit(Enums.Part.LEG_R, 20.0, 1.0)
	assert_float(b.bleed_rate_total()).is_equal(3.0)


func test_bleed_does_not_stack_on_the_same_part() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	var again := b.apply_hit(Enums.Part.ARM_L, 5.0, 1.0)
	assert_float(again.bleed_added).is_equal(0.0)
	assert_float(b.bleed_rate_total()).is_equal(1.5)


func test_bleed_drains_torso_over_time() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	_run(b, 2.0)
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal_approx(80.0 - 3.0, 0.05)


func test_bleed_can_kill_through_the_torso_pool() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	b.apply_hit(Enums.Part.TORSO, 5.0, 1.0)
	b.hp[Enums.Part.TORSO] = 2.0
	_run(b, 2.0)
	assert_bool(b.alive).is_false()


func test_bandage_requires_a_wound() -> void:
	assert_bool(_body().start_bandage()).is_false()


func test_bandage_starts_when_bleeding() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	assert_bool(b.start_bandage()).is_true()
	assert_bool(b.bandaging).is_true()


func test_bandage_completes_after_28_seconds() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	b.start_bandage()
	_run(b, 2.7)
	assert_bool(b.bandaging).is_true()
	_run(b, 0.2)
	assert_bool(b.bandaging).is_false()


func test_bandage_stops_the_bleed() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	b.start_bandage()
	_run(b, 3.0)
	assert_bool(b.is_bleeding_any()).is_false()


func test_bandage_heals_the_part_by_25() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)   # 6/18
	b.start_bandage()
	_run(b, 3.0)
	assert_float(b.part_hp(Enums.Part.ARM_L)).is_equal(18.0)


func test_bandage_heal_is_capped_at_part_max() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.LEG_L, 10.0, 1.0)   # 14/22, heals to max
	b.start_bandage()
	_run(b, 3.0)
	assert_float(b.part_hp(Enums.Part.LEG_L)).is_equal(22.0)


func test_bandage_picks_the_worst_bleeding_part() -> void:
	var b := _body(false, false)
	b.hp[Enums.Part.TORSO] = 20.0
	b.apply_hit(Enums.Part.TORSO, 1.0, 1.0)      # 2.5/s torso bleed
	b.hp[Enums.Part.ARM_L] = 5.0
	b.apply_hit(Enums.Part.ARM_L, 1.0, 1.0)      # 1.5/s limb bleed
	b.start_bandage()
	_run(b, 3.0)
	assert_bool(b.is_bleeding(Enums.Part.TORSO)).is_false()
	assert_bool(b.is_bleeding(Enums.Part.ARM_L)).is_true()


func test_bandage_interrupt_clears_progress() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	b.start_bandage()
	_run(b, 1.0)
	assert_float(b.bandage_progress).is_greater(0.0)
	b.interrupt_bandage()
	assert_float(b.bandage_progress).is_equal(0.0)
	assert_bool(b.bandaging).is_false()


func test_damage_interrupts_the_bandage() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	b.start_bandage()
	_run(b, 1.0)
	b.apply_hit(Enums.Part.LEG_L, 5.0, 1.0)
	assert_bool(b.bandaging).is_false()


func test_interrupted_bandage_does_not_heal() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	var before := b.part_hp(Enums.Part.ARM_L)
	b.start_bandage()
	_run(b, 1.0)
	b.interrupt_bandage()
	_run(b, 3.0)
	assert_float(b.part_hp(Enums.Part.ARM_L)).is_equal(before)


func test_torso_regen_starts_after_seven_seconds() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.TORSO, KESTREL_DMG, 1.0)   # 50/80
	_run(b, 6.9)
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal_approx(50.0, 0.01)
	_run(b, 0.5)
	assert_float(b.part_hp(Enums.Part.TORSO)).is_greater(50.0)


func test_torso_regen_rate_is_two_per_second() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.TORSO, KESTREL_DMG, 1.0)
	_run(b, 9.0)   # 7 s delay + 2 s regen
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal_approx(54.0, 0.2)


func test_torso_regen_caps_at_70_percent() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.TORSO, KESTREL_DMG, 1.0)
	_run(b, 30.0)
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal_approx(56.0, 0.01)


func test_limbs_do_not_regen() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.LEG_L, 20.0, 1.0)   # 6/22 → bleeding, stops regen anyway
	b.hp[Enums.Part.LEG_L] = 10.0
	_run(b, 20.0)
	assert_float(b.part_hp(Enums.Part.LEG_L)).is_equal(10.0)


func test_damage_resets_the_regen_timer() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.TORSO, KESTREL_DMG, 1.0)
	_run(b, 6.0)
	b.apply_hit(Enums.Part.LEG_L, 5.0, 1.0)   # untouched torso value, resets timer
	_run(b, 1.5)
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal_approx(50.0, 0.01)


func test_bleeding_blocks_regen() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.TORSO, KESTREL_DMG, 1.0)   # 50/80
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)          # limb bleed → regen gated
	_run(b, 10.0)
	# Bleed drains the torso pool and regen never starts while bleeding.
	assert_float(b.part_hp(Enums.Part.TORSO)).is_less(50.0)


func test_cripple_threshold_leg_at_30_percent() -> void:
	var b := _body()
	b.hp[Enums.Part.LEG_L] = 7.0    # 31.8%
	assert_bool(b.is_crippled(Enums.Part.LEG_L)).is_false()
	b.hp[Enums.Part.LEG_L] = 6.0    # 27.3%
	assert_bool(b.is_crippled(Enums.Part.LEG_L)).is_true()


func test_cripple_returns_the_crossing_part() -> void:
	var b := _body()
	b.hp[Enums.Part.LEG_R] = 7.0
	var result := b.apply_hit(Enums.Part.LEG_R, 1.0, 1.0)
	assert_int(result.crippled).is_equal(Enums.Part.LEG_R)


func test_cripple_is_reported_once() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.LEG_R, 20.0, 1.0)
	var second := b.apply_hit(Enums.Part.LEG_R, 1.0, 1.0)
	assert_int(second.crippled).is_equal(-1)


func test_crippled_leg_slows_movement() -> void:
	var b := _body()
	b.hp[Enums.Part.LEG_L] = 1.0
	assert_float(b.speed_mult()).is_equal(BodyModel.CRIPPLED_LEG_SPEED_MULT)


func test_crippled_leg_forbids_sprinting() -> void:
	var b := _body()
	b.hp[Enums.Part.LEG_R] = 1.0
	assert_bool(b.can_sprint()).is_false()


func test_healthy_body_has_neutral_multipliers() -> void:
	var b := _body()
	assert_float(b.speed_mult()).is_equal(1.0)
	assert_float(b.spread_mult()).is_equal(1.0)
	assert_float(b.reload_mult()).is_equal(1.0)
	assert_bool(b.can_sprint()).is_true()


func test_crippled_arm_widens_spread_and_slows_reload() -> void:
	var b := _body()
	b.hp[Enums.Part.ARM_L] = 1.0
	assert_float(b.spread_mult()).is_equal(BodyModel.CRIPPLED_ARM_SPREAD_MULT)
	assert_float(b.reload_mult()).is_equal(BodyModel.CRIPPLED_ARM_RELOAD_MULT)


func test_crippled_arm_does_not_slow_movement() -> void:
	var b := _body()
	b.hp[Enums.Part.ARM_R] = 1.0
	assert_float(b.speed_mult()).is_equal(1.0)


func test_crippled_leg_does_not_widen_spread() -> void:
	var b := _body()
	b.hp[Enums.Part.LEG_L] = 1.0
	assert_float(b.spread_mult()).is_equal(1.0)


func test_part_at_offset_centre_is_head() -> void:
	assert_int(BodyModel.part_at_offset(Vector2.ZERO)).is_equal(Enums.Part.HEAD)


func test_part_at_offset_forward_tip_is_head() -> void:
	assert_int(BodyModel.part_at_offset(Vector2(5.0, 0.0))).is_equal(Enums.Part.HEAD)


func test_part_at_offset_beyond_head_radius_is_torso() -> void:
	assert_int(BodyModel.part_at_offset(Vector2(9.0, 0.0))).is_equal(Enums.Part.TORSO)


func test_part_at_offset_side_is_arm() -> void:
	assert_int(BodyModel.part_at_offset(Vector2(0.0, 7.0))).is_equal(Enums.Part.ARM_R)
	assert_int(BodyModel.part_at_offset(Vector2(0.0, -7.0))).is_equal(Enums.Part.ARM_L)


func test_part_at_offset_rear_is_leg() -> void:
	assert_int(BodyModel.part_at_offset(Vector2(-6.0, 0.0))).is_equal(Enums.Part.LEG_L)


func test_part_at_offset_rear_right_is_right_leg() -> void:
	assert_int(BodyModel.part_at_offset(Vector2(-6.0, 3.0))).is_equal(Enums.Part.LEG_R)


func test_part_at_offset_wide_rear_is_leg() -> void:
	assert_int(BodyModel.part_at_offset(Vector2(-3.0, 9.0))).is_equal(Enums.Part.LEG_R)


func test_part_at_offset_front_shoulders_are_torso() -> void:
	assert_int(BodyModel.part_at_offset(Vector2(4.0, 5.0))).is_equal(Enums.Part.TORSO)


func test_part_at_offset_covers_every_part() -> void:
	var seen := {}
	for x: float in [-8.0, -2.0, 2.0, 6.0, 10.0]:
		for y: float in [-9.0, -3.0, 0.0, 3.0, 9.0]:
			seen[BodyModel.part_at_offset(Vector2(x, y))] = true
	assert_int(seen.size()).is_equal(Enums.PART_COUNT)


func test_part_at_offset_mirrors_arms_and_legs() -> void:
	assert_int(BodyModel.part_at_offset(Vector2(0.0, 7.0))).is_equal(Enums.Part.ARM_R)
	assert_int(BodyModel.part_at_offset(Vector2(0.0, -7.0))).is_equal(Enums.Part.ARM_L)
	assert_int(BodyModel.part_at_offset(Vector2(-8.0, 2.0))).is_equal(Enums.Part.LEG_R)
	assert_int(BodyModel.part_at_offset(Vector2(-8.0, -2.0))).is_equal(Enums.Part.LEG_L)


func test_bandage_refused_when_dead() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.HEAD, KESTREL_DMG, 1.0)
	assert_bool(b.start_bandage()).is_false()


func test_bandage_refused_while_already_channeling() -> void:
	var b := _body()
	b.apply_hit(Enums.Part.ARM_L, 20.0, 1.0)
	assert_bool(b.start_bandage()).is_true()
	assert_bool(b.start_bandage()).is_false()


func test_dead_body_stops_processing_ticks() -> void:
	var b := _body(false, false)
	b.apply_hit(Enums.Part.HEAD, KESTREL_DMG, 1.0)
	var snapshot := b.part_hp(Enums.Part.TORSO)
	_run(b, 5.0)
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal(snapshot)


func test_lynx_torso_shot_is_lethal_unarmored() -> void:
	var b := _body(false, false)
	assert_bool(b.apply_hit(Enums.Part.TORSO, LYNX_DMG, 1.0).died).is_true()


func test_lynx_through_a_fresh_vest_leaves_the_target_alive() -> void:
	# 110 raw, vest soaks 44 → 66 into an 80 HP torso: the sniper one-shot is
	# a no-armor property. Design §6's "torso one-shot" is a content statement,
	# so this pins the armour interaction rather than the roster table.
	var b := _body(true, false)
	assert_bool(b.apply_hit(Enums.Part.TORSO, LYNX_DMG, 1.0).died).is_false()
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal_approx(14.0, 0.01)