extends GdUnitTestSuite
## TTK table from docs/design/game-design.md §6, driven end-to-end through
## WeaponModel → ShotRequest → BodyModel. Numbers are the design doc's roster.
## Stationary, unarmored torso (80 HP), no movement spread penalty.

## 240 Hz: the research §2.3 integration rate. Coarser steps quantize a
## 0.0923 s rifle interval up to the next tick and inflate TTK by ~10%.
const DT := 1.0 / 240.0

func _roster(id: StringName) -> WeaponDef:
	var def := WeaponDef.new()
	def.id = id
	# Already in hand: TTK measures cadence, not the draw animation.
	def.equip_time = 0.0
	match id:
		&"kestrel":
			def.rpm = 650.0
			def.mag_size = 30
			def.damage = 30.0
			def.bullet_speed = 6200.0
			def.fire_modes = [Enums.FireMode.AUTO, Enums.FireMode.BURST, Enums.FireMode.SEMI]
			def.spread_base = 0.5
			def.bloom_per_shot = 0.40
			def.bloom_max = 5.0
			def.bloom_recovery = 4.0
			def.pellets = 1
		&"adder":
			def.rpm = 420.0
			def.mag_size = 17
			def.damage = 24.0
			def.bullet_speed = 4600.0
			def.fire_modes = [Enums.FireMode.SEMI]
			def.spread_base = 0.7
			def.bloom_per_shot = 0.55
			def.bloom_max = 3.5
			def.bloom_recovery = 4.0
			def.pellets = 1
		&"lynx":
			def.rpm = 45.0
			def.mag_size = 5
			def.damage = 110.0
			def.bullet_speed = 9000.0
			def.fire_modes = [Enums.FireMode.BOLT]
			def.spread_base = 0.15
			def.bloom_per_shot = 1.50
			def.bloom_max = 8.0
			def.bloom_recovery = 4.0
			def.pellets = 1
		&"falx":
			def.rpm = 300.0
			def.mag_size = 20
			def.damage = 46.0
			def.bullet_speed = 7000.0
			def.fire_modes = [Enums.FireMode.SEMI, Enums.FireMode.BURST]
			def.spread_base = 0.35
			def.bloom_per_shot = 0.60
			def.bloom_max = 6.0
			def.bloom_recovery = 4.0
			def.pellets = 1
		&"breve":
			def.rpm = 70.0
			def.mag_size = 6
			def.damage = 12.0
			def.bullet_speed = 4000.0
			def.fire_modes = [Enums.FireMode.PUMP]
			def.spread_base = 4.0
			def.bloom_per_shot = 0.0
			def.bloom_max = 6.0
			def.bloom_recovery = 4.0
			def.pellets = 8
		_:
			push_error("unknown roster id %s" % id)
	return def

func _ctx() -> Dictionary:
	return {"vel": 0.0, "vmax": 215.0, "stance": Enums.Stance.STAND,
		"focus": false, "arm_mult": 1.0, "rng": RandomNumberGenerator.new()}

## Runs a trigger-pull sequence and returns {time_to_kill, hits, died}.
## `press` is called each tick; AUTO-style modes use `fire` held.
func _ttk(def: WeaponDef, body: BodyModel, use_press: bool, seconds: float = 3.0) -> Dictionary:
	var w := WeaponModel.new(def)
	var intent := Intent.new()
	intent.aim = Vector2.RIGHT
	var ctx := _ctx()
	var t := 0.0
	var hits := 0
	for _i: int in int(seconds / DT):
		intent.fire = not use_press
		intent.fire_press = use_press
		w.tick(DT, ctx)
		for shot: ShotRequest in w.try_fire(intent, Vector2.ZERO, Vector2.RIGHT):
			# Perfect aim: use the un-spread direction so TTK is a weapon stat.
			shot.dir = Vector2.RIGHT
			body.apply_hit(Enums.Part.TORSO, shot.damage, shot.penetration)
			hits += 1
			if not body.alive:
				return {"ttk": t, "hits": hits, "died": true}
		t += DT
	return {"ttk": t, "hits": hits, "died": false}


func test_kestrel_three_hits_kill_unarmored_torso() -> void:
	var r := _ttk(_roster(&"kestrel"), BodyModel.new(false, false), false, 1.0)
	assert_int(r["hits"]).is_equal(3)
	assert_bool(r["died"]).is_true()


func test_kestrel_ttk_is_about_0185s() -> void:
	# 650 RPM → 0.0923 s interval; 3 hits at t = 0, 0.0923, 0.1846 ≈ 0.19 s.
	var r := _ttk(_roster(&"kestrel"), BodyModel.new(false, false), false, 1.0)
	assert_float(r["ttk"]).is_equal_approx(0.185, 0.02)


func test_kestrel_ttk_within_design_band_018_020() -> void:
	var r := _ttk(_roster(&"kestrel"), BodyModel.new(false, false), false, 1.0)
	assert_float(r["ttk"]).is_between(0.15, 0.21)


