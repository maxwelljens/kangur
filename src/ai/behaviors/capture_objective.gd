extends "res://src/ai/behaviors/behavior.gd"
## CaptureObjective — Battle attackers take the active zone and hold it:
## point/support bodies stand INSIDE the capture rect (only bodies inside
## count), flankers cut defender rotations from cover on the enemy side, and
## everyone commits while the zone is contested (design §9.8, §10).
##
## Fairness: geometry comes from map data (capture rect, cover points, spawn
## markers) and contacts from own memory/radio only — never an enemy node.

const BASE := 0.30
const AGGRESSION_W := 0.30
const DISCIPLINE_W := 0.10
## Nothing to shoot: the objective is the only useful thing to do.
const NO_TARGET_BONUS := 0.22
const CONTESTED_BONUS := 0.18
const PHASE_PUSH_BONUS := 0.08
const STALL_BONUS := 0.15
## Post-kill push window: the attacker who just cleared a defender carries on.
const PUSH_BONUS := 0.20
## Wave gate: the non-lead half waits for the wave or for the zone to clear.
const WAVE_PENALTY := 0.25
const ARRIVE_PX := 32.0
## Chasing a remembered contact: how far around the zone still counts as "near".
const CLEAR_RADIUS_PX := 340.0
const CLEAR_MAX_AGE_S := 5.0
## Flankers work this far outside the rect edge facing the defender spawn. They
## sit ON the defender's route, not beside it: the bar only fills while no
## defender is inside the rect, and a defender walks in from spawn every 8 s
## (BattleRules.DEFENDER_WAVE_S) while a capture takes 20 s. Intercepting on
## the approach is the only way that window ever gets long enough.
const CUT_OUT_PX := 420.0
const CUT_COVER_RADIUS := 380.0
## Cap spread: raw personal offsets (±40–74 px) would stack ten bodies deep.
const SPREAD_MULT := 2.0
## Perimeter hold: how far outside the rect edge the blocking line sits.
const PERIMETER_PX := 160.0
## Keep the hold spot this far inside the rect edge (one body width).
const EDGE_INSET_PX := 36.0

func score(bb: Blackboard) -> float:
	if bb.mode() != Enums.Mode.BATTLE or not bb.has_objective() or not bb.attacking():
		return 0.0
	var value := BASE + AGGRESSION_W * bb.trait_of(&"aggression") \
		+ DISCIPLINE_W * bb.trait_of(&"discipline")
	if not bb.has_target():
		value += NO_TARGET_BONUS
	if bb.contested():
		value += CONTESTED_BONUS
	if bb.phase() == &"push":
		value += PHASE_PUSH_BONUS
	if bb.stalled():
		value += STALL_BONUS
	if bb.pushing():
		value += PUSH_BONUS
	if bb.squad != null and not bool(bb.squad.call(&"wave_open", bb.controller)):
		value -= WAVE_PENALTY * (1.0 - bb.trait_of(&"independence"))
	return clampf(value, 0.0, 1.2)

func enter(bb: Blackboard, _controller: Node) -> void:
	_start(bb)

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	# The chain moved on (or the action resumed later): re-derive the hold point.
	if bb.action_data.get(&"cap_obj", &"") != bb.objective_info.get(&"obj_id", &""):
		_start(bb)
	var target: Vector2 = bb.action_data.get(&"cap_pos", Vector2.ZERO)
	if target == Vector2.ZERO:
		target = bb.objective_pos()
	# Clear before hold: a contact remembered around the zone is what keeps the
	# bar contested, so walk at it (own memory only — never an enemy node).
	var clear := _clear_target(bb)
	if clear != Vector2.ZERO:
		move_to(bb, clear, true)
		bb.note_progress()
		return
	# Contested: the bar is frozen anyway, so standing ON the same spot only
	# trades bodies against infinite defender respawns. Step to the rect edge
	# and win the fight from cover; the bodies still count once they clear.
	# (Sims: the bar froze at 0.38 within 9 s and never moved again in 15 min.)
	if bb.contested() and bb.current_action == &"capture_objective":
		var edge := _edge_point(bb)
		if edge != Vector2.ZERO:
			target = edge
	if bb.at(target, ARRIVE_PX):
		stop(bb)
		crouch(bb, true)
		bb.take_cover_at(bb.host_pos(), _watch_dir(bb))
		face(bb, _watch_dir(bb))
		bb.note_progress()
		return
	move_to(bb, target, true)
	if bb.intent.move.length() > 0.1:
		bb.note_progress()

