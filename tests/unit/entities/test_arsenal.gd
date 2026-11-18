extends GdUnitTestSuite
## Arsenal + rig/perk contract tests. Arsenal wraps WeaponModel, so ammo and
## mode logic is shared with the pure model; these tests pin the SHELL behaviour
## (slot switching, perk injection, kit throws, event emission).

const ArsenalScript := preload("res://src/entities/arsenal.gd")
const BodyScript := preload("res://src/entities/body.gd")
const Perks := preload("res://src/entities/perks.gd")
const WeaponVisual := preload("res://src/entities/weapon_visual.gd")

const KESTREL := &"kestrel"
const ADDER := &"adder"

func _class_def(overrides: Dictionary = {}) -> ClassDef:
	var def := ClassDef.new()
	def.id = &"vanguard"
	def.display_name = "Vanguard"
	def.armor_vest = 60.0
	def.bandages = 3
	def.sidearm_id = ADDER
	def.equipment = [&"frag", &"flash"]
	for key: StringName in overrides:
		def.set(key, overrides[key])
	return def

## Arsenal needs a host Node2D for world positions and aim_dir.
func _arsenal(class_def: ClassDef = null, primary: StringName = KESTREL,
		primary_def: WeaponDef = null, sidearm_def: WeaponDef = null) -> Node:
	var host := Node2D.new()
	add_child(host)
	auto_free(host)
	var arsenal: Node = ArsenalScript.new()
	host.add_child(arsenal)
	auto_free(arsenal)
	arsenal.setup(host, class_def if class_def != null else _class_def(), primary,
		&"", primary_def if primary_def != null else _weapon_def(&"ar"),
		sidearm_def if sidearm_def != null else _weapon_def(&"pistol"))
	return arsenal

## Synthetic defs: data/ ships weapons in the content wave; the shell contract
## must hold before that (and in the zero-content boot).
func _weapon_def(category: StringName) -> WeaponDef:
	var def := WeaponDef.new()
	def.id = StringName("%s_test" % category)
	def.display_name = String(category)
	def.category = category
	def.weight = 3.5
	def.reload_time = 2.4
	def.fire_modes = [Enums.FireMode.AUTO, Enums.FireMode.SEMI]
	return def

func _ctx(vel: float = 0.0) -> Dictionary:
	return {&"vel": vel, &"vmax": 215.0, &"stance": Enums.Stance.STAND,
		&"focus": false, &"arm_mult": 1.0, &"rng": _rng()}

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng

func _trigger() -> Intent:
	var intent := Intent.new()
	intent.fire = true
	intent.fire_press = true
	return intent


func test_setup_equips_primary_and_sidearm() -> void:
	var arsenal := _arsenal()
	assert_object(arsenal.current()).is_not_null()
	assert_str(String(arsenal.current_id())).is_equal("ar_test")
	assert_object(arsenal.sidearm).is_not_null()


func test_missing_primary_falls_back_to_sidearm() -> void:
	# No primary def at all: the class sidearm becomes the drawn weapon.
	var arsenal := _arsenal(null, &"", null, _weapon_def(&"pistol"))
	assert_int(arsenal.slot).is_equal(ArsenalScript.SLOT_SIDEARM)
	assert_str(String(arsenal.current_id())).is_equal("pistol_test")


func test_switch_slot_cancels_reload_and_resets_equip() -> void:
	var arsenal := _arsenal()
	arsenal.current().equip_timer = 0.0
	arsenal.current().mag = 1
	arsenal.start_reload()
	assert_bool(arsenal.current().is_reloading()).is_true()
	assert_bool(arsenal.switch_slot(ArsenalScript.SLOT_SIDEARM)).is_true()
	assert_str(String(arsenal.current_id())).is_equal("pistol_test")
	assert_bool(arsenal.primary.is_reloading()).is_false()
	assert_bool(arsenal.current().is_equipped()).is_false()


func test_switch_slot_to_same_slot_is_rejected() -> void:
	var arsenal := _arsenal()
	assert_bool(arsenal.switch_slot(ArsenalScript.SLOT_PRIMARY)).is_false()


func test_switch_slot_rejects_invalid_index() -> void:
	var arsenal := _arsenal()
	assert_bool(arsenal.switch_slot(ArsenalScript.SLOT_NONE)).is_false()
	assert_bool(arsenal.switch_slot(7)).is_false()


