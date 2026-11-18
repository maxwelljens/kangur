class_name CameraRig
extends Camera2D
## Match camera (design §4): lean toward the cursor, lerp in at 8/s, kick on
## your own fire, shake on hits/explosions, clamp to the map bounds. After
## death it follows a living teammate; Space cycles (design §10 spectate).
##
## Settings read live: video/zoom (1.0–2.4), gameplay/camera_lean (0–1),
## video/screen_shake. Default 1.8: at 1.6 a 26 px operator is ~42 px on screen,
## too small to read stance/weapon at a glance.
##
## Small maps: a map whose whole bounds fits the viewport at SMALL_MAP_FIT or
## above (Range: 48×32 tiles) is drawn whole instead of keeping the player zoom,
## which would leave it as a ring of fog around the pad.

## Camera lean: target = player + clamp((cursor − player) × lean, MAX_LEAN_PX).
const MAX_LEAN_PX := 220.0
const LEAN_RATE := 8.0
const ZOOM_MIN := 1.0
const ZOOM_MAX := 2.4
## Fraction of the viewport the map may fill when fitting a small map; the rest
## stays as a readable margin around the pad.
const FIT_MARGIN := 0.96
## A map whose bounds fit the viewport at this zoom or above is small enough
## that keeping the player's zoom shows a ring of fog instead of the map
## (Range: 48×32 tiles fits at ×0.88). Real maps fit far below ×0.5.
const SMALL_MAP_FIT := 0.75
## Shot kick along the recoil direction, px and recovery per second.
const RECOIL_KICK_PX := 2.0
const RECOIL_RECOVERY := 9.0
## Cap accumulated recoil so automatic fire doesn't build into huge displacement.
const RECOIL_MAX_PX := 7.0
## Shake amplitude: your own hit vs an explosion nearby.
const HIT_SHAKE_PX := 3.0
const BLAST_SHAKE_PX := 9.0
const SHAKE_DECAY := 5.5
const SHAKE_FREQ := 38.0
const BLAST_SHAKE_RADIUS := 420.0
const SPECTATE_LERP := 4.0

var target: Character = null
var world: World = null
## Followed teammate while the player is dead (set by Match).
var spectate_target: Character = null
var player: Character = null

var _lean := Vector2.ZERO
var _recoil := Vector2.ZERO
var _shake := 0.0
var _shake_phase := 0.0
var _rng := RandomNumberGenerator.new()


func setup(player_character: Character, world_node: World) -> void:
	player = player_character
	target = player_character
	world = world_node
	_rng.seed = hash([player_character.callsign if player_character != null else "camera",
		player_character.team if player_character != null else 0])
	if player_character != null:
		global_position = player_character.global_position
	_apply_zoom()
	make_current()
	if not EventBus.shot_fired.is_connected(_on_shot_fired):
		EventBus.shot_fired.connect(_on_shot_fired)
	if not EventBus.character_hit.is_connected(_on_character_hit):
		EventBus.character_hit.connect(_on_character_hit)
	if not EventBus.equipment_detonated.is_connected(_on_detonated):
		EventBus.equipment_detonated.connect(_on_detonated)
	if not EventBus.settings_changed.is_connected(_on_settings_changed):
		EventBus.settings_changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if EventBus.shot_fired.is_connected(_on_shot_fired):
		EventBus.shot_fired.disconnect(_on_shot_fired)
	if EventBus.character_hit.is_connected(_on_character_hit):
		EventBus.character_hit.disconnect(_on_character_hit)
	if EventBus.equipment_detonated.is_connected(_on_detonated):
		EventBus.equipment_detonated.disconnect(_on_detonated)
	if EventBus.settings_changed.is_connected(_on_settings_changed):
		EventBus.settings_changed.disconnect(_on_settings_changed)


## Spectating: follow a living teammate (Match picks the next one).
func spectate(character: Character) -> void:
	spectate_target = character
	target = character


func clear_spectate() -> void:
	spectate_target = null
	target = player


