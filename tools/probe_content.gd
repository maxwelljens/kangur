extends Node
## Content probe: proves `Defs` indexes every authored def, every id reference
## between defs resolves, and each def validates. Run:
##   tools/godot.sh --headless --path . tools/probe_content.tscn
## Prints CONTENT_PROBE_OK <counts> or CONTENT_PROBE_FAIL and exits nonzero.
## A scene (not `-s`) because `-s` skips autoloads.

const EXPECTED := {
	"weapons": 12, "classes": 5, "equipment": 3, "factions": 2,
	"difficulty": 4, "radio": 2, "maps": 5, "sounds": 7,
}

var _failures: Array[String] = []
## MapDefs whose scene the world wave has not built yet (expected, reported).
var _pending: Array[String] = []


func _ready() -> void:
	var counts := {
		"weapons": Defs.all_weapons().size(),
		"classes": Defs.all_classes().size(),
		"equipment": Defs.all_equipment().size(),
		"factions": Defs.all_factions().size(),
		"difficulty": Defs.all_difficulties().size(),
		"radio": Defs.all_radio().size(),
		"maps": Defs.all_maps().size(),
		"sounds": Defs.all_sound_sets().size(),
	}
	for key: String in EXPECTED:
		_check(counts[key] == EXPECTED[key], "%s = %d (want %d)" % [key, counts[key], EXPECTED[key]])

	_weapons()
	_classes()
	_equipment()
	_factions()
	_difficulty()
	_maps()
	_radio()

	if _failures.is_empty():
		print("CONTENT_PROBE_OK ", JSON.stringify(counts))
		if not _pending.is_empty():
			print("  pending scenes (world wave): ", ", ".join(_pending))
		get_tree().quit(0)
		return
	for failure: String in _failures:
		print("  FAIL ", failure)
	print("CONTENT_PROBE_FAIL (%d)" % _failures.size())
	get_tree().quit(1)


func _weapons() -> void:
	# design §6 roster, verbatim: rpm, damage, pellets, bullet px/s. Pinned here so
	# a tuning typo in data/ fails the gate (tune balance in sims, not by drift).
	var roster := {
		&"adder": [420.0, 24.0, 1, 4600.0],
		&"judge": [150.0, 55.0, 1, 5200.0],
		&"vespa": [800.0, 20.0, 1, 4400.0],
		&"kedr": [1000.0, 18.0, 1, 4200.0],
		&"kestrel": [650.0, 30.0, 1, 6200.0],
		&"volk": [600.0, 34.0, 1, 6000.0],
		&"falx": [300.0, 46.0, 1, 7000.0],
		&"sokol": [260.0, 55.0, 1, 7600.0],
		&"lynx": [45.0, 110.0, 1, 9000.0],
		&"mule": [700.0, 28.0, 1, 6000.0],
		&"breve": [70.0, 12.0, 8, 4000.0],
		&"automa": [240.0, 10.0, 6, 3900.0],
	}
	for id: StringName in roster:
		var def := Defs.weapon(id)
		_check(def != null, "weapon '%s' indexed" % id)
		if def == null:
			continue
		var want: Array = roster[id]
		_check(is_equal_approx(def.rpm, want[0]), "weapon '%s' rpm %s (want %s)" % [id, def.rpm, want[0]])
		_check(is_equal_approx(def.damage, want[1]), "weapon '%s' damage %s (want %s)" % [id, def.damage, want[1]])
		_check(def.pellets == int(want[2]), "weapon '%s' pellets %d (want %d)" % [id, def.pellets, want[2]])
		_check(is_equal_approx(def.bullet_speed, want[3]), "weapon '%s' bullet_speed %s (want %s)" % [id, def.bullet_speed, want[3]])
		_check(def.validate().is_empty(), "weapon '%s' validates: %s" % [def.id, def.validate()])
		_check(Defs.sound_set(def.sound_set) != null,
			"weapon '%s' sound_set '%s' resolves" % [def.id, def.sound_set])
	# Visual params: silhouettes must be readable per category (art-direction §1).
	_check(Defs.weapon(&"adder").stock_len == 0.0, "pistol has no stock")
	_check(not Defs.weapon(&"adder").has_scope, "pistol has no scope")
	_check(Defs.weapon(&"lynx").has_scope, "lynx has a scope")
	_check(Defs.weapon(&"lynx").armor_piercing, "lynx is armor_piercing")
	_check(Defs.weapon(&"mule").mag_size > 50, "mule has a big mag")
	_check(Defs.weapon(&"breve").pellets > 1, "breve fires pellets")
	# Length ordering: pistol < smg < ar < br/dmr < sniper.
	var order: Array[StringName] = [&"adder", &"vespa", &"kestrel", &"falx", &"sokol", &"lynx"]
	for i: int in order.size() - 1:
		var a := _length(Defs.weapon(order[i]))
		var b := _length(Defs.weapon(order[i + 1]))
		_check(a < b, "%s shorter than %s (%.0f < %.0f)" % [order[i], order[i + 1], a, b])
	# Shotgun: short overall + wide barrel (design brief), tube mag = no stick mag.
	for id: StringName in [&"breve", &"automa"]:
		var sg := Defs.weapon(id)
		_check(_length(sg) < _length(Defs.weapon(&"kestrel")), "%s shorter than an AR" % id)
		_check(sg.body_width > Defs.weapon(&"kestrel").body_width, "%s is wide" % id)
		_check(sg.mag_len == 0.0, "%s has a tube mag (no stick mag)" % id)
	# LMG: long, big mag, stocked.
	_check(Defs.weapon(&"mule").stock_len > 0.0, "mule is stocked")
	_check(Defs.weapon(&"mule").mag_len > Defs.weapon(&"kestrel").mag_len, "mule mag is long")


