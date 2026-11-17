extends "res://src/ai/behaviors/behavior.gd"
## Peek — lean out from cover, take the shot window, retract. The human tempo
## verb (design §9.3): peek-and-retract, plus an occasional overpeek when
## caution is low (peek_too_long). Retract waits out a fresh sighting.

const BASE := 0.24
const LEAN_OUT_S := 0.45
const RETRACT_S := 1.1
const OVERPEEK_LEAN_S := 1.1

enum Phase { LEAN, HOLD, RETRACT }

func score(bb: Blackboard) -> float:
	if not bb.in_cover:
		return 0.0
	if bb.has_target():
		return 0.0
	var contact := bb.best_contact()
	var threat := threat_dist(bb)
	var value := BASE + 0.25 * bb.trait_of(&"caution") + 0.18 * bb.trait_of(&"campiness")
	if contact.is_empty():
		value += 0.10
	elif threat < FOCUS_RANGE_PX * 2.0:
		value += 0.18
	if bb.killzone_at(bb.host_pos()) > 0.0:
		value -= 0.15
	return clampf(value, 0.0, 1.0)

func enter(bb: Blackboard, _controller: Node) -> void:
	bb.action_data[&"peek_phase"] = Phase.LEAN
	bb.action_data[&"peek_timer"] = LEAN_OUT_S
	bb.action_data[&"peek_too_long"] = bb.roll_overpeek()
	bb.peek_count += 1

func tick(bb: Blackboard, _controller: Node, dt: float) -> void:
	var phase: int = int(bb.action_data.get(&"peek_phase", Phase.LEAN))
	var timer: float = float(bb.action_data.get(&"peek_timer", 0.0)) - dt
	if timer <= 0.0:
		if phase == Phase.LEAN:
			phase = Phase.HOLD
			timer = OVERPEEK_LEAN_S if bb.action_data.get(&"peek_too_long", false) else 0.35
		elif phase == Phase.HOLD:
			phase = Phase.RETRACT
			timer = RETRACT_S
		else:
			phase = Phase.LEAN
			timer = LEAN_OUT_S
			bb.action_data[&"peek_too_long"] = bb.roll_overpeek()
			bb.peek_count += 1
		bb.action_data[&"peek_phase"] = phase
		bb.action_data[&"peek_timer"] = timer
	stop(bb)
	match phase:
		Phase.LEAN, Phase.HOLD:
			crouch(bb, false)
			var lean: Vector2 = bb.action_data.get(&"cover_lean", Vector2.ZERO)
			if lean.length() < 0.001:
				lean = threat_dir(bb)
			face(bb, lean)
			bb.action_data[&"aim_pos"] = bb.host_pos() + lean.normalized() * 400.0
		_:
			crouch(bb, true)
			bb.action_data.erase(&"aim_pos")