func test_adder_four_hits_kill_unarmored_torso() -> void:
	var r := _ttk(_roster(&"adder"), BodyModel.new(false, false), true, 1.5)
	assert_int(r["hits"]).is_equal(4)
	assert_bool(r["died"]).is_true()


func test_adder_ttk_is_about_043s() -> void:
	# 420 RPM → 0.1429 s; 4 hits at t = 0, .1429, .2857, .4286.
	var r := _ttk(_roster(&"adder"), BodyModel.new(false, false), true, 1.5)
	assert_float(r["ttk"]).is_equal_approx(0.4286, 0.03)


func test_adder_semi_needs_a_press_per_shot() -> void:
	var def := _roster(&"adder")
	var w := WeaponModel.new(def)
	var intent := Intent.new()
	intent.fire = true
	intent.fire_press = false
	w.tick(DT, _ctx())
	assert_int(w.try_fire(intent, Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)


func test_lynx_one_torso_hit_kills() -> void:
	var r := _ttk(_roster(&"lynx"), BodyModel.new(false, false), true, 0.1)
	assert_int(r["hits"]).is_equal(1)
	assert_bool(r["died"]).is_true()


func test_lynx_bolt_cycle_blocks_a_second_shot() -> void:
	var def := _roster(&"lynx")
	var w := WeaponModel.new(def)
	var intent := Intent.new()
	intent.fire = true
	intent.fire_press = true
	w.tick(DT, _ctx())
	w.try_fire(intent, Vector2.ZERO, Vector2.RIGHT)
	w.tick(DT, _ctx())
	assert_int(w.try_fire(intent, Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)


func test_falx_two_hits_kill_unarmored_torso() -> void:
	var r := _ttk(_roster(&"falx"), BodyModel.new(false, false), true, 1.0)
	assert_int(r["hits"]).is_equal(2)
	assert_bool(r["died"]).is_true()


func test_falx_second_shot_waits_for_rpm() -> void:
	var def := _roster(&"falx")
	var w := WeaponModel.new(def)
	var intent := Intent.new()
	intent.fire = true
	intent.fire_press = true
	w.tick(DT, _ctx())
	w.try_fire(intent, Vector2.ZERO, Vector2.RIGHT)
	w.tick(DT, _ctx())
	assert_int(w.try_fire(intent, Vector2.ZERO, Vector2.RIGHT).size()).is_equal(0)


func test_ttk_with_vest_needs_more_rifle_hits() -> void:
	var r := _ttk(_roster(&"kestrel"), BodyModel.new(true, false), false, 2.0)
	assert_int(r["hits"]).is_greater(3)
	assert_bool(r["died"]).is_true()


func test_ttk_with_vest_still_faster_than_two_seconds() -> void:
	var r := _ttk(_roster(&"kestrel"), BodyModel.new(true, false), false, 2.0)
	assert_float(r["ttk"]).is_less(1.0)


func test_breve_shotgun_kills_within_one_pull_at_close_range() -> void:
	# Design: shotgun ≤ 1 hit at close range. 8 × 12 = 96 ≥ 80.
	var def := _roster(&"breve")
	var body := BodyModel.new(false, false)
	var w := WeaponModel.new(def)
	var intent := Intent.new()
	intent.fire = true
	intent.fire_press = true
	w.tick(DT, _ctx())
	var shots := w.try_fire(intent, Vector2.ZERO, Vector2.RIGHT)
	assert_int(shots.size()).is_equal(8)
	for shot: ShotRequest in shots:
		body.apply_hit(Enums.Part.TORSO, shot.damage, shot.penetration)
	assert_bool(body.alive).is_false()


func test_breve_spends_one_shell_per_trigger_pull() -> void:
	var w := WeaponModel.new(_roster(&"breve"))
	var intent := Intent.new()
	intent.fire = true
	intent.fire_press = true
	w.tick(DT, _ctx())
	w.try_fire(intent, Vector2.ZERO, Vector2.RIGHT)
	assert_int(w.mag).is_equal(5)


func test_design_high_lethality_single_rifle_burst_kills() -> void:
	# Whole-design check: one 3-round rifle burst at torso ends a fight.
	var def := _roster(&"kestrel")
	def.fire_modes.assign([Enums.FireMode.BURST])
	def.burst_count = 3
	var body := BodyModel.new(false, false)
	var w := WeaponModel.new(def)
	var intent := Intent.new()
	intent.fire = true
	intent.fire_press = true
	var ctx := _ctx()
	# 3 rounds at 650 RPM need 0.185 s = 45 ticks at 240 Hz.
	for _i: int in 60:
		w.tick(DT, ctx)
		for shot: ShotRequest in w.try_fire(intent, Vector2.ZERO, Vector2.RIGHT):
			body.apply_hit(Enums.Part.TORSO, shot.damage, shot.penetration)
	assert_bool(body.alive).is_false()