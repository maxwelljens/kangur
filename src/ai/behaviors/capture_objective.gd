extends "res://src/ai/behaviors/behavior.gd"
## CaptureObjective — Battle attackers push the current zone in waves, spread
## across the capture rect (design §9.8). Wave gating lives in SquadCoordinator
## so twelve bots never rush one door at once; independence lets individuals
## ignore the gate occasionally.

const BASE := -0.3
const ARRIVE_PX := 40.0

func score(bb: Blackboard) -> float:
	if bb.mode() != Enums.Mode.BATTLE or not bb.has_objective() or not bb.attacking():
		return 0.0
	var value := BASE + 0.55 * bb.trait_of(&"aggression") + 0.10 * bb.trait_of(&"discipline")
	if bb.squad != null and not bb.squad.call(&"wave_open", bb.controller):
		value -= 0.35 * (1.0 - bb.trait_of(&"independence"))
	if bb.has_target():
		value += 0.10
	return clampf(value, 0.0, 1.1)

func enter(bb: Blackboard, _controller: Node) -> void:
	var zone := _zone_rect(bb)
	var target: Vector2 = zone.get_center() + bb.personal_offset()
	bb.action_data[&"cap_pos"] = target
	bb.set_nav_target(target)

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	var target: Vector2 = bb.action_data.get(&"cap_pos", Vector2.ZERO)
	if target == Vector2.ZERO:
		target = bb.objective_pos()
	if bb.at(target, ARRIVE_PX):
		stop(bb)
		# Inside the zone: hold the edges rather than the middle.
		crouch(bb, bb.trait_of(&"caution") > 0.4)
		face(bb, threat_dir(bb))
		bb.note_progress()
		return
	move_to(bb, target, true)
	if bb.intent.move.length() > 0.1:
		bb.note_progress()

func _zone_rect(bb: Blackboard) -> Rect2:
	if bb.world != null:
		var zone := bb.world.objective(bb.objective_info.get(&"obj_id", &""))
		if zone != null:
			return zone.capture_rect()
	return Rect2(bb.objective_pos(), Vector2.ZERO)