extends "res://src/ai/behaviors/behavior.gd"
## TakeCover — break contact to the best scored cover point: protection from the
## threat, lane coverage, spacing, danger penalty (design §9.6). Crouches on
## arrival; standing up is Peek's or Engage's job.

const BASE := 0.22
const ARRIVE_PX := 20.0

func score(bb: Blackboard) -> float:
	var threat := threat_dist(bb)
	if threat == INF and bb.intel_contact().is_empty():
		return 0.0
	var hp := bb.torso_ratio()
	var value := BASE + 0.34 * bb.trait_of(&"caution") + 0.20 * (1.0 - hp)
	if bb.has_target():
		value += 0.18
	if bb.visible_enemy_count() >= 2:
		value += 0.22
	if bb.killzone_at(bb.host_pos()) > 0.0:
		value += 0.25
	if bb.in_cover:
		value -= 0.18
	if best_cover(bb) == null:
		value -= 0.3
	return clampf(value, 0.0, 1.2)

func enter(bb: Blackboard, _controller: Node) -> void:
	bb.in_cover = false
	var point := best_cover(bb)
	if point == null:
		return
	bb.action_data[&"cover_pos"] = point.stand_position()
	bb.action_data[&"cover_lean"] = point.lean_dir
	bb.set_nav_target(point.stand_position())

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	var cover_pos: Vector2 = bb.action_data.get(&"cover_pos", Vector2.ZERO)
	if cover_pos == Vector2.ZERO:
		stop(bb)
		return
	if bb.at(cover_pos, ARRIVE_PX):
		stop(bb)
		crouch(bb, true)
		bb.in_cover = true
		bb.note_progress()
		var lean: Vector2 = bb.action_data.get(&"cover_lean", Vector2.ZERO)
		face(bb, lean if lean.length() > 0.001 else threat_dir(bb))
		return
	move_to(bb, cover_pos, bb.torso_ratio() < 0.5)
	if bb.intent.move.length() > 0.1:
		bb.note_progress()

func exit(bb: Blackboard, _controller: Node) -> void:
	bb.in_cover = false