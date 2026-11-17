extends GdUnitTestSuite
## The Game autoload owns app flow by scene path; a typo or a renamed screen
## silently breaks every transition with only a push_error at runtime. These
## tests pin the contract the other way round: every path Game knows exists,
## and each is a Control/CanvasLayer screen with its script attached.


func test_every_game_scene_path_exists() -> void:
	# Game.MATCH_SCENE belongs to the modes wave; it is not this module's job.
	for path: String in [
		Game.TITLE_SCENE, Game.LOBBY_SCENE, Game.SETTINGS_SCENE,
		Game.CREDITS_SCENE, Game.DEBRIEF_SCENE,
	]:
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"Game screen missing: %s" % path).is_true()


func test_screens_instantiate_with_script() -> void:
	for path: String in [
		Game.TITLE_SCENE, Game.LOBBY_SCENE, Game.SETTINGS_SCENE,
		Game.CREDITS_SCENE, Game.DEBRIEF_SCENE,
	]:
		var packed := load(path) as PackedScene
		assert_object(packed).is_not_null()
		var instance := packed.instantiate()
		assert_object(instance).is_not_null()
		assert_object(instance.get_script()).override_failure_message(
			"%s has no script attached" % path).is_not_null()
		instance.free()


func test_pause_menu_is_a_separate_overlay_not_a_game_scene() -> void:
	# Pause lives inside the match HUD's CanvasLayer, so it must not be one of
	# Game's scene transitions.
	var path := "res://src/ui/pause/pause_menu.tscn"
	assert_bool(ResourceLoader.exists(path)).is_true()
	assert_bool(path in [Game.TITLE_SCENE, Game.LOBBY_SCENE, Game.SETTINGS_SCENE,
		Game.CREDITS_SCENE, Game.DEBRIEF_SCENE]).is_false()


func test_hud_scene_is_a_canvas_layer() -> void:
	var packed := load("res://src/ui/hud/hud.tscn") as PackedScene
	assert_object(packed).is_not_null()
	var instance := packed.instantiate()
	assert_bool(instance is CanvasLayer).is_true()
	assert_bool(instance.has_method(&"bind_character")).is_true()
	assert_bool(instance.has_method(&"refresh")).is_true()
	assert_bool(instance.has_method(&"set_minimap_blips")).is_true()
	assert_bool(instance.has_method(&"add_killfeed")).is_true()
	instance.free()


func test_theme_is_the_only_theme_resource() -> void:
	# One theme resource is the contract (design §13): widgets must read it
	# rather than define their own fonts/colours.
	var theme := load("res://src/ui/kangur_theme.tres") as Theme
	assert_object(theme).is_not_null()
	assert_object(theme.default_font).is_same(KangurTheme.FONT_UI)