class_name SquadCoordinator
extends Node
## One per team. Owns the shared TeamIntel + DangerMap, assigns loose roles,
## turns teammate deaths into danger heat + a radio killzone warning, and holds
## the objective_info dict the Match runtime later feeds. Contract:
## architecture §4 ("SquadCoordinator (Node, per team) owns TeamIntel + danger
## map"). Pure logic stays in the models; this node only wires EventBus ↔ them.
##
## Get the instance with `SquadCoordinator.for_team(get_tree(), team)`; it
## self-creates, and frees itself once the last member leaves the tree.

const ROLE_POINT := &"point"
const ROLE_FLANK := &"flank"
const ROLE_SUPPORT := &"support"
const ROLE_ANCHOR := &"anchor"
## Role rotation cadence while the objective phase is stable, seconds.
const ROLE_ROTATE_S := 12.0
## Attackers commit in waves, not as one blob (design §9.8). A wave is only
## closed for the following half of the squad: half the bodies are always on
## the objective, so a capture is never stalled by a gate.
const WAVE_PERIOD_S := 10.0
## A contested zone reopens the wave instantly: contest is the moment to pile in.
const RECAPTURE_ROTATE_S := 6.0
## Share of attackers allowed through during a closed wave (rounded up).
const WAVE_SHARE := 0.5
## Attacker role split: one flanker per N bodies, one support per N bodies.
## The flanker's job is to cut defender rotations BEFORE they reach the rect —
## the bar only fills while no defender is inside, and a defender walks in from
## spawn every 8 s (BattleRules.DEFENDER_WAVE_S). One flanker per six bots left
## the approach uncovered and capped the bar at 0.38 every single attempt.
const ATTACKER_FLANK_DIV := 4
const ATTACKER_SUPPORT_DIV := 5
## Defenders: share of living bodies anchored on the zone itself.
const DEFENDER_ANCHOR_SHARE := 0.6
## A death is "witnessed" when a living teammate is this close, px.
const WITNESS_RADIUS_PX := 900.0
## A teammate's sighting stays the team's hunt anchor for this long, seconds.
## Radio contact itself fades in ~12 s (TeamIntel TTL); without a longer memory
## the survivors of a firefight scatter again and the match goes quiet. This
## remembers WHERE a teammate saw somebody — never where they are now.
const HUNT_ANCHOR_TTL_S := 45.0

const GROUP := &"squad_coordinators"

var team: int = Enums.Team.BASTION
var intel: TeamIntel = null
var danger: DangerMap = null
## Objective interface. Match calls set_objective_info(); defaults = free hunt.
var objective_info: Dictionary = {
	&"mode": Enums.Mode.ELIMINATION,
	&"obj_id": &"",
	&"obj_pos": Vector2.ZERO,
	&"obj_order": 0,
	&"attacking": true,
	&"phase": &"hunt",
	&"obj_contested": false,
}

var _members: Array = []
var _roles: Dictionary = {}
var _role_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _killzone_cd: Dictionary = {}
var _wave_timer: float = 0.0
var _wave_open: bool = true
## Instance ids of the bodies allowed to push while the wave is closed.
var _wave_leaders: Dictionary = {}
## Last place a teammate reported an enemy: {pos, time}. A *memory*, not a feed.
var _hunt_anchor: Dictionary = {}
var _clock: float = 0.0

## tree+team → coordinator. Survives across characters set up in one frame.
static var _instances: Dictionary = {}

## Per-team singleton, created on first request (arena/test friendly). The node
## is parented deferred: Characters ask for it during their own _ready, when the
## tree is busy adding children. Signals connect eagerly in _init, so even the
## very first frame's sightings reach the radio.
static func for_team(tree: SceneTree, team_id: int) -> SquadCoordinator:
	if tree == null:
		return null
	var key := "%d:%d" % [tree.root.get_instance_id(), team_id]
	var cached: Variant = _instances.get(key)
	if cached is SquadCoordinator and is_instance_valid(cached) \
			and not cached.is_queued_for_deletion():
		return cached
	_instances.erase(key)
	# A coordinator from an earlier match/test may still be in the group: reuse
	# it only if it still has members, otherwise let it die and start fresh.
	for node: Node in tree.get_nodes_in_group(GROUP):
		var stale := node as SquadCoordinator
		if stale == null or stale.team != team_id:
			continue
		if stale.is_queued_for_deletion() or stale.members().is_empty():
			stale.queue_free()
			continue
		_instances[key] = stale
		return stale
	var created := SquadCoordinator.new()
	created.team = team_id
	created.name = "SquadCoordinator_%s" % Enums.team_name(team_id)
	_instances[key] = created
	tree.root.add_child.call_deferred(created)
	return created

