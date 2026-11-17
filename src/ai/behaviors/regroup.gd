extends "res://src/ai/behaviors/behavior.gd"
## Regroup — fall in on the nearest teammate / squad anchor and take their
## flank. Individuals deviate through independence; 2:1 odds retreat here
## rather than to the map edge (design §9.4, §9.5).

const BASE := 0.10
const FORMATION_PX := 110.0
const ARRIVE_PX := FORMATION_PX * 0.7

func score(bb: Blackboard) -> float:
	var mate := bb.teammate_for_regroup()
	if mate == null:
		return 0.0
	var dist := bb.host_pos().distance_to(mate.global_position)
	if dist < FORMATION_PX:
		return 0.0
	var value := BASE + 0.20 * (1.0 - bb.trait_of(&"independence"))
	if bb.visible_enemy_count() == 2 and bb.torso_ratio() < 0.6:
		value += 0.22
	if bb.killzone_at(bb.host_pos()) > 0.0:
		value += 0.20
	if bb.has_target():
		value -= 0.25
	value += clampf(dist / 900.0, 0.0, 0.2)
	return clampf(value, 0.0, 1.0)

func enter(bb: Blackboard, _controller: Node) -> void:
	var mate := bb.teammate_for_regroup()
	if mate == null:
		return
	# Offset beside them so regrouping never builds a conga line.
	var offset := bb.personal_offset()
	var target := mate.global_position + offset
	bb.action_data[&"regroup_target"] = target
	bb.set_nav_target(target)

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	var target: Vector2 = bb.action_data.get(&"regroup_target", Vector2.ZERO)
	if target == Vector2.ZERO:
		return
	if bb.at(target, ARRIVE_PX):
		stop(bb)
		face(bb, threat_dir(bb))
		bb.note_progress()
		return
	move_to(bb, target, true)
	if bb.intent.move.length() > 0.1:
		bb.note_progress()

func exit(bb: Blackboard, _controller: Node) -> void:
	bb.action_data.erase(&"regroup_target")