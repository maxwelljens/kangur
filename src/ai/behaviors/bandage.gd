extends "res://src/ai/behaviors/behavior.gd"
## Bandage — bleeding + safe + charges left → get behind cover and channel.
## Speed comes from the shared Body (host body try_start_bandage); this only
## chooses the moment. Cannot fire while bandaging (design §7).

const BASE := 0.05
const SAFE_AGE_S := 2.5
const SAFE_DIST_PX := 260.0
const ARRIVE_PX := 18.0

func score(bb: Blackboard) -> float:
	if not bb.bleeding() or bb.bandages() <= 0:
		return 0.0
	if bb.has_target() and threat_dist(bb) < SAFE_DIST_PX:
		return 0.0
	var age := bb.memory.freshest_age()
	if age >= 0.0 and age < SAFE_AGE_S and threat_dist(bb) < SAFE_DIST_PX * 1.6:
		return 0.0
	var value := BASE + 0.45 * clampf(1.0 - bb.torso_ratio(), 0.0, 1.0)
	value += 0.20 * bb.trait_of(&"caution")
	if bb.in_cover:
		value += 0.20
	return clampf(value, 0.0, 0.9)

func enter(bb: Blackboard, controller: Node) -> void:
	controller.call(&"say", &"bandage_start", 0)
	bb.action_data[&"bandage_moving"] = false
	var point := best_cover(bb)
	if point != null and not bb.at(point.stand_position(), 60.0):
		bb.action_data[&"bandage_moving"] = true
		bb.set_nav_target(point.stand_position())
	bb.action_data[&"bandage_started"] = false

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
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