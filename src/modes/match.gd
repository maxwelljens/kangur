class_name Match
extends Node2D
## One match: map, combatants, subsystems, rules and HUD. Contract:
## architecture §10. Game.to_match() swaps the scene here and `_ready` starts
## from `Game.match_config`; the sim harness calls `start(config, true)` on the
## same tree so what is verified is what ships.
##
## Tick order is explicit: rules → vision → camera/HUD/audio. Character,
## ProjectileSystem, EquipmentSystem and Grenade tick themselves at the engine's
## fixed 60 Hz (the sim runs the engine loop at --fixed-fps 60, never
## Engine.time_scale — tests/simulation/README.md).

signal finished(result: MatchResult)

const HudScene := preload("res://src/ui/hud/hud.tscn")
const EffectsScript := preload("res://src/entities/effects.gd")
const KangurTheme := preload("res://src/ui/theme.gd")
const RangeControllerScript := preload("res://src/modes/range_controller.gd")
const ProjectileScript := preload("res://src/combat/projectile_system.gd")
const EquipmentScript := preload("res://src/combat/equipment_system.gd")

const GROUP := &"match_runtime"
## HUD feed cadence (contract §11a: 10 Hz).
const HUD_HZ := 10.0
## Death cam hold before the debrief swaps the scene.
const DEBRIEF_DELAY_S := 2.0
## Tension: engaged = damage within this window; clutch = few teammates left.
const ENGAGED_MEMORY_S := 6.0
const CLUTCH_ALIVE := 3
## Elimination default 8 min, Battle 15 min (design §10).
const ELIMINATION_LIMIT_S := 480.0
const BATTLE_LIMIT_S := 900.0

var config: MatchConfig = null
var mode: int = Enums.Mode.ELIMINATION
var sim_mode: bool = false

var world: World = null
var characters_node: Node2D = null
var projectiles: Node2D = null
var equipment: Node2D = null
var vision: VisionSystem = null
var rules_runner: RulesRunner = null
var camera_rig: CameraRig = null
var hud: CanvasLayer = null
var effects: Node2D = null
var range_controller: Node = null

var spawn_manager: SpawnManager = null
var rules: MatchRules = null
var squads: Dictionary[int, SquadCoordinator] = {}
var characters: Array[Character] = []
var player: Character = null

var result: MatchResult = null
var running := false
## Guards start(): it awaits the nav bake, so `running` cannot be the guard.
var _starting := false
var elapsed := 0.0

var _rows: Dictionary = {}
var _hud_accum := 0.0
var _match_over := false
var _finished := false
var _last_damage_time := -INF
var _spectate_index := 0


func _ready() -> void:
	add_to_group(GROUP)
	if Game.match_config != null and not running:
		start(Game.match_config)


# --- lifecycle --------------------------------------------------------------