func test_fire_emits_once_per_trigger_pull_with_pellets() -> void:
	var arsenal := _arsenal()
	# Clear the draw delay so the first pull is legal.
	arsenal.current().equip_timer = 0.0
	var emitted: Array = []
	var handler := func(_w: Node, _id: StringName, _o: Vector2, _d: Vector2,
			pellets: int) -> void: emitted.append(pellets)
	EventBus.shot_fired.connect(handler)
	var shots: Array = arsenal.try_fire(_trigger(), Vector2.ZERO, Vector2.RIGHT)
	EventBus.shot_fired.disconnect(handler)
	assert_array(shots).has_size(1)
	assert_array(emitted).has_size(1)


func test_magazine_depletes_and_reload_refills() -> void:
	var arsenal := _arsenal()
	var weapon: WeaponModel = arsenal.current()
	weapon.equip_timer = 0.0
	weapon.mag = 0
	assert_array(arsenal.try_fire(_trigger(), Vector2.ZERO, Vector2.RIGHT)).is_empty()
	assert_bool(arsenal.start_reload()).is_true()
	for _i: int in 240:
		arsenal.tick(1.0 / 60.0, _ctx())
	assert_int(weapon.mag).is_equal(weapon.def.mag_size)


func test_perk_reload_multiplier_shortens_the_channel() -> void:
	var arsenal := _arsenal()
	arsenal.apply_perks(Perks.reload_mult(&"vanguard"), 1.0, 0.0)
	arsenal.current().equip_timer = 0.0
	arsenal.current().mag = 0
	arsenal.start_reload()
	assert_float(arsenal.current().effective_reload_time()) \
		.is_equal_approx(arsenal.current().def.reload_time * 0.9, 0.01)


func test_cycle_mode_emits_and_wraps() -> void:
	var arsenal := _arsenal()
	var modes: Array = []
	var handler := func(_w: Node, mode: int) -> void: modes.append(mode)
	EventBus.fire_mode_changed.connect(handler)
	var changed: bool = arsenal.cycle_mode()
	EventBus.fire_mode_changed.disconnect(handler)
	# Kestrel ships AUTO/BURST/SEMI in data; a zero-content boot may have one.
	if arsenal.current().def.fire_modes.size() > 1:
		assert_bool(changed).is_true()
		assert_array(modes).has_size(1)
	else:
		assert_bool(changed).is_false()


func test_kit_throws_decrement_and_emit() -> void:
	var arsenal := _arsenal()
	var thrown: Array = []
	var handler := func(_w: Node, kind: StringName, _pos: Vector2, _cook: bool) -> void:
		thrown.append(kind)
	EventBus.equipment_thrown.connect(handler)
	var threw: Object = arsenal.throw_equipment(0)
	EventBus.equipment_thrown.disconnect(handler)
	if arsenal.kit_ids.is_empty():
		assert_object(threw).is_null()
	else:
		assert_object(threw).is_not_null()
		assert_int(arsenal.kit_counts[0]).is_equal(0)
		assert_array(thrown).has_size(1)
		# Second throw of an empty entry must be a no-op.
		assert_object(arsenal.throw_equipment(0)).is_null()
		assert_array(thrown).has_size(1)


func test_out_of_range_kit_index_is_null() -> void:
	var arsenal := _arsenal()
	assert_object(arsenal.throw_equipment(-1)).is_null()
	assert_object(arsenal.throw_equipment(99)).is_null()


func test_muzzle_position_uses_barrel_tip_along_aim() -> void:
	var arsenal := _arsenal()
	var host: Node2D = arsenal.get_parent()
	var right: Vector2 = arsenal.muzzle_position(Vector2.RIGHT)
	var down: Vector2 = arsenal.muzzle_position(Vector2.DOWN)
	assert_float(right.x - host.global_position.x) \
		.is_equal_approx(WeaponVisual.muzzle_len(arsenal.current_def()), 0.0001)
	assert_float(down.y - host.global_position.y) \
		.is_equal_approx(WeaponVisual.muzzle_len(arsenal.current_def()), 0.0001)


func test_weapon_silhouettes_differ_by_category() -> void:
	var pistol := _def(&"pistol")
	var rifle := _def(&"ar")
	var sniper := _def(&"sniper")
	assert_float(WeaponVisual.muzzle_len(rifle)).is_greater(WeaponVisual.muzzle_len(pistol))
	assert_float(WeaponVisual.muzzle_len(sniper)).is_greater(WeaponVisual.muzzle_len(rifle))
	var p := WeaponVisual.profile(pistol)
	var s := WeaponVisual.profile(sniper)
	assert_float(float(s[&"barrel_len"])).is_greater(float(p[&"barrel_len"]))


