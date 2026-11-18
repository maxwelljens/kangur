extends RefCounted
## Class perk modifiers (design §8). Read once by Character.setup(); the values
## are injected into Movement / Arsenal / Aim, never mutated globally.
## Keys are the perk ids; Character falls back to the class id when a ClassDef
## has an empty perk_id, so either data convention works.

const VANGUARD := &"vanguard"
const PATHFINDER := &"pathfinder"
const BULWARK := &"bulwark"
const RAM := &"ram"
const LONGSHOT := &"longshot"

const SPEED_FACTOR: Dictionary[StringName, float] = {
	PATHFINDER: 1.08,
	RAM: 0.95,
}
const RELOAD_FACTOR: Dictionary[StringName, float] = {
	VANGUARD: 0.9,
}
## Pump/shotgun cycle time factor (Ram): lower = faster.
const CYCLE_FACTOR: Dictionary[StringName, float] = {
	RAM: 0.8,
}
## Focus spread multiplier; 0 = use the weapon/Ballistics default.
const FOCUS_SPREAD: Dictionary[StringName, float] = {
	LONGSHOT: 0.4,
}
const SUPPRESSION_ERROR_DEG: Dictionary[StringName, float] = {
	BULWARK: 1.5,
}
const SPOT_PERSIST_BONUS_S: Dictionary[StringName, float] = {
	PATHFINDER: 4.0,
}

static func speed_mult(perk_id: StringName) -> float:
	return SPEED_FACTOR.get(perk_id, 1.0)

static func reload_mult(perk_id: StringName) -> float:
	return RELOAD_FACTOR.get(perk_id, 1.0)

static func cycle_mult(perk_id: StringName) -> float:
	return CYCLE_FACTOR.get(perk_id, 1.0)

static func focus_spread(perk_id: StringName) -> float:
	return FOCUS_SPREAD.get(perk_id, 0.0)

static func suppression_error_deg(perk_id: StringName) -> float:
	return SUPPRESSION_ERROR_DEG.get(perk_id, 0.0)

static func spot_persist_bonus_s(perk_id: StringName) -> float:
	return SPOT_PERSIST_BONUS_S.get(perk_id, 0.0)