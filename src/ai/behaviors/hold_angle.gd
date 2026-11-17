extends "res://src/ai/behaviors/behavior.gd"
## HoldAngle — camp a lane: face the hotspot (contact/lane/objective), crouch,
## check six periodically. Weighted by campiness + anchor role + danger
## (design §9.3, §9.6). The camp-heavy counterpart to Advance.

const BASE := 0.16
const ARRIVE_PX := 26.0
const HOTSPOT_RADIUS := 480.0
## A camp has a budget: even a camper eventually moves (design §9.3 tempo).
## Campiness scales it; a pure camper still leaves after ~20 s.
const DWELL_MIN_S := 7.0
const DWELL_MAX_S := 16.0

func score(bb: Blackboard) -> float:
	# Dwell budget spent: hand the tick to Advance so patrols keep flowing.
	if bb.action_data.get(&"hold_expired", false):
		return 0.0
	var value := BASE + 0.40 * bb.trait_of(&"campiness")
	if bb.role == SquadCoordinator.ROLE_ANCHOR:
		value += 0.18
	if bb.mode() == Enums.Mode.BATTLE and not bb.attacking() and bb.has_objective():
		value += 0.22
	if bb.intel_contact().is_empty():
		value += 0.10
	if bb.killzone_at(bb.host_pos()) > 0.0:
		value += 0.10
	if bb.stalled():
		value -= 0.15
	return clampf(value, 0.0, 1.0)

func enter(bb: Blackboard, controller: Node) -> void:
	var hotspot := _hotspot(bb)
	bb.action_data[&"hold_pos"] = hotspot
	bb.action_data[&"hold_left"] = bb.rng().randf_range(DWELL_MIN_S, DWELL_MAX_S) \
		* (0.6 + 0.8 * bb.trait_of(&"campiness"))
	bb.set_nav_target(hotspot)
	bb.check_six_timer = bb.roll_check_six()
	if bb.at(hotspot, ARRIVE_PX):
		controller.call(&"say", &"hold", 0)

func tick(bb: Blackboard, _controller: Node, dt: float) -> void:
	var hold_left: float = float(bb.action_data.get(&"hold_left", 0.0)) - dt
	bb.action_data[&"hold_left"] = hold_left
	if hold_left <= 0.0:
		bb.action_data[&"hold_expired"] = true
		stop(bb)
		return
	var hold_pos: Vector2 = bb.action_data.get(&"hold_pos", Vector2.ZERO)
	if hold_pos == Vector2.ZERO:
		stop(bb)
		return
	if not bb.at(hold_pos, ARRIVE_PX):
		crouch(bb, false)
		move_to(bb, hold_pos)
		return
	stop(bb)
	crouch(bb, bb.trait_of(&"caution") > 0.35)
	# Check six: rotate the cone backward for a beat, then back on the lane.
	if bb.action_data.get(&"check_six", false):
		var left: float = float(bb.action_data.get(&"check_six_left", 0.0)) - dt
		bb.action_data[&"check_six_left"] = left
		if left <= 0.0:
			bb.action_data.erase(&"check_six")
		else:
			var rear := threat_dir(bb)
			face(bb, -rear if rear.length() > 0.001 else Vector2.LEFT)
			return
	if bb.check_six_timer <= 0.0 and bb.trait_of(&"caution") > 0.3:
		bb.action_data[&"check_six"] = true
		bb.action_data[&"check_six_left"] = bb.roll_check_six_hold()
		bb.check_six_timer = bb.roll_check_six()
		bb.check_six_count += 1
		_controller.call(&"say", &"check_six", 0)
		return
	# Face the lane: last contact, else the remembered hotspot direction.
	var lane := threat_dir(bb)
	if lane.length() < 0.001:
		lane = bb.action_data.get(&"face", Vector2.ZERO)
	if lane.length() < 0.001:
		lane = bb.host_pos() - hold_pos
	face(bb, lane)

## Where to camp: objective, else a cover point near the nearest contact.
func _hotspot(bb: Blackboard) -> Vector2:
	if bb.mode() == Enums.Mode.BATTLE and bb.has_objective():
		return bb.objective_pos() + bb.personal_offset()
	var point := best_cover(bb, HOTSPOT_RADIUS)
	if point != null:
		return point.stand_position()
	var contact := bb.best_contact()
	if not contact.is_empty():
		var to: Vector2 = contact[&"pos"] - bb.host_pos()
		return bb.host_pos() + to.normalized() * HOTSPOT_RADIUS * 0.5
	return bb.host_pos() + bb.personal_offset()