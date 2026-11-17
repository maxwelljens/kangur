class_name VisionSystem
extends Node
## VisionSystem — per-match vision orchestration (docs/architecture.md §10).
## Owns four things and nothing else:
##   1. the player's fog cone (patched VisionCone2D, 30 rays @ 10 Hz, Polygon2D
##      output only) plus a wall-clipped 70 px peripheral disc,
##   2. entity gating: enemy rigs render only through the player's own
##      cone+LOS (or peripheral), with a 3 s ghost at the last-seen position
##      and corpses that stay visible once discovered (design §5),
##   3. team radio sharing for the minimap (TeamVision) — never on-screen,
##   4. shot provenance for fairness sims (ShotProvenance).
##
## LOS truth is NEVER re-implemented here: gating, peripheral checks and
## provenance all ask `Perception.can_see/has_los`. Smoke is the one extra
## occluder Perception cannot know about, so it is applied on top.
##
## Headless: the fog layer is not created (no viewport texture, tech §6.2) but
## gating, sharing and provenance keep running for sims.

const FogOverlayScript := preload("res://src/vision/fog_overlay.gd")
const TeamVisionScript := preload("res://src/vision/team_vision.gd")
const ShotProvenanceScript := preload("res://src/vision/shot_provenance.gd")

## Vision refresh rate. 30 rays over a 100° fan at 10 Hz ≈ 0.06 ms/frame
## (addons.md §1.7 measured 0.133 ms per 50 rays per cone).
const GATE_HZ := 10.0
const CONE_RAY_COUNT := 30
## Rays for the peripheral disc; its exact edge is cosmetic, gating uses LOS.
const DISC_RAY_COUNT := 24
## Design §5: 70 px 360° awareness, no cone needed.
const PERIPHERAL_RADIUS := 70.0
## Design §5: fading marker at the last-seen position.
const GHOST_S := 3.0
## Shield so sub-tick fuzz cannot make the throttle fire twice in one frame.
const GATE_EPSILON := 0.0001

## Radio sharing for the player's team (minimap only).
var team_vision: TeamVisionScript = null
## Fairness ledger (sim + debug builds).
var shot_provenance: ShotProvenanceScript = null
## Optional F3 extension: `func(overlay: Node2D) -> void` drawing AI-owned debug
## state (danger map, nav paths). Assigned any time after setup().
var debug_extra: Callable = Callable():
	set(value):
		debug_extra = value
		if _overlay != null:
			_overlay.debug_extra = value

var _player: Character = null
var _characters: Array[Character] = []
var _world: World = null
var _active: bool = false

var _fog: FogOverlayScript = null
var _cone_root: Node2D = null
var _cone: VisionCone2D = null
var _disc: VisionCone2D = null
var _cone_poly: Polygon2D = null
var _disc_poly: Polygon2D = null
var _overlay: Overlay = null

var _accum: float = 0.0
## Source of truth for smoke when the EquipmentSystem is wired in.
var _equipment: Node = null
## entity_id -> {pos: Vector2, age: float}
var _ghosts: Dictionary[int, Dictionary] = {}
## Enemies whose corpse has been seen at least once (stay visible, §5).
var _discovered: Dictionary[int, bool] = {}
## [{pos: Vector2, radius: float, ttl: float}] — both teams blinded.
var _smoke: Array[Dictionary] = []


## Optional: the live EquipmentSystem. When present its `smoke_clouds()` is the
## source of truth (growing radius, expiry), so the two never disagree;
## `smoke_deployed` still arrives for the fog pulse and for systems without one.
func setup_equipment(equipment: Node) -> void:
	_equipment = equipment


