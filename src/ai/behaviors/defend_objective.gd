extends "res://src/ai/behaviors/behavior.gd"
## DefendObjective — Battle defenders anchor the zone and rotate to the
## threatened edge: hold a lane-facing cover point inside/around the objective
## (design §9.8). Campiness and the anchor role decide who never leaves.

const BASE := -0.3
const ANCHOR_RADIUS := 220.0
const ARRIVE_PX := 28.0

func score(bb: Blackboard) -> float:
	if bb.mode() != Enums.Mode.BATTLE or not bb.has_objective() or bb.attacking():
		return 0.0
	var value := BASE + 0.45 * bb.trait_of(&"campiness") + 0.20 * bb.trait_of(&"discipline")
	if bb.role == SquadCoordinator.ROLE_ANCHOR:
		value += 0.25
	if bool(bb.objective_info.get(&"obj_contested", false)):
		value += 0.30
	if bb.has_target():
		value += 0.10
	return clampf(value, 0.0, 1.1)

func enter(bb: Blackboard, _controller: Node) -> void:
	var anchor := _anchor_point(bb)
	bb.action_data[&"defend_pos"] = anchor
	bb.set_nav_target(anchor)
	bb.check_six_timer = bb.roll_check_six()

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	var anchor: Vector2 = bb.action_data.get(&"defend_pos", Vector2.ZERO)
	if anchor == Vector2.ZERO:
		anchor = bb.objective_pos()
	if not bb.at(anchor, ARRIVE_PX):
		move_to(bb, anchor)
		return
	stop(bb)
	crouch(bb, bb.trait_of(&"caution") > 0.3)
	var lane := threat_dir(bb)
	if lane.length() < 0.001:
		lane = bb.intent.aim
	face(bb, lane)
	bb.note_progress()

## Best cover near the objective (protects the zone), else the zone itself.
func _anchor_point(bb: Blackboard) -> Vector2:
	if bb.world == null:
		return bb.objective_pos() + bb.personal_offset()
	var best: CoverPoint = null
	var best_score := -INF
	var zone := bb.world.objective(bb.objective_info.get(&"obj_id", &""))
	var zone_pos := zone.global_position if zone != null else bb.objective_pos()
	for point: CoverPoint in bb.world.cover_points_near(zone_pos, ANCHOR_RADIUS):
		var value := point.quality - bb.danger_at(point.stand_position())
		value -= point.stand_position().distance_to(zone_pos) / ANCHOR_RADIUS * 0.4
		if value > best_score:
			best_score = value
			best = point
	if best == null:
		return zone_pos + bb.personal_offset()
	bb.action_data[&"cover_lean"] = best.lean_dir
	return best.stand_position()