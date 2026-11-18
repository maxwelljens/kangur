extends Node2D
## Procedural vector operator. One canvas item, local space +X = aim, +Y = right
## (matches BodyModel.part_at_offset). Draw order per docs/design/art-direction.md
## §1: shadow → legs → torso → head → arms → weapon → status overlays.
## All colours come from FactionDef (set_faction) or the palette consts below.

## Palette fallbacks (art-direction §1). FactionDef colours win when present.
const WeaponVisual := preload("res://src/entities/weapon_visual.gd")

const BASTION_PRIMARY := Color(0.243, 0.361, 0.463)   # #3E5C76 slate
const BASTION_ACCENT := Color(0.949, 0.647, 0.255)    # #F2A541 amber
const BASTION_VISOR := Color(0.482, 0.922, 0.831)     # cyan glint
const SIROCCO_PRIMARY := Color(0.769, 0.333, 0.176)   # #C4552D burnt
const SIROCCO_ACCENT := Color(0.290, 0.306, 0.329)    # #4A4E54 gunmetal
const SIROCCO_VISOR := Color(1.0, 0.42, 0.25)         # red-orange glint

const SHADOW := Color(0.0, 0.0, 0.0, 0.30)
const BLOOD := Color(0.478, 0.122, 0.122, 0.85)       # #7A1F1F
const BLOOD_POOL := Color(0.478, 0.122, 0.122, 0.55)
const GUNMETAL := Color(0.38, 0.40, 0.43)
const GUNMETAL_DARK := Color(0.14, 0.15, 0.17)
const SKIN := Color(0.72, 0.57, 0.45)
const TROUSERS := Color(0.23, 0.25, 0.28)
const BOOTS := Color(0.09, 0.10, 0.12)
const HELMET_CROWN := Color(0.20, 0.22, 0.25)
const BANDAGE := Color(0.93, 0.93, 0.88)
const FLINCH := Color(1.0, 0.25, 0.2, 0.55)
const BLIND := Color(1.0, 1.0, 1.0, 1.0)
## Below this speed the rig uses the planted-legs pose instead of the gait.
const STILL_SPEED := 6.0

## Rig geometry (art-direction §1: torso 18×14, head r6, collision r10).
## Layout is top-down: +X forward (aim), +Y right. Value ladder so the parts
## never merge: boots ~0.10, helmet crown 0.15, gun 0.27, sleeves 0.35×faction,
## vest = faction colour, accents bright. The weapon starts forward of the
## helmet (its stock runs along the right shoulder) so the gun never eats the
## head silhouette.
const TORSO_LEN := 18.0
const TORSO_WID := 14.0
const TORSO_RADIUS := 4.0
const TORSO_CENTER_X := -2.0
## Helmet covers the BodyModel head hit zone (centre +2 forward, r≈5).
const HEAD_RADIUS := 4.6
const HEAD_FORWARD := 2.5
const SHOULDER_X := 2.4
const SHOULDER_Y := 5.8
const SLEEVE_RADIUS := 2.7
const HIP_X := -6.5
const HIP_Y := 4.0
const FOOT_BACK := 9.0
const LEG_WIDTH := 3.8
const BOOT_RADIUS := 2.1
const ARM_WIDTH := 2.1
const HAND_RADIUS := 1.5
const STRIDE_PX := 6.0
const GAIT_RATE := 0.055
const VMAX_REF := 215.0
const VISOR_ARC_RADIUS := 3.0
const VISOR_ARC_HALF := 0.85
## The stock rides the right shoulder, clear of the helmet centre.
const STOCK_Y_OFFSET := 2.6

## Pose constants.
const CROUCH_SCALE := 0.82
const CROUCH_TUCK := 0.55
const SPRINT_LEAN_PX := 2.0
const FOCUS_LEAN_PX := 1.2
const BREATHE_AMP := 0.55
const BREATHE_HZ := 0.55
const RECOIL_DECAY := 9.0
const RECOIL_MAX_PX := 3.2
const FLINCH_TIME := 0.08
const FLINCH_PX := 2.2
const DEATH_ROT := PI * 0.5
const DEATH_ROT_RATE := 6.0
const DEATH_POOL_MAX := 21.0
const BLIND_DECAY := 1.4
const BLEED_DROP_INTERVAL := 0.35

