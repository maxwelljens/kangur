extends "res://src/ai/behaviors/behavior.gd"
## CheckSix — the standalone rear check: hold still, sweep the cone 180° for
## 0.6–1.2 s, then face the lane again. Every 8–20 s while idle (design §9.3).
## HoldAngle runs the same beat inline while camping; this action exists so a
## moving/holding NPC without cover still checks its back.

const BASE := 0.08
const INTERVAL_JITTER := 0.35

func score(bb: Blackboard) -> float:
	if bb.has_target() or bb.check_six_timer > 0.0:
		return 0.0
	if bb.trait_of(&"caution") < 0.25:
		return 0.0
	return clampf(BASE + 0.22 * bb.trait_of(&"caution") + 0.12 * bb.trait_of(&"discipline"),
		0.0, 0.6)

func enter(bb: Blackboard, controller: Node) -> void:
	bb.action_data[&"six_left"] = bb.roll_check_six_hold()
	bb.check_six_timer = bb.roll_check_six() * (1.0 + bb.rng().randf_range(0.0, INTERVAL_JITTER))
	bb.check_six_count += 1
	controller.call(&"say", &"check_six", 0)

func tick(bb: Blackboard, _controller: Node, dt: float) -> void:
	stop(bb)
	crouch(bb, bb.in_cover)
	var left: float = float(bb.action_data.get(&"six_left", 0.0)) - dt
	bb.action_data[&"six_left"] = left
	var lane := threat_dir(bb)
	if lane.length() < 0.001:
		lane = bb.intent.aim
	face(bb, -lane)