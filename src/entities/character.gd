class_name Character
extends CharacterBody2D
## One combatant: composition root for Motor/Body/Arsenal/Aim/Perception/
## Controller/Rig. Owns no gameplay maths — the models live in the components,
## this node orders them and translates to/from EventBus.
## Contract: docs/architecture.md §4 (Character).
##
## Public interface consumed by combat/vision/AI/HUD: `team`, `callsign`,
## `class_def`, `is_player`, `alive`, `body`, `movement`, `aim_dir`, `stance`,
## `arsenal`, `perception`, `intent`, `pending_shots`, `setup()`, `apply_hit()`,
## `part_at_world_pos()`, `take_pending_shots()`.

const MotorScript := preload("res://src/entities/motor.gd")
const BodyScript := preload("res://src/entities/body.gd")
const ArsenalScript := preload("res://src/entities/arsenal.gd")
const AimScript := preload("res://src/entities/aim.gd")
const PerceptionScript := preload("res://src/entities/perception.gd")
const RigScript := preload("res://src/entities/rig.gd")
const PlayerControllerScript := preload("res://src/entities/player_controller.gd")
## The AI wave replaced the stub body: this path now extends the utility-driven
## brain in src/ai/ai_controller.gd, so Character keeps one stable preload and
## the entity tests keep asserting on the same script.
const AIControllerScript := preload("res://src/entities/ai_controller.gd")
const Perks := preload("res://src/entities/perks.gd")

## Body-fall loudness, px (design §12).
const BODYFALL_LOUDNESS := 180.0
## AI aim error floor as a fraction of the rolled initial error (research §5.6:
## the error converges but never reaches zero; no floor field in DifficultyDef).
const AIM_ERROR_FLOOR_RATIO := 0.3
## Fallback AI ranges when no DifficultyDef is indexed (Operator-ish).
const AI_TURN_RATE_FALLBACK := Vector2(270.0, 400.0)
const AI_REACTION_FALLBACK := Vector2(240.0, 360.0)
const AI_ERROR_FALLBACK := Vector2(2.5, 5.0)

# --- identity ---------------------------------------------------------------
var team: int = Enums.Team.BASTION
var callsign: String = "Operator"
var class_def: ClassDef = null
var is_player: bool = false

# --- live state (read by HUD/vision/AI; written only by this node) ----------
var alive: bool = true
var aim_dir: Vector2 = Vector2.RIGHT
var stance: Enums.Stance = Enums.Stance.STAND
## Read-only for debug consumers; the controller writes it every tick.
var intent: Intent = Intent.new()
## Projectiles produced this tick for the combat wave to consume.
var pending_shots: Array[ShotRequest] = []

# --- components (children, typed through their scripts) --------------------
@onready var motor: MotorScript = $Motor
@onready var body: BodyScript = $Body
@onready var arsenal: ArsenalScript = $Arsenal
@onready var aim: AimScript = $Aim
@onready var perception: PerceptionScript = $Perception
@onready var rig: RigScript = $Rig
@onready var controller: Node = $Controller

## Alias for HUD/AI code that reads the raw model (same object as motor.model).
var movement: MovementModel = null

## Injected by World before setup(): func(pos: Vector2) -> int surface id.
var surface_provider: Callable = Callable()

var _rng := RandomNumberGenerator.new()
var _difficulty: DifficultyDef = null
var _perk_id: StringName = &""

func _ready() -> void:
	add_to_group(&"characters")
	collision_layer = Layers.CHARACTER_BIT
	collision_mask = Layers.CHARACTER_MASK
	if intent == null:
		intent = Intent.new()