## Optional texture-overlay hooks (art-direction §1): future hand-drawn parts
## replace the vector layer without code changes.
@export var texture_overlays: Dictionary[StringName, Texture2D] = {}

var faction_primary: Color = BASTION_PRIMARY
var faction_accent: Color = BASTION_ACCENT
var visor_color: Color = BASTION_VISOR
var class_id: StringName = &"vanguard"
var weapon_def: WeaponDef = null

var alive: bool = true
var _velocity: Vector2 = Vector2.ZERO
var _stance: Enums.Stance = Enums.Stance.STAND
var _focused: bool = false
var _reloading: bool = false
var _reload_progress: float = 0.0
var _bandaging: bool = false
var _bandage_progress: float = 0.0
var _health_ratio: float = 1.0

var _gait_phase: float = 0.0
var _breathe_phase: float = 0.0
var _recoil: float = 0.0
var _flinch: float = 0.0
var _flinch_dir: Vector2 = Vector2.RIGHT
var _blind: float = 0.0
var _scale: float = 1.0
var _bob: float = 0.0
var _lean: float = 0.0
var _sprinting: bool = false
var _death_t: float = 0.0
var _death_rot: float = 0.0
var _bleed_timer: float = 0.0
var _bleed_drops: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()

func setup(team: int, primary: Color, accent: Color, visor: Color,
		character_class: StringName) -> void:
	faction_primary = primary
	faction_accent = accent
	visor_color = visor
	class_id = character_class
	_rng.seed = hash(team) ^ hash(character_class)

## Faction palette by team; used by fixtures and by Character when no FactionDef.
func apply_team_palette(team: int) -> void:
	if team == Enums.Team.BASTION:
		faction_primary = BASTION_PRIMARY
		faction_accent = BASTION_ACCENT
		visor_color = BASTION_VISOR
	else:
		faction_primary = SIROCCO_PRIMARY
		faction_accent = SIROCCO_ACCENT
		visor_color = SIROCCO_VISOR

func set_weapon(def: WeaponDef) -> void:
	weapon_def = def
	queue_redraw()

## Per-physics-tick pose update (contract shape: velocity/aim/stance/state).
## `state` keys: focus, reloading, reload_progress, bandaging, bandage_progress,
## health. Animation time comes from the physics clock, not from the caller.
func update(velocity: Vector2, aim_dir: Vector2, stance: Enums.Stance,
		state: Dictionary) -> void:
	var dt := get_physics_process_delta_time()
	_velocity = velocity
	_stance = stance
	_focused = bool(state.get(&"focus", false))
	_reloading = bool(state.get(&"reloading", false))
	_reload_progress = float(state.get(&"reload_progress", 0.0))
	_bandaging = bool(state.get(&"bandaging", false))
	_bandage_progress = float(state.get(&"bandage_progress", 0.0))
	_health_ratio = float(state.get(&"health", 1.0))
	_sprinting = bool(state.get(&"sprinting", false))
	if alive:
		rotation = aim_dir.angle()
	_tick_pose(dt)
	queue_redraw()

func die() -> void:
	alive = false
	_death_t = 0.0
	_blind = 0.0

## Back on your feet (Battle respawn). Without this the rig keeps the corpse
## rotation and blood pool, so a revived operator still looks dead.
func revive() -> void:
	alive = true
	_death_t = 0.0
	_death_rot = 0.0
	_blind = 0.0
	_flinch = 0.0
	_recoil = 0.0
	_bleed_timer = 0.0
	_bleed_drops.clear()
	queue_redraw()

func flinch(from_dir: Vector2) -> void:
	_flinch = FLINCH_TIME
	_flinch_dir = from_dir.normalized() if from_dir != Vector2.ZERO else Vector2.RIGHT

