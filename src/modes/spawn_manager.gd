class_name SpawnManager
extends Node
## Creates combatants and keeps every subsystem's roster in sync: the
## Characters node, the projectile/equipment systems, vision and the squad
## coordinator (the AI registers itself in setup). Match owns one instance.
##
## Bot loadouts are rolled, never hardcoded (AGENTS §4): the class comes from a
## personality-weighted roll over `Defs.all_classes()`, the primary is any
## indexed weapon the class may carry, the callsign comes from the faction pool.
##
## Respawns REVIVE the existing node instead of instantiating a new one:
## VisionSystem, TeamVision, ShotProvenance, EquipmentSystem and the HUD all
## capture combatant lists/references at setup, and a fresh node would silently
## escape player fog gating and the fairness ledger.

const CharacterScene := preload("res://src/entities/character.tscn")
const Perks := preload("res://src/entities/perks.gd")

## Spawn ring radius. Characters have a 10 px body radius, so a ring smaller
## than this overlaps colliders and the spawn pair fights the physics solver.
const SPAWN_SPREAD_PX := 26.0
## Minimum gap enforced between any two spawns of one team, px.
const SPAWN_MIN_GAP_PX := 24.0
## Name prefix of the Battle forward-spawn markers (maps.md).
const FORWARD_SPAWNS := ^"ForwardSpawns"
const FORWARD_PREFIX := "spawn_fwd_"

var world: World = null
var characters_node: Node2D = null
var projectiles: Node = null
var equipment: Node = null
var vision: Node = null
var match_seed: int = 0
var difficulty_id: StringName = &"operator"

## Every combatant in spawn order (shared by reference with the combat systems).
var characters: Array[Character] = []
var player: Character = null
## team -> roster size; Battle waves refill to it.
var _team_size: Dictionary[int, int] = {}
## character -> loadout dictionary (needed to rebuild weapons on revive).
var _loadouts: Dictionary[Character, Dictionary] = {}
var _used_callsigns: Dictionary[String, bool] = {}


func setup(world_node: World, p_characters: Node2D, p_projectiles: Node,
		p_equipment: Node, p_vision: Node, p_seed: int,
		p_difficulty_id: StringName) -> void:
	world = world_node
	characters_node = p_characters
	projectiles = p_projectiles
	equipment = p_equipment
	vision = p_vision
	characters.clear()
	_loadouts.clear()
	_team_size.clear()
	_used_callsigns.clear()
	match_seed = p_seed
	difficulty_id = p_difficulty_id
	player = null


## Player + bots for both teams, spread over each team's spawn markers.
func spawn_initial(config: MatchConfig, with_player: bool = true) -> void:
	for team: int in [Enums.Team.BASTION, Enums.Team.SIROCCO]:
		var has_player := with_player and team == config.player_team
		_team_size[team] = maxi(config.bot_count(team), 0) + (1 if has_player else 0)
	var bastion_slots := _start_points(Enums.Team.BASTION, config.total_team(Enums.Team.BASTION))
	var sirocco_slots := _start_points(Enums.Team.SIROCCO, config.total_team(Enums.Team.SIROCCO))
	for team: int in [Enums.Team.BASTION, Enums.Team.SIROCCO]:
		var slots := bastion_slots if team == Enums.Team.BASTION else sirocco_slots
		var index := 0
		if with_player and team == config.player_team:
			player = spawn_player(config, _slot(slots, 0, team))
			index = 1
		# Headless sims spawn a bot in the player's slot: same team size, same
		# loadout rolls, and no human-only subsystems to special-case.
		for i: int in maxi(config.bot_count(team), 0):
			spawn_bot(team, _slot(slots, index, team), index)
			index += 1


func spawn_player(config: MatchConfig, at: Vector2) -> Character:
	var class_def: ClassDef = Defs.cls(config.player_class_id)
	var opts := {
		&"is_player": true, &"class_def": _player_class(config, class_def),
		&"primary_id": config.primary_id,
		&"sidearm_id": config.sidearm_id,
		&"callsign": config.player_callsign if not config.player_callsign.is_empty() \
			else "Kestrel",
		&"seed": hash([match_seed, config.player_team, &"player"]),
	}
	return spawn_character(config.player_team, at, opts)


## Player kit override applies only when the lobby chose one (`equipment_ids`
## empty keeps the ClassDef default). Duplicated so the shared .tres is safe.
func _player_class(config: MatchConfig, class_def: ClassDef) -> ClassDef:
	if class_def == null or config.equipment_ids.is_empty():
		return class_def
	var copy: ClassDef = class_def.duplicate()
	copy.equipment = config.equipment_ids.duplicate()
	return copy


func spawn_bot(team: int, at: Vector2, index: int) -> Character:
	return spawn_character(team, at, _roll_loadout(team, index))


