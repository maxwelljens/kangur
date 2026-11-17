extends GdUnitTestSuite
## Perk injection points added to the pure models: Ram's cycle ×0.8 on bolt/pump
## actions and Longshot's focus spread ×0.4 instead of ×0.55. Both are additive
## fields on WeaponModel fed by Arsenal.apply_perks (design §8).

const DT := 1.0 / 60.0

func _def(modes: Array[int], rpm: float) -> WeaponDef:
	var def := WeaponDef.new()
	def.id = &"test"
	def.display_name = "Test"
	def.rpm = rpm
	def.mag_size = 10
	def.reserve_mags = 2
	def.equip_time = 0.0
	def.damage = 20.0
	def.spread_base = 1.0
	def.bloom_per_shot = 0.0
	def.bloom_max = 5.0
	def.bloom_recovery = 4.0
	def.recoil_kick = 0.0
	def.recoil_recovery = 0.0
	def.fire_modes.assign(modes)
	return def

func _intent(press: bool) -> Intent:
	var intent := Intent.new()
	intent.fire_press = press
	return intent

## ---- Ram: pump/bolt cycle ×0.8 ---------------------------------------------

func test_cycle_mult_shortens_pump_cycle_only() -> void:
	var pump := WeaponModel.new(_def([Enums.FireMode.PUMP], 70.0))
	var base_interval := pump.cycle_interval()
	pump.cycle_mult = 0.8
	assert_float(pump.cycle_interval()).is_equal_approx(base_interval * 0.8, 0.0001)
	# The raw RPM interval is untouched: only the action cycle is perk-shortened.
	assert_float(pump.fire_interval()).is_equal_approx(base_interval, 0.0001)

func test_cycle_mult_ignores_automatic_cadence() -> void:
	var auto := WeaponModel.new(_def([Enums.FireMode.AUTO], 600.0))
	auto.cycle_mult = 0.8
	assert_float(auto.cycle_interval()).is_equal_approx(auto.fire_interval(), 0.0001)

func test_ram_pump_fires_sooner_than_the_stock_pump() -> void:
	# Pump at 70 RPM = 0.857 s; ×0.8 → 0.686 s. 45 ticks (0.75 s) is between.
	var stock := WeaponModel.new(_def([Enums.FireMode.PUMP], 70.0))
	var ram := WeaponModel.new(_def([Enums.FireMode.PUMP], 70.0))
	ram.cycle_mult = 0.8
	assert_int(stock.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(1)
	assert_int(ram.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(1)
	var ctx := {}
	for _i: int in 45:
		stock.tick(DT, ctx)
		ram.tick(DT, ctx)
	assert_int(stock.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)
	assert_int(ram.try_fire(_intent(true), Vector2.ZERO, Vector2.RIGHT).size()).is_equal(1)


## ---- Longshot: focus spread ×0.4 -------------------------------------------

func test_focus_override_replaces_the_default_focus_mult() -> void:
	var w := WeaponModel.new(_def([Enums.FireMode.SEMI], 300.0))
	w.tick(DT, {&"focus": true})
	var stock := w.current_spread_deg()
	w.focus_spread_override = 0.4
	assert_float(w.current_spread_deg()).is_equal_approx(stock * 0.4 / 0.55, 0.0001)

func test_focus_override_zero_keeps_the_default() -> void:
	var w := WeaponModel.new(_def([Enums.FireMode.SEMI], 300.0))
	w.tick(DT, {&"focus": true})
	var focused := w.current_spread_deg()
	w.tick(DT, {&"focus": false})
	var unbraced := w.current_spread_deg()
	assert_float(focused).is_equal_approx(unbraced * Ballistics.FOCUS_SPREAD_MULT, 0.0001)

func test_focus_override_does_nothing_when_not_focused() -> void:
	var w := WeaponModel.new(_def([Enums.FireMode.SEMI], 300.0))
	w.tick(DT, {&"focus": false})
	var plain := w.current_spread_deg()
	w.focus_spread_override = 0.4
	assert_float(w.current_spread_deg()).is_equal_approx(plain, 0.0001)


## ---- Arsenal feeds both fields ---------------------------------------------

func test_arsenal_apply_perks_pushes_cycle_and_focus_into_the_weapons() -> void:
	var host := CharacterBody2D.new()
	add_child(host)
	auto_free(host)
	var arsenal: Node = preload("res://src/entities/arsenal.gd").new()
	host.add_child(arsenal)
	auto_free(arsenal)
	arsenal.setup(host, null, &"kestrel",
		&"", _def([Enums.FireMode.PUMP], 70.0), _def([Enums.FireMode.BOLT], 45.0))
	arsenal.apply_perks(0.9, 0.8, 0.4)
	assert_float(arsenal.current().cycle_mult).is_equal(0.8)
	assert_float(arsenal.current().focus_spread_override).is_equal(0.4)
	assert_float(arsenal.current().reload_mult).is_equal(0.9)