func pulse_recoil(kick_deg: float) -> void:
	_recoil = minf(_recoil + kick_deg * 0.35, RECOIL_MAX_PX)

func flash(strength: float) -> void:
	_blind = maxf(_blind, clampf(strength, 0.0, 1.0))

func _tick_pose(dt: float) -> void:
	_breathe_phase += dt * TAU * BREATHE_HZ
	var speed := _velocity.length()
	var ratio := clampf(speed / VMAX_REF, 0.0, 1.0)
	_gait_phase += speed * dt * GAIT_RATE
	_recoil = maxf(0.0, _recoil - _recoil * RECOIL_DECAY * dt)
	_flinch = maxf(0.0, _flinch - dt)
	_blind = maxf(0.0, _blind - dt * BLIND_DECAY)
	var target_scale := CROUCH_SCALE if _stance == Enums.Stance.CROUCH else 1.0
	_scale = lerpf(_scale, target_scale, minf(1.0, dt * 12.0))
	var breathe := sin(_breathe_phase) * BREATHE_AMP
	var step_bob := absf(sin(_gait_phase)) * 0.9 * ratio
	_bob = breathe * (1.0 - ratio) + step_bob
	# Sprint leans the body forward over the lead foot; focus braces it back.
	var lean_target := 0.0
	if _sprinting and _stance == Enums.Stance.STAND:
		lean_target = SPRINT_LEAN_PX
	elif _focused:
		lean_target = -FOCUS_LEAN_PX
	_lean = lerpf(_lean, lean_target, minf(1.0, dt * 8.0))
	if not alive:
		_death_t += dt
		_death_rot = lerpf(_death_rot, DEATH_ROT, minf(1.0, dt * DEATH_ROT_RATE))
	if _health_ratio < 0.7 and speed > 20.0:
		_bleed_timer += dt
		if _bleed_timer >= BLEED_DROP_INTERVAL:
			_bleed_timer = 0.0
			_bleed_drops.append(Vector2(
				_rng.randf_range(-9.0, -2.0), _rng.randf_range(-7.0, 7.0)))
			if _bleed_drops.size() > 4:
				_bleed_drops.pop_front()

func _draw() -> void:
	_draw_shadow()
	draw_set_transform(Vector2(_lean, _bob) + _flinch_offset(), _death_rot,
		Vector2(_scale, _scale))
	_draw_legs()
	_draw_torso()
	_draw_head()
	_draw_arms()
	_draw_weapon()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_status()

