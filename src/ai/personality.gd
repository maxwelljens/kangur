class_name Personality
extends RefCounted
## One NPC's rolled temperament. Traits are 0..1 and only ever weight utility
## scores — no trait hardcodes a decision (design §9.2). Rolled per match from a
## seeded RNG, so the same seed reproduces the same squad and a new seed does not.

const TRAIT_NAMES: Array[StringName] = [
	&"aggression", &"caution", &"discipline", &"aim_skill",
	&"reaction", &"campiness", &"curiosity", &"independence",
]

## Roll ranges per trait. Wide enough that two NPCs read differently, narrow
## enough that nobody is a caricature. Centres are pulled toward the decisive
## side of the scale: sims showed a campy roster producing elimination
## timeouts (design §9 "human tempo", not "hold a corner for eight minutes").
const RANGES: Dictionary[StringName, Vector2] = {
	&"aggression": Vector2(0.25, 0.95),
	&"caution": Vector2(0.10, 0.85),
	&"discipline": Vector2(0.10, 0.95),
	&"aim_skill": Vector2(0.20, 0.95),
	&"reaction": Vector2(0.20, 0.95),
	&"campiness": Vector2(0.00, 0.75),
	&"curiosity": Vector2(0.15, 0.90),
	&"independence": Vector2(0.00, 0.85),
}
## Bell-curve width: average of 3 uniform rolls ≈ human-ish center weighting.
const BELL_ROLLS := 3
## Difficulty shifts, as a fraction of the remaining headroom to 1.
const DIFFICULTY_SHIFT := 0.5

var aggression: float = 0.5
var caution: float = 0.5
var discipline: float = 0.5
var aim_skill: float = 0.5
var reaction: float = 0.5
var campiness: float = 0.5
var curiosity: float = 0.5
var independence: float = 0.5

## Seeded roll. `difficulty` biases aggression/discipline only (design §9:
## presets scale temperament, never sensors). Aim error / turn rate are
## configured separately on Aim from the DifficultyDef ranges.
static func roll(rng: RandomNumberGenerator, difficulty: DifficultyDef = null) -> Personality:
	var p := Personality.new()
	var aggression_bias: float = difficulty.aggression_bias if difficulty != null else 0.0
	var discipline_bias: float = difficulty.discipline_bias if difficulty != null else 0.0
	for key: StringName in TRAIT_NAMES:
		var span: Vector2 = RANGES[key]
		var value := lerpf(span.x, span.y, _bell(rng))
		if key == &"aggression":
			value += (1.0 - value) * aggression_bias * DIFFICULTY_SHIFT
		elif key == &"discipline":
			value += (1.0 - value) * discipline_bias * DIFFICULTY_SHIFT
		p.set(key, clampf(value, 0.0, 1.0))
	return p

static func _bell(rng: RandomNumberGenerator) -> float:
	var sum := 0.0
	for _i: int in BELL_ROLLS:
		sum += rng.randf()
	return sum / float(BELL_ROLLS)

func trait_value(key: StringName) -> float:
	return float(get(key))

## 0..1 → readable tag for the F3 overlay.
func label() -> String:
	var tags: Array[String] = []
	if aggression > 0.65:
		tags.append("push")
	if caution > 0.65:
		tags.append("careful")
	if discipline > 0.7:
		tags.append("calm")
	if campiness > 0.65:
		tags.append("camp")
	if curiosity > 0.65:
		tags.append("nosy")
	if independence > 0.6:
		tags.append("lone")
	return ",".join(tags) if not tags.is_empty() else "steady"

func _to_string() -> String:
	return "Personality(%s)" % label()