func _length(def: WeaponDef) -> float:
	return def.body_len + def.barrel_len + def.stock_len


func _classes() -> void:
	var want: Array[StringName] = [&"vanguard", &"pathfinder", &"bulwark", &"ram", &"longshot"]
	var perks := preload("res://src/entities/perks.gd")
	for id: StringName in want:
		_check(Defs.cls(id) != null, "class '%s' indexed" % id)
	for def: ClassDef in Defs.all_classes():
		_check(def.validate().is_empty(), "class '%s' validates: %s" % [def.id, def.validate()])
		_check(Defs.weapon(def.sidearm_id) != null,
			"class '%s' sidearm '%s' resolves" % [def.id, def.sidearm_id])
		for category: StringName in def.primary_categories:
			_check(_weapons_in_category(category) > 0,
				"class '%s' primary category '%s' has weapons" % [def.id, category])
		for equip: StringName in def.equipment:
			_check(Defs.equipment(equip) != null,
				"class '%s' equipment '%s' resolves" % [def.id, equip])
		_check(def.perk_id != &"", "class '%s' has a perk_id" % def.id)
		# Character multiplies ClassDef.speed_mult by Perks.speed_mult(perk_id);
		# design §8 states those speeds as PERKS, so the class field must stay
		# neutral or the bonus is applied twice.
		if perks.SPEED_FACTOR.has(def.perk_id):
			_check(is_equal_approx(def.speed_mult, 1.0),
				"class '%s' speed_mult is neutral (perk supplies speed)" % def.id)


func _weapons_in_category(category: StringName) -> int:
	var n := 0
	for def: WeaponDef in Defs.all_weapons():
		if def.category == category:
			n += 1
	return n


func _equipment() -> void:
	for def: EquipmentDef in Defs.all_equipment():
		_check(def.id != &"", "equipment id set")
		_check(Enums.EquipKind.values().has(def.kind), "equipment '%s' kind valid" % def.id)
		_check(def.radius > 0.0, "equipment '%s' radius > 0" % def.id)
	_check(Defs.equipment(&"smoke").vision_block_time == 12.0, "smoke lasts 12 s (design §6)")


func _factions() -> void:
	for def: FactionDef in Defs.all_factions():
		_check(def.callsigns.size() >= 12, "faction '%s' callsign pool >= 12" % def.id)
		_check(ResourceLoader.exists(def.emblem_path), "faction '%s' emblem exists" % def.id)
		_check(Defs.radio(def.radio_set) != null,
			"faction '%s' radio_set '%s' resolves" % [def.id, def.radio_set])
		_check(not def.doctrine.is_empty(), "faction '%s' has doctrine weights" % def.id)


