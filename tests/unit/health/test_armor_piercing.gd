extends GdUnitTestSuite
## Armor-piercing rounds (`WeaponDef.armor_piercing`) bypass vest/helmet
## absorption entirely. design §6: the Lynx torso one-shot is a property of the
## round, so a fresh plate must not turn it into a 2-shot weapon.

const LYNX_DMG := 110.0


func test_ap_lynx_kills_through_a_fresh_vest() -> void:
	var b := BodyModel.new(true, false)
	var result := b.apply_hit(Enums.Part.TORSO, LYNX_DMG, 1.0, null, true)
	assert_float(result.absorbed).is_equal(0.0)
	assert_bool(result.died).is_true()
	assert_float(b.vest_durability).is_equal(BodyModel.VEST_MAX_DURABILITY)


func test_same_round_without_the_ap_flag_survives_the_vest() -> void:
	var b := BodyModel.new(true, false)
	var result := b.apply_hit(Enums.Part.TORSO, LYNX_DMG, 1.0)
	assert_float(result.absorbed).is_equal_approx(44.0, 0.001)
	assert_bool(result.died).is_false()
	assert_float(b.part_hp(Enums.Part.TORSO)).is_equal_approx(14.0, 0.01)