class_name BodyModel
extends RefCounted
## Body parts, armor, bleeding, regen, bandage, cripple modifiers.
## Pure: no nodes, no EventBus. Contract: docs/architecture.md §4;
## numbers: docs/design/game-design.md §7.

## Part max HP, indexed by Enums.Part.
const PART_MAX: Array[float] = [35.0, 80.0, 18.0, 18.0, 22.0, 22.0]

## Bleed thresholds (design §7): limbs below 50%, torso below 35%.
const LIMB_BLEED_RATIO := 0.5
const LIMB_BLEED_RATE := 1.5
const TORSO_BLEED_RATIO := 0.35
const TORSO_BLEED_RATE := 2.5

## Armor absorb fractions (design §6/§7) and durability per slot.
const VEST_ABSORB := 0.40
const HELMET_ABSORB := 0.60
const VEST_MAX_DURABILITY := 100.0
const HELMET_MAX_DURABILITY := 60.0

const REGEN_DELAY := 7.0
const REGEN_RATE := 2.0
const REGEN_CAP_RATIO := 0.70
const BANDAGE_TIME := 2.8
const BANDAGE_HEAL := 25.0

## Cripple (<30% part HP): leg speed ×0.55, arm spread ×1.6, reload ×1.3.
const CRIPPLE_RATIO := 0.30
const CRIPPLED_LEG_SPEED_MULT := 0.55
const CRIPPLED_ARM_SPREAD_MULT := 1.6
const CRIPPLED_ARM_RELOAD_MULT := 1.3

var hp: Array[float] = []
## Per-part bleed rate, HP/s, indexed by Enums.Part.
var bleed: Array[float] = []
var vest_durability: float = 0.0
var helmet_durability: float = 0.0
var alive: bool = true
var bandaging: bool = false
var bandage_progress: float = 0.0

var _regen_timer: float = 0.0
var _bandage_target: int = -1

func _init(has_vest: bool = true, has_helmet: bool = true) -> void:
	hp.resize(Enums.PART_COUNT)
	bleed.resize(Enums.PART_COUNT)
	for i: int in Enums.PART_COUNT:
		hp[i] = PART_MAX[i]
		bleed[i] = 0.0
	vest_durability = VEST_MAX_DURABILITY if has_vest else 0.0
	helmet_durability = HELMET_MAX_DURABILITY if has_helmet else 0.0

## Apply one bullet. `attacker_info` is opaque to the model (killfeed/score
## bookkeeping only); the node keeps it, the pure model just ignores it.
func apply_hit(part: int, base_dmg: float, pen_mult: float, _attacker_info: Variant = null, armor_piercing: bool = false) -> HitResult:
	var result := HitResult.new()
	if not alive:
		return result
	var dmg := base_dmg * Enums.PART_DAMAGE_MULT[part] * pen_mult
	var before := hp[part]
	var absorbed := 0.0 if armor_piercing else _absorb_damage(part, dmg)
	dmg -= absorbed
	result.absorbed = absorbed
	_set_hp(part, before - dmg)
	result.bleed_added = _update_bleed(part)
	if is_crippled(part) and before / PART_MAX[part] >= CRIPPLE_RATIO:
		result.crippled = part
	_regen_timer = 0.0
	if bandaging and dmg > 0.0:
		interrupt_bandage()
	if hp[Enums.Part.HEAD] <= 0.0 or hp[Enums.Part.TORSO] <= 0.0:
		alive = false
		result.died = true
		result.fatal_part = Enums.Part.HEAD if hp[Enums.Part.HEAD] <= 0.0 else Enums.Part.TORSO
		interrupt_bandage()
	return result

## Bleed drain, torso regen, bandage channel.
func tick(dt: float) -> void:
	if dt <= 0.0 or not alive:
		return
	var drain := bleed_rate_total()
	if drain > 0.0:
		_set_hp(Enums.Part.TORSO, hp[Enums.Part.TORSO] - drain * dt)
		if hp[Enums.Part.TORSO] <= 0.0:
			alive = false
			return
	_regen_timer += dt
	_tick_regen(dt)
	_tick_bandage(dt)

## Start the 2.8 s channel. Needs a bleeding wound or a damaged part.
func start_bandage() -> bool:
	if not alive or bandaging:
		return false
	_bandage_target = _bandage_candidate()
	if _bandage_target < 0:
		return false
	bandaging = true
	bandage_progress = 0.0
	return true

func interrupt_bandage() -> void:
	bandaging = false
	bandage_progress = 0.0
	_bandage_target = -1

func part_hp(part: int) -> float:
	return hp[part]

func part_ratio(part: int) -> float:
	return hp[part] / PART_MAX[part]

func is_crippled(part: int) -> bool:
	return part_ratio(part) < CRIPPLE_RATIO

func is_bleeding(part: int) -> bool:
	return bleed[part] > 0.0

