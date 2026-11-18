extends Node2D
## Effects — procedural combat VFX driven purely by EventBus (art-direction
## §2). Lives once per match (add as a child of Match/Projectiles); it owns no
## gameplay state, only FIFO-capped visuals. Headless: drawing no-ops safely.
## One Effects node draws every decal/flash itself; brass and tracers are
## transient children so they can move independently.

## Caps (art-direction §2: brass 120, blood 250, chips 300).
const MAX_BRASS := 120
const MAX_BLOOD := 250
const MAX_CHIPS := 300
## Muzzle flash star + light.
const FLASH_TIME := 0.06
const FLASH_LIGHT_ENERGY := 1.2
const FLASH_SIZE := 15.0
const FLASH_FAN_SCALE := 1.6
const SHOTGUN_PELLET_MIN := 2
## Tracers: 60 ms fade, one frame of motion.
const TRACER_TIME := 0.06
const TRACER_WIDTH := 1.8
const TRACER_WIDTH_PELLET := 1.0
## Brass: arc + spin, fade 1.2 s.
const BRASS_TIME := 1.2
const BRASS_SPEED := 90.0
const BRASS_LIFT := 30.0
const BRASS_GRAVITY := 420.0
const BRASS_SIZE := Vector2(2.0, 1.0)
## Blood: splat + growing pool.
const BLOOD_SPLAT_R := 5.0
const BLOOD_POOL_R := 9.0
const BLOOD_POOL_GROWTH := 4.0
## Chips: sparks + permanent mark.
const CHIP_R := 2.2
const CHIP_TIME := 0.18
## Hitmarkers: white X on a hit, red X on a kill (art-direction §2, 120 ms).
const HITMARKER_TIME := 0.12
const HITMARKER_ARM := 4.5
const HITMARKER_WIDTH := 1.4
## Colours come from the palette (art-direction §2), never ad-hoc hex.
const COL_FLASH := Color(1.0, 0.85, 0.55)
const COL_TRACER_DEFAULT := Color(0.95, 0.65, 0.25)
const COL_CHIP := Color(0.62, 0.63, 0.65)
const COL_BLOOD := Color(0.478, 0.122, 0.122, 0.85)
const COL_BLOOD_POOL := Color(0.478, 0.122, 0.122, 0.5)
const COL_HIT := Color(0.96, 0.97, 1.0)
const COL_KILL := Color(0.95, 0.22, 0.18)
const GORE_DEFAULT := true
## Muzzle light pool: one reused PointLight2D (art-direction §2: transient
## PointLight2D, energy 1.2, 0.06 s). GL Compatibility keeps the 2D light list
## short if the node count stays constant, so a pool beats spawn/free per shot.
const LIGHT_POOL := 4

## Decal records: {&"pos", &"rot", &"size", &"color"}; drawn every frame.
var _blood: Array[Dictionary] = []
var _chips: Array[Dictionary] = []
var _brass: Array[Dictionary] = []
var _tracers: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _markers: Array[Dictionary] = []
var _lights: Array[PointLight2D] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 5
	_build_light_pool()
	EventBus.shot_fired.connect(_on_shot_fired)
	EventBus.bullet_impact.connect(_on_bullet_impact)
	EventBus.character_hit.connect(_on_character_hit)
	EventBus.equipment_detonated.connect(_on_equipment_detonated)

func _exit_tree() -> void:
	if EventBus.shot_fired.is_connected(_on_shot_fired):
		EventBus.shot_fired.disconnect(_on_shot_fired)
	if EventBus.bullet_impact.is_connected(_on_bullet_impact):
		EventBus.bullet_impact.disconnect(_on_bullet_impact)
	if EventBus.character_hit.is_connected(_on_character_hit):
		EventBus.character_hit.disconnect(_on_character_hit)
	if EventBus.equipment_detonated.is_connected(_on_equipment_detonated):
		EventBus.equipment_detonated.disconnect(_on_equipment_detonated)

func _process(dt: float) -> void:
	_tick_transients(dt)
	queue_redraw()

## Pre-built muzzle lights; `_light_for` assigns one per flash and frees it on
## expiry, so the total light count stays constant instead of spiking per shot.
func _build_light_pool() -> void:
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.7, 1.0))
	gradient.set_color(1, Color(1.0, 0.7, 0.4, 0.0))
	texture.gradient = gradient
	for _i: int in LIGHT_POOL:
		var light := PointLight2D.new()
		light.texture = texture
		light.energy = 0.0
		light.blend_mode = Light2D.BLEND_MODE_ADD
		light.enabled = false
		add_child(light)
		_lights.append(light)

func _light_for() -> PointLight2D:
	for light: PointLight2D in _lights:
		if not light.enabled:
			return light
	return null

