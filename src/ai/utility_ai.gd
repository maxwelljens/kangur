class_name UtilityAI
extends RefCounted
## Action scoring + selection. Static: no state, no nodes. Score = the
## behavior's own weighted trait×situation sum, times the faction doctrine
## weight, plus a hysteresis bonus for the running action. Deterministic given
## the same blackboard (design §9.2: hysteresis prevents jitter).

## Ties are broken by candidate order, never by randomness — reproducible sims.
## Scores land on the blackboard, not a static: the F3 overlay reads per NPC.

## One candidate action. `id` is the behavior id, `data` carries the behavior's
## own scratch (never serialized into the Intent).
class Action extends RefCounted:
	var id: StringName = &""
	var score: float = 0.0
	var data: Dictionary = {}

	func _init(action_id: StringName = &"", action_score: float = 0.0) -> void:
		id = action_id
		score = action_score

	func _to_string() -> String:
		return "Action(%s %.2f)" % [id, score]

## Highest score wins. `current` keeps a bonus so borderline re-scores do not
## flip-flop between equally good actions.
static func choose(candidates: Array, bb: Blackboard) -> Action:
	var doctrine: Dictionary = _doctrine_for(bb)
	var bonus := Blackboard.HYSTERESIS_BONUS
	if bb.action_time < Blackboard.ACTION_MIN_S:
		bonus *= 2.0
	var best: Action = null
	bb.last_scores.clear()
	for candidate: Variant in candidates:
		var action: Action = candidate
		var weight: float = float(doctrine.get(action.id, 1.0))
		var total := action.score * weight
		if action.id == bb.current_action:
			total += bonus
		bb.last_scores[action.id] = total
		if best == null or total > best.score:
			action.score = total
			best = action
	return best

## Faction flavour: `FactionDef.doctrine` weights behavior ids (design §9.2).
## The blackboard carries it, so no Defs autoload is assumed in unit fixtures.
static func _doctrine_for(bb: Blackboard) -> Dictionary:
	return bb.doctrine