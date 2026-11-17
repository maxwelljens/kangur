extends Node
## Core smoke test. Run: `tools/godot.sh --headless --path . tools/smoke_core.tscn`
## A scene (not a `-s` script) because `-s` replaces the main loop and does NOT
## instantiate autoloads. Prints CORE_SMOKE_OK or CORE_SMOKE_FAIL <reason>.
## Temporary fixture until the unit-test framework lands (architecture §11).

func _ready() -> void:
	var failure := _run_checks()
	if failure.is_empty():
		print("CORE_SMOKE_OK")
		get_tree().quit(0)
	else:
		print("CORE_SMOKE_FAIL %s" % failure)
		get_tree().quit(1)

## Returns "" on success, else the first failure description.
func _run_checks() -> String:
	for name: String in ["EventBus", "Defs", "Settings", "Game", "Dev"]:
		if get_node_or_null(NodePath("/root/" + name)) == null:
			return "autoload %s missing" % name

	# Indexing is valid whether data/ is empty (now) or populated (content wave):
	# every indexed def must be reachable by its own id, and a missing id nulls.
	for def: WeaponDef in Defs.all_weapons():
		if def.id == &"" or Defs.weapon(def.id) != def:
			return "Defs weapon index inconsistent for '%s'" % def.display_name
	for def: MapDef in Defs.all_maps():
		if not Defs.maps_for_mode(Enums.Mode.ELIMINATION).has(def) \
				and def.supported_modes.has(Enums.Mode.ELIMINATION):
			return "maps_for_mode missed '%s'" % def.id
		if Defs.maps_for_mode(Enums.Mode.BATTLE).has(def) \
				and not def.supported_modes.has(Enums.Mode.BATTLE):
			return "maps_for_mode included a non-battle map '%s'" % def.id
	if Defs.weapon(&"__missing_id__") != null:
		return "Defs.weapon did not return null for a missing id"

	# Settings roundtrip on a real key, restored afterwards.
	var original: int = int(Settings.get_value(&"gameplay", &"crosshair_style", -1))
	Settings.set_value(&"gameplay", &"crosshair_style", 7)
	if int(Settings.get_value(&"gameplay", &"crosshair_style")) != 7:
		return "Settings set/get roundtrip failed"
	Settings.set_value(&"gameplay", &"crosshair_style", original)
	if int(Settings.get_value(&"gameplay", &"crosshair_style")) != original:
		return "Settings restore failed"

	if InputDefaults.move_vector() != Vector2.ZERO:
		return "move_vector should be zero with no keys held"

	var config := MatchConfig.new()
	config.player_team = Enums.Team.BASTION
	config.bot_count_bastion = 4
	config.bot_count_sirocco = 5
	if config.total_team(Enums.Team.BASTION) != 5:
		return "total_team must count the local player"
	if config.total_characters() != 10:
		return "total_characters wrong"
	if config.enemy_team() != Enums.Team.SIROCCO:
		return "enemy_team wrong"

	var result := MatchResult.new()
	result.winner = Enums.Team.SIROCCO
	result.reason = &"elimination"
	result.characters.append(MatchResult.new_character_row("Kestrel", Enums.Team.BASTION, &"vanguard"))
	var roundtrip := MatchResult.from_dict(JSON.parse_string(JSON.stringify(result.to_dict())))
	if roundtrip.winner != result.winner or roundtrip.reason != result.reason:
		return "MatchResult serialization roundtrip failed"
	if roundtrip.characters.size() != 1:
		return "MatchResult character rows lost in roundtrip"

	# Missing UI scenes must be graceful (expected push_error above), and a
	# present one must actually switch. Compares both ways so this stays valid
	# after the UI wave lands.
	var title_exists := ResourceLoader.exists(Game.TITLE_SCENE)
	Game.to_title()
	if (Game.current_scene_kind == &"title") != title_exists:
		return "Game.to_title state does not match scene presence"
	return ""