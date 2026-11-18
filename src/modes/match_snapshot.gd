class_name MatchSnapshot
extends RefCounted
## Plain data handed to MatchRules.tick(). Zero node references so the rules
## stay headless-testable (architecture §4: pure models).
##
## `objective_states` entries:
##   {id: StringName, order: int, capture_time: float, pos: Vector2,
##    locked: bool, owner: int, progress: float, contested: bool,
##    present: Array[int]}   # living bodies inside, indexed by team

var elapsed: float = 0.0
var alive_per_team: Array[int] = [0, 0]
var tickets_per_team: Array[int] = [0, 0]
## Summed torso HP of living characters — the timeout tie-break (design §10).
var total_hp_per_team: Array[float] = [0.0, 0.0]
## Deaths since the previous tick, indexed by team (Battle ticket drain).
var deaths_this_tick: Array[int] = [0, 0]
var objective_states: Array[Dictionary] = []

func alive(team: int) -> int:
	return alive_per_team[team] if team >= 0 and team < alive_per_team.size() else 0

func tickets(team: int) -> int:
	return tickets_per_team[team] if team >= 0 and team < tickets_per_team.size() else 0

func total_hp(team: int) -> float:
	return total_hp_per_team[team] if team >= 0 and team < total_hp_per_team.size() else 0.0

func objective(id: StringName) -> Dictionary:
	for state: Dictionary in objective_states:
		if StringName(state.get(&"id", &"")) == id:
			return state
	return {}