extends GdUnitTestSuite
## Menu flow logic that breaks silently: mode↔map compatibility when the lobby
## switches modes, and the MatchConfig the lobby hands to Game.to_match.
## Renders nothing — every screen is exercised through its script API.

const LobbyScript := preload("res://src/ui/menus/lobby_screen.gd")


func _lobby() -> Control:
	var screen: Control = LobbyScript.new()
	# `_build` needs the autoload theme path only; add to the tree so Settings
	# and Defs are available exactly as they are in game.
	add_child(screen)
	return screen


func test_mode_switch_picks_a_compatible_map() -> void:
	var lobby := _lobby()
	var battle_maps := Defs.maps_for_mode(Enums.Mode.BATTLE)
	if battle_maps.is_empty():
		lobby.free()
		return  # content wave has no Battle map yet
	lobby.call(&"_select_mode", Enums.Mode.BATTLE)
	var config: MatchConfig = lobby.get(&"_config")
	assert_int(config.mode).is_equal(Enums.Mode.BATTLE)
	var chosen := Defs.map(config.map_id)
	assert_object(chosen).is_not_null()
	assert_bool(chosen.supported_modes.has(Enums.Mode.BATTLE)).is_true()
	lobby.free()


func test_mode_switch_keeps_map_when_it_supports_both_modes() -> void:
	var lobby := _lobby()
	var dual: MapDef = null
	for map_def: MapDef in Defs.all_maps():
		if map_def.supported_modes.has(Enums.Mode.ELIMINATION) \
				and map_def.supported_modes.has(Enums.Mode.BATTLE):
			dual = map_def
			break
	if dual == null:
		lobby.free()
		return  # content has no dual-mode map yet; nothing to assert
	lobby.call(&"_select_mode", Enums.Mode.ELIMINATION)
	lobby.call(&"_select_map", dual)
	lobby.call(&"_select_mode", Enums.Mode.BATTLE)
	var config: MatchConfig = lobby.get(&"_config")
	assert_str(String(config.map_id)).is_equal(String(dual.id))
	lobby.free()


func test_unsupported_map_selection_is_refused() -> void:
	var lobby := _lobby()
	lobby.call(&"_select_mode", Enums.Mode.ELIMINATION)
	var config: MatchConfig = lobby.get(&"_config")
	var before := config.map_id
	var battle_only: MapDef = null
	for map_def: MapDef in Defs.all_maps():
		if map_def.supported_modes.has(Enums.Mode.BATTLE) \
				and not map_def.supported_modes.has(Enums.Mode.ELIMINATION):
			battle_only = map_def
			break
	if battle_only == null:
		lobby.free()
		return
	lobby.call(&"_select_map", battle_only)
	assert_str(String(config.map_id)).is_equal(String(before))
	lobby.free()


func test_bot_count_sliders_clamp_to_design_limits() -> void:
	var lobby := _lobby()
	lobby.call(&"_on_bots_changed", Enums.Team.BASTION, 99)
	lobby.call(&"_on_bots_changed", Enums.Team.SIROCCO, -4)
	var config: MatchConfig = lobby.get(&"_config")
	assert_int(config.bot_count_bastion).is_equal(lobby.get(&"BOT_COUNT_MAX"))
	assert_int(config.bot_count_sirocco).is_equal(lobby.get(&"BOT_COUNT_MIN"))
	lobby.free()


func test_deploy_config_is_complete() -> void:
	# The deploy button must never hand Match an incomplete config: seed is
	# rolled by Game, but map/mode/class/primary must already be valid.
	var lobby := _lobby()
	lobby.call(&"_select_mode", Enums.Mode.ELIMINATION)
	var config: MatchConfig = lobby.get(&"_config")
	assert_int(config.mode).is_equal(Enums.Mode.ELIMINATION)
	assert_bool(config.map_id != &"").is_true()
	assert_bool(config.player_class_id != &"").is_true()
	assert_int(config.total_team(config.player_team)).is_greater(0)
	assert_int(config.total_team(config.enemy_team())).is_greater(0)
	lobby.free()