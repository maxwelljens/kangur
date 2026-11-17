extends "res://src/ai/behaviors/behavior.gd"
## Investigate — go look at a heard sound above the occluded loudness
## threshold. Curiosity makes a bot nosy; caution makes it slow and careful.
## Hearing gives a position, never an identity (design §9.7, fairness).

const BASE := 0.14
const MIN_LOUDNESS := 60.0
const ARRIVE_PX := 60.0
const MAX_AGE_S := 4.0

func score(bb: Blackboard) -> float:
	if bb.has_target():
		return 0.0
	var heard := bb.memory.last_heard()
	if heard.is_empty():
		return 0.0
	if float(heard[&"loudness"]) < MIN_LOUDNESS or bb.memory.heard_age() > MAX_AGE_S:
		return 0.0
	var value := BASE + 0.34 * bb.trait_of(&"curiosity") + 0.10 * bb.trait_of(&"aggression")
	if StringName(heard[&"kind"]) == &"gunshot":
		value += 0.12
	if bb.killzone_at(heard[&"pos"]) > 0.0:
		value -= 0.25
	return clampf(value, 0.0, 1.0)

func enter(bb: Blackboard, _controller: Node) -> void:
	var heard := bb.memory.last_heard()
	if heard.is_empty():
		return
	var target: Vector2 = heard[&"pos"]
	bb.action_data[&"heard_pos"] = target
	bb.set_nav_target(target)

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	var target: Vector2 = bb.action_data.get(&"heard_pos", Vector2.ZERO)
	if target == Vector2.ZERO:
		return
	if bb.at(target, ARRIVE_PX):
		stop(bb)
		crouch(bb, true)
		# Sweep the area: poked a hornet's nest, now look for the nest.
		face(bb, Vector2.RIGHT.rotated(bb.rng().randf_range(0.0, TAU)))
		bb.note_progress()
		return
	crouch(bb, bb.trait_of(&"caution") > 0.55)
	move_to(bb, target)
	if bb.intent.move.length() > 0.1:
		bb.note_progress()

func exit(bb: Blackboard, _controller: Node) -> void:
	bb.action_data.erase(&"heard_pos")