extends "res://src/ai/behaviors/behavior.gd"
## Suppress — no LOS, but a contact the NPC personally saw moments ago: fire at
## the last-seen position / cover edge to keep heads down. Legal under the
## provenance rule (prior sighting, not a blind kill) and time-boxed by the
## controller gate (design §9.7, tests/simulation fairness contract).

const MAX_AGE_S := 4.0
const BASE := 0.36
const BURST_ON_S := 0.35
const BURST_OFF_S := 0.45

func score(bb: Blackboard) -> float:
	if bb.has_target():
		return 0.0
	var age := bb.memory.freshest_age()
	if age < 0.0 or age > MAX_AGE_S:
		return 0.0
	var value := BASE + 0.30 * bb.trait_of(&"discipline") + 0.15 * bb.trait_of(&"aggression")
	if bb.stalled():
		value += 0.25
	if bb.mag_ratio() < 0.3:
		value -= 0.35
	return clampf(value, 0.0, 1.0)

func enter(bb: Blackboard, _controller: Node) -> void:
	bb.action_data[&"suppress_on"] = false
	bb.action_data[&"suppress_timer"] = 0.0
	_controller.call(&"say", &"suppress", 1)

func tick(bb: Blackboard, _controller: Node, dt: float) -> void:
	var contact := bb.best_contact()
	if contact.is_empty():
		return
	var pos: Vector2 = contact[&"pos"]
	face(bb, pos - bb.host_pos())
	bb.action_data[&"aim_pos"] = pos
	# Hold ground in cover if it is close; otherwise keep the angle from here.
	crouch(bb, bb.in_cover)
	stop(bb)
	# Stop the moment the sighting ages out: the gate would deny it anyway, and
	# blind trigger pulls must stay exceptional rather than routine.
	var age := bb.memory.freshest_age()
	if age < 0.0 or age > MAX_AGE_S:
		bb.intent.fire = false
		return
	var timer: float = float(bb.action_data.get(&"suppress_timer", 0.0)) - dt
	var firing := bool(bb.action_data.get(&"suppress_on", false))
	if timer <= 0.0:
		firing = not firing
		timer = BURST_ON_S if firing else BURST_OFF_S
	bb.action_data[&"suppress_on"] = firing
	bb.action_data[&"suppress_timer"] = timer
	bb.intent.fire = firing