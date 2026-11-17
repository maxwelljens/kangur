class_name Ballistics
extends RefCounted
## Static ballistics maths: spread cone, bloom, recoil, falloff, penetration.
## Contract: docs/architecture.md §4; formulas: docs/design/game-design.md §6 +
## docs/research/genre-mechanics.md §7.3. Determinism comes from the injected
## RandomNumberGenerator — never from the global RNG.

## Cone multipliers (design §6).
const CROUCH_SPREAD_MULT := 0.75
const FOCUS_SPREAD_MULT := 0.55
## Movement penalty: 1.0 at rest → 4.0 at full speed (1 + 3.0·r^1.5).
const MOVE_SPREAD_COEFF := 3.0
const MOVE_SPREAD_EXP := 1.5
## Exponential bloom never reaches zero; snap below this to restore first-shot truth.
const BLOOM_EPSILON := 0.01
## Recoil jitter around the push direction, as a fraction of kick (research §7.3).
const RECOIL_JITTER_MIN := -0.35
const RECOIL_JITTER_MAX := 1.0


## Effective cone half-angle in degrees.
## `stance` is an Enums.Stance value; `arm_mult` is 1.6 for a crippled arm;
## `focus_override` is the class-perk focus multiplier (0 = use the default).
static func spread_deg(
	base: float, bloom: float, vel: float, vmax: float,
	stance: int, focus: bool, arm_mult: float, focus_override: float = 0.0
) -> float:
	var ratio := 0.0 if vmax <= 0.0 else clampf(vel / vmax, 0.0, 1.0)
	var move_mult := 1.0 + MOVE_SPREAD_COEFF * pow(ratio, MOVE_SPREAD_EXP)
	var stance_mult := CROUCH_SPREAD_MULT if stance == Enums.Stance.CROUCH else 1.0
	var focus_mult_value := focus_override if focus_override > 0.0 else FOCUS_SPREAD_MULT
	var focus_mult := focus_mult_value if focus else 1.0
	return (base + bloom) * move_mult * stance_mult * focus_mult * arm_mult

## One pellet direction: uniform random angle inside ±spread_deg of `aim`.
static func sample_dir(rng: RandomNumberGenerator, aim: Vector2, cone_deg: float) -> Vector2:
	var dir := aim.normalized() if aim != Vector2.ZERO else Vector2.RIGHT
	if cone_deg <= 0.0:
		return dir
	return dir.rotated(deg_to_rad(rng.randf_range(-cone_deg, cone_deg)))

## Per-shot bloom accumulation, capped at `bloom_max` (absolute cap, research §7.3).
static func bloom_add(bloom: float, per_shot: float, bloom_max: float) -> float:
	return minf(bloom_max, bloom + per_shot)

## Exponential recovery: `rate` is 1/s, so ~95% is gone after 3/rate seconds.
static func bloom_decay(bloom: float, dt: float, rate: float) -> float:
	if bloom <= 0.0:
		return 0.0
	var next := bloom * exp(-maxf(rate, 0.0) * dt)
	return 0.0 if next < BLOOM_EPSILON else next

## Recoil impulse as an aim-vector offset: rotates the aim by ~kick_deg, biased
## one way so a spray walks, with random lateral jitter per shot.
## Add the result to the aim vector, then normalize.
static func recoil_kick(aim: Vector2, rng: RandomNumberGenerator, kick_deg: float) -> Vector2:
	var dir := aim.normalized() if aim != Vector2.ZERO else Vector2.RIGHT
	var lateral := rng.randf_range(RECOIL_JITTER_MIN, RECOIL_JITTER_MAX) * deg_to_rad(kick_deg)
	return dir.rotated(lateral) - dir

## Exponential spring back toward pre-fire aim.
static func recoil_recover(offset: Vector2, dt: float, rate: float) -> Vector2:
	if offset == Vector2.ZERO:
		return Vector2.ZERO
	return offset * exp(-maxf(rate, 0.0) * dt)

## Linear damage falloff from `start` to `end`, floored at `min_mult`.
static func falloff(dmg: float, dist: float, start: float, end: float, min_mult: float) -> float:
	if dist <= start:
		return dmg
	if end <= start or dist >= end:
		return dmg * min_mult
	return lerpf(dmg, dmg * min_mult, (dist - start) / (end - start))

## Damage after passing one surface (0.55 wood/glass, 0.35 thin concrete, …).
static func pen_damage(dmg: float, pen_mult: float) -> float:
	return dmg * maxf(pen_mult, 0.0)