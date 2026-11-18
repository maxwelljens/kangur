extends "res://src/ai/behaviors/behavior.gd"
## Advance — move toward the objective / patrol waypoint with personal offset,
## route jitter and human linger at corners (design §9.3, §9.8).

const ARRIVE_PX := 28.0
const SPRINT_MIN_DIST := 240.0
## A waypoint is "worth a linger" when it is this close and the roll says so.
const LINGER_CHANCE := 0.45
## Free-hunt scatter when the map gives us no spawn anchors (px).
const HUNT_SCATTER_PX := 260.0
const BASE := 0.34

func score(bb: Blackboard) -> float:
	if bb.has_target():
		return 0.0
	var value := BASE + 0.26 * bb.trait_of(&"aggression") + 0.14 * bb.trait_of(&"curiosity")
	if bb.mode() == Enums.Mode.BATTLE and bb.has_objective():
		value += 0.22
	# Battle attackers that just won a duel go take ground, not a new angle.
	if bb.pushing():
		value += 0.20
	# Stalling means the current angle produced nothing: push instead of settling
	# in for another minute (sims: camp-heavy rosters timed out Elimination).
	if bb.stalled():
		value += 0.15
	return clampf(value, 0.0, 1.0)

func enter(bb: Blackboard, _controller: Node) -> void:
	bb.clear_nav()
	_pick_goal(bb)

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	if bb.linger_timer > 0.0:
		stop(bb)
		return
	if bb.action_data.get(&"goal_done", false) or bb.at(bb.goal, ARRIVE_PX):
		# First arrival: roll a linger, then pick the next waypoint.
		if bb.action_data.get(&"lingered", false):
			bb.action_data[&"lingered"] = false
			bb.action_data[&"goal_done"] = false
			_pick_goal(bb)
		elif bb.rng().randf() < LINGER_CHANCE:
			bb.action_data[&"lingered"] = true
			bb.linger_timer = bb.roll_linger()
			stop(bb)
			return
		else:
			bb.action_data[&"goal_done"] = true
			_pick_goal(bb)
	var dist := bb.host_pos().distance_to(bb.goal)
	var sprint := dist > SPRINT_MIN_DIST and bb.trait_of(&"aggression") > 0.55
	move_to(bb, bb.goal, sprint)
	# Clearing ground is progress: keep the stalemate breaker honest.
	if bb.intent.move.length() > 0.1:
		bb.note_progress()

func _pick_goal(bb: Blackboard) -> void:
	var base := Vector2.ZERO
	var shared := false
	if bb.mode() == Enums.Mode.BATTLE and bb.has_objective():
		base = bb.objective_pos()
		shared = true
	else:
		# Free hunt converges: freshest radio contact, else the enemy half.
		# Twelve independent patrols only meet by luck, which is what turned
		# Elimination into 14 kills in eight minutes.
		base = bb.hunt_point()
		shared = base != Vector2.ZERO
		if base == Vector2.ZERO:
			base = bb.host_pos() + Vector2.RIGHT.rotated(
				bb.rng().randf_range(0.0, TAU)) * HUNT_SCATTER_PX
	bb.goal = base + (bb.converge_offset() if shared else bb.personal_offset())
	bb.action_data[&"goal_done"] = false
	bb.set_nav_target(bb.goal)