func _difficulty() -> void:
	var want: Array[StringName] = [&"recruit", &"operator", &"veteran", &"elite"]
	for id: StringName in want:
		_check(Defs.difficulty(id) != null, "difficulty '%s' indexed" % id)
	# design §9: difficulty scales reaction/error, never sensors.
	for def: DifficultyDef in Defs.all_difficulties():
		_check(def.reaction_range.x <= def.reaction_range.y, "'%s' reaction range ordered" % def.id)
		_check(def.aim_error_range.x <= def.aim_error_range.y, "'%s' aim range ordered" % def.id)
		_check(def.turn_rate_range.x <= def.turn_rate_range.y, "'%s' turn range ordered" % def.id)
		_check(def.burst_range.x <= def.burst_range.y, "'%s' burst range ordered" % def.id)


func _maps() -> void:
	var want: Array[StringName] = [&"dustworks", &"compound", &"terminal", &"oldtown", &"range"]
	for id: StringName in want:
		_check(Defs.map(id) != null, "map '%s' indexed" % id)
	for def: MapDef in Defs.all_maps():
		_check(def.briefing.length() > 40, "map '%s' has a briefing" % def.id)
		_check(not def.ambience_id.is_empty(), "map '%s' has ambience" % def.id)
		_check(not def.supported_modes.is_empty(), "map '%s' has modes" % def.id)
		for mode: int in def.supported_modes:
			_check(Enums.Mode.values().has(mode), "map '%s' mode %d valid" % [def.id, mode])
		if ResourceLoader.exists(def.scene_path):
			_check(def.validate().is_empty(), "map '%s' validates: %s" % [def.id, def.validate()])
		else:
			# Scene authoring is the world wave's; a MapDef may point at a scene
			# that has not been built yet. Excuse ONLY the missing-scene error —
			# any other validation error still fails here.
			var errors := def.validate()
			var excused := errors.size() == 1 and errors[0].begins_with("scene_path does not exist")
			_check(excused, "map '%s' validates except its pending scene: %s" % [def.id, errors])
			if excused:
				_pending.append("%s (%s)" % [def.id, def.scene_path])
	# Mode assignments come from design §10.
	_check(Defs.map(&"dustworks").supported_modes == [Enums.Mode.ELIMINATION], "dustworks = Elimination")
	_check(Defs.map(&"terminal").supported_modes == [Enums.Mode.BATTLE], "terminal = Battle")
	_check(Defs.map(&"range").supported_modes == [Enums.Mode.TRAINING], "range = Training")
	_check(Defs.maps_for_mode(Enums.Mode.ELIMINATION).size() == 2, "2 Elimination maps")
	_check(Defs.maps_for_mode(Enums.Mode.BATTLE).size() == 2, "2 Battle maps")


func _radio() -> void:
	# Event keys are the contract from docs/design/radio-lines.md.
	var want: Array[StringName] = [&"contact", &"contact_multiple", &"kill", &"kill_streak",
		&"death", &"reload", &"bandage_start", &"bandage_done", &"killzone", &"retreat",
		&"regroup", &"hold", &"check_six", &"flank", &"suppress", &"objective_start",
		&"objective_contested", &"objective_captured", &"objective_lost", &"tickets_low",
		&"last_man", &"flash_out", &"smoke_out", &"frag_out", &"enemy_flash",
		&"enemy_smoke", &"spot_sniper", &"spot_lmg", &"low_hp", &"armor_broken",
		&"win", &"lose", &"spawn"]
	for def: RadioDef in Defs.all_radio():
		for event: StringName in want:
			var lines: Array = def.lines.get(event, [])
			_check(not lines.is_empty(), "radio '%s' has '%s'" % [def.id, event])
			for line: Variant in lines:
				_check(line is String and not String(line).is_empty(),
					"radio '%s'.'%s' line is a non-empty string" % [def.id, event])
		# Placeholders must survive authoring — the radio layer substitutes them.
		var all := ""
		for event: StringName in def.lines:
			for line: Variant in def.lines[event]:
				all += String(line)
		for placeholder: String in ["{grid}", "{callsign}"]:
			_check(all.contains(placeholder), "radio '%s' keeps %s" % [def.id, placeholder])


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)