## Build and run the match. `headless` (sim) skips HUD/camera/audio and spawns
## no player; rules, combatants and combat systems are identical.
func start(cfg: MatchConfig, p_sim: bool = false) -> void:
	if running or _starting or cfg == null:
		return
	_starting = true
	config = cfg
	mode = cfg.mode
	# Training is solo (design §10). The title screen hands over a lobby-default
	# config, so the bot counts must be zeroed here or the range fills with AI.
	if mode == Enums.Mode.TRAINING:
		config.bot_count_bastion = 0
		config.bot_count_sirocco = 0
	sim_mode = p_sim
	_build_tree()
	_connect_bus()

	var map_def := Defs.map(cfg.map_id)
	var scene_path := map_def.scene_path if map_def != null else \
		"res://maps/%s/map.tscn" % cfg.map_id
	if not world.load_map(scene_path):
		push_error("Match: cannot load map '%s'" % cfg.map_id)
		return
	# NavigationServer serves polygons a few frames after the map enters the
	# tree; spawning before the first sync makes every closest_point fail.
	if world.nav != null:
		await world.nav.map_ready

	spawn_manager = SpawnManager.new()
	spawn_manager.name = "SpawnManager"
	add_child(spawn_manager)
	spawn_manager.setup(world, characters_node, projectiles, equipment, vision,
		cfg.seed, cfg.difficulty_id)
	spawn_manager.spawn_initial(cfg, not sim_mode)
	characters = spawn_manager.characters
	player = spawn_manager.player
	# Stat rows exist before the first shot: the scoreboard, killfeed and
	# MatchResult all read the same dictionaries.
	for character: Character in characters:
		_row_for(character)
	# Headless sims have no local player; the fog anchor is any living bot so
	# VisionSystem's player-relative paths stay on their normal branch.
	var vision_player: Character = player if player != null else _first_character()

	projectiles.call(&"setup", world, characters, cfg.seed)
	equipment.call(&"setup", world, characters)
	vision.setup_equipment(equipment)
	# The Training Range is a sandbox (design §10): no fog of war, so every
	# target, rack and readout is visible from the firing line.
	vision.setup(characters, vision_player, world, cfg.seed, true,
		mode != Enums.Mode.TRAINING)
	# Vision is stepped by this node so the tick order is explicit.
	vision.set_physics_process(false)
	projectiles.set_physics_process(not sim_mode)
	equipment.set_physics_process(not sim_mode)

	squads.clear()
	for team: int in [Enums.Team.BASTION, Enums.Team.SIROCCO]:
		var squad := SquadCoordinator.for_team(get_tree(), team)
		if squad != null:
			squads[team] = squad

	rules = _make_rules()
	rules.time_limit_s = cfg.time_limit_s if cfg.time_limit_s > 0.0 else _default_limit()
	rules_runner.setup(world, rules, spawn_manager, characters, squads, cfg.seed)
	rules_runner.match_finished.connect(_on_match_finished)
	rules_runner.wave_respawned.connect(_on_wave_respawned)

	if mode == Enums.Mode.TRAINING:
		range_controller = RangeControllerScript.new()
		range_controller.name = "RangeController"
		add_child(range_controller)
		range_controller.call(&"setup", self)
	_start_camera_and_hud(map_def)
	_play_audio(map_def)
	running = true
	_starting = false


func _build_tree() -> void:
	world = World.new()
	world.name = "World"
	add_child(world)
	characters_node = Node2D.new()
	characters_node.name = "Characters"
	characters_node.y_sort_enabled = true
	add_child(characters_node)
	projectiles = ProjectileScript.new() as Node2D
	projectiles.name = "Projectiles"
	add_child(projectiles)
	equipment = EquipmentScript.new() as Node2D
	equipment.name = "Equipment"
	add_child(equipment)
	effects = EffectsScript.new() as Node2D
	effects.name = "Effects"
	add_child(effects)
	vision = VisionSystem.new()
	vision.name = "Vision"
	add_child(vision)
	# F3 overlay: AI actions, nav goals and danger heat stay a VisionSystem job
	# (it already owns the debug flag), fed through its documented hook.
	vision.debug_extra = _draw_dev_overlay
	rules_runner = RulesRunner.new()
	rules_runner.name = "RulesRunner"
	add_child(rules_runner)
	if not sim_mode:
		camera_rig = CameraRig.new()
		camera_rig.name = "CameraRig"
		add_child(camera_rig)


func _first_character() -> Character:
	return characters[0] if not characters.is_empty() else null


## F3 debug overlay (architecture §3.6): one line per bot — current action,
## role and role counts. Draws in world space through the vision overlay so the
## data follows the characters (VisionSystem owns the toggle + culling).
func _draw_dev_overlay(overlay: Node2D) -> void:
	var font := ThemeDB.fallback_font
	for character: Character in characters:
		if character == null or not is_instance_valid(character) or not character.alive:
			continue
		if character.controller == null:
			continue
		var state: Dictionary = character.controller.call(&"debug_state")
		if state.is_empty():
			continue
		var line := "%s %s/%s" % [character.callsign,
			String(state.get(&"action", "?")), String(state.get(&"role", ""))]
		overlay.draw_string(font, character.global_position + Vector2(-30.0, -24.0),
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.98, 0.85, 0.45, 0.9) if character.team == Enums.Team.BASTION
			else Color(1.0, 0.55, 0.35, 0.9))


