extends Node
## TeamVision — the PLAYER's radio memory for the minimap (design §5).
## Any teammate's cone sighting is relayed late and imprecise: delay 0.4–1.5 s
## plus position noise, contacts fade over 6–12 s. Fairness: a teammate's eyes
## never put a live enemy on screen, only a delayed blip on the minimap.
##
## The AI's `TeamIntel` (src/ai) is a separate system built from the same
## per-perception `enemy_spotted` signal; sharing the source keeps both fair
## without either knowing the other's memory.

const REPORT_DELAY_MIN_S := 0.4
const REPORT_DELAY_MAX_S := 1.5
## 1-sigma-ish bound of the relayed position error, px.
const POSITION_NOISE_PX := 26.0
const FADE_MIN_S := 6.0
const FADE_MAX_S := 12.0
## Perception re-emits a still-visible enemy every 0.5 s; ignore the duplicates.
const REPORT_GUARD_S := 0.25
## Skull hints linger this long after a witnessed teammate death.
const DANGER_MARK_S := 20.0
const MAX_DANGER_MARKS := 12

var _team: int = Enums.Team.BASTION
var _characters: Array[Character] = []
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0
## entity_id -> {team, pos, time, confidence, entity_id, ttl}
var _contacts: Dictionary[int, Dictionary] = {}
## Reports still on the radio: {due_at, spotter_id, enemy_id, pos, ttl}
var _pending: Array[Dictionary] = []
var _last_report: Dictionary[Vector2i, float] = {}
var _danger: Array[Dictionary] = []


func setup(team: int, characters: Array[Character], seed: int) -> void:
	_team = team
	_characters = characters
	_rng.seed = hash([seed, &"team_vision"])
	_contacts.clear()
	_pending.clear()
	_last_report.clear()
	_danger.clear()
	_time = 0.0
	for c: Character in _characters:
		if c == null or c.perception == null:
			continue
		if c.team != team:
			continue
		if not c.perception.enemy_spotted.is_connected(_on_spotted):
			c.perception.enemy_spotted.connect(_on_spotted)
	if not EventBus.character_died.is_connected(_on_character_died):
		EventBus.character_died.connect(_on_character_died)


func _exit_tree() -> void:
	for c: Character in _characters:
		if c != null and c.perception != null \
				and c.perception.enemy_spotted.is_connected(_on_spotted):
			c.perception.enemy_spotted.disconnect(_on_spotted)
	if EventBus.character_died.is_connected(_on_character_died):
		EventBus.character_died.disconnect(_on_character_died)


## Sim time, driven by VisionSystem (never wall clock: determinism, README).
## Contacts outlive their TTL briefly at zero confidence so the minimap can draw
## a fade instead of a pop; the shader/blip alpha does the dimming.
func tick(dt: float) -> void:
	_time += dt
	var due: Array[Dictionary] = []
	for report: Dictionary in _pending:
		if _time >= float(report[&"due_at"]):
			due.append(report)
	_pending = _pending.filter(func(r: Dictionary) -> bool:
		return _time < float(r[&"due_at"]))
	for report: Dictionary in due:
		_deliver(report)
	for id: int in _contacts.keys():
		var contact: Dictionary = _contacts[id]
		var remaining := float(contact[&"ttl"]) - (_time - float(contact[&"time"]))
		if remaining <= 0.0:
			_contacts.erase(id)
			continue
		contact[&"confidence"] = clampf(remaining / float(contact[&"ttl"]), 0.0, 1.0)
	for mark: Dictionary in _danger.duplicate():
		if _time >= float(mark[&"until"]):
			_danger.erase(mark)


## Live contacts for `team`, newest first. Empty for any team but ours: the
## player's team radio is the only one this system holds.
func shared_contacts(team: int) -> Array[Dictionary]:
	if team != _team:
		return []
	var out: Array[Dictionary] = []
	for contact: Dictionary in _contacts.values():
		out.append(contact)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a[&"time"]) > float(b[&"time"]))
	return out


## Simulation/debug view of the radio queue (tests assert delay without waiting).
func pending_reports() -> Array[Dictionary]:
	return _pending.duplicate()


## Bumped by the sim clock only; exposed so tests can land a report exactly.
func now() -> float:
	return _time


## Skull hints: {pos, until} for teammates' deaths our team actually saw.
func danger_marks() -> Array[Dictionary]:
	return _danger


func _on_spotted(spotter: Node, enemy: Node, pos: Vector2) -> void:
	if not (spotter is Character) or not (enemy is Character):
		return
	# The player's own eyes are what the fog already shows; radioing them back
	# would put a noisy duplicate of a live enemy on their minimap.
	if (spotter as Character).is_player:
		return
	# Only the player's team radio is modelled here (design §5: the player's
	# minimap). The AI's TeamIntel covers the bots' own radio separately.
	if (spotter as Character).team != _team:
		return
	var pair := Vector2i(spotter.get_instance_id(), enemy.get_instance_id())
	var last: float = _last_report.get(pair, -REPORT_GUARD_S)
	if _time - last < REPORT_GUARD_S:
		return
	_last_report[pair] = _time
	var bonus := (spotter as Character).spot_persist_bonus_s()
	_pending.append({
		&"due_at": _time + _rng.randf_range(REPORT_DELAY_MIN_S, REPORT_DELAY_MAX_S),
		&"enemy_id": enemy.get_instance_id(),
		&"pos": pos + _noise(),
		&"ttl": _rng.randf_range(FADE_MIN_S, FADE_MAX_S) + bonus,
	})


func _deliver(report: Dictionary) -> void:
	var id: int = report[&"enemy_id"]
	_contacts[id] = {
		&"team": _team,
		&"pos": report[&"pos"],
		&"time": _time,
		&"confidence": 1.0,
		&"entity_id": id,
		&"ttl": report[&"ttl"],
	}


func _noise() -> Vector2:
	return Vector2(_rng.randf_range(-POSITION_NOISE_PX, POSITION_NOISE_PX),
		_rng.randf_range(-POSITION_NOISE_PX, POSITION_NOISE_PX))


## Only a death our team could actually see earns a skull hint.
func _on_character_died(victim: Node, _attacker: Node, _weapon_id: StringName,
		pos: Vector2, _distance: float) -> void:
	if not (victim is Character):
		return
	if (victim as Character).team != _team:
		# Dead enemy: drop its shared contact so no spotted marker lingers on a corpse.
		_contacts.erase(victim.get_instance_id())
		return
	for c: Character in _characters:
		if c == null or not c.alive or c.perception == null:
			continue
		if c.perception.can_see(pos, Enums.Stance.STAND):
			if _danger.size() >= MAX_DANGER_MARKS:
				_danger.pop_front()
			_danger.append({&"pos": pos, &"until": _time + DANGER_MARK_S})
			return