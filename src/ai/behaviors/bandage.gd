extends "res://src/ai/behaviors/behavior.gd"
## Bandage — bleeding + safe + charges left → get behind cover and channel.
## Speed comes from the shared Body (host body try_start_bandage); this only
## chooses the moment. Cannot fire while bandaging (design §7).

const BASE := 0.12
const SAFE_AGE_S := 1.2
const SAFE_DIST_PX := 260.0
const ARRIVE_PX := 18.0
## Bleeding is a clock, not a mood: an active bleed outranks any angle, because
## the alternative is dying behind cover with a full torso ratio. Wound-driven
## (bleed rate), so a limb wound at full HP still gets treated.
const BLEED_WEIGHT := 0.75
## Threat has to be this close to beat a serious bleed: 140 px.
const CLOSE_THREAT_PX := 140.0
## A running bandage is a commitment: outrank everything while it runs. 1.05
## was not enough — Peek (1.44) and HoldAngle still stole the tick mid-channel,
## and every steal re-rolls the 2.8 s channel with the charge already spent
## (sims: 13 started, 5 finished).
const COMMITTED_SCORE := 1.6
## Starting a channel with no cover nearby costs the charge and the time.
const OPEN_CHANNEL_PENALTY := 0.35
## Losing blood faster than it can be ignored: a torso bleed from 35 HP is a
## 14 s clock (BodyModel.TORSO_BLEED_RATE). Below this ratio, drop everything.
const DYING_RATIO := 0.55
const DYING_SCORE := 1.0

## True while the shared Body is mid-channel (design §7). The behavior must not
## restart a channel it already started: `try_start_bandage` is one-shot.
func _channeling(bb: Blackboard) -> bool:
	var body_node := bb.body()
	return body_node != null and body_node.has_method(&"is_bandaging") \
		and bool(body_node.call(&"is_bandaging"))

func score(bb: Blackboard) -> float:
	if not bb.bleeding() or bb.bandages() <= 0:
		return 0.0
	# Mid-channel: the 2.8 s (design §7) is already paid for, finish it. Leaving
	# half-done re-rolls the whole channel and is how a bleeding bot died behind
	# cover with charges left (sims: 12 bleed-outs, 4 bandages).
	if _channeling(bb):
		return COMMITTED_SCORE
	if bb.has_target() and threat_dist(bb) < CLOSE_THREAT_PX:
		return 0.0
	# Bleeding out: the wound kills faster than the fight does. Only a point
	# blank enemy beats it, and the channel starts the moment the LOS breaks.
	# Still not while bullets are landing: a channel under fire is interrupted
	# 69% of the time (sims: 13 started, 4 finished), so it costs a charge and
	# the 2.8 s for nothing. Duck first, bleed second.
	if bb.torso_ratio() < DYING_RATIO and bb.hit_timer <= 0.0:
		return DYING_SCORE
	var age := bb.memory.freshest_age()
	if age >= 0.0 and age < SAFE_AGE_S and threat_dist(bb) < SAFE_DIST_PX * 1.6:
		return 0.0
	var value := BASE + 0.45 * clampf(1.0 - bb.torso_ratio(), 0.0, 1.0)
	value += BLEED_WEIGHT * bb.bleed_urgency()
	value += 0.20 * bb.trait_of(&"caution")
	if bb.in_cover:
		value += 0.12
	# A channel started in the open is 2.8 s of standing still under fire — it
	# gets interrupted and the charge is wasted (sims: 13 started, 4 finished).
	# Insist on cover unless the bleed is about to kill.
	var covered := bb.in_cover or best_cover(bb, COVER_RADIUS * 0.5) != null
	if not covered and bb.torso_ratio() >= DYING_RATIO:
		value -= OPEN_CHANNEL_PENALTY
	return clampf(value, 0.0, 1.0)

func enter(bb: Blackboard, controller: Node) -> void:
	controller.call(&"say", &"bandage_start", 0)
	bb.action_data[&"bandage_moving"] = false
	var point := best_cover(bb)
	if point != null and not bb.at(point.stand_position(), 60.0):
		bb.action_data[&"bandage_moving"] = true
		bb.set_nav_target(point.stand_position())
	bb.action_data[&"bandage_started"] = false

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	# Mid-channel: hold completely still. Moving interrupts the channel in
	# BodyModel.apply_hit only, but a moving bot also re-enters cover logic and
	# abandons a channel it paid 2.8 s for.
	if _channeling(bb):
		stop(bb)
		crouch(bb, true)
		bb.intent.bandage = true
		return
	if bb.action_data.get(&"bandage_moving", false):
		move_to(bb, bb.nav_target)
		if bb.at(bb.nav_target, ARRIVE_PX):
			bb.action_data[&"bandage_moving"] = false
			stop(bb)
		return
	stop(bb)
	crouch(bb, true)
	bb.intent.bandage = true
	if not bb.action_data.get(&"bandage_started", false):
		bb.action_data[&"bandage_started"] = true
		var body: Node = bb.body()
		if body != null and body.has_method(&"try_start_bandage"):
			body.call(&"try_start_bandage")

func exit(bb: Blackboard, _controller: Node) -> void:
	bb.intent.bandage = false
	bb.action_data.erase(&"bandage_moving")