## Hold position on the rect edge nearest the fight: inside the zone (so the
## body still counts the instant the defender dies) but behind the edge cover.
func _edge_point(bb: Blackboard) -> Vector2:
	var rect := bb.objective_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2.ZERO
	var center := rect.get_center()
	var threat := threat_dir(bb)
	if threat.length() < 0.001:
		threat = bb.toward_enemy_spawns()
	if threat.length() < 0.001:
		return Vector2.ZERO
	# Just inside the edge that faces the threat, inset by a body width.
	var half := Vector2(rect.size.x, rect.size.y) * 0.5
	var reach := (half * threat.abs()).dot(threat.abs()) * 0.5
	var point := center + threat * maxf(reach - EDGE_INSET_PX, 0.0)
	return Vector2(clampf(point.x, rect.position.x + EDGE_INSET_PX,
		rect.end.x - EDGE_INSET_PX), clampf(point.y, rect.position.y + EDGE_INSET_PX,
		rect.end.y - EDGE_INSET_PX))

func _start(bb: Blackboard) -> void:
	bb.action_data[&"cap_obj"] = bb.objective_info.get(&"obj_id", &"")
	var target := _cap_point(bb)
	bb.action_data[&"cap_pos"] = target
	bb.set_nav_target(target)
	bb.check_six_timer = bb.roll_check_six()

## Where this role holds: inside the rect for point/support, on the defender
## approach for flankers (a body outside the rect cannot fill the bar).
func _cap_point(bb: Blackboard) -> Vector2:
	var rect := bb.objective_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return bb.objective_pos() + bb.personal_offset()
	var enemy := bb.toward_enemy_spawns()
	if bb.role == SquadCoordinator.ROLE_FLANK and enemy != Vector2.ZERO:
		return _cut_point(bb, rect, enemy)
	# Hold cover INSIDE the rect: the body still fills the bar (occupancy is
	# positional) but is not standing in the lane. Standing tall in a contested
	# rect is what fed 94 attacker deaths into a 36-ticket budget.
	var inset := rect.grow(-minf(rect.size.x, rect.size.y) * 0.15)
	var spot := _cover_in(bb, inset, rect.get_center())
	if spot != Vector2.ZERO:
		return spot
	var point := inset.get_center() + bb.personal_offset() * SPREAD_MULT
	if bb.role == SquadCoordinator.ROLE_SUPPORT:
		point -= enemy * inset.size.y * 0.25
	return Vector2(clampf(point.x, inset.position.x, inset.end.x),
		clampf(point.y, inset.position.y, inset.end.y))

## Best cover whose stand spot is inside `rect`; ZERO when the zone has none.
func _cover_in(bb: Blackboard, rect: Rect2, threat: Vector2) -> Vector2:
	if bb.world == null:
		return Vector2.ZERO
	var best := Vector2.ZERO
	var best_value := -INF
	for point: CoverPoint in bb.world.cover_points_near(rect.get_center(),
			maxf(rect.size.x, rect.size.y)):
		var stand := point.stand_position()
		if not rect.has_point(stand):
			continue
		var value := cover_value(bb, point, threat)
		if value > best_value:
			best_value = value
			best = stand
	return best

## Flankers hold cover between the zone and the defender spawns: rotations run
## into them instead of walking into the capture rect for free.
func _cut_point(bb: Blackboard, rect: Rect2, enemy: Vector2) -> Vector2:
	var edge := rect.get_center() + enemy * rect.size.dot(enemy.abs()) * 0.5
	var cut := edge + enemy * CUT_OUT_PX
	if bb.world == null:
		return cut
	var approach := edge + enemy * CUT_COVER_RADIUS
	var best := cut
	var best_value := -INF
	for point: CoverPoint in bb.world.cover_points_near(cut, CUT_COVER_RADIUS):
		var value := cover_value(bb, point, approach)
		if value > best_value:
			best_value = value
			best = point.stand_position()
	return best

## Nearest personally-remembered contact near the zone, or ZERO when the NPC
## has nothing fresh to clear. Chasing a stale ghost is worse than holding.
func _clear_target(bb: Blackboard) -> Vector2:
	if bb.has_target():
		return Vector2.ZERO
	var contact := bb.best_contact()
	if contact.is_empty() or bb.memory.freshest_age() > CLEAR_MAX_AGE_S:
		return Vector2.ZERO
	var pos: Vector2 = contact[&"pos"]
	var rect := bb.objective_rect()
	if rect.size.x <= 0.0:
		rect = Rect2(bb.objective_pos(), Vector2.ZERO)
	return pos if rect.grow(CLEAR_RADIUS_PX).has_point(pos) else Vector2.ZERO

func _watch_dir(bb: Blackboard) -> Vector2:
	var threat := threat_dir(bb)
	if threat.length() > 0.001:
		return threat
	var enemy := bb.toward_enemy_spawns()
	return enemy if enemy != Vector2.ZERO else bb.intent.aim