## `seed` drives team-radio noise/delays (per match, deterministic).
## `enable_provenance` defaults to debug/sim builds (release strips it).
func setup(characters: Array[Character], player: Character, world: World,
		seed: int = 0, enable_provenance: bool = false) -> void:
	_characters = characters
	_player = player
	_world = world
	_ghosts.clear()
	_discovered.clear()
	_smoke.clear()
	_accum = 0.0

	team_vision = TeamVisionScript.new()
	team_vision.name = "TeamVision"
	add_child(team_vision)
	if player != null:
		team_vision.setup(player.team, characters, seed)

	shot_provenance = ShotProvenanceScript.new()
	shot_provenance.name = "ShotProvenance"
	shot_provenance.enabled = enable_provenance or OS.is_debug_build() or Dev.harness_active
	add_child(shot_provenance)
	shot_provenance.setup(characters, world, Callable(self, "_smoke_blocks"))

	# Ghost markers must stay readable in explored (dim) terrain: own layer above
	# the fog (1) and below the HUD (10), world-space via follow_viewport.
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "VisionOverlayLayer"
	overlay_layer.layer = 2
	overlay_layer.follow_viewport_enabled = true
	add_child(overlay_layer)
	_overlay = Overlay.new()
	_overlay.name = "VisionOverlay"
	overlay_layer.add_child(_overlay)
	_overlay.debug_extra = debug_extra  # may already be set before setup()

	if DisplayServer.get_name() != "headless" and player != null and world != null:
		_build_cone(world.bounds())
	_active = true


func _ready() -> void:
	if not EventBus.equipment_detonated.is_connected(_on_equipment_detonated):
		EventBus.equipment_detonated.connect(_on_equipment_detonated)
	if EventBus.has_signal(&"smoke_deployed") \
			and not EventBus.is_connected(&"smoke_deployed", _on_smoke_deployed):
		EventBus.connect(&"smoke_deployed", _on_smoke_deployed)


func _exit_tree() -> void:
	if EventBus.equipment_detonated.is_connected(_on_equipment_detonated):
		EventBus.equipment_detonated.disconnect(_on_equipment_detonated)
	if EventBus.has_signal(&"smoke_deployed") \
			and EventBus.is_connected(&"smoke_deployed", _on_smoke_deployed):
		EventBus.disconnect(&"smoke_deployed", _on_smoke_deployed)


func _physics_process(dt: float) -> void:
	advance(dt)


## One vision tick. `_physics_process` calls this; tests/sims call it directly so
## timing is deterministic (never wall clock — tests/simulation/README.md).
func advance(dt: float) -> void:
	if not _active:
		return
	shot_provenance.tick(dt)
	team_vision.tick(dt)
	_tick_smoke(dt)
	_accum += dt
	if _accum + GATE_EPSILON < 1.0 / GATE_HZ:
		return
	var step := _accum
	_accum = 0.0
	_refresh(step)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"debug_overlay"):
		return
	_overlay.show_debug = not _overlay.show_debug
	_overlay.queue_redraw()
	get_viewport().set_input_as_handled()


# --- public queries --------------------------------------------------------

## Player cone polygon in world space (minimap wedge + debug view).
func player_cone_world() -> PackedVector2Array:
	if _cone_root == null or _cone_poly == null:
		return PackedVector2Array()
	return _world_points(_cone_root, _cone_poly.polygon)


## Peripheral circle polygon in world space (fog mask + debug view).
func player_peripheral_world() -> PackedVector2Array:
	if _cone_root == null or _disc_poly == null:
		return PackedVector2Array()
	return _world_points(_cone_root, _disc_poly.polygon)


## True when `enemy` is currently rendered for the player.
func is_visible_to_player(enemy: Character) -> bool:
	return enemy != null and enemy.rig != null and enemy.rig.visible


## [{pos, radius}] active smoke clouds. A live EquipmentSystem's clouds come
## first (they own lifetime/radius growth); local ones cover fixtures and sims
## that have no EquipmentSystem wired.
func smoke_circles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _equipment != null and is_instance_valid(_equipment) \
			and _equipment.has_method(&"smoke_clouds"):
		out.assign(_equipment.call(&"smoke_clouds"))
	for cloud: Dictionary in _smoke:
		out.append({&"pos": cloud[&"pos"], &"radius": cloud[&"radius"]})
	return out