func _make_rules() -> MatchRules:
	# Training is a sandbox: the base rules never end the match, and the range
	# controller owns every interaction (design §10 "Training Range").
	if mode == Enums.Mode.TRAINING:
		return MatchRules.new()
	if mode == Enums.Mode.BATTLE:
		var battle := BattleRules.new()
		battle.setup([], config.attacker_tickets, BattleRules.ATTACKER_DEFAULT)
		return battle
	return EliminationRules.new()


func _default_limit() -> float:
	return BATTLE_LIMIT_S if mode == Enums.Mode.BATTLE else ELIMINATION_LIMIT_S


func _start_camera_and_hud(map_def: MapDef) -> void:
	if sim_mode:
		return
	if camera_rig != null and player != null:
		camera_rig.setup(player, world)
	hud = HudScene.instantiate()
	add_child(hud)
	hud.call(&"bind_character", player)
	hud.call(&"set_roster", _roster_rows())
	_apply_minimap_texture(map_def)
	_feed_hud()


func _play_audio(map_def: MapDef) -> void:
	if sim_mode or map_def == null:
		return
	if map_def.music_id != &"":
		AudioDirector.play_music(map_def.music_id)
	if map_def.ambience_id != &"":
		AudioDirector.play_ambience(map_def.ambience_id)


# --- tick -------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	# Sim mode owns the clock: the harness calls sim_tick() for every step, so
	# ticking here too would run the rules at double speed.
	if not running or _match_over or sim_mode:
		return
	elapsed += dt
	rules_runner.tick(dt)
	vision.advance(dt)
	_update_camera(dt)
	_hud_accum += dt
	if _hud_accum >= 1.0 / HUD_HZ:
		_hud_accum = 0.0
		_feed_hud()
	_update_audio()
	_update_spectate()


## One deterministic simulation step: the same calls the live loop makes, with
## a fixed dt and no rendering waits (tests/simulation/README.md).
func sim_tick(dt: float) -> void:
	if not running or _match_over:
		return
	elapsed += dt
	projectiles.call(&"_physics_process", dt)
	equipment.call(&"_process", dt)
	rules_runner.tick(dt)
	vision.advance(dt)


func _unhandled_input(event: InputEvent) -> void:
	if not running or _match_over or sim_mode or player == null:
		return
	if not player.alive and event.is_action_pressed(&"spectate_next"):
		get_viewport().set_input_as_handled()
		_cycle_spectate()


# --- camera / spectate ------------------------------------------------------

func _update_camera(dt: float) -> void:
	if camera_rig == null:
		return
	camera_rig.update(dt, get_global_mouse_position())


func _update_spectate() -> void:
	if player == null or player.alive:
		return
	if camera_rig != null and camera_rig.spectate_target == null:
		_cycle_spectate()


## Follow the next living teammate (Space while dead, design §10).
func _cycle_spectate() -> void:
	if camera_rig == null or player == null:
		return
	var mates: Array[Character] = []
	for character: Character in characters:
		if character.alive and character.team == player.team and character != player:
			mates.append(character)
	if mates.is_empty():
		return
	_spectate_index = (_spectate_index + 1) % mates.size()
	camera_rig.spectate(mates[_spectate_index])


# --- HUD feed ---------------------------------------------------------------

func _feed_hud() -> void:
	if hud == null:
		return
	hud.call(&"set_alive_counts", spawn_manager.living_count(Enums.Team.BASTION),
		spawn_manager.living_count(Enums.Team.SIROCCO))
	if rules is BattleRules:
		var battle := rules as BattleRules
		# HUD bars are [bastion, sirocco]: defenders hold, attackers spend.
		if battle.attacker_team() == Enums.Team.BASTION:
			hud.call(&"set_tickets", battle.tickets_left(), battle.defender_tickets_display())
		else:
			hud.call(&"set_tickets", battle.defender_tickets_display(), battle.tickets_left())
	else:
		hud.call(&"set_tickets", spawn_manager.living_count(Enums.Team.BASTION),
			spawn_manager.living_count(Enums.Team.SIROCCO))
	hud.call(&"set_objectives", rules_runner.objective_rows)
	hud.call(&"set_minimap_blips", _minimap_blips())
	hud.call(&"set_minimap_cone", _minimap_cone())
	if player != null:
		hud.call(&"set_equipment", _player_equipment())


