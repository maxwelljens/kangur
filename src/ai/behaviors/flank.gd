extends "res://src/ai/behaviors/behavior.gd"
## Flank — stalled engagement (>6 s) or an aggressive personality goes wide:
## route around the contact's cover, re-acquire from an odd angle. Route hints
## are derived from map cover lanes, never from enemy positions (fairness).

const BASE := 0.18
const WIDE_PX := 260.0
const ARRIVE_PX := 40.0

func score(bb: Blackboard) -> float:
	if bb.best_contact().is_empty():
		return 0.0
	var value := BASE + 0.30 * bb.trait_of(&"aggression") + 0.10 * bb.trait_of(&"independence")
	if bb.stalled():
		value += 0.45
	if bb.has_target():
		# Flanking while being shot at the current spot is the right time.
		value += 0.12
	if bb.visible_enemy_count() >= 2:
		value -= 0.15
	if bb.world == null:
		value -= 0.2
	return clampf(value, 0.0, 1.2)

func enter(bb: Blackboard, controller: Node) -> void:
	var contact := bb.best_contact()
	var threat_pos: Vector2 = contact.get(&"pos", bb.intel_pos())
	var away := bb.host_pos() - threat_pos
	if away.length() < 1.0:
		away = Vector2.RIGHT
	# Go around: pick the side the personality prefers (rng rolls it per match).
	var side := 1.0 if bb.rng().randf() < 0.5 + 0.2 * bb.trait_of(&"independence") else -1.0
	var wide := away.normalized().orthogonal() * side * WIDE_PX \
		+ away.normalized() * 120.0
	var target := bb.host_pos() + wide
	if bb.nav_ready():
		target = bb.world.nav.closest_point(target)
	bb.action_data[&"flank_target"] = target
	bb.set_nav_target(target)
	bb.flank_count += 1
	controller.call(&"say", &"flank", 0)

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	var target: Vector2 = bb.action_data.get(&"flank_target", Vector2.ZERO)
	if target == Vector2.ZERO:
		return
	if bb.at(target, ARRIVE_PX):
		stop(bb)
		face(bb, threat_dir(bb))
		bb.note_progress()
		return
	move_to(bb, target, true)
	if bb.intent.move.length() > 0.1:
		bb.note_progress()

func exit(bb: Blackboard, _controller: Node) -> void:
	bb.action_data.erase(&"flank_target")