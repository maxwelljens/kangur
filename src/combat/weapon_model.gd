class_name WeaponModel
extends RefCounted
## One weapon instance: ammo, fire modes, bloom, recoil, reload stages.
## Pure: no nodes, no EventBus. Contract: docs/architecture.md §4;
## numbers: docs/design/game-design.md §6. Spread maths lives in Ballistics.

## Reload stage ids (HUD + animation hooks).
const STAGE_NONE := 0
const STAGE_MAG_OUT := 1
const STAGE_MAG_IN := 2
const STAGE_BOLT := 3
## Fraction of reload_time spent in each stage (mag_out, mag_in, bolt).
const RELOAD_STAGE_FRACTIONS: Array[float] = [0.30, 0.50, 0.20]
## Enforced pause after a burst, as a multiple of the shot interval.
const BURST_PAUSE_MULT := 2.5
## Recoil dampers (design §3: focus ×0.7; research §7.3: crouch ×0.85).
const CROUCH_RECOIL_MULT := 0.85
const FOCUS_RECOIL_MULT := 0.70
## Timer comparisons: dt sums land one ULP off (0.1 vs 6 × 1/60).
const TIMER_EPSILON := 1e-9

var def: WeaponDef

## Runtime state.
var mag: int = 0
## Round-level reserve pool (no partial mag is ever lost on reload).
var reserve_rounds: int = 0
var bloom: float = 0.0
var recoil_offset: Vector2 = Vector2.ZERO
var cycle_timer: float = 0.0
var reload_timer: float = 0.0
var reload_stage: int = STAGE_NONE
var fire_mode_index: int = 0
var burst_left: int = 0
var equip_timer: float = 0.0
## True when the last trigger pull found an empty mag (drives the click sound).
var dry_fire: bool = false

## Injected by Arsenal from the crippled arm (1.3) — slows the reload channel.
var reload_mult: float = 1.0

var _ctx: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _init(weapon_def: WeaponDef) -> void:
	def = weapon_def
	mag = def.mag_size
	reserve_rounds = def.reserve_mags * def.mag_size
	equip_timer = def.equip_time

## Advance timers. `ctx` keys: vel, vmax, stance, focus, arm_mult, rng.
## Camera/Aim nodes read `recoil_offset`; spread needs the movement state here.
func tick(dt: float, ctx: Dictionary) -> void:
	_ctx = ctx
	equip_timer = maxf(0.0, equip_timer - dt)
	# Carry the sub-tick overshoot (bounded to one dt) so the cadence averages
	# to the real interval; clamping at 0 would round 650 RPM down to 600.
	# A timer that is already ready stays at 0 so a fresh shot gets a full
	# interval instead of inheriting the tick that fired it.
	if cycle_timer > 0.0:
		cycle_timer = maxf(cycle_timer - dt, -dt)
	if reload_stage != STAGE_NONE:
		_tick_reload(dt)
	# WeaponDef.bloom_recovery is the exponential rate (1/s): 95% gone in 3/rate s.
	bloom = Ballistics.bloom_decay(bloom, dt, def.bloom_recovery)
	recoil_offset = Ballistics.recoil_recover(recoil_offset, dt, def.recoil_recovery)

## Returns zero or more projectiles (pellets) for this trigger pull.
func try_fire(intent: Intent, origin: Vector2, aim: Vector2) -> Array[ShotRequest]:
	var shots: Array[ShotRequest] = []
	if equip_timer > TIMER_EPSILON or is_reloading() or cycle_timer > TIMER_EPSILON:
		return shots
	if not _trigger_pulled(intent):
		return shots
	if mag <= 0:
		dry_fire = true
		cycle_timer += fire_interval()
		burst_left = 0
		return shots
	dry_fire = false
	if fire_mode() == Enums.FireMode.BURST and burst_left <= 0:
		burst_left = def.burst_count
	_fire(origin, aim, shots)
	return shots

## Called when the weapon is drawn (slot switch); blocks firing until done.
func equip() -> void:
	equip_timer = def.equip_time

func effective_reload_time() -> float:
	return def.reload_time * reload_mult

func start_reload() -> bool:
	if is_reloading() or equip_timer > TIMER_EPSILON:
		return false
	if mag >= def.mag_size or reserve_rounds <= 0:
		return false
	reload_timer = 0.0
	reload_stage = STAGE_MAG_OUT
	burst_left = 0
	return true

## Interruptible: no ammo moves until the reload completes.
func cancel_reload() -> void:
	reload_stage = STAGE_NONE
	reload_timer = 0.0