func _init() -> void:
	intel = TeamIntel.new(team, hash(team) ^ 0x5EED)
	danger = DangerMap.new()
	_rng.seed = hash(team) ^ 0xA11CE
	EventBus.character_died.connect(_on_character_died)
	EventBus.enemy_spotted.connect(_on_enemy_spotted)
	EventBus.objective_captured.connect(_on_objective_captured)

func _ready() -> void:
	add_to_group(GROUP)

func _exit_tree() -> void:
	for key: String in _instances.keys():
		if _instances[key] == self:
			_instances.erase(key)
	if EventBus.character_died.is_connected(_on_character_died):
		EventBus.character_died.disconnect(_on_character_died)
	if EventBus.enemy_spotted.is_connected(_on_enemy_spotted):
		EventBus.enemy_spotted.disconnect(_on_enemy_spotted)
	if EventBus.objective_captured.is_connected(_on_objective_captured):
		EventBus.objective_captured.disconnect(_on_objective_captured)

func _physics_process(dt: float) -> void:
	if not is_inside_tree():
		return
	_clock += dt
	intel.tick(dt)
	danger.tick(dt)
	_role_timer += dt
	if _role_timer >= ROLE_ROTATE_S:
		_role_timer = 0.0
		_assign_roles()
	# A contested zone is not a time to wait for the next wave.
	var contested := bool(objective_info.get(&"obj_contested", false))
	_wave_timer += dt
	if contested or _wave_timer >= WAVE_PERIOD_S:
		_wave_timer = 0.0
		_wave_open = true
		if not contested:
			_rotate_wave_leaders()
	_trim_members()

# --- membership -------------------------------------------------------------

func register(controller: Node) -> void:
	if controller != null and not _members.has(controller):
		_members.append(controller)
		_assign_roles()

func unregister(controller: Node) -> void:
	_members.erase(controller)
	_roles.erase(controller.get_instance_id())

func teammates_of(controller: Node) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for member: Variant in _members:
		if not is_instance_valid(member) or member == controller:
			continue
		var host: Variant = member.get(&"_host")
		if host is Node2D:
			out.append(host)
	return out

func role_for(controller: Node) -> StringName:
	return _roles.get(controller.get_instance_id(), ROLE_POINT)

## Live controller list (tests/sim read it to prove the squad is wired).
func members() -> Array:
	return _members.duplicate()

func role_counts() -> Dictionary:
	var counts: Dictionary = {}
	for role: StringName in _roles.values():
		counts[role] = int(counts.get(role, 0)) + 1
	return counts

## Attackers commit in waves: the wave rotates through the squad so half the
## bodies are pushing at any time. Flankers and point never wait (they are the
## cutting edge), and a contested zone opens everything.
func wave_open(controller: Node) -> bool:
	if _wave_open:
		return true
	var role := role_for(controller)
	if role == ROLE_POINT or role == ROLE_FLANK:
		return true
	return _wave_leaders.has(controller.get_instance_id())

## Rotate the stuck-behind half so the same four bots never anchor forever.
func _rotate_wave_leaders() -> void:
	_wave_leaders.clear()
	_trim_members()
	var living: Array = _living()
	if living.is_empty():
		return
	_wave_open = false
	var allowed := int(ceil(float(living.size()) * WAVE_SHARE))
	# Start at the current timer phase so the rotation is staggered, then take
	# `allowed` members round-robin: no fixed "elite half" every wave.
	var start := int(_rng.randi_range(0, living.size() - 1))
	for i: int in mini(allowed, living.size()):
		var member: Variant = living[(start + i) % living.size()]
		_wave_leaders[member.get_instance_id()] = true

# --- Match interface --------------------------------------------------------

## Feed the current mode/objective phase (same dict shape as Blackboard).
func set_objective_info(info: Dictionary) -> void:
	var phase_changed := StringName(info.get(&"phase", &"")) \
		!= StringName(objective_info.get(&"phase", &""))
	var side_changed := bool(info.get(&"attacking", true)) \
		!= bool(objective_info.get(&"attacking", true))
	var become_contested := bool(info.get(&"obj_contested", false)) \
		and not bool(objective_info.get(&"obj_contested", false))
	objective_info.merge(info, true)
	if phase_changed or side_changed:
		_assign_roles()
		_wave_timer = 0.0
		_wave_open = true
		_wave_leaders.clear()
	elif become_contested:
		# Contest is the moment to commit: everything flows in at once.
		_wave_timer = 0.0
		_wave_open = true
		_wave_leaders.clear()

# --- roles ------------------------------------------------------------------

