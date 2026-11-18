extends "res://src/ai/behaviors/behavior.gd"
## Peek — fight from cover: lean out, take the shot window, retract. The human
## tempo verb (design §9.3 peek-and-retract) and the reason cover time counts
## as *engaged* time (tests/simulation cover% gate), plus an occasional
## overpeek when caution is low (peek_too_long).
##
## Fires through the same `_justified_fire` gate as Engage: leaning out only
## changes the body, never the provenance rule. That is also why this is where
## a covered NPC with a live sighting belongs — Engage stands in the lane.

const BASE := 0.30
const LEAN_OUT_S := 0.45
const RETRACT_S := 1.1
const OVERPEEK_LEAN_S := 1.1
## In cover with a shot: this must beat standing Engage (0.55–1.15), otherwise
## the bot leaves cover the moment it sees somebody and cover% never accumulates.
const SHOT_BONUS := 0.62
## Already engaged from here and still covered: stay. Re-acquiring cover costs
## a full reposition under fire, which is exactly how a duel becomes a loss.
const KEEP_BONUS := 0.18
## Taking hits while covered: retract sooner, do not trade in the open.
const UNDER_FIRE_PULL := 0.10
## Beyond this the shot is not worth leaning for; go find a better angle.
const MAX_ENGAGE_PX := 600.0

enum Phase { LEAN, HOLD, RETRACT }

func score(bb: Blackboard) -> float:
	if not bb.in_cover:
		return 0.0
	var value := BASE + 0.18 * bb.trait_of(&"caution") \
		+ 0.12 * bb.trait_of(&"campiness")
	if bb.has_target():
		# Do not lean out for a 700 px duel: that is how the lane gets lost.
		if threat_dist(bb) > MAX_ENGAGE_PX:
			return 0.0
		value += SHOT_BONUS
		if bb.current_action == &"peek":
			value += KEEP_BONUS
		if bb.hit_timer > 0.0:
			value += UNDER_FIRE_PULL
	else:
		# No LOS: peek to re-acquire a remembered contact nearby.
		var contact := bb.best_contact()
		if contact.is_empty():
			value -= 0.12
		elif threat_dist(bb) < FOCUS_RANGE_PX * 2.0:
			value += 0.16
	if bb.killzone_at(bb.host_pos()) > 0.0:
		value -= 0.15
	return clampf(value, 0.0, 1.2)

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
			var lean := bb.cover_lean
			if lean.length() < 0.001:
				lean = threat_dir(bb)
			face(bb, lean)
			var target := bb.primary_visible()
			if target.is_empty():
				bb.action_data[&"aim_pos"] = bb.host_pos() + lean.normalized() * 400.0
				return
			# Exposed and sighted: shoot on the same burst discipline as Engage.
			bb.action_data[&"aim_pos"] = target[&"pos"]
			if phase == Phase.HOLD or bb.trait_of(&"discipline") > 0.4:
				bb.intent.fire = true
		_:
			crouch(bb, true)
			bb.action_data.erase(&"aim_pos")
			bb.intent.fire = false