## Consumed from EquipmentSystem (`equipment_detonated` today, `smoke_deployed`
## from the concurrent wave). Duplicate reports refresh the existing cloud
## instead of stacking a second one.
func deploy_smoke(pos: Vector2, radius: float, duration: float) -> void:
	if radius <= 0.0 or duration <= 0.0:
		return
	for cloud: Dictionary in _smoke:
		if (cloud[&"pos"] as Vector2).distance_to(pos) <= 4.0 \
				and is_equal_approx(float(cloud[&"radius"]), radius):
			cloud[&"ttl"] = maxf(float(cloud[&"ttl"]), duration)
			_push_fog_smoke()
			return
	_smoke.append({&"pos": pos, &"radius": radius, &"ttl": duration})
	_push_fog_smoke()


## Pure: does the segment from → to pass through a smoke cloud?
static func smoke_blocks_segment(from: Vector2, to: Vector2,
		circles: Array[Dictionary]) -> bool:
	for cloud: Dictionary in circles:
		if segment_hits_circle(from, to, cloud[&"pos"], float(cloud[&"radius"])):
			return true
	return false


## Pure: segment/circle overlap, including endpoints inside the circle.
static func segment_hits_circle(from: Vector2, to: Vector2, center: Vector2,
		radius: float) -> bool:
	var closest := Geometry2D.get_closest_point_to_segment(center, from, to)
	return closest.distance_squared_to(center) <= radius * radius


# --- cone + gating ---------------------------------------------------------

## Runs one full vision step now (tests force this after a physics frame).
func refresh_now() -> void:
	_refresh(0.0)


func _refresh(step: float) -> void:
	if not _active:
		return
	_refresh_cone()
	_update_gating(step)
	_overlay.ghosts = _ghost_list()
	_overlay.characters = _characters
	_overlay.player = _player
	_overlay.contacts = team_vision.shared_contacts(_player.team) if _player != null else []
	_overlay.cone_points = player_cone_world()
	_overlay.smoke = smoke_circles()
	_overlay.queue_redraw()
	if _fog != null:
		_fog.set_smoke(_overlay.smoke)


func _build_cone(bounds: Rect2) -> void:
	_fog = FogOverlayScript.new()
	_fog.name = "FogOverlay"
	add_child(_fog)
	_fog.setup(bounds)  # (fog is res://-preloaded, so the script resource is first)

	_cone_root = Node2D.new()
	_cone_root.name = "PlayerCone"
	add_child(_cone_root)

	_cone = _make_cone(Layers.CONE_MASK_STAND, "Cone")
	# The renderer Polygon2D is deliberately NOT added to the tree: it is only a
	# data sink for VisionCone2D. Adding it would paint a white cone over the
	# world; the fog mask is the only place the cone may be drawn.
	_cone_poly = Polygon2D.new()
	_cone.write_polygon2d = _cone_poly

	# Peripheral awareness is a wall-clipped disc, not a free circle: standing
	# mask, because it is noticing someone next to you, not looking over cover.
	_disc = _make_cone(Layers.CONE_MASK_STAND, "Peripheral")
	_disc.angle_deg = 360
	_disc.ray_count = DISC_RAY_COUNT
	_disc.max_distance = PERIPHERAL_RADIUS
	_disc_poly = Polygon2D.new()
	_disc.write_polygon2d = _disc_poly


func _make_cone(mask: int, node_name: String) -> VisionCone2D:
	var cone := VisionCone2D.new()
	cone.name = node_name
	cone.angle_deg = 100
	cone.ray_count = CONE_RAY_COUNT
	cone.max_distance = 520.0
	cone.collision_layer_mask = mask
	cone.min_distance_sqr = 16.0
	cone.recalculate_if_static = true
	# The fan is driven by GATE_HZ below; the addon's own timer would double the work.
	cone.minimum_recalculate_time_msec = 1_000_000_000
	_cone_root.add_child(cone)
	return cone


