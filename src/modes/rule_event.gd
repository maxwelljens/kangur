class_name RuleEvent
extends RefCounted
## One instruction from a pure MatchRules tick to the runtime.
## Contract: architecture §4 (MatchRules), §10 (RulesRunner applies events).

## Respawning wave. data: {team: int, count: int, forward: bool}
const SPAWN := &"spawn"
## data: {id: StringName, team: int, progress: float, contested: bool}
const OBJECTIVE_PROGRESS := &"objective_progress"
## data: {id: StringName, team: int, order: int}
const OBJECTIVE_CAPTURED := &"objective_captured"
## data: {team: int, tickets: int}
const TICKETS := &"tickets"
## data: {winner: int, reason: StringName}
const MATCH_END := &"match_end"
## data: {obj_id, obj_order, obj_pos, contested, attacker_phase, defender_phase}
const PHASE := &"phase"

var type: StringName = &""
var data: Dictionary = {}

static func make(p_type: StringName, p_data: Dictionary = {}) -> RuleEvent:
	var event := RuleEvent.new()
	event.type = p_type
	event.data = p_data
	return event