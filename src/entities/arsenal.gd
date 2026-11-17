extends Node
## Arsenal — WeaponModel ×2 (primary/sidearm) + equipment kit state.
## Pure model does ammo/mode/reload timing; this shell adds slot switching,
## kit throws and EventBus translation. Contract: docs/architecture.md §4.

const SLOT_PRIMARY := 0
const SLOT_SIDEARM := 1
const SLOT_NONE := -1

const WeaponVisual := preload("res://src/entities/weapon_visual.gd")

## Reload foley loudness, px (design §12), and the throw hand offset.
const RELOAD_LOUDNESS := 200.0
const THROW_OFFSET := 10.0
var primary: WeaponModel = null
var sidearm: WeaponModel = null
## EquipmentDef ids in kit order, with remaining counts in parallel.
var kit_ids: Array[StringName] = []
var kit_counts: Array[int] = []
var slot: int = SLOT_PRIMARY

## Perk factors (Vanguard reload ×0.9, Ram cycle ×0.8, Longshot focus spread
## ×0.4). Pushed into both WeaponModels here (fields added to WeaponModel).
var reload_perk_mult: float = 1.0
var cycle_mult: float = 1.0
var focus_spread_override: float = 0.0

var _host: Node2D = null
var _was_reloading: bool = false

## `primary_def`/`sidearm_def` override the Defs lookup. Character passes them
## through from setup() so tests, fixtures and the zero-content boot can equip a
## weapon before data/ is populated; normal play resolves the ids via Defs.
func setup(host: Node2D, class_def: ClassDef, primary_id: StringName,
		sidearm_override: StringName = &"", primary_def: WeaponDef = null,
		sidearm_def: WeaponDef = null) -> void:
	_host = host
	primary = _make_weapon(primary_id, primary_def)
	var sidearm_id: StringName = sidearm_override if sidearm_override != &"" \
		else (class_def.sidearm_id if class_def != null else &"")
	sidearm = _make_weapon(sidearm_id, sidearm_def)
	slot = SLOT_PRIMARY if primary != null else SLOT_SIDEARM
	_build_kit(class_def)

## Push perk factors into both WeaponModels. Called once by Character.setup, so
## the reload channel length is correct before the first tick.
func apply_perks(reload_mult_value: float, cycle_mult_value: float,
		focus_override: float) -> void:
	reload_perk_mult = reload_mult_value
	cycle_mult = cycle_mult_value
	focus_spread_override = focus_override
	for weapon: WeaponModel in [primary, sidearm]:
		if weapon != null:
			weapon.reload_mult = reload_mult_value
			weapon.cycle_mult = cycle_mult_value
			weapon.focus_spread_override = focus_override

func _make_weapon(id: StringName, def_override: WeaponDef = null) -> WeaponModel:
	if id == &"":
		return null
	var def := def_override if def_override != null else Defs.weapon(id)
	return WeaponModel.new(def) if def != null else null

## Current weapon, or null when the character is fully disarmed.
func current() -> WeaponModel:
	return primary if slot == SLOT_PRIMARY else sidearm

func current_id() -> StringName:
	var weapon := current()
	return weapon.def.id if weapon != null else &""

func current_def() -> WeaponDef:
	var weapon := current()
	return weapon.def if weapon != null else null

## Host aim with a fixture-safe default (only Character is guaranteed to have it).
func _aim_dir() -> Vector2:
	var dir: Variant = _host.get(&"aim_dir")
	return dir if dir is Vector2 else Vector2.RIGHT

## Muzzle centre in world space: barrel tip along the aim. The drawn barrel tip
## and this point come from the same WeaponVisual.muzzle_len, so they agree.
func muzzle_position(aim_dir: Vector2) -> Vector2:
	var def := current_def()
	if def == null or _host == null:
		return _host.global_position if _host != null else Vector2.ZERO
	return _host.global_position + aim_dir * WeaponVisual.muzzle_len(def)

func tick(dt: float, ctx: Dictionary) -> void:
	var arm: float = float(ctx.get(&"arm_mult", 1.0))
	for weapon: WeaponModel in [primary, sidearm]:
		if weapon == null:
			continue
		weapon.reload_mult = arm * reload_perk_mult
		weapon.tick(dt, ctx)
	var now_reloading := current() != null and current().is_reloading()
	if _was_reloading and not now_reloading:
		EventBus.weapon_reloaded.emit(_host, current_id())
	_was_reloading = now_reloading

## Trigger pull → ShotRequests (empty array means no shot). Emits shot_fired
## once per trigger pull, not per pellet.
func try_fire(intent: Intent, origin: Vector2, aim: Vector2) -> Array[ShotRequest]:
	var weapon := current()
	if weapon == null:
		return []
	var shots := weapon.try_fire(intent, origin, aim)
	if not shots.is_empty():
		EventBus.shot_fired.emit(
			_host, weapon.def.id, shots[0].origin, shots[0].dir, shots.size())
	return shots

func start_reload() -> bool:
	var weapon := current()
	if weapon == null or not weapon.start_reload():
		return false
	EventBus.sound_emitted.emit(
		_host.global_position, RELOAD_LOUDNESS, &"reload", _host, Enums.Surface.CONCRETE)
	return true

func cycle_mode() -> bool:
	var weapon := current()
	if weapon == null or not weapon.switch_mode():
		return false
	EventBus.fire_mode_changed.emit(_host, weapon.fire_mode())
	return true

## 0 primary, 1 sidearm. A half-finished reload is cancelled, not carried —
## the same rule the player sees (design §6), applied to the shared model.
func switch_slot(new_slot: int) -> bool:
	if new_slot != SLOT_PRIMARY and new_slot != SLOT_SIDEARM:
		return false
	if new_slot == slot:
		return false
	var target := primary if new_slot == SLOT_PRIMARY else sidearm
	if target == null:
		return false
	var previous := current()
	if previous != null and previous.is_reloading():
		previous.cancel_reload()
	slot = new_slot
	_was_reloading = false
	target.equip()
	EventBus.weapon_switched.emit(_host, target.def.id)
	return true

## Throw kit entry `index`. Returns the EquipmentDef (null when empty/invalid);
## the EquipmentSystem spawns the physical grenade from the emitted event.
func throw_equipment(index: int) -> EquipmentDef:
	if index < 0 or index >= kit_ids.size() or kit_counts[index] <= 0:
		return null
	var def := Defs.equipment(kit_ids[index])
	if def == null:
		return null
	kit_counts[index] -= 1
	var pos := _host.global_position + _aim_dir() * THROW_OFFSET
	EventBus.equipment_thrown.emit(_host, def.id, pos)
	return def

func kit_count(index: int) -> int:
	return kit_counts[index] if index >= 0 and index < kit_counts.size() else 0

func _build_kit(class_def: ClassDef) -> void:
	kit_ids.clear()
	kit_counts.clear()
	if class_def == null:
		return
	# ClassDef.equipment is the kit in slot order; a repeated id (Ram: two
	# flashes) is two separate slots, not one stack of two.
	for id: StringName in class_def.equipment:
		if Defs.equipment(id) == null:
			continue
		kit_ids.append(id)
		kit_counts.append(1)