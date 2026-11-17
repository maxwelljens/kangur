class_name TeamIntel
extends RefCounted
## Team radio. Sightings arrive delayed (0.4–1.5 s) and position-noisy, then
## fade. This is the ONLY way an NPC learns about something it did not see or
## hear itself — no live enemy positions, ever (design §9.1, fairness §1).
## Owned by SquadCoordinator; every NPC on the team reads the same instance.

const DELAY_MIN_S := 0.4
const DELAY_MAX_S := 1.5
## Position noise is a ring, not gaussian junk: 8–40 px off the true spot.
const NOISE_MIN_PX := 8.0
const NOISE_MAX_PX := 40.0
## Radio sightings are less certain than eyes-on (target may have moved).
const RADIO_CONFIDENCE := 0.6
const MAX_CONTACTS := 24

## team -> shared contact dict (id, pos, team, time, confidence, ttl)
var contacts: Dictionary = {}
## Pending radio packets, sorted by arrival: {id, pos, team, arrival, confidence}
var inbox: Array[Dictionary] = []
var clock: float = 0.0

var _rng := RandomNumberGenerator.new()
var _team: int = -1

func _init(team: int = -1, seed_value: int = 0) -> void:
	_team = team
	_rng.seed = seed_value

## Queue a sighting for radio transmission. The delay and noise are rolled at
## queue time (seeded), so replays of a seed are identical.
func report_sighting(id: int, pos: Vector2, team: int) -> void:
	var delay := _rng.randf_range(DELAY_MIN_S, DELAY_MAX_S)
	inbox.append({
		&"id": id,
		&"pos": pos + _noise(),
		&"team": team,
		&"arrival": clock + delay,
		&"confidence": RADIO_CONFIDENCE,
	})
	inbox.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a[&"arrival"]) < float(b[&"arrival"]))

## Advance the clock, deliver everything that has arrived, fade old contacts.
func tick(dt: float) -> void:
	clock += dt
	while not inbox.is_empty() and float(inbox[0][&"arrival"]) <= clock:
		var packet: Dictionary = inbox.pop_front()
		contacts[packet[&"id"]] = {
			&"id": packet[&"id"], &"pos": packet[&"pos"], &"team": packet[&"team"],
			&"time": clock, &"confidence": packet[&"confidence"],
			&"ttl": MemoryModel.CONTACT_TTL_MAX,
		}
		_trim()
	for id: int in contacts.keys():
		var contact: Dictionary = contacts[id]
		if clock - float(contact[&"time"]) > float(contact[&"ttl"]):
			contacts.erase(id)
	_trim()

## Freshest shared contact, or {} when the team knows nothing.
func best_contact() -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1.0
	for contact: Dictionary in contacts.values():
		var age: float = clock - float(contact[&"time"])
		var score: float = float(contact[&"confidence"]) * (1.0 - age / float(contact[&"ttl"]))
		if score > best_score:
			best_score = score
			best = contact
	return best

func knows(id: int) -> bool:
	return contacts.has(id)

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

func _noise() -> Vector2:
	return Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) \
		* _rng.randf_range(NOISE_MIN_PX, NOISE_MAX_PX)