## Seed is per character so each spawn rolls its own AI error/turn rate without
## touching the global RNG (AGENTS §7: every match fresh).
## config keys: team, class_id | class_def, primary_id, sidearm_id, callsign,
## is_player, ai (defaults to !is_player), difficulty_id | difficulty, seed,
## faction_def. Unknown ids fall back to a functional empty def, never null.
func setup(config: Dictionary) -> void:
	team = int(config.get(&"team", team))
	callsign = String(config.get(&"callsign", callsign))
	is_player = bool(config.get(&"is_player", false))
	var wants_ai: bool = bool(config.get(&"ai", not is_player))
	_rng.seed = int(config.get(&"seed", hash(callsign) ^ (team << 16)))
	class_def = _resolve_class(config)
	_perk_id = class_def.perk_id if class_def.perk_id != &"" else class_def.id
	_difficulty = _resolve_difficulty(config)

	motor.setup(self)
	motor.surface_provider = surface_provider
	movement = motor.model
	body.setup(self, class_def)
	arsenal.setup(self, class_def, _primary_choice(config),
		StringName(config.get(&"sidearm_id", &"")),
		config.get(&"primary_def") if config.get(&"primary_def") is WeaponDef else null,
		config.get(&"sidearm_def") if config.get(&"sidearm_def") is WeaponDef else null)
	arsenal.apply_perks(Perks.reload_mult(_perk_id), Perks.cycle_mult(_perk_id),
		Perks.focus_spread(_perk_id))
	aim.setup(_rng, wants_ai)
	if wants_ai:
		_configure_ai_aim()
	perception.setup(self)
	_setup_rig(config)
	_attach_controller(wants_ai)

## Controller swap happens once, at setup: Character talks to the interface
## (fill_intent/setup) and never to a concrete controller.
func _attach_controller(wants_ai: bool) -> void:
	controller.set_script(AIControllerScript if wants_ai else PlayerControllerScript)
	controller.call(&"setup", self)

func _physics_process(dt: float) -> void:
	if not alive:
		rig.update(Vector2.ZERO, aim_dir, stance, _rig_state())
		return
	controller.call(&"fill_intent", intent, dt)
	_apply_modifiers()
	stance = intent.stance

	var ctx := {
		&"vel": motor.velocity().length(), &"vmax": motor.vmax(),
		&"stance": stance, &"focus": intent.focus,
		&"arm_mult": body.model.spread_mult(),
		&"rng": _rng,
	}
	arsenal.tick(dt, ctx)
	var weapon: WeaponModel = arsenal.current()
	var recoil := weapon.recoil_offset if weapon != null else Vector2.ZERO
	aim_dir = aim.tick(dt, intent, recoil)
	motor.tick(intent, dt)
	_handle_edges()
	_try_fire()
	body.tick(dt)
	if not body.alive():
		_die(null, &"")
		return
	perception.tick(dt, stance, intent.focus, motor.is_sprinting())
	rig.update(velocity, aim_dir, stance, _rig_state())

## Body/perk modifiers are pushed every tick: cripples evolve per hit.
func _apply_modifiers() -> void:
	var class_mult := class_def.speed_mult if class_def != null else 1.0
	motor.model.speed_mult = class_mult * Perks.speed_mult(_perk_id) * body.model.speed_mult()
	motor.model.can_sprint = body.model.can_sprint()

func _handle_edges() -> void:
	if intent.reload:
		if body.is_bandaging():
			body.interrupt_bandage()
		arsenal.start_reload()
	if intent.switch_slot >= 0 and arsenal.switch_slot(intent.switch_slot):
		rig.set_weapon(arsenal.current_def())
	if intent.cycle_fire_mode:
		arsenal.cycle_mode()
	if intent.bandage and not body.is_bandaging():
		body.try_start_bandage()
	if intent.sprint and body.is_bandaging():
		body.interrupt_bandage()
	if intent.throw_equipment >= 0:
		arsenal.throw_equipment(intent.throw_equipment, intent.cook)

func _try_fire() -> void:
	# Design §7: cannot fire while bandaging.
	var shots: Array[ShotRequest] = []
	if not body.is_bandaging():
		shots = arsenal.try_fire(intent, arsenal.muzzle_position(aim_dir), aim_dir)
	pending_shots = shots
	if pending_shots.is_empty():
		return
	var def := arsenal.current_def()
	if def != null:
		rig.pulse_recoil(def.recoil_kick)