## One camera tick. Called by Match with the physics dt (never wall clock).
func update(dt: float, cursor_world: Vector2) -> void:
	var focus := _focus_character()
	if focus != null:
		var lean_weight := clampf(float(Settings.get_value(&"gameplay", &"camera_lean", 0.35)), 0.0, 1.0)
		var lean := (cursor_world - focus.global_position) * lean_weight
		if lean.length() > MAX_LEAN_PX:
			lean = lean.normalized() * MAX_LEAN_PX
		var rate := LEAN_RATE if focus == player else SPECTATE_LERP
		_lean = _lean.lerp(lean, clampf(dt * rate, 0.0, 1.0))
		var goal := focus.global_position + _lean
		global_position = _clamp_to_bounds(
			global_position.lerp(goal, clampf(dt * rate, 0.0, 1.0)))
	_recoil = _recoil.lerp(Vector2.ZERO, clampf(dt * RECOIL_RECOVERY, 0.0, 1.0))
	_shake = maxf(0.0, _shake - dt * SHAKE_DECAY)
	_shake_phase += dt * SHAKE_FREQ
	var shake := Vector2.ZERO
	if _shake > 0.0 and bool(Settings.get_value(&"video", &"screen_shake", true)):
		shake = Vector2(sin(_shake_phase), cos(_shake_phase * 1.37)) * _shake
	offset = _recoil + shake


func _focus_character() -> Character:
	if spectate_target != null and is_instance_valid(spectate_target):
		return spectate_target
	if player != null and is_instance_valid(player):
		return player
	return target


func _clamp_to_bounds(pos: Vector2) -> Vector2:
	if world == null:
		return pos
	var rect := world.bounds()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return pos
	var half := get_viewport_rect().size * 0.5 / maxf(zoom.x, 0.001)
	var min_pos := rect.position + half
	var max_pos := rect.end - half
	# A map smaller than the viewport cannot be clamped on this axis; center it
	# instead of snapping the camera to a corner.
	if min_pos.x > max_pos.x:
		min_pos.x = rect.get_center().x
		max_pos.x = min_pos.x
	if min_pos.y > max_pos.y:
		min_pos.y = rect.get_center().y
		max_pos.y = min_pos.y
	return Vector2(clampf(pos.x, min_pos.x, max_pos.x),
		clampf(pos.y, min_pos.y, max_pos.y))


func _apply_zoom() -> void:
	var value := clampf(float(Settings.get_value(&"video", &"zoom", 1.8)),
		ZOOM_MIN, ZOOM_MAX)
	if world != null:
		# Genuinely small maps (Range: 48×32 tiles) otherwise render as a ring
		# of fog around the pad. `fit >= SMALL_MAP_FIT` keeps this off the big
		# maps, which would otherwise be zoomed all the way out.
		var rect := world.bounds()
		var viewport := get_viewport_rect().size
		if rect.size.x > 0.0 and rect.size.y > 0.0 and viewport.x > 0.0:
			var fit := minf(viewport.x / rect.size.x,
				viewport.y / rect.size.y) * FIT_MARGIN
			if fit >= SMALL_MAP_FIT:
				value = clampf(fit, ZOOM_MIN, value)
	zoom = Vector2(value, value)


# --- bus ---------------------------------------------------------------------

## Recoil kick: only your own shots move your camera.
func _on_shot_fired(shooter: Node, _weapon: StringName, _origin: Vector2,
		dir: Vector2, _pellets: int) -> void:
	if shooter == null or shooter != player:
		return
	_recoil = (_recoil + dir.normalized() * RECOIL_KICK_PX).limit_length(RECOIL_MAX_PX)


func _on_character_hit(victim: Node, attacker: Node, _part: int, _damage: float,
		_fatal: bool, _pos: Vector2) -> void:
	if victim == player:
		_add_shake(HIT_SHAKE_PX)
	elif attacker == player:
		_add_shake(HIT_SHAKE_PX * 0.15)


func _on_detonated(_kind: StringName, pos: Vector2, _radius: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var distance := player.global_position.distance_to(pos)
	if distance > BLAST_SHAKE_RADIUS:
		return
	_add_shake(BLAST_SHAKE_PX * (1.0 - distance / BLAST_SHAKE_RADIUS))


func _add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, BLAST_SHAKE_PX * 1.5)
	_shake_phase = _rng.randf_range(0.0, TAU)


func _on_settings_changed(section: StringName) -> void:
	if section == &"video" or section == &"gameplay":
		_apply_zoom()