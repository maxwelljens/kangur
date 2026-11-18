extends Node
## Motor — MovementModel wrapper. Owns move_and_slide() on the host body and
## the footstep sound cycle. No gameplay math here: the pure model decides.
## Contract: docs/architecture.md §4 ("Motor: MovementModel + move_and_slide").

## Footstep cadence in px of travelled distance, per surface feel (design §12).
const STRIDE_PX := 56.0
const CROUCH_STRIDE_PX := 40.0
## Below this speed the character is standing still (no step, no leg cycle).
const MIN_STEP_SPEED := 8.0
## Audible radius per stance, px (design §12 loudness table).
const LOUDNESS_SPRINT := 420.0
const LOUDNESS_WALK := 260.0
const LOUDNESS_CROUCH := 120.0
## Spread normalisation reference when the model has no sprint speed set.
const FALLBACK_VMAX := 215.0

var model: MovementModel = MovementModel.new()
## Injected by World: func(pos: Vector2) -> int returning Enums.Surface.
## Unset → every step is CONCRETE (no world query yet).
var surface_provider: Callable = Callable()

var _host: CharacterBody2D = null
var _step_accum: float = 0.0

func setup(host: CharacterBody2D) -> void:
	_host = host

## Advance the model, move the body, emit footsteps. Returns world velocity.
func tick(intent: Intent, dt: float) -> Vector2:
	if _host == null:
		return Vector2.ZERO
	model.tick(intent, dt)
	_host.velocity = model.velocity
	_host.move_and_slide()
	# Move-and-slide clipped velocity feeds back so walls stop the Source-style
	# accel/friction maths instead of letting it build speed into the wall.
	model.velocity = _host.velocity
	_tick_footsteps(dt)
	return _host.velocity

func velocity() -> Vector2:
	return model.velocity

func stance() -> Enums.Stance:
	return model.stance

func stamina_ratio() -> float:
	return model.stamina_ratio()

func stamina() -> float:
	return model.stamina

func is_sprinting() -> bool:
	return model.sprinting

func is_exhausted() -> bool:
	return model.exhausted

func vmax() -> float:
	return model.sprint_speed * model.speed_mult if model.sprint_speed > 0.0 else FALLBACK_VMAX

## Surface under `pos`. Without a World provider every footstep is CONCRETE.
## shortcut: one surface until World.surface_at is injected; upgrade when the
## world wave owns tile custom-data queries.
func surface_at(pos: Vector2) -> int:
	if surface_provider.is_valid():
		return int(surface_provider.call(pos))
	return Enums.Surface.CONCRETE

func _tick_footsteps(dt: float) -> void:
	var speed := model.velocity.length()
	if speed < MIN_STEP_SPEED:
		_step_accum = 0.0
		return
	_step_accum += speed * dt
	var stride := CROUCH_STRIDE_PX if model.stance == Enums.Stance.CROUCH else STRIDE_PX
	if _step_accum < stride:
		return
	_step_accum -= stride
	var loudness := LOUDNESS_CROUCH
	if model.stance == Enums.Stance.STAND:
		loudness = LOUDNESS_SPRINT if model.sprinting else LOUDNESS_WALK
	var pos := _host.global_position
	EventBus.sound_emitted.emit(
		pos, loudness, &"footstep", _host, surface_at(pos))