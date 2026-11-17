class_name MovementModel
extends RefCounted
## Source-style ground movement for one character. Pure: no nodes, no EventBus.
## Contract: docs/architecture.md §4. Formula: docs/research/genre-mechanics.md
## §2.1 (verbatim `CGameMovement`): friction FIRST, then acceleration.
## The owning node calls tick() in _physics_process and does move_and_slide().

## Injected config (design §3, research §2.3 derived table).
var walk_speed: float = 130.0
var sprint_speed: float = 215.0
var crouch_speed: float = 65.0
var accel_rate: float = 10.0
var friction: float = 9.0
var stop_speed: float = 60.0
## Externally injected multiplier: crippled leg (0.55), class, weapon weight.
var speed_mult: float = 1.0
## False when a crippled leg forbids sprinting at all.
var can_sprint: bool = true

## State.
var velocity: Vector2 = Vector2.ZERO
var stamina: float = STAMINA_MAX
var stance: Enums.Stance = Enums.Stance.STAND
var exhausted: bool = false
var sprinting: bool = false

const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 18.0
const STAMINA_REGEN := 12.0
const STAMINA_REST_DELAY := 1.0
const EXHAUST_RECOVER := 30.0
const FOCUS_SPEED_MULT := 0.5
## Source skips friction below 0.1 u/s; keeps the constant stop from jittering.
const MIN_FRICTION_SPEED := 0.1

var _rest_time: float = 0.0

func tick(intent: Intent, dt: float) -> Vector2:
	if dt <= 0.0:
		return velocity
	stance = intent.stance
	sprinting = _can_sprint(intent)
	_apply_friction(dt, target_speed(intent))
	var wishdir := intent.move.normalized()
	if wishdir != Vector2.ZERO:
		# |move| scales wishspeed so analog sticks/AI throttles stay proportional.
		_accelerate(wishdir, target_speed(intent) * minf(intent.move.length(), 1.0), dt)
	_tick_stamina(dt)
	return velocity

## Maximum (pre-focus) speed this tick's intent allows.
func target_speed(intent: Intent) -> float:
	var base := crouch_speed
	if intent.stance == Enums.Stance.STAND:
		base = sprint_speed if _can_sprint(intent) else walk_speed
	var mult := FOCUS_SPEED_MULT if intent.focus else 1.0
	return base * speed_mult * mult

func current_speed() -> float:
	return velocity.length()

func stamina_ratio() -> float:
	return stamina / STAMINA_MAX

## Source `CGameMovement::Friction`. The stopspeed floor is clamped to the wish
## speed while moving: at 60 px/s it exceeds crouch+focus (32.5) and would make
## that stance unreachable (research §2.3 flags exactly this).
func _apply_friction(dt: float, wish_speed: float) -> void:
	var speed := velocity.length()
	if speed < MIN_FRICTION_SPEED:
		return
	var floor_speed := stop_speed
	if wish_speed > 0.0:
		floor_speed = minf(stop_speed, wish_speed)
	var control := maxf(speed, floor_speed)
	var newspeed := maxf(0.0, speed - control * friction * dt)
	velocity *= newspeed / speed

## Source `CGameMovement::Accelerate` (surface friction = 1 here).
func _accelerate(wishdir: Vector2, wishspeed: float, dt: float) -> void:
	var currentspeed := velocity.dot(wishdir)
	var addspeed := wishspeed - currentspeed
	if addspeed <= 0.0:
		return
	var accelspeed := minf(accel_rate * dt * wishspeed, addspeed)
	velocity += wishdir * accelspeed

func _can_sprint(intent: Intent) -> bool:
	if not can_sprint or stance != Enums.Stance.STAND:
		return false
	if not intent.sprint or exhausted or stamina <= 0.0:
		return false
	return intent.move.length() > 0.0

func _tick_stamina(dt: float) -> void:
	if sprinting:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * dt)
		_rest_time = 0.0
		if stamina <= 0.0:
			exhausted = true
		return
	_rest_time += dt
	if _rest_time >= STAMINA_REST_DELAY:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * dt)
	if exhausted and stamina >= EXHAUST_RECOVER:
		exhausted = false