func _minimap_blips() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null:
		return out
	var own_color := KangurTheme.team_color(player.team).lightened(0.25)
	for character: Character in characters:
		if character == null or not is_instance_valid(character) or not character.alive:
			continue
		if character == player:
			out.append({"pos": RulesRunner.normalise(world, character.global_position),
				"kind": &"player", "color": own_color, "dir": character.aim_dir})
		elif character.team == player.team:
			out.append({"pos": RulesRunner.normalise(world, character.global_position),
				"kind": &"ally", "color": own_color, "dir": character.aim_dir})
	if vision != null and vision.team_vision != null:
		for contact: Dictionary in vision.team_vision.shared_contacts(player.team):
			out.append({"pos": RulesRunner.normalise(world, contact[&"pos"]),
				"kind": &"enemy", "color": KangurTheme.DANGER})
	return out


func _minimap_cone() -> Dictionary:
	if player == null:
		return {}
	var perception := player.perception
	var rect := world.bounds()
	var diagonal := maxf(Vector2(rect.size).length(), 1.0)
	return {
		"pos": RulesRunner.normalise(world, player.global_position),
		"dir": player.aim_dir,
		"half_deg": perception.cone_angle_deg * 0.5,
		"dist": perception.cone_range / diagonal,
	}


func _player_equipment() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null:
		return out
	var arsenal := player.arsenal
	for i: int in arsenal.kit_ids.size():
		var def := Defs.equipment(arsenal.kit_ids[i])
		if def != null:
			out.append({"kind": def.kind, "count": arsenal.kit_count(i)})
	return out


func _roster_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for character: Character in characters:
		out.append(_row_for(character))
	return out


func _apply_minimap_texture(map_def: MapDef) -> void:
	if hud == null:
		return
	var path := map_def.minimap_path if map_def != null else ""
	if path.is_empty():
		path = world.minimap_path(config.map_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var minimap: Variant = hud.get(&"minimap")
	if minimap != null:
		minimap.set(&"map_texture", load(path))


# --- audio ------------------------------------------------------------------

func _update_audio() -> void:
	if camera_rig == null:
		return
	AudioDirector.set_listener(camera_rig.global_position)
	var teammates := 0
	if player != null:
		for character: Character in characters:
			if character.alive and character.team == player.team:
				teammates += 1
	var engaged := elapsed - _last_damage_time < ENGAGED_MEMORY_S
	var level := &"calm"
	if engaged:
		level = &"engaged"
	if engaged and player != null and teammates > 0 and teammates <= CLUTCH_ALIVE:
		level = &"clutch"
	AudioDirector.set_tension(level)


# --- stats / result ---------------------------------------------------------

func _connect_bus() -> void:
	EventBus.shot_fired.connect(_on_shot_fired)
	EventBus.character_hit.connect(_on_character_hit)
	EventBus.character_died.connect(_on_character_died)
	EventBus.bandage_finished.connect(_on_bandage_finished)
	EventBus.objective_captured.connect(_on_objective_captured)


func _exit_tree() -> void:
	for pair: Array in [
		[EventBus.shot_fired, _on_shot_fired],
		[EventBus.character_hit, _on_character_hit],
		[EventBus.character_died, _on_character_died],
		[EventBus.bandage_finished, _on_bandage_finished],
		[EventBus.objective_captured, _on_objective_captured],
	]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])


func _row_for(character: Character) -> Dictionary:
	if not _rows.has(character):
		_rows[character] = MatchResult.new_character_row(character.callsign,
			character.team, character.class_def.id if character.class_def != null else &"")
	return _rows[character]


func _on_shot_fired(shooter: Node, _weapon: StringName, _origin: Vector2,
		_dir: Vector2, pellets: int) -> void:
	if shooter is Character and characters.has(shooter):
		var row := _row_for(shooter)
		row["shots_fired"] = int(row["shots_fired"]) + maxi(pellets, 1)