## Combat wave takes ownership of the projectiles. Preferred over reading
## `pending_shots` directly so a tick can never be consumed twice.
func take_pending_shots() -> Array[ShotRequest]:
	var out := pending_shots
	pending_shots = []
	return out

# --- damage ----------------------------------------------------------------

## `part` is an Enums.Part (combat converts the hit offset with
## part_at_world_pos). Emits character_hit / character_died, drives the rig.
func apply_hit(part: int, dmg: float, pen: float, attacker: Node, armor_piercing: bool = false) -> HitResult:
	var result := HitResult.new()
	if not alive:
		return result
	result = body.apply_hit(part, dmg, pen, attacker, armor_piercing)
	rig.flinch(_incoming_dir(attacker))
	if result.died:
		_die(attacker, _weapon_id_of(attacker))
	return result

## Map a world hit point to a body part. The zones in BodyModel are local with
## +X = forward, so the offset is counter-rotated by the current facing.
func part_at_world_pos(hit_pos: Vector2) -> int:
	return BodyModel.part_at_offset((hit_pos - global_position).rotated(-aim_dir.angle()))

func flash(strength: float) -> void:
	rig.flash(strength)

## Killed from outside apply_hit (bleed-out, scripted). Idempotent.
func die(attacker: Node = null, weapon_id: StringName = &"") -> void:
	_die(attacker, weapon_id)

func _die(attacker: Node, weapon_id: StringName) -> void:
	if not alive:
		return
	alive = false
	body.model.alive = false
	rig.die()
	var distance := 0.0
	if attacker is Node2D:
		distance = global_position.distance_to((attacker as Node2D).global_position)
	EventBus.character_died.emit(self, attacker, weapon_id, global_position, distance)
	EventBus.sound_emitted.emit(global_position, BODYFALL_LOUDNESS, &"bodyfall", self,
		Enums.Surface.CONCRETE)

# --- HUD / AI getters ------------------------------------------------------

## HUD bind contract (architecture §11a): the HUD reads these defensively and
## falls back to properties, but the getters are the documented path.
func get_team() -> int:
	return team

func get_body_model() -> BodyModel:
	return body.model

func get_weapon_model() -> WeaponModel:
	return arsenal.current()

func get_bandages() -> int:
	return body.bandages_left

## Kit counts, index-aligned with ClassDef.equipment (`{kind, count}`).
func get_equipment_counts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in arsenal.kit_ids.size():
		var def := Defs.equipment(arsenal.kit_ids[i])
		if def == null:
			continue
		out.append({"kind": def.kind, "count": arsenal.kit_count(i)})
	return out

func weapon_id() -> StringName:
	return arsenal.current_id()

func fire_mode() -> int:
	var weapon := arsenal.current()
	return weapon.fire_mode() if weapon != null else Enums.FireMode.SEMI

func spread_deg() -> float:
	var weapon := arsenal.current()
	return weapon.current_spread_deg() if weapon != null else 0.0

func mag() -> int:
	var weapon := arsenal.current()
	return weapon.mag if weapon != null else 0

func reserve_rounds() -> int:
	var weapon := arsenal.current()
	return weapon.reserve_rounds if weapon != null else 0

func is_reloading() -> bool:
	var weapon := arsenal.current()
	return weapon.is_reloading() if weapon != null else false

func reload_progress() -> float:
	var weapon := arsenal.current()
	return weapon.reload_progress() if weapon != null else 0.0

func stamina_ratio() -> float:
	return motor.stamina_ratio()

func perk_id() -> StringName:
	return _perk_id

## Bulwark suppression: enemies under this character's fire take extra aim
## error. The AI wave applies it; 0 for every other perk.
func suppression_error_deg() -> float:
	return Perks.suppression_error_deg(_perk_id)