func is_bleeding_any() -> bool:
	return bleed_rate_total() > 0.0

func bleed_rate_total() -> float:
	var total := 0.0
	for rate: float in bleed:
		total += rate
	return total

## Cripple modifiers, injected into MovementModel / WeaponModel / Arsenal.
func speed_mult() -> float:
	return CRIPPLED_LEG_SPEED_MULT if _leg_crippled() else 1.0

func spread_mult() -> float:
	return CRIPPLED_ARM_SPREAD_MULT if _arm_crippled() else 1.0

func reload_mult() -> float:
	return CRIPPLED_ARM_RELOAD_MULT if _arm_crippled() else 1.0

func can_sprint() -> bool:
	return not _leg_crippled()

## Topdown hit zones in character local space: +X = forward (aim), +Y = right.
## head  = the small disc at center+forward*2 (r 5)
## arms  = beside the shoulders (|lateral| > 6, not behind them)
## legs  = behind the hips (forward < -4) or wide to the rear (|lateral| > 8)
## torso = everything else
static func part_at_offset(local_offset: Vector2) -> Enums.Part:
	var forward := local_offset.x
	var lateral := absf(local_offset.y)
	# Torso-dominant: center mass is torso so most hits contribute to the kill.
	# Head is a small center-forward disc; limbs only at the extreme periphery
	# (wide limb zones made most hits non-lethal arm/leg chips -> bullet sponges).
	if (local_offset - Vector2(3.0, 0.0)).length() <= 4.0:
		return Enums.Part.HEAD
	if lateral > 8.5 and forward > -1.0:
		return Enums.Part.ARM_R if local_offset.y > 0.0 else Enums.Part.ARM_L
	if forward < -8.0:
		return Enums.Part.LEG_R if local_offset.y > 0.0 else Enums.Part.LEG_L
	return Enums.Part.TORSO

func _leg_crippled() -> bool:
	return is_crippled(Enums.Part.LEG_L) or is_crippled(Enums.Part.LEG_R)

func _arm_crippled() -> bool:
	return is_crippled(Enums.Part.ARM_L) or is_crippled(Enums.Part.ARM_R)

func _set_hp(part: int, value: float) -> void:
	hp[part] = clampf(value, 0.0, PART_MAX[part])

## Armor only covers torso and head; damaged armor soaks less than listed and
## breaks when its durability runs out.
func _absorb_damage(part: int, dmg: float) -> float:
	var durability := 0.0
	var absorb := 0.0
	if part == Enums.Part.TORSO:
		durability = vest_durability
		absorb = VEST_ABSORB
	elif part == Enums.Part.HEAD:
		durability = helmet_durability
		absorb = HELMET_ABSORB
	if durability <= 0.0:
		return 0.0
	# Durability is a pool of HP the plate can soak before it is spent.
	var absorbed := minf(dmg * absorb, durability)
	if part == Enums.Part.TORSO:
		vest_durability = maxf(0.0, vest_durability - absorbed)
	else:
		helmet_durability = maxf(0.0, helmet_durability - absorbed)
	return absorbed

## Returns the bleed rate added by this hit (0 when the part already bleeds).
func _update_bleed(part: int) -> float:
	var rate := 0.0
	if part_ratio(part) < (TORSO_BLEED_RATIO if part == Enums.Part.TORSO else LIMB_BLEED_RATIO):
		rate = TORSO_BLEED_RATE if part == Enums.Part.TORSO else LIMB_BLEED_RATE
	if rate <= bleed[part]:
		return 0.0
	bleed[part] = rate
	return rate

## Worst bleeding part first, else the most damaged one; -1 when unhurt.
func _bandage_candidate() -> int:
	var target := -1
	var worst := 0.0
	for i: int in Enums.PART_COUNT:
		if bleed[i] > worst:
			worst = bleed[i]
			target = i
	if target >= 0:
		return target
	var worst_ratio := 1.0
	for i: int in Enums.PART_COUNT:
		var ratio := part_ratio(i)
		if ratio < worst_ratio:
			worst_ratio = ratio
			target = i
	return target if worst_ratio < 1.0 else -1

func _tick_regen(dt: float) -> void:
	if _regen_timer < REGEN_DELAY or is_bleeding_any():
		return
	_set_hp(Enums.Part.TORSO, minf(
		PART_MAX[Enums.Part.TORSO] * REGEN_CAP_RATIO,
		hp[Enums.Part.TORSO] + REGEN_RATE * dt))

func _tick_bandage(dt: float) -> void:
	if not bandaging:
		return
	bandage_progress += dt / BANDAGE_TIME
	if bandage_progress < 1.0:
		return
	bleed[_bandage_target] = 0.0
	_set_hp(_bandage_target, hp[_bandage_target] + BANDAGE_HEAL)
	interrupt_bandage()