## Cycle to the next supported fire mode. False when the weapon has only one.
func switch_mode() -> bool:
	if def.fire_modes.size() <= 1:
		return false
	fire_mode_index = (fire_mode_index + 1) % def.fire_modes.size()
	burst_left = 0
	return true

func fire_mode() -> int:
	if def.fire_modes.is_empty():
		return Enums.FireMode.SEMI
	return def.fire_modes[fire_mode_index]

func fire_interval() -> float:
	return 60.0 / def.rpm if def.rpm > 0.0 else 0.0

func is_reloading() -> bool:
	return reload_stage != STAGE_NONE

func is_equipped() -> bool:
	return equip_timer <= TIMER_EPSILON

## 0..1; 0 when not reloading.
func reload_progress() -> float:
	if not is_reloading():
		return 0.0
	var total := effective_reload_time()
	return 0.0 if total <= 0.0 else clampf(reload_timer / total, 0.0, 1.0)

## Whole mags left, for HUD pips.
func reserve_mags() -> int:
	return reserve_rounds / def.mag_size

## Cone half-angle this shot would use, degrees (HUD crosshair + AI aim error).
func current_spread_deg() -> float:
	var vel: float = _ctx.get("vel", 0.0)
	var vmax: float = _ctx.get("vmax", 215.0)
	var stance: int = _ctx.get("stance", Enums.Stance.STAND)
	var focus: bool = _ctx.get("focus", false)
	var arm_mult: float = _ctx.get("arm_mult", 1.0)
	return Ballistics.spread_deg(def.spread_base, bloom, vel, vmax, stance, focus, arm_mult)

func _trigger_pulled(intent: Intent) -> bool:
	match fire_mode():
		Enums.FireMode.AUTO:
			return intent.fire
		Enums.FireMode.BURST:
			return burst_left > 0 or intent.fire_press
		_:
			return intent.fire_press

func _fire(origin: Vector2, aim: Vector2, shots: Array[ShotRequest]) -> void:
	var rng := _rng_for_shot()
	var cone := current_spread_deg()
	for _i: int in maxi(def.pellets, 1):
		var shot := ShotRequest.new()
		shot.origin = origin
		shot.dir = Ballistics.sample_dir(rng, aim, cone)
		shot.speed = def.bullet_speed
		shot.damage = def.damage
		shot.penetration = def.penetration
		shot.falloff_start = def.falloff_start
		shot.falloff_end = def.falloff_end
		shot.min_mult = def.min_mult
		shot.tracer_len = def.falloff_end
		shot.weapon_id = def.id
		shots.append(shot)
	mag -= 1
	# WeaponDef.bloom_max is the absolute cone cap, so the bloom budget is the rest.
	bloom = Ballistics.bloom_add(bloom, def.bloom_per_shot, maxf(0.0, def.bloom_max - def.spread_base))
	var recoil := def.recoil_kick
	var focus: bool = _ctx.get("focus", false)
	var stance: int = _ctx.get("stance", Enums.Stance.STAND)
	if focus:
		recoil *= FOCUS_RECOIL_MULT
	if stance == Enums.Stance.CROUCH:
		recoil *= CROUCH_RECOIL_MULT
	recoil_offset += Ballistics.recoil_kick(aim, rng, recoil)
	if fire_mode() == Enums.FireMode.BURST:
		burst_left = maxi(0, burst_left - 1)
		cycle_timer += fire_interval() * (BURST_PAUSE_MULT if burst_left == 0 else 1.0)
	else:
		cycle_timer += fire_interval()

func _rng_for_shot() -> RandomNumberGenerator:
	var injected: RandomNumberGenerator = _ctx.get("rng")
	return injected if injected != null else _rng

func _tick_reload(dt: float) -> void:
	reload_timer += dt
	var total := effective_reload_time()
	if total <= 0.0 or reload_timer >= total:
		_finish_reload()
		return
	var frac := reload_timer / total
	var boundary := 0.0
	reload_stage = STAGE_MAG_OUT
	for i: int in RELOAD_STAGE_FRACTIONS.size() - 1:
		boundary += RELOAD_STAGE_FRACTIONS[i]
		if frac >= boundary:
			reload_stage = STAGE_MAG_OUT + i + 1

func _finish_reload() -> void:
	var taken := mini(def.mag_size - mag, reserve_rounds)
	mag += taken
	reserve_rounds -= taken
	reload_stage = STAGE_NONE
	reload_timer = 0.0