func _assign_roles() -> void:
	_trim_members()
	var living := _living()
	if living.is_empty():
		return
	var count := living.size()
	var attacking := bool(objective_info.get(&"attacking", true))
	if not attacking:
		# Defenders: most bodies sit IN the zone (only bodies in the rect
		# contest the capture), the rest rotate onto the attacker approach.
		var anchors := maxi(int(ceil(float(count) * DEFENDER_ANCHOR_SHARE)), 1)
		for i: int in count:
			_roles[living[i].get_instance_id()] = ROLE_ANCHOR if i < anchors \
				else ROLE_FLANK
		return
	# Attackers: a couple of flankers cut the defenders' rotations, a couple
	# of supports overwatch the approach, everyone else carries the zone.
	var flankers := maxi(count / ATTACKER_FLANK_DIV, 1 if count >= 3 else 0)
	var supports := maxi(count / ATTACKER_SUPPORT_DIV, 1 if count >= 4 else 0)
	for i: int in count:
		var role := ROLE_POINT
		if i < flankers:
			role = ROLE_FLANK
		elif i < flankers + supports:
			role = ROLE_SUPPORT
		_roles[living[i].get_instance_id()] = role

func _living() -> Array:
	var out: Array = []
	for member: Variant in _members:
		if not is_instance_valid(member):
			continue
		var host: Variant = member.get(&"_host")
		if host != null and host.get(&"alive") != false:
			out.append(member)
	return out

func _trim_members() -> void:
	for i: int in range(_members.size() - 1, -1, -1):
		var member: Variant = _members[i]
		if not is_instance_valid(member) or not member.is_inside_tree():
			if is_instance_valid(member):
				_roles.erase(member.get_instance_id())
			_members.remove_at(i)

# --- EventBus ingress -------------------------------------------------------

func _on_enemy_spotted(spotter: Node, enemy: Node, pos: Vector2) -> void:
	if enemy == null or spotter == null:
		return
	if _team_of(spotter) != team or _team_of(enemy) == team:
		return
	# Radio it to the team: queued at sighting time, delivered 0.4–1.5 s later
	# with position noise — never a live enemy feed.
	intel.report_sighting(enemy.get_instance_id(), pos, _team_of(enemy))
	_hunt_anchor = {&"pos": pos, &"time": _clock}

## Where the team last believed an enemy was, or ZERO when that memory faded.
## A reported position with an age, exactly like a radio contact — it can
## justify hunting toward a place, never a shot.
func hunt_anchor() -> Vector2:
	if _hunt_anchor.is_empty():
		return Vector2.ZERO
	if _clock - float(_hunt_anchor[&"time"]) > HUNT_ANCHOR_TTL_S:
		return Vector2.ZERO
	return _hunt_anchor[&"pos"]

func _centroid(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var mean := Vector2.ZERO
	for point: Vector2 in points:
		mean += point
	return mean / float(points.size())

func _find_world() -> World:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if node is World:
			return node
	return null

func _on_character_died(victim: Node, _attacker: Node, _weapon: StringName,
		pos: Vector2, _distance: float) -> void:
	if victim == null or _team_of(victim) != team:
		return
	# The danger map is team *knowledge*: a death nobody on the team saw or
	# heard leaves no heat and no radio call (design §9.5, radio-lines §Usage).
	if not _witnessed(pos):
		return
	var zone: Variant = danger.add_death(pos)
	if zone != null:
		_radio_killzone(zone, pos)

## The team learns about a death from a teammate close enough to have seen or
## heard it — no omniscient "lost two at mid" from across the map.
func _witnessed(pos: Vector2) -> bool:
	return _closest_living(pos) <= WITNESS_RADIUS_PX

func _radio_killzone(zone_pos: Vector2, death_pos: Vector2) -> void:
	var cell := DangerMap.cell_of(zone_pos)
	if _killzone_cd.has(cell) \
			and danger.clock - float(_killzone_cd[cell]) < DangerMap.KILLZONE_COOLDOWN_S:
		return
	_killzone_cd[cell] = danger.clock
	# Speaker: the closest living member, i.e. they saw it first-hand.
	var speaker: Variant = null
	var best := INF
	for member: Variant in _members:
		if not is_instance_valid(member):
			continue
		var host: Variant = member.get(&"_host")
		if host == null or host.get(&"alive") == false:
			continue
		var dist: float = (host as Node2D).global_position.distance_to(death_pos)
		if dist < best:
			best = dist
			speaker = member
	if speaker != null:
		speaker.call(&"say", &"killzone", 2)

func _team_of(node: Object) -> int:
	var value: Variant = node.get(&"team") if node != null else null
	return value if value is int else -1

func _closest_living(pos: Vector2) -> float:
	var best := INF
	for member: Variant in _members:
		if not is_instance_valid(member):
			continue
		var host: Variant = member.get(&"_host")
		if host == null or host.get(&"alive") == false:
			continue
		best = minf(best, (host as Node2D).global_position.distance_to(pos))
	return best

func _on_objective_captured(_obj_id: StringName, capturer: int) -> void:
	if capturer == team:
		objective_info[&"phase"] = &"hold" if not bool(objective_info.get(&"attacking", true)) \
			else &"push"
	_assign_roles()