func _draw_shadow() -> void:
	# Counter-rotate so the blob stays world-aligned (the root rotates to aim).
	draw_set_transform(Vector2(0.0, 2.0), -rotation, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, 11.0, SHADOW, true, -1.0, true)
	if not alive and _death_t > 0.0:
		var radius := minf(DEATH_POOL_MAX, 6.0 + _death_t * 9.0)
		draw_circle(Vector2(3.0, 4.0), radius, BLOOD_POOL, true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_legs() -> void:
	var move_local := _local_dir(_velocity)
	var speed := _velocity.length()
	var crouched := _stance == Enums.Stance.CROUCH
	var tuck := CROUCH_TUCK if crouched else 1.0
	if speed > STILL_SPEED:
		var swing := sin(_gait_phase) * STRIDE_PX * clampf(speed / VMAX_REF + 0.25, 0.0, 1.0)
		for leg: int in 2:
			var side := 1.0 if leg == 0 else -1.0
			var hip := Vector2(HIP_X, HIP_Y * side)
			# Opposite phase per leg: one foot forward while the other trails.
			var foot := hip + move_local * swing * side * tuck - Vector2(FOOT_BACK, 0.0)
			_leg(hip, foot)
		return
	# Idle: feet planted just behind the hips; splayed and bent on death.
	var splay := sin(_death_rot)
	for leg: int in 2:
		var side := 1.0 if leg == 0 else -1.0
		var hip := Vector2(HIP_X, HIP_Y * side)
		var foot := hip + Vector2(-FOOT_BACK + splay * 4.0,
			side * (2.0 + splay * 7.0))
		if crouched:
			foot = hip + Vector2(-FOOT_BACK * CROUCH_TUCK, side * 3.5)
		_leg(hip, foot)

## Thigh/calf in trouser colour ending in a boot blob: the boot reads darkest so
## the leg direction is obvious at gameplay zoom.
func _leg(hip: Vector2, foot: Vector2) -> void:
	_capsule(hip, foot, LEG_WIDTH, TROUSERS)
	draw_circle(hip, LEG_WIDTH * 0.5, TROUSERS.darkened(0.08), true, -1.0, true)
	draw_circle(foot, BOOT_RADIUS, BOOTS, true, -1.0, true)

func _draw_torso() -> void:
	var outline := faction_primary.darkened(0.5)
	var body_center := Vector2(TORSO_CENTER_X, 0.0)
	# Sleeves first so the vest plate reads on top of them.
	for side: float in [-1.0, 1.0]:
		draw_circle(Vector2(SHOULDER_X, SHOULDER_Y * side), SLEEVE_RADIUS,
			faction_primary.darkened(0.25), true, -1.0, true)
	_rounded_rect(body_center, Vector2(TORSO_LEN, TORSO_WID), TORSO_RADIUS,
		faction_primary)
	_rounded_rect_outline(body_center, Vector2(TORSO_LEN, TORSO_WID), TORSO_RADIUS,
		outline, 1.0)
	# Armor plate seams (design: vest read from above).
	var seam := faction_primary.lightened(0.22)
	draw_line(Vector2(-4.0, -TORSO_WID * 0.32), Vector2(4.0, -TORSO_WID * 0.32),
		seam, 1.0, true)
	draw_line(Vector2(-4.0, TORSO_WID * 0.32), Vector2(4.0, TORSO_WID * 0.32),
		seam, 1.0, true)
	# Faction accent stripe across the shoulders.
	draw_line(Vector2(-7.5, -4.2), Vector2(-7.5, 4.2), faction_accent, 2.2, true)
	_draw_class_cue()
	if _bandaging:
		var alpha := 0.55 + 0.35 * sin(_bandage_progress * TAU * 2.0)
		draw_line(Vector2(-2.0, -5.0), Vector2(1.0, 5.0),
			Color(BANDAGE, alpha), 3.0, true)
	if _flinch > 0.0:
		_rounded_rect(body_center, Vector2(TORSO_LEN, TORSO_WID), TORSO_RADIUS,
			Color(FLINCH, FLINCH.a * (_flinch / FLINCH_TIME)))

## Class silhouette cue from ClassDef.id (design §8 roster). Drawn on the back
## half of the vest so it never covers the head/arms.
func _draw_class_cue() -> void:
	match class_id:
		&"pathfinder":
			draw_line(Vector2(-9.5, 2.0), Vector2(-14.5, 5.0), GUNMETAL, 1.4, true)
			draw_circle(Vector2(-14.5, 5.0), 1.3, faction_accent, true, -1.0, true)
		&"bulwark":
			draw_rect(Rect2(-13.0, -5.0, 4.6, 10.0), GUNMETAL_DARK, true)
			draw_rect(Rect2(-13.0, -5.0, 4.6, 10.0), faction_accent, false, 1.0)
		&"ram":
			draw_arc(Vector2(3.0, 0.0), 8.0, -0.85, 0.85, 10,
				faction_accent.darkened(0.15), 1.8, true)
		&"longshot":
			for i: int in 4:
				var y := -4.5 + float(i) * 3.0
				draw_line(Vector2(-10.0, y), Vector2(-14.5 - float(i), y + 2.0),
					Color(0.32, 0.36, 0.24), 1.0, true)
		_:
			# Vanguard chest rig: three magazine pouches on the front-left.
			for i: int in 3:
				draw_rect(Rect2(-2.5 + float(i) * 3.0, 1.8, 2.0, 3.6),
					GUNMETAL_DARK, true)

## Helmet from above: a dark faction-tinted shell (clearly darker than the vest
## so the head separates) with a bright visor arc marking the aim direction.
func _draw_head() -> void:
	var center := Vector2(HEAD_FORWARD, 0.0)
	if texture_overlays.has(&"head"):
		draw_texture_rect(texture_overlays[&"head"],
			Rect2(center - Vector2(HEAD_RADIUS, HEAD_RADIUS),
				Vector2(HEAD_RADIUS, HEAD_RADIUS) * 2.0), false)
		return
	draw_circle(center, HEAD_RADIUS, faction_primary.darkened(0.45), true, -1.0, true)
	draw_circle(center, HEAD_RADIUS - 1.2, HELMET_CROWN, true, -1.0, true)
	draw_arc(center, VISOR_ARC_RADIUS, -VISOR_ARC_HALF, VISOR_ARC_HALF, 9,
		visor_color, 1.6, true)

## Arms: sleeve colour (faction), skin hands. Both hands on the grip; the mag
## hand drops on reload, both wrap the torso while bandaging.
func _draw_arms() -> void:
	var grip := Vector2(WeaponVisual.GRIP_X + 0.4, STOCK_Y_OFFSET * 0.5) \
		- Vector2(_recoil, 0.0)
	var left_hand := grip + Vector2(0.9, -1.8)
	var right_hand := grip + Vector2(-0.3, 1.8)
	var left_shoulder := Vector2(SHOULDER_X, -SHOULDER_Y)
	var right_shoulder := Vector2(SHOULDER_X, SHOULDER_Y)
	if _reloading:
		var dip := sin(clampf(_reload_progress, 0.0, 1.0) * PI)
		left_hand = grip + Vector2(-2.0 - dip * 3.0, -2.4 - dip * 2.2)
	if _bandaging:
		left_hand = Vector2(2.0, 2.2)
		right_hand = Vector2(2.0, -2.2)
	_arm(right_shoulder, right_hand)
	_arm(left_shoulder, left_hand)
	if _bandaging:
		draw_circle(left_hand, HAND_RADIUS + 0.4, BANDAGE, true, -1.0, true)
		draw_circle(right_hand, HAND_RADIUS + 0.4, BANDAGE, true, -1.0, true)

## Upper arm in sleeve colour plus a forearm in the same tone, ending in a hand.
func _arm(shoulder: Vector2, hand: Vector2) -> void:
	_capsule(shoulder, hand, ARM_WIDTH, faction_primary.darkened(0.3))
	draw_circle(hand, HAND_RADIUS, SKIN.darkened(0.05), true, -1.0, true)

func _draw_weapon() -> void:
	var p := WeaponVisual.profile(weapon_def)
	var body_len := float(p[&"body_len"])
	var barrel_len := float(p[&"barrel_len"])
	var width := float(p[&"width"])
	var mag_len := float(p[&"mag_len"])
	var mag_offset := float(p[&"mag_offset"])
	var stock := float(p[&"stock"])
	var scope := float(p[&"scope"])
	# Per-weapon gunmetal: body, recessed accents and the barrel highlight all
	# derive from the authored colour so each gun keeps its own value ladder.
	var gun: Color = p[&"color"]
	var gun_dark := gun.darkened(0.5)
	# Recoil pushes the whole gun back along aim; the arms follow via the grip.
	var receiver_x := WeaponVisual.GRIP_X - _recoil
	var gun_y := STOCK_Y_OFFSET
	if _bandaging:
		# Weapon lowered along the body while both hands wrap the torso.
		receiver_x -= 2.0
		gun_y = 4.0
		width *= 0.9
	if stock > 0.0:
		draw_rect(Rect2(receiver_x - stock, gun_y - width * 0.38, stock, width * 0.76),
			gun, true)
	draw_rect(Rect2(receiver_x, gun_y - width * 0.5, body_len, width), gun, true)
	draw_rect(Rect2(receiver_x, gun_y - width * 0.5, body_len * 0.3, width),
		gun_dark, true)
	draw_line(Vector2(receiver_x + 1.0, gun_y - width * 0.5 + 0.6),
		Vector2(receiver_x + body_len - 1.0, gun_y - width * 0.5 + 0.6),
		gun.lightened(0.3), 0.7, true)
	var barrel_start := receiver_x + body_len
	draw_rect(Rect2(barrel_start, gun_y - width * 0.3, barrel_len, width * 0.6),
		gun.lightened(0.06), true)
	draw_rect(Rect2(barrel_start, gun_y - width * 0.3, barrel_len * 0.25, width * 0.6),
		gun_dark, true)
	if scope > 0.0:
		draw_rect(Rect2(barrel_start - scope - 3.0, gun_y - width * 0.5 - 2.2, scope, 2.2),
			gun_dark, true)
	# Muzzle blob: the visual tip matches WeaponVisual.muzzle_len exactly.
	draw_rect(Rect2(barrel_start + barrel_len - 1.2, gun_y - width * 0.34, 1.2,
		width * 0.68), gun_dark, true)
	# Magazine: dips out during the mag-out stage of the reload animation.
	var mag_drop := 0.0
	if _reloading and _reload_progress < WeaponModel.RELOAD_STAGE_FRACTIONS[0]:
		var stage := clampf(_reload_progress / WeaponModel.RELOAD_STAGE_FRACTIONS[0],
			0.0, 1.0)
		mag_drop = sin(stage * PI * 0.5) * 4.0
	if mag_len > 0.0:
		draw_rect(Rect2(receiver_x + mag_offset, gun_y + width * 0.5 + mag_drop, 2.4,
			mag_len * 0.6), gun_dark, true)
	# Faction accent dot on the receiver (design: gunmetal + faction accent).
	draw_circle(Vector2(receiver_x + 1.8, gun_y), 1.2, faction_accent, true, -1.0, true)

func _draw_status() -> void:
	for drop: Vector2 in _bleed_drops:
		draw_circle(drop, 1.1, BLOOD, true, -1.0, true)
	if _flinch > 0.0:
		draw_circle(Vector2.ZERO, 12.0, Color(FLINCH, FLINCH.a * 0.35 * (_flinch / FLINCH_TIME)),
			true, -1.0, true)
	if _blind > 0.0:
		draw_circle(Vector2.ZERO, 13.0, Color(BLIND, 0.85 * _blind), true, -1.0, true)

func _flinch_offset() -> Vector2:
	if _flinch <= 0.0:
		return Vector2.ZERO
	return -_flinch_dir * FLINCH_PX * (_flinch / FLINCH_TIME)

## Velocity in rig-local space (the node itself is rotated to aim).
func _local_dir(world_velocity: Vector2) -> Vector2:
	if world_velocity.length() < 1.0:
		return Vector2.RIGHT
	return world_velocity.rotated(-rotation).normalized()

func _capsule(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	draw_line(from, to, color, width, true)
	draw_circle(from, width * 0.5, color, true, -1.0, true)
	draw_circle(to, width * 0.5, color, true, -1.0, true)

func _rounded_rect(center: Vector2, size: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(_rounded_points(center, size, radius), color)

func _rounded_rect_outline(center: Vector2, size: Vector2, radius: float,
		color: Color, width: float) -> void:
	var points := _rounded_points(center, size, radius)
	points.append(points[0])
	draw_polyline(points, color, width, true)

func _rounded_points(center: Vector2, size: Vector2, radius: float) -> PackedVector2Array:
	const CORNER_SEGMENTS := 4
	var half := size * 0.5
	var inner := half - Vector2(radius, radius)
	var points := PackedVector2Array()
	# Corners walk front-right → back-right → back-left → front-left, each arc
	# sweeping its own quarter turn, so the polygon is convex and never folds.
	for corner: int in 4:
		var pivot := center + Vector2(
			inner.x * (1.0 if corner in [0, 3] else -1.0),
			inner.y * (1.0 if corner in [0, 1] else -1.0))
		var start := float(corner) * PI * 0.5
		for step: int in CORNER_SEGMENTS + 1:
			var angle := start + float(step) / float(CORNER_SEGMENTS) * PI * 0.5
			points.append(pivot + Vector2(cos(angle), sin(angle)) * radius)
	return points