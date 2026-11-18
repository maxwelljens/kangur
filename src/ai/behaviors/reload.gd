extends "res://src/ai/behaviors/behavior.gd"
## Reload — mag low + behind cover (or nothing to shoot) → reload now, not in
## contact. Shares WeaponModel reload timing with the player (design §6).

const BASE := 0.04
const LOW_MAG := 0.30
const URGENT_MAG := 0.08
const SAFE_AGE_S := 1.5

## True while the shared Body is mid-bandage channel.
func _bandaging(bb: Blackboard) -> bool:
	var body_node := bb.body()
	return body_node != null and body_node.has_method(&"is_bandaging") \
		and bool(body_node.call(&"is_bandaging"))

func score(bb: Blackboard) -> float:
	if bb.is_reloading() or bb.mag_ratio() > LOW_MAG:
		return 0.0
	# Bandaging is a 2.8 s channel that a reload cancels outright
	# (Character._handle_edges). Bleeding out beats a partial mag; only a
	# completely dry weapon still takes precedence.
	if _bandaging(bb) and bb.mag_ratio() > 0.0:
		return 0.0
	var value := BASE + 0.55 if bb.mag_ratio() <= URGENT_MAG else BASE + 0.30
	value += 0.15 * bb.trait_of(&"discipline")
	# Out of ammo entirely: this is the only action that matters, and it must
	# outrank TakeCover so a dry NPC never camps a corner with an empty rifle.
	if bb.mag_ratio() <= 0.0:
		value += 0.62
	if bb.has_target():
		value -= 0.30
	elif bb.in_cover:
		value += 0.25
	var age := bb.memory.freshest_age()
	if age >= 0.0 and age < SAFE_AGE_S:
		value -= 0.15
	return clampf(value, 0.0, 1.0)

func enter(bb: Blackboard, controller: Node) -> void:
	controller.call(&"say", &"reload", 0)
	var point := best_cover(bb)
	if point != null and bb.mag_ratio() > 0.0:
		bb.set_nav_target(point.stand_position())

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	if bb.mag_ratio() > LOW_MAG or bb.is_reloading():
		return
	# A dry weapon is reloaded no matter what: standing in a firefight with an
	# empty mag is not a decision, it is a bug. Partial mags wait for cover.
	var dry := bb.mag_ratio() <= 0.0
	if not dry and bb.has_target() and threat_dist(bb) < FOCUS_RANGE_PX:
		return
	if not dry and bb.has_nav_target and not bb.at(bb.nav_target, 24.0):
		move_to(bb, bb.nav_target)
		return
	stop(bb)
	crouch(bb, bb.trait_of(&"discipline") > 0.3)
	bb.intent.reload = true