## The one constructor. `opts` keys mirror Character.setup plus `is_player`.
func spawn_character(team: int, at: Vector2, opts: Dictionary) -> Character:
	var character: Character = CharacterScene.instantiate()
	character.position = _navigable(at)
	characters_node.add_child(character)
	# Injected BEFORE setup: the Motor reads it then (first footstep material).
	if world != null:
		character.surface_provider = world.surface_at
	var config := opts.duplicate()
	config[&"team"] = team
	if not config.has(&"callsign"):
		config[&"callsign"] = unique_callsign(team)
	if not config.has(&"is_player"):
		config[&"is_player"] = false
	if not config.has(&"ai"):
		config[&"ai"] = not bool(config[&"is_player"])
	if not config.has(&"difficulty_id"):
		config[&"difficulty_id"] = difficulty_id
	if not config.has(&"seed"):
		config[&"seed"] = hash([match_seed, team, characters.size()])
	character.setup(config)

	characters.append(character)
	_loadouts[character] = {
		&"class_def": character.class_def,
		&"primary_id": character.arsenal.primary.def.id if character.arsenal.primary != null else &"",
		&"sidearm_id": character.arsenal.sidearm.def.id if character.arsenal.sidearm != null else &"",
	}
	if projectiles != null:
		projectiles.call(&"add_character", character)
	if equipment != null:
		equipment.call(&"add_character", character)
	_bridge_provenance(character)
	return character


## ShotProvenance connects each character's sighting signal at its own setup.
## A revived character keeps the same node, so this is only needed once — but
## the call is idempotent and keeps a manually-added fixture honest.
func _bridge_provenance(character: Character) -> void:
	if vision == null or character.perception == null:
		return
	var provenance: Variant = vision.get(&"shot_provenance")
	if provenance == null:
		return
	var bridge := Callable(provenance, "_on_enemy_spotted")
	if not character.perception.enemy_spotted.is_connected(bridge):
		character.perception.enemy_spotted.connect(bridge)


## Battle reinforcement wave: revive every dead member of `team` at the forward
## spawns of the last captured objective (or the base spawns).
func refill(team: int, forward_order: int) -> int:
	var dead: Array[Character] = []
	for character: Character in characters:
		# A freed combatant (test teardown, tooling) must never throw here.
		if not is_instance_valid(character):
			continue
		if character.team == team and not character.alive:
			dead.append(character)
	if dead.is_empty():
		return 0
	var starts := forward_spawns(team, forward_order)
	if starts.is_empty():
		starts = _start_points(team, int(_team_size.get(team, dead.size())))
	var revived := 0
	for i: int in dead.size():
		var at: Vector2 = starts[i % starts.size()] if not starts.is_empty() \
			else _base_position(team)
		if revive(dead[i], at):
			revived += 1
	return revived


## Bring a dead character back with a fresh body, full magazines and kit.
## `hud` needs `bind_character` again when the player body model is replaced.
func revive(character: Character, at: Vector2) -> bool:
	if character == null or not is_instance_valid(character) or character.alive:
		return false
	var loadout: Dictionary = _loadouts.get(character, {})
	var class_def: ClassDef = loadout.get(&"class_def", character.class_def)
	if class_def == null:
		class_def = character.class_def
	character.body.setup(character, class_def)
	character.arsenal.setup(character, class_def,
		StringName(loadout.get(&"primary_id", &"")),
		StringName(loadout.get(&"sidearm_id", &"")))
	character.arsenal.apply_perks(Perks.reload_mult(character.perk_id()),
		Perks.cycle_mult(character.perk_id()), Perks.focus_spread(character.perk_id()))
	character.alive = true
	character.body.model.alive = true
	character.rig.call(&"revive")
	character.pending_shots.clear()
	character.velocity = Vector2.ZERO
	character.motor.model.velocity = Vector2.ZERO
	character.global_position = _navigable(at)
	character.rig.position = Vector2.ZERO
	character.rig.rotation = 0.0
	return true


func living_count(team: int) -> int:
	var alive := 0
	for character: Character in characters:
		if character != null and is_instance_valid(character) and character.alive \
				and character.team == team:
			alive += 1
	return alive


func team_members(team: int) -> Array[Character]:
	var out: Array[Character] = []
	for character: Character in characters:
		if is_instance_valid(character) and character.team == team:
			out.append(character)
	return out


# --- positions --------------------------------------------------------------

func _slot(slots: Array[Vector2], index: int, team: int) -> Vector2:
	return slots[index % slots.size()] if not slots.is_empty() else _base_position(team)