func _on_shot_fired(shooter: Node, weapon_id: StringName, origin: Vector2,
		dir: Vector2, pellets: int) -> void:
	var def: WeaponDef = null
	if shooter != null and shooter.get(&"arsenal") != null:
		var weapon: WeaponModel = shooter.get(&"arsenal").current()
		if weapon != null:
			def = weapon.def
	if def == null:
		def = Defs.weapon(weapon_id)
	var fan := FLASH_FAN_SCALE if pellets >= SHOTGUN_PELLET_MIN else 1.0
	_flashes.append({
		&"pos": origin, &"rot": dir.angle(), &"t": FLASH_TIME, &"fan": fan,
		&"color": COL_FLASH,
	})
	var light := _light_for()
	if light != null:
		light.global_position = origin
		light.energy = FLASH_LIGHT_ENERGY
		light.enabled = true
	var tracer_color := def.tracer_color if def != null else COL_TRACER_DEFAULT
	var length := def.falloff_end if def != null else ShotRequest.new().tracer_len
	_tracers.append({
		&"from": origin, &"to": origin + dir * length, &"t": TRACER_TIME,
		&"color": tracer_color,
		&"width": TRACER_WIDTH_PELLET if pellets >= SHOTGUN_PELLET_MIN else TRACER_WIDTH,
	})
	_eject_brass(origin, dir, def)

func _eject_brass(origin: Vector2, dir: Vector2, def: WeaponDef) -> void:
	var side := dir.orthogonal()
	var color := def.shell_color if def != null else COL_TRACER_DEFAULT
	_brass.append({
		&"pos": origin, &"vel": side * BRASS_SPEED * _rng.randf_range(0.6, 1.3)
			+ dir * BRASS_SPEED * 0.25, &"rot": _rng.randf_range(0.0, TAU),
		&"spin": _rng.randf_range(-14.0, 14.0), &"t": BRASS_TIME, &"color": color,
	})
	_trim(_brass, MAX_BRASS)

func _on_bullet_impact(pos: Vector2, normal: Vector2, surface: int,
		_penetrated: bool) -> void:
	var color := COL_CHIP
	var size := CHIP_R
	if surface == Enums.Surface.GLASS:
		color = Color(0.55, 0.9, 0.95, 0.9)
		size = CHIP_R * 1.4
	_chips.append({
		&"pos": pos, &"rot": normal.angle(), &"size": size, &"t": CHIP_TIME,
		&"color": color,
	})
	_trim(_chips, MAX_CHIPS)

func _on_character_hit(victim: Node, _attacker: Node, _part: int, damage: float,
		fatal: bool, pos: Vector2) -> void:
	_markers.append({
		&"pos": pos, &"t": HITMARKER_TIME,
		&"color": COL_KILL if fatal else COL_HIT,
	})
	if not _gore_enabled():
		_chips.append({
			&"pos": pos, &"rot": _rng.randf_range(0.0, TAU), &"size": CHIP_R,
			&"t": CHIP_TIME, &"color": COL_CHIP,
		})
		_trim(_chips, MAX_CHIPS)
		return
	var strength := clampf(damage / 40.0, 0.5, 2.0)
	for _i: int in 3:
		_blood.append({
			&"pos": pos + Vector2(
				_rng.randf_range(-BLOOD_SPLAT_R, BLOOD_SPLAT_R),
				_rng.randf_range(-BLOOD_SPLAT_R, BLOOD_SPLAT_R)),
			&"rot": _rng.randf_range(0.0, TAU),
			&"size": BLOOD_SPLAT_R * strength * _rng.randf_range(0.5, 1.2),
			&"pool": false, &"color": COL_BLOOD,
		})
	_trim(_blood, MAX_BLOOD)

func _on_equipment_detonated(_kind: StringName, pos: Vector2, radius: float) -> void:
	_chips.append({
		&"pos": pos, &"rot": 0.0, &"size": radius * 0.18, &"t": CHIP_TIME,
		&"color": COL_FLASH,
	})
	_trim(_chips, MAX_CHIPS)

func _tick_transients(dt: float) -> void:
	for flash: Dictionary in _flashes:
		flash[&"t"] = float(flash[&"t"]) - dt
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return float(f[&"t"]) > 0.0)
	_tick_lights(dt)
	for marker: Dictionary in _markers:
		marker[&"t"] = float(marker[&"t"]) - dt
	_markers = _markers.filter(func(m: Dictionary) -> bool: return float(m[&"t"]) > 0.0)
	for tracer: Dictionary in _tracers:
		tracer[&"t"] = float(tracer[&"t"]) - dt
	_tracers = _tracers.filter(func(t: Dictionary) -> bool: return float(t[&"t"]) > 0.0)
	for chip: Dictionary in _chips:
		chip[&"t"] = float(chip[&"t"]) - dt
	_chips = _chips.filter(func(c: Dictionary) -> bool: return float(c[&"t"]) > 0.0)
	for shell: Dictionary in _brass:
		shell[&"t"] = float(shell[&"t"]) - dt
		shell[&"rot"] = float(shell[&"rot"]) + float(shell[&"spin"]) * dt
		var vel: Vector2 = shell[&"vel"]
		vel.y += BRASS_GRAVITY * 0.15 * dt
		shell[&"vel"] = vel
		shell[&"pos"] = (shell[&"pos"] as Vector2) + vel * dt
	_brass = _brass.filter(func(b: Dictionary) -> bool: return float(b[&"t"]) > 0.0)
	# Blood pools grow after the corpse settles; splats fade with the blood cap.
	for splat: Dictionary in _blood:
		if bool(splat[&"pool"]):
			splat[&"size"] = minf(BLOOD_POOL_R, float(splat[&"size"]) + BLOOD_POOL_GROWTH * dt)

