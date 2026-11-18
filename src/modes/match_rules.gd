class_name MatchRules
extends RefCounted
## Pure match-rule base: one tick in, RuleEvents out. No nodes, no EventBus
## (architecture §4). EliminationRules / BattleRules subclass this.

## Extra time granted when the final objective is being contested at the time
## limit (design §10 "grace: last life plays out"; sim asserts termination
## within limit + GRACE_S).
const GRACE_S := 30.0

var time_limit_s: float = 480.0

func tick(_snapshot: MatchSnapshot, _dt: float) -> Array[RuleEvent]:
	return []

## The attacking team for objective/ticket rules; -1 when the mode has none.
func attacker_team() -> int:
	return -1

## HUD-ready objective rows (String keys, see RulesRunner.objective_rows).
func objective_rows() -> Array[Dictionary]:
	return []

## Order of the last captured objective (attacker forward-spawn anchor).
func last_captured_order() -> int:
	return 0

static func end_event(winner: int, reason: StringName) -> RuleEvent:
	return RuleEvent.make(RuleEvent.MATCH_END, {&"winner": winner, &"reason": reason})