func _on_character_hit(victim: Node, attacker: Node, _part: int, damage: float,
		fatal: bool, _pos: Vector2) -> void:
	if victim == player:
		_last_damage_time = elapsed
	if attacker is Character and characters.has(attacker):
		var row := _row_for(attacker)
		row["shots_hit"] = int(row["shots_hit"]) + 1
		row["damage"] = float(row["damage"]) + damage
	if fatal:
		_last_damage_time = elapsed


func _on_bandage_finished(who: Node, _part: int) -> void:
	if who is Character and characters.has(who):
		var row := _row_for(who)
		row["bandages_used"] = int(row["bandages_used"]) + 1


func _on_character_died(victim: Node, attacker: Node, weapon_id: StringName,
		_pos: Vector2, distance: float) -> void:
	if not (victim is Character) or not characters.has(victim):
		return
	var dead := victim as Character
	var dead_row := _row_for(dead)
	dead_row["deaths"] = int(dead_row["deaths"]) + 1
	_last_damage_time = elapsed
	if attacker is Character and characters.has(attacker) and attacker != dead:
		var killer := attacker as Character
		var row := _row_for(killer)
		row["kills"] = int(row["kills"]) + 1
		var weapon: WeaponDef = Defs.weapon(weapon_id) if weapon_id != &"" else null
		_add_timeline(&"kill", "%s → %s (%s, %d m)" % [killer.callsign, dead.callsign,
			weapon.display_name if weapon != null else "unknown",
			int(round(distance / Tiles.SIZE))], killer.team)
	else:
		_add_timeline(&"kill", "%s killed by the environment" % dead.callsign, dead.team)
	if dead == player:
		_cycle_spectate()


func _on_objective_captured(obj_id: StringName, team: int) -> void:
	_add_timeline(&"objective", "%s captured %s" % [
		Enums.team_name(team), String(obj_id).to_upper()], team)


func _add_timeline(kind: StringName, text: String, team: int) -> void:
	if result == null:
		result = MatchResult.new()
	result.timeline.append({"t": elapsed, "kind": String(kind), "text": text,
		"team": team})


func _on_match_finished(winner: int, reason: StringName) -> void:
	if _match_over:
		return
	_match_over = true
	running = false
	_build_result(winner, reason)
	_emit_finished()


func _build_result(winner: int, reason: StringName) -> void:
	var stats: Array[Dictionary] = []
	# Timeline collected during play survives the rebuild.
	var timeline: Array[Dictionary] = []
	if result != null:
		timeline.assign(result.timeline)
	result = MatchResult.new()
	result.winner = winner
	result.reason = reason
	result.duration_s = elapsed
	result.mode = mode
	result.map_id = config.map_id
	result.player_index = -1
	for character: Character in characters:
		var row := _row_for(character)
		row["survived"] = character.alive
		if player != null and character == player:
			result.player_index = stats.size()
		stats.append(row)
	if config.player_team == Enums.Team.SIROCCO and sim_mode:
		result.player_index = -1
	result.characters = stats
	result.timeline = timeline
	_add_timeline(&"end", "%s — %s" % [
		"draw" if winner < 0 else String(Enums.team_name(winner)), String(reason)], winner)
	result.timeline.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["t"]) < float(b["t"]))


func _emit_finished() -> void:
	if _finished:
		return
	_finished = true
	finished.emit(result)
	if sim_mode:
		return
	await get_tree().create_timer(DEBRIEF_DELAY_S).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.to_debrief(result)


## Harness exit path: produce a result even for a cut-short run.
func force_finish(winner: int = -1, reason: StringName = &"aborted") -> void:
	if _match_over:
		return
	_match_over = true
	running = false
	_build_result(winner, reason)
	_emit_finished()


## A reinforcement wave replaced dead bodies (and the player's): the HUD holds
## a BodyModel reference from bind_character, so it must be rebound or it keeps
## rendering the corpse's HP.
func _on_wave_respawned(team: int, _count: int) -> void:
	if player == null or player.team != team or not player.alive:
		return
	if hud != null:
		hud.call(&"bind_character", player)
		hud.call(&"clear_killcam")
	if camera_rig != null:
		camera_rig.clear_spectate()