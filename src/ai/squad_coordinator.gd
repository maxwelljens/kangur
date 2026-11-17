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
## Attackers commit in waves, not as one blob (design §9.8).
const WAVE_PERIOD_S := 14.0
## A death is "witnessed" when a living teammate is this close, px.
const WITNESS_RADIUS_PX := 900.0

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
	intel.tick(dt)
	danger.tick(dt)
	_role_timer += dt
	if _role_timer >= ROLE_ROTATE_S:
		_role_timer = 0.0
		_assign_roles()
	_wave_timer += dt
	if _wave_timer >= WAVE_PERIOD_S:
		_wave_timer = 0.0
		_wave_open = not _wave_open
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

## Attackers commit in waves: point/flank push while the wave is open.
func wave_open(controller: Node) -> bool:
	var role := role_for(controller)
	return _wave_open or role == ROLE_POINT or role == ROLE_FLANK

# --- Match interface --------------------------------------------------------

## Feed the current mode/objective phase (same dict shape as Blackboard).
func set_objective_info(info: Dictionary) -> void:
	var phase_changed := StringName(info.get(&"phase", &"")) \
		!= StringName(objective_info.get(&"phase", &""))
	objective_info.merge(info, true)
	if phase_changed:
		_assign_roles()
		_wave_open = true
		_wave_timer = 0.0

# --- roles ------------------------------------------------------------------

func _assign_roles() -> void:
	_trim_members()
	var living: Array = []
	for member: Variant in _members:
		if not is_instance_valid(member):
			continue
		var host: Variant = member.get(&"_host")
		if host != null and host.get(&"alive") != false:
			living.append(member)
	if living.is_empty():
		return
	var count := living.size()
	var flankers := 1 if count >= 3 else 0
	var supports := 1 if count >= 4 else 0
	var attacking := bool(objective_info.get(&"attacking", true))
	for i: int in count:
		var role := ROLE_POINT
		if not attacking:
			role = ROLE_ANCHOR
		elif i == 0 and count >= 2:
			role = ROLE_FLANK
		elif i <= flankers + supports and i > flankers - 1 and i > 0:
			role = ROLE_SUPPORT
		_roles[living[i].get_instance_id()] = role

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