## Muzzle lights fade out over the flash duration, then switch off.
func _tick_lights(dt: float) -> void:
	for light: PointLight2D in _lights:
		if not light.enabled:
			continue
		light.energy = maxf(0.0, light.energy - FLASH_LIGHT_ENERGY * dt / FLASH_TIME)
		if light.energy <= 0.0:
			light.enabled = false

func _draw() -> void:
	for splat: Dictionary in _blood:
		draw_circle(splat[&"pos"], splat[&"size"], splat[&"color"], true, -1.0, true)
	for chip: Dictionary in _chips:
		var t := float(chip[&"t"]) / CHIP_TIME
		var color: Color = chip[&"color"]
		draw_circle(chip[&"pos"], float(chip[&"size"]) * t, color, true, -1.0, true)
	for shell: Dictionary in _brass:
		var fade := clampf(float(shell[&"t"]) / BRASS_TIME, 0.0, 1.0)
		var color: Color = shell[&"color"]
		draw_set_transform(shell[&"pos"], shell[&"rot"], Vector2.ONE)
		draw_rect(Rect2(-BRASS_SIZE * 0.5, BRASS_SIZE), Color(color, fade), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for tracer: Dictionary in _tracers:
		var fade := clampf(float(tracer[&"t"]) / TRACER_TIME, 0.0, 1.0)
		var color: Color = tracer[&"color"]
		draw_line(tracer[&"from"], tracer[&"to"], Color(color, fade),
			float(tracer[&"width"]), true)
	for marker: Dictionary in _markers:
		var fade := clampf(float(marker[&"t"]) / HITMARKER_TIME, 0.0, 1.0)
		_draw_hitmarker(marker[&"pos"], Color(marker[&"color"], fade))
	for flash: Dictionary in _flashes:
		var fade := clampf(float(flash[&"t"]) / FLASH_TIME, 0.0, 1.0)
		_draw_flash(flash[&"pos"], float(flash[&"rot"]), float(flash[&"fan"]), fade)

## 4-point star; shotgun pellets widen the fan (art-direction §2).
func _draw_flash(pos: Vector2, rot: float, fan: float, alpha: float) -> void:
	var color := Color(COL_FLASH, alpha)
	draw_set_transform(pos, rot, Vector2(fan, 1.0))
	var star := PackedVector2Array([
		Vector2(FLASH_SIZE, 0.0), Vector2(FLASH_SIZE * 0.22, FLASH_SIZE * 0.22),
		Vector2(0.0, FLASH_SIZE * 0.55), Vector2(-FLASH_SIZE * 0.22, FLASH_SIZE * 0.22),
		Vector2(-FLASH_SIZE * 0.35, 0.0), Vector2(-FLASH_SIZE * 0.22, -FLASH_SIZE * 0.22),
		Vector2(0.0, -FLASH_SIZE * 0.55), Vector2(FLASH_SIZE * 0.22, -FLASH_SIZE * 0.22),
	])
	draw_colored_polygon(star, color)
	draw_circle(Vector2(FLASH_SIZE * 0.3, 0.0), FLASH_SIZE * 0.28, color, true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## White X on a hit, red X on a kill: four strokes, no fill, readable at zoom.
func _draw_hitmarker(pos: Vector2, color: Color) -> void:
	var arm := HITMARKER_ARM
	draw_line(pos + Vector2(-arm, -arm), pos + Vector2(-arm * 0.3, -arm * 0.3),
		color, HITMARKER_WIDTH, true)
	draw_line(pos + Vector2(arm, -arm), pos + Vector2(arm * 0.3, -arm * 0.3),
		color, HITMARKER_WIDTH, true)
	draw_line(pos + Vector2(-arm, arm), pos + Vector2(-arm * 0.3, arm * 0.3),
		color, HITMARKER_WIDTH, true)
	draw_line(pos + Vector2(arm, arm), pos + Vector2(arm * 0.3, arm * 0.3),
		color, HITMARKER_WIDTH, true)

## Gore toggle (Settings gameplay/gore). Transient PointLight2D is skipped:
## the rig/lighting wave owns map lights, and a light per shot would recompile
## the 2D light list every 60 ms on GL Compatibility.
func _gore_enabled() -> bool:
	return bool(Settings.get_value(&"gameplay", &"gore", GORE_DEFAULT))

func _trim(list: Array[Dictionary], cap: int) -> void:
	while list.size() > cap:
		list.pop_front()

## Pool spawning for the effects wave that follows (tracer brass are transient
## records here; a future projectile system can share the caps).
func clear() -> void:
	_blood.clear()
	_chips.clear()
	_brass.clear()
	_tracers.clear()
	_flashes.clear()
	_markers.clear()