func _refresh_cone() -> void:
	if _cone == null or _player == null or not _player.alive:
		return
	var perception := _player.perception
	_cone_root.global_position = _player.global_position
	# The addon's cone faces local +Y; aim is +X (addons.md §1.4a).
	_cone_root.global_rotation = _player.aim_dir.angle() - PI / 2.0
	_cone.angle_deg = int(round(perception.cone_angle_deg))
	_cone.max_distance = perception.cone_range
	_cone.collision_layer_mask = Layers.CONE_MASK_CROUCH \
		if _player.stance == Enums.Stance.CROUCH else Layers.CONE_MASK_STAND
	_cone.recalculate_vision(true)
	_disc.recalculate_vision(true)
	if _fog != null:
		_fog.set_visible_shape(player_cone_world(), player_peripheral_world())


func _update_gating(step: float) -> void:
	if _player == null:
		return
	for id: int in _ghosts.keys():
		var aged: Dictionary = _ghosts[id]
		aged[&"age"] = float(aged[&"age"]) + step
		if float(aged[&"age"]) >= GHOST_S:
			_ghosts.erase(id)
	var team := _player.team
	for c: Character in _characters:
		if c == null or not is_instance_valid(c) or c.rig == null:
			continue
		if c == _player or c.team == team:
			c.rig.visible = true
			continue
		var id := c.get_instance_id()
		if not c.alive:
			# Corpses persist once discovered; never leak an unseen death.
			c.rig.visible = _discovered.get(id, false)
			continue
		if _player_sees(c):
			_discovered[id] = true
			_ghosts[id] = {&"pos": c.global_position, &"age": 0.0}
			c.rig.visible = true
			continue
		c.rig.visible = false


## Player's own eyes only: cone+LOS, then smoke on top.
func _player_sees(enemy: Character) -> bool:
	var perception := _player.perception
	if perception == null:
		return false
	var target := enemy.global_position
	if _smoke_blocks(_player.global_position, target):
		return false
	if perception.can_see(target, enemy.stance):
		return true
	# Peripheral ring: any direction, but still needs an unblocked line.
	if _player.global_position.distance_to(target) > PERIPHERAL_RADIUS:
		return false
	return perception.has_los(target, enemy.stance)


func _ghost_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ghost: Dictionary in _ghosts.values():
		out.append(ghost)
	return out


# --- smoke ----------------------------------------------------------------

func _on_equipment_detonated(kind: StringName, pos: Vector2, radius: float) -> void:
	if kind != &"smoke":
		return
	# A wired EquipmentSystem already answers `smoke_clouds()`; mirroring the
	# event here would create a second cloud and double the blindness window.
	if _equipment != null and is_instance_valid(_equipment):
		return
	var def := Defs.equipment(&"smoke")
	var duration: float = def.vision_block_time if def != null else 12.0
	deploy_smoke(pos, radius, duration)


## Bridge for the concurrent EquipmentSystem signal (absent until it lands).
## Ignored when the EquipmentSystem node itself is wired: its live cloud list is
## the single source of truth and already includes this cloud.
func _on_smoke_deployed(pos: Vector2, radius: float, duration: float) -> void:
	if _equipment != null and is_instance_valid(_equipment):
		return
	deploy_smoke(pos, radius, duration)


func _tick_smoke(dt: float) -> void:
	if _equipment != null and is_instance_valid(_equipment):
		return  # EquipmentSystem owns cloud lifetime; _refresh pushes them to fog.
	if _smoke.is_empty():
		return
	var expired := false
	for cloud: Dictionary in _smoke.duplicate():
		cloud[&"ttl"] = float(cloud[&"ttl"]) - dt
		if float(cloud[&"ttl"]) <= 0.0:
			_smoke.erase(cloud)
			expired = true
	if expired:
		_push_fog_smoke()


