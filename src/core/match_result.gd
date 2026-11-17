class_name MatchResult
extends RefCounted
## Outcome of one match, consumed by the debrief screen and sim harnesses.
## Contract: docs/architecture.md §10–§11.
## Character rows are Dictionaries (plain data) so they serialize to JSON as-is:
## {callsign, team, class_id, kills, deaths, damage, shots_fired, shots_hit,
##  bandages_used, survived}. Timeline rows: {t, kind, text, team}.

var winner: int = -1
var reason: StringName = &""
var duration_s: float = 0.0
var mode: int = Enums.Mode.ELIMINATION
var map_id: StringName = &""
var characters: Array[Dictionary] = []
var timeline: Array[Dictionary] = []
## Index into `characters` for the local player; -1 = spectated/absent.
var player_index: int = -1

func player_stats() -> Dictionary:
	if player_index < 0 or player_index >= characters.size():
		return {}
	return characters[player_index]

## New row with the debrief/sim keys present and zeroed.
static func new_character_row(callsign: String, team: int, class_id: StringName) -> Dictionary:
	return {
		"callsign": callsign,
		"team": team,
		"class_id": String(class_id),
		"kills": 0,
		"deaths": 0,
		"damage": 0.0,
		"shots_fired": 0,
		"shots_hit": 0,
		"bandages_used": 0,
		"survived": false,
	}

## Plain-data form for JSON sim reports (`JSON.stringify(result.to_dict())`).
func to_dict() -> Dictionary:
	return {
		"winner": winner,
		"reason": String(reason),
		"duration_s": duration_s,
		"mode": mode,
		"map_id": String(map_id),
		"characters": characters,
		"timeline": timeline,
		"player_index": player_index,
	}

static func from_dict(data: Dictionary) -> MatchResult:
	var result := MatchResult.new()
	result.winner = int(data.get("winner", -1))
	result.reason = StringName(str(data.get("reason", "")))
	result.duration_s = float(data.get("duration_s", 0.0))
	result.mode = int(data.get("mode", Enums.Mode.ELIMINATION))
	result.map_id = StringName(str(data.get("map_id", "")))
	result.player_index = int(data.get("player_index", -1))
	for row: Variant in data.get("characters", []):
		if row is Dictionary:
			result.characters.append(row)
	for row: Variant in data.get("timeline", []):
		if row is Dictionary:
			result.timeline.append(row)
	return result