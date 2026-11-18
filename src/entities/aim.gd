extends Node
## Aim — aim_dir state, recoil application, AI turn-rate/aim-error pipeline.
## The player aims instantly (cursor); an AI is limited by reaction, turn rate
## and a decaying aim error. Fairness: both then feed the SAME WeaponModel
## spread. Numbers: docs/research/genre-mechanics.md §5.5–5.6.

## Fallbacks when no DifficultyDef/Personality is injected (Operator-ish).
const DEFAULT_TURN_RATE_DEG := 300.0
const DEFAULT_REACTION_S := 0.28
const DEFAULT_ERROR_INITIAL_DEG := 4.0
const DEFAULT_ERROR_FLOOR_DEG := 1.3
const DEFAULT_ERROR_TAU_S := 0.85

## Per-tick angular deadband: an AI that is already on target does not wobble.
const ANGLE_DEADBAND_DEG := 0.05
## Below this length an input aim vector is treated as "no change".
const MIN_AIM_LEN := 0.0001

## Final aim direction after recoil (world space, normalized).
var aim_dir: Vector2 = Vector2.RIGHT
## Where the character is pointing before the recoil offset is added.
var tracking_dir: Vector2 = Vector2.RIGHT
## False for the player (instant cursor aim).
var ai_limited: bool = false

## AI pipeline parameters (degrees / seconds).
var turn_rate_deg: float = DEFAULT_TURN_RATE_DEG
var reaction_s: float = DEFAULT_REACTION_S
var error_initial_deg: float = DEFAULT_ERROR_INITIAL_DEG
var error_floor_deg: float = DEFAULT_ERROR_FLOOR_DEG
var error_tau_s: float = DEFAULT_ERROR_TAU_S

var _target_dir: Vector2 = Vector2.RIGHT
var _reaction_left: float = 0.0
var _engage_time: float = 0.0
var _error_sign: float = 1.0
var _engaged: bool = false
var _rng := RandomNumberGenerator.new()

func setup(rng: RandomNumberGenerator, is_ai: bool) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	ai_limited = is_ai

## One-shot AI tuning; Character fills this from the DifficultyDef ranges.
func configure_ai(params: Dictionary) -> void:
	turn_rate_deg = float(params.get(&"turn_rate_deg", turn_rate_deg))
	reaction_s = float(params.get(&"reaction_s", reaction_s))
	error_initial_deg = float(params.get(&"error_initial_deg", error_initial_deg))
	error_floor_deg = float(params.get(&"error_floor_deg", error_floor_deg))
	error_tau_s = float(params.get(&"error_tau_s", error_tau_s))

## Advance and return the world aim direction. `recoil_offset` comes from the
## current WeaponModel (Ballistics.recoil_kick) and is applied here only, so the
## rig and the ballistics agree on the muzzle vector.
func tick(dt: float, intent: Intent, recoil_offset: Vector2) -> Vector2:
	if not ai_limited:
		var wanted := intent.aim.normalized()
		if wanted.length() > MIN_AIM_LEN:
			tracking_dir = wanted
	else:
		_tick_ai(dt, intent.aim)
	var fired_dir := (tracking_dir + recoil_offset)
	aim_dir = fired_dir.normalized() if fired_dir.length() > MIN_AIM_LEN else tracking_dir
	return aim_dir

## AI got a fresh sighting: restart the reaction clock and roll the aim error.
func acquire(dir: Vector2) -> void:
	_engage_time = 0.0
	_reaction_left = reaction_s
	_error_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	_engaged = true
	if dir.length() > MIN_AIM_LEN:
		_target_dir = dir.normalized()

## Target lost: freeze the current tracking direction (no free pre-aim).
func release() -> void:
	_engaged = false

## Current applied error, degrees (0 for the player).
func error_deg() -> float:
	if not ai_limited or not _engaged:
		return 0.0
	return maxf(error_floor_deg, error_initial_deg * exp(-_engage_time / maxf(error_tau_s, 0.001)))

func _tick_ai(dt: float, wanted: Vector2) -> void:
	if wanted.length() > MIN_AIM_LEN:
		_target_dir = wanted.normalized()
	if not _engaged:
		# Out of combat: face the look/movement direction freely (no reaction lag,
		# no frozen right-facing). Combat reaction/error only apply while engaged.
		if wanted.length() > MIN_AIM_LEN:
			tracking_dir = wanted.normalized()
		return
	_engage_time += dt
	if _reaction_left > 0.0:
		_reaction_left = maxf(0.0, _reaction_left - dt)
		return
	var goal := _target_dir.rotated(deg_to_rad(error_deg() * _error_sign))
	var delta := rad_to_deg(tracking_dir.angle_to(goal))
	if absf(delta) <= ANGLE_DEADBAND_DEG:
		return
	var step := clampf(delta, -turn_rate_deg * dt, turn_rate_deg * dt)
	tracking_dir = tracking_dir.rotated(deg_to_rad(step))