## Pathfinder: shared contacts persist this much longer on the minimap.
func spot_persist_bonus_s() -> float:
	return Perks.spot_persist_bonus_s(_perk_id)

# --- setup helpers ---------------------------------------------------------

func _resolve_class(config: Dictionary) -> ClassDef:
	if config.get(&"class_def") is ClassDef:
		return config[&"class_def"]
	var id: StringName = StringName(config.get(&"class_id", &"vanguard"))
	var found := Defs.cls(id)
	if found != null:
		return found
	# Zero-content boot / fixtures: an empty ClassDef keeps every component
	# functional (no armor, 0 bandages) instead of nulling out.
	var fallback := ClassDef.new()
	fallback.id = id
	fallback.display_name = String(id)
	return fallback

func _resolve_difficulty(config: Dictionary) -> DifficultyDef:
	if config.get(&"difficulty") is DifficultyDef:
		return config[&"difficulty"]
	return Defs.difficulty(StringName(config.get(&"difficulty_id", &"operator")))

## Loadout: explicit primary > first indexed weapon the class may carry >
## empty (sidearm only). Zero hardcoded weapon lists (AGENTS §4).
func _primary_choice(config: Dictionary) -> StringName:
	var explicit: StringName = StringName(config.get(&"primary_id", &""))
	if explicit != &"":
		return explicit
	for def: WeaponDef in Defs.all_weapons():
		if class_def.primary_categories.has(def.category):
			return def.id
	return &""

## AI aim pipeline from the DifficultyDef ranges (research §5.6).
func _configure_ai_aim() -> void:
	var turn := AI_TURN_RATE_FALLBACK
	var react := AI_REACTION_FALLBACK
	var err := AI_ERROR_FALLBACK
	if _difficulty != null:
		turn = _difficulty.turn_rate_range
		react = _difficulty.reaction_range
		err = _difficulty.aim_error_range
	var initial := _rng.randf_range(err.x, err.y)
	aim.configure_ai({
		&"turn_rate_deg": _rng.randf_range(turn.x, turn.y),
		&"reaction_s": _rng.randf_range(react.x, react.y) / 1000.0,
		&"error_initial_deg": initial,
		&"error_floor_deg": initial * AIM_ERROR_FLOOR_RATIO,
	})

func _setup_rig(config: Dictionary) -> void:
	var faction: FactionDef = config.get(&"faction_def") if \
		config.get(&"faction_def") is FactionDef else null
	rig.setup(team, faction.color_primary if faction != null else _rig_color(true),
		faction.color_accent if faction != null else _rig_color(false),
		_rig_visor(), class_def.id)
	rig.set_weapon(arsenal.current_def())

func _rig_color(primary: bool) -> Color:
	if team == Enums.Team.BASTION:
		return RigScript.BASTION_PRIMARY if primary else RigScript.BASTION_ACCENT
	return RigScript.SIROCCO_PRIMARY if primary else RigScript.SIROCCO_ACCENT

func _rig_visor() -> Color:
	return RigScript.BASTION_VISOR if team == Enums.Team.BASTION \
		else RigScript.SIROCCO_VISOR

func _rig_state() -> Dictionary:
	return {
		&"focus": intent.focus,
		&"reloading": is_reloading(),
		&"reload_progress": reload_progress(),
		&"bandaging": body.is_bandaging(),
		&"bandage_progress": body.bandage_progress(),
		&"health": body.torso_ratio(),
		&"sprinting": motor.is_sprinting(),
	}

func _incoming_dir(attacker: Node) -> Vector2:
	if attacker is Node2D:
		return (attacker as Node2D).global_position - global_position
	return Vector2.RIGHT

func _weapon_id_of(attacker: Node) -> StringName:
	if attacker != null and attacker.has_method(&"weapon_id"):
		return attacker.call(&"weapon_id")
	return &""