## Spread `count` slots over the team's markers, each nudged onto a ring so a
## 12-bot squad never stacks on four marker pixels.
func _start_points(team: int, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if world == null:
		return out
	var markers := world.spawn_points(team)
	if markers.is_empty():
		return out
	var slots := maxi(count, markers.size())
	var occupied: Array[Vector2] = []
	for i: int in slots:
		var base := markers[i % markers.size()]
		var candidate := base
		# Ring offsets first; if the marker grid is denser than the body radius,
		# push outward until the point clears every slot already taken.
		for ring_step: int in 6:
			var radius := SPAWN_SPREAD_PX * float(ring_step)
			var angle := float(i) * TAU / float(slots)
			candidate = base + Vector2.RIGHT.rotated(angle) * radius
			var clear := true
			for taken: Vector2 in occupied:
				if taken.distance_to(candidate) < SPAWN_MIN_GAP_PX:
					clear = false
					break
			if clear:
				break
		occupied.append(candidate)
		out.append(candidate)
	return out


## Forward spawn markers of the last captured objective (Battle, maps.md).
## Markers are `spawn_fwd_<obj letter>_NN`; team comes from SpawnMarker.team.
func forward_spawns(team: int, order: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if world == null or world.map == null or order <= 0:
		return out
	var node := world.map.get_node_or_null(FORWARD_SPAWNS)
	if node == null:
		return out
	var wanted := "%s%s_" % [FORWARD_PREFIX, _order_letter(order)]
	for child: Node in node.get_children():
		if not (child is SpawnMarker):
			continue
		var marker := child as SpawnMarker
		if marker.team != team or not marker.name.begins_with(wanted):
			continue
		out.append(marker.global_position)
	return out


static func _order_letter(order: int) -> String:
	return String.chr(96 + clampi(order, 1, 26))


func _base_position(team: int) -> Vector2:
	if world != null:
		var markers := world.spawn_points(team)
		if not markers.is_empty():
			return markers[0]
		return world.bounds().get_center()
	return Vector2.ZERO


## Snap onto the navigation mesh when it is live so nobody spawns inside a wall.
func _navigable(pos: Vector2) -> Vector2:
	if world == null or world.nav == null or not world.nav.is_ready():
		return pos
	return world.nav.closest_point(pos)


# --- loadout ----------------------------------------------------------------

## Personality-weighted class roll, then a weapon the class may actually carry
## (ClassDef.primary_categories). No id literals: new content just works.
func _roll_loadout(team: int, index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([match_seed, team, index, &"loadout"])
	var difficulty: DifficultyDef = Defs.difficulty(difficulty_id)
	var personality := Personality.roll(rng, difficulty)
	var class_def := _pick_class(rng, personality)
	var primary: StringName = &""
	var candidates: Array[WeaponDef] = []
	for def: WeaponDef in Defs.all_weapons():
		if class_def != null and class_def.primary_categories.has(def.category):
			candidates.append(def)
	if not candidates.is_empty():
		primary = candidates[rng.randi_range(0, candidates.size() - 1)].id
	var sidearm := class_def.sidearm_id if class_def != null else &""
	if sidearm == &"":
		sidearm = _first_weapon_of_category(&"pistol")
	return {
		&"class_def": class_def,
		&"primary_id": primary,
		&"sidearm_id": sidearm,
		&"seed": hash([match_seed, team, index, &"bot"]),
	}


func _pick_class(rng: RandomNumberGenerator, personality: Personality) -> ClassDef:
	var classes := Defs.all_classes()
	if classes.is_empty():
		return null
	var best: ClassDef = null
	var best_score := -INF
	for def: ClassDef in classes:
		var score := 1.0 + rng.randf_range(0.0, 0.35)
		# Fast kits suit aggression; heavy/helmeted kits suit caution and camping.
		score += (personality.aggression - 0.5) * (def.speed_mult - 1.0) * 20.0
		score += (personality.caution - 0.5) * (def.armor_vest / 100.0) * 2.0
		score += (personality.campiness - 0.5) * (0.6 if def.armor_helmet > 0.0 else 0.0)
		if score > best_score:
			best_score = score
			best = def
	return best


func _first_weapon_of_category(category: StringName) -> StringName:
	for def: WeaponDef in Defs.all_weapons():
		if def.category == category:
			return def.id
	return &""


## Unique per match: faction pool first, then `-2` suffixes once it runs out.
func unique_callsign(team: int) -> String:
	var pool: Array[String] = []
	var faction: FactionDef = Defs.faction(StringName(Enums.team_name(team).to_lower()))
	if faction != null:
		pool = faction.callsigns
	if pool.is_empty():
		pool = ["Operator"]
	var start := absi(hash([match_seed, team])) % pool.size()
	for i: int in pool.size():
		var name := pool[(start + i) % pool.size()]
		if not _used_callsigns.has(name):
			_used_callsigns[name] = true
			return name
	var base := pool[start]
	var suffix := 2
	var candidate := "%s-%d" % [base, suffix]
	while _used_callsigns.has(candidate):
		suffix += 1
		candidate = "%s-%d" % [base, suffix]
	_used_callsigns[candidate] = true
	return candidate