func _def(category: StringName) -> WeaponDef:
	var def := WeaponDef.new()
	def.id = category
	def.category = category
	def.weight = 3.5
	return def


## The rig draws from the authored params: a pistol with no stock and an optic
## on a sniper must survive profile() instead of collapsing to the category
## table (the pre-params behaviour).
func test_silhouette_reads_the_authored_visual_params() -> void:
	var sniper := _def(&"sniper")
	sniper.body_len = 20.0
	sniper.barrel_len = 18.0
	sniper.mag_len = 4.5
	sniper.mag_offset = 4.0
	sniper.stock_len = 8.0
	sniper.has_scope = true
	sniper.gun_color = Color(0.5, 0.1, 0.1, 1.0)
	var p := WeaponVisual.profile(sniper)
	assert_float(float(p[&"body_len"])).is_equal(20.0)
	assert_float(float(p[&"barrel_len"])).is_equal(18.0)
	assert_float(float(p[&"stock"])).is_equal(8.0)
	assert_float(float(p[&"scope"])).is_greater(0.0)
	assert_float(float(p[&"color"].r)).is_equal_approx(0.5, 0.001)
	# The pistol params: no stock, no optic, short mag.
	var pistol := _def(&"pistol")
	pistol.body_len = 10.0
	pistol.barrel_len = 4.0
	pistol.stock_len = 0.0
	var pp := WeaponVisual.profile(pistol)
	assert_float(float(pp[&"stock"])).is_equal(0.0)
	assert_float(float(pp[&"scope"])).is_equal(0.0)
	# Muzzle still matches body+barrel exactly (visual == ballistic origin).
	assert_float(WeaponVisual.muzzle_len(sniper)) \
		.is_equal_approx(WeaponVisual.GRIP_X + 20.0 + 18.0, 0.0001)


## A def still on the schema defaults predates the params: fall back to the
## category silhouette so untouched content never draws a 14×10 box.
func test_schema_defaults_fall_back_to_the_category_silhouette() -> void:
	var untouched := WeaponDef.new()
	untouched.category = &"pistol"
	var p := WeaponVisual.profile(untouched)
	var fallback: Vector4 = WeaponVisual.CATEGORY_GEOMETRY[&"pistol"]
	assert_float(float(p[&"body_len"])).is_equal(fallback.x)
	assert_float(float(p[&"barrel_len"])).is_equal(fallback.y)
	assert_float(float(p[&"stock"])) \
		.is_equal(WeaponVisual.CATEGORY_FEATURES[&"pistol"].x)


## Every shipped weapon must be distinguishable: no two share the whole
## silhouette tuple (geometry + optic + colour).
func test_shipped_weapons_have_distinct_silhouettes() -> void:
	var seen: Dictionary[String, StringName] = {}
	for def: WeaponDef in Defs.all_weapons():
		var p := WeaponVisual.profile(def)
		var key := "%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.3f" % [
			float(p[&"body_len"]), float(p[&"barrel_len"]), float(p[&"width"]),
			float(p[&"mag_len"]), float(p[&"stock"]), float(p[&"scope"]),
			float(p[&"color"].r), float(p[&"color"].b)]
		assert_bool(seen.has(key)).override_failure_message(
			"%s draws the same silhouette as %s" % [def.id, seen.get(key, &"")]).is_false()
		seen[key] = def.id


func test_perk_table_matches_design() -> void:
	assert_float(Perks.reload_mult(&"vanguard")).is_equal_approx(0.9, 0.0001)
	assert_float(Perks.speed_mult(&"pathfinder")).is_equal_approx(1.08, 0.0001)
	assert_float(Perks.speed_mult(&"ram")).is_equal_approx(0.95, 0.0001)
	assert_float(Perks.cycle_mult(&"ram")).is_equal_approx(0.8, 0.0001)
	assert_float(Perks.focus_spread(&"longshot")).is_equal_approx(0.4, 0.0001)
	assert_float(Perks.suppression_error_deg(&"bulwark")).is_equal_approx(1.5, 0.0001)
	# Unknown perk is neutral everywhere.
	assert_float(Perks.reload_mult(&"nope")).is_equal_approx(1.0, 0.0001)
	assert_float(Perks.speed_mult(&"")).is_equal_approx(1.0, 0.0001)
	assert_float(Perks.focus_spread(&"")).is_equal(0.0)