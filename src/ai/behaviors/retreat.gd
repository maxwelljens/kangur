extends "res://src/ai/behaviors/behavior.gd"
## Retreat — impossible odds break contact NOW: 3+ visible enemies or critical
## HP against a healthy enemy → run to cover away from the threat and don't
## re-engage until the NPC recovers (design §9.5). Unlikely odds (2:1) are the
## cautious Peek/Regroup path, not this one.

const BASE := -0.4
const CRITICAL_HP := 0.35
const IMPOSSIBLE_ENEMIES := 3
const FLEE_PX := 300.0
const ARRIVE_PX := 30.0

func score(bb: Blackboard) -> float:
	var odds := bb.visible_enemy_count()
	var hp := bb.torso_ratio()
	var value := BASE
	if odds >= IMPOSSIBLE_ENEMIES:
		value += 0.75
	if hp < CRITICAL_HP and odds >= 1:
		value += 0.55
	if bb.bleeding():
		value += 0.15
	value += 0.15 * bb.trait_of(&"caution")
	if odds == 0:
		value -= 0.5
	return value

func enter(bb: Blackboard, controller: Node) -> void:
	var threat := threat_dir(bb)
	if threat.length() < 0.001:
		threat = Vector2.RIGHT
	var flee := bb.host_pos() - threat * FLEE_PX
	var point := best_cover(bb)
	if point != null and point.stand_position().distance_to(bb.host_pos()) < FLEE_PX * 1.4:
		flee = point.stand_position()
	elif bb.nav_ready():
		flee = bb.world.nav.closest_point(flee)
	bb.action_data[&"flee_pos"] = flee
	bb.set_nav_target(flee)
	bb.retreat_count += 1
	controller.call(&"say", &"retreat", 2)

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	var flee: Vector2 = bb.action_data.get(&"flee_pos", Vector2.ZERO)
	if flee == Vector2.ZERO:
		return
	if bb.at(flee, ARRIVE_PX):
		stop(bb)
		crouch(bb, true)
		face(bb, threat_dir(bb))
		return
	move_to(bb, flee, true)
	if bb.intent.move.length() > 0.1:
		bb.note_progress()

func exit(bb: Blackboard, _controller: Node) -> void:
	bb.action_data.erase(&"flee_pos")