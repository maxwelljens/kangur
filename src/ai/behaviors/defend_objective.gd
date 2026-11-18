extends "res://src/ai/behaviors/behavior.gd"
## DefendObjective — Battle defenders own the active zone: anchors hold cover
## INSIDE the rect (a body outside it cannot contest, and contesting is what
## stops the attackers' bar), rotators work the attacker approach to cut their
## push, and everybody collapses back into the zone when it is contested
## (design §9.8 "defenders anchor + rotate", §10 recapture at 2×).

const BASE := 0.30
const CAMPINESS_W := 0.26
const DISCIPLINE_W := 0.16
const ANCHOR_BONUS := 0.20
## Contested is the whole job: bodies in the zone stop the capture bar.
const CONTESTED_BONUS := 0.32
const PHASE_HOLD_BONUS := 0.08
const STALL_BONUS := 0.10
const ARRIVE_PX := 26.0
## Rotators work cover on the attacker-approach side of the zone.
const ROTATE_OUT_PX := 200.0
const ROTATE_RADIUS := 340.0

func score(bb: Blackboard) -> float:
	if bb.mode() != Enums.Mode.BATTLE or not bb.has_objective() or bb.attacking():
		return 0.0
	var value := BASE + CAMPINESS_W * bb.trait_of(&"campiness") \
		+ DISCIPLINE_W * bb.trait_of(&"discipline")
	if bb.role == SquadCoordinator.ROLE_ANCHOR:
		value += ANCHOR_BONUS
	if bb.contested():
		value += CONTESTED_BONUS
	if bb.phase() == &"hold":
		value += PHASE_HOLD_BONUS
	if bb.stalled():
		value += STALL_BONUS
	if bb.has_target() and threat_dist(bb) < FOCUS_RANGE_PX:
		value -= 0.12
	return clampf(value, 0.0, 1.2)

func enter(bb: Blackboard, _controller: Node) -> void:
	_start(bb)

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	if bb.action_data.get(&"def_obj", &"") != bb.objective_info.get(&"obj_id", &""):
		_start(bb)
	var anchor: Vector2 = bb.action_data.get(&"defend_pos", Vector2.ZERO)
	if anchor == Vector2.ZERO:
		anchor = bb.objective_pos()
	if not bb.at(anchor, ARRIVE_PX):
		move_to(bb, anchor)
		if bb.intent.move.length() > 0.1:
			bb.note_progress()
		return
	stop(bb)
	crouch(bb, bb.trait_of(&"caution") > 0.3)
	bb.take_cover_at(anchor)
	var lane := threat_dir(bb)
	if lane.length() < 0.001:
		lane = bb.toward_enemy_spawns()
	if lane.length() < 0.001:
		lane = bb.intent.aim
	face(bb, lane)
	bb.note_progress()

func _start(bb: Blackboard) -> void:
	bb.action_data[&"def_obj"] = bb.objective_info.get(&"obj_id", &"")
	var point := _anchor_point(bb)
	bb.action_data[&"defend_pos"] = point
	bb.set_nav_target(point)
	bb.check_six_timer = bb.roll_check_six()

## Best cover near the objective (protects the zone), else the zone itself.
func _anchor_point(bb: Blackboard) -> Vector2:
	var rect := bb.objective_rect()
	var zone_pos := rect.get_center() if rect.size.x > 0.0 else bb.objective_pos()
	if bb.world == null:
		return zone_pos + bb.personal_offset()
	# Rotators (non-anchors) hold the attacker approach so the push is met
	# outside the rect; anchors stay on the zone itself.
	var approach := bb.toward_enemy_spawns()
	var search_center := zone_pos
	var radius := ROTATE_RADIUS
	if bb.role != SquadCoordinator.ROLE_ANCHOR and approach != Vector2.ZERO:
		search_center = zone_pos + approach * ROTATE_OUT_PX
		radius = ROTATE_RADIUS * 0.8
	var best: CoverPoint = null
	var best_score := -INF
	for point: CoverPoint in bb.world.cover_points_near(search_center, radius):
		var value := cover_value(bb, point, search_center)
		# Anchors must be able to step into the rect; rotators less so.
		if bb.role == SquadCoordinator.ROLE_ANCHOR and rect.size.x > 0.0 \
				and not rect.grow(60.0).has_point(point.stand_position()):
			value -= 0.9
		value -= point.stand_position().distance_to(search_center) / radius * 0.4
		if value > best_score:
			best_score = value
			best = point
	if best == null:
		return zone_pos + bb.personal_offset()
	bb.action_data[&"cover_lean"] = best.lean_dir
	return best.stand_position()