func _push_fog_smoke() -> void:
	if _fog != null:
		_fog.set_smoke(smoke_circles())


func _smoke_blocks(from: Vector2, to: Vector2) -> bool:
	return smoke_blocks_segment(from, to, smoke_circles())


# --- rendering extras -----------------------------------------------------

func _world_points(root: Node2D, local: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(local.size())
	for i: int in local.size():
		out[i] = root.global_position + local[i].rotated(root.global_rotation)
	return out


## Ghost markers + F3 debug drawing. One Node2D, no gameplay state. Lives on its
## own CanvasLayer above the fog so a fading last-seen marker stays readable in
## explored (dim) terrain; `follow_viewport_enabled` keeps it in world space.
class Overlay extends Node2D:
	const GHOST_COLOR := Color(0.95, 0.65, 0.25)
	const ALLY_COLOR := Color(0.75, 0.92, 0.85)
	const ENEMY_COLOR := Color(0.88, 0.32, 0.29)
	const DEBUG_COLOR := Color(0.48, 0.92, 0.83, 0.55)
	const SMOKE_COLOR := Color(0.55, 0.58, 0.62, 0.10)

	var show_debug: bool = false
	var ghosts: Array[Dictionary] = []
	var characters: Array[Character] = []
	var contacts: Array[Dictionary] = []
	var cone_points: PackedVector2Array = PackedVector2Array()
	var smoke: Array[Dictionary] = []
	var player: Character = null
	var debug_extra: Callable = Callable()

	func _draw() -> void:
		for ghost: Dictionary in ghosts:
			var age := clampf(float(ghost.get(&"age", 0.0)) / VisionSystem.GHOST_S, 0.0, 1.0)
			if age >= 1.0:
				continue
			var at: Vector2 = ghost[&"pos"]
			var c := Color(GHOST_COLOR, (1.0 - age) * 0.8)
			var r := 9.0
			draw_polyline(PackedVector2Array([
				at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r),
				at + Vector2(-r, 0), at + Vector2(0, -r),
			]), c, 1.5, true)
			draw_circle(at, 2.0, c)
		if not show_debug:
			return
		for cloud: Dictionary in smoke:
			var points := PackedVector2Array()
			for i: int in 16:
				var a := TAU * float(i) / 16.0
				points.append(cloud[&"pos"] + Vector2(cos(a), sin(a)) * float(cloud[&"radius"]))
			draw_colored_polygon(points, SMOKE_COLOR)
		if cone_points.size() > 2:
			var closed := PackedVector2Array(cone_points)
			closed.append(cone_points[0])
			draw_polyline(closed, DEBUG_COLOR, 1.0, true)
		for c: Character in characters:
			if c == null or not is_instance_valid(c) or c.perception == null:
				continue
			var reach := c.perception.cone_range
			var half := deg_to_rad(c.perception.cone_angle_deg * 0.5)
			var base := c.aim_dir.angle()
			var arc := PackedVector2Array([c.global_position])
			for i: int in 9:
				var a := base - half + (2.0 * half) * float(i) / 8.0
				arc.append(c.global_position + Vector2(cos(a), sin(a)) * reach)
			arc.append(c.global_position)
			draw_polyline(arc, Color(ALLY_COLOR if c == player else ENEMY_COLOR, 0.35),
				1.0, true)
		for contact: Dictionary in contacts:
			draw_circle(contact[&"pos"], 6.0,
				Color(ENEMY_COLOR, 0.25 + 0.5 * float(contact[&"confidence"])))
			draw_arc(contact[&"pos"], 14.0, 0.0, TAU, 18,
				Color(ENEMY_COLOR, 0.35), 1.0, true)
		if debug_extra.is_valid():
			debug_extra.call(self)