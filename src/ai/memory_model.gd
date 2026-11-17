class_name MemoryModel
extends RefCounted
## What one NPC personally knows: eyes-on contacts and heard sounds. Pure — no
## nodes, no EventBus, no enemy references (positions copied at sighting time).
## Contacts decay over 6–12 s (design §5); sounds fade faster.
##
## Radio knowledge is deliberately NOT merged here: TeamIntel lives beside the
## memory so a sighting (which may justify fire) is never confused with a
## second-hand radio packet (which may not).

const CONTACT_TTL_MIN := 6.0
const CONTACT_TTL_MAX := 12.0
const SOUND_TTL := 4.0
const CONFIDENCE_FIRST := 1.0
const CONFIDENCE_GAIN := 0.25
const MAX_CONTACTS := 16
const MAX_SOUNDS := 16

## entity_id -> {id, pos, team, time, confidence, ttl}
var contacts: Dictionary = {}
## Newest last: {pos, loudness, kind, time}
var sounds: Array[Dictionary] = []
var clock: float = 0.0

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value

## First-hand sighting. Only the id and the copied position survive; the enemy
## node itself is never kept.
func see(pos: Vector2, id: int, team: int) -> Dictionary:
	var previous: Dictionary = contacts.get(id, {})
	var confidence := CONFIDENCE_FIRST if previous.is_empty() \
		else minf(1.0, float(previous[&"confidence"]) + CONFIDENCE_GAIN)
	var contact := {
		&"id": id, &"team": team, &"pos": pos, &"time": clock,
		&"confidence": confidence,
		&"ttl": _rng.randf_range(CONTACT_TTL_MIN, CONTACT_TTL_MAX),
	}
	contacts[id] = contact
	_trim()
	return contact

## Occluded hearing: a position and a loudness, never an identity.
func hear(pos: Vector2, loudness: float, kind: StringName) -> void:
	sounds.append({&"pos": pos, &"loudness": loudness, &"kind": kind, &"time": clock})
	while sounds.size() > MAX_SOUNDS:
		sounds.pop_front()

func tick(dt: float) -> void:
	clock += dt
	for id: int in contacts.keys():
		var contact: Dictionary = contacts[id]
		if clock - float(contact[&"time"]) > float(contact[&"ttl"]):
			contacts.erase(id)
	while not sounds.is_empty() and clock - float(sounds[0][&"time"]) > SOUND_TTL:
		sounds.pop_front()

## Freshest sighting, or {} when the NPC has seen nobody recently.
func freshest() -> Dictionary:
	var best: Dictionary = {}
	for contact: Dictionary in contacts.values():
		if best.is_empty() or float(contact[&"time"]) > float(best[&"time"]):
			best = contact
	return best

func best_threat() -> Dictionary:
	return freshest()

func last_seen(id: int) -> Dictionary:
	return contacts.get(id, {})

## Seconds since the last sighting of `id`; -1 when never seen / forgotten.
func contact_age(id: int) -> float:
	var contact: Dictionary = contacts.get(id, {})
	return -1.0 if contact.is_empty() else clock - float(contact[&"time"])

func freshest_age() -> float:
	var contact := freshest()
	return -1.0 if contact.is_empty() else clock - float(contact[&"time"])

## Newest heard sound, or {} when nothing recent.
func last_heard() -> Dictionary:
	return sounds[-1] if not sounds.is_empty() else {}

func heard_age() -> float:
	var heard := last_heard()
	return -1.0 if heard.is_empty() else clock - float(heard[&"time"])

func _trim() -> void:
	while contacts.size() > MAX_CONTACTS:
		var oldest_id := -1
		var oldest_time := INF
		for id: int in contacts.keys():
			var time: float = float(contacts[id][&"time"])
			if time < oldest_time:
				oldest_time = time
				oldest_id = id
		if oldest_id < 0:
			return
		contacts.erase(oldest_id)