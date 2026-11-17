class_name Behavior
extends RefCounted
## Base for every utility action. Contract (architecture §4): `score(bb)` asks
## "how good does this look right now", `enter/tick/exit` drive the Intent.
## Pure: behaviors never touch nodes except through the blackboard.

## Cover search radius around the NPC, px.
const COVER_RADIUS := 320.0
## Preferred spacing from teammates when picking a cover spot, px.
const COVER_SPACING_MIN := 56.0
const COVER_SPACING_MAX := 240.0
## Threat direction alignment weight in cover scoring.
const COVER_ALIGN_WEIGHT := 1.2
const DANGER_COVER_PENALTY := 1.4
## Beyond this range a rifleman should brace (focus) before firing.
const FOCUS_RANGE_PX := 300.0

func score(_bb: Blackboard) -> float:
	return 0.0

func enter(_bb: Blackboard, _controller: Node) -> void:
	pass

func tick(_bb: Blackboard, _controller: Node, _dt: float) -> void:
	pass

func exit(_bb: Blackboard, _controller: Node) -> void:
	pass

# --- helpers ---------------------------------------------------------------

## Direction toward the freshest remembered contact (own memory only).
static func threat_dir(bb: Blackboard) -> Vector2:
	var contact := bb.best_contact()
	if contact.is_empty():
		return Vector2.ZERO
	var to: Vector2 = contact[&"pos"] - bb.host_pos()
	return to.normalized() if to.length() > 1.0 else Vector2.ZERO

static func threat_dist(bb: Blackboard) -> float:
	var contact := bb.best_contact()
	return INF if contact.is_empty() else bb.host_pos().distance_to(contact[&"pos"])

## Walk/run toward a position using the shared nav target + path.
static func move_to(bb: Blackboard, pos: Vector2, sprint: bool = false) -> void:
	bb.set_nav_target(pos)
	bb.intent.move = bb.nav_dir()
	bb.intent.sprint = sprint and bb.intent.move.length() > 0.1
	if bb.intent.move.length() > 0.1:
		face(bb, bb.intent.move)

static func stop(bb: Blackboard) -> void:
	bb.intent.move = Vector2.ZERO
	bb.intent.sprint = false

## Sticky facing hint for idle/hold actions (the controller falls back to it).
static func face(bb: Blackboard, dir: Vector2) -> void:
	if dir.length() > 0.001:
		bb.action_data[&"face"] = dir.normalized()

static func crouch(bb: Blackboard, on: bool = true) -> void:
	bb.intent.stance = Enums.Stance.CROUCH if on else Enums.Stance.STAND

## Closest cover point worth using, scored from protection/lanes/spacing/danger.
static func best_cover(bb: Blackboard, radius: float = COVER_RADIUS) -> CoverPoint:
	if bb.world == null:
		return null
	var threat_pos: Vector2 = bb.best_contact().get(&"pos", Vector2.ZERO)
	if threat_pos == Vector2.ZERO:
		threat_pos = bb.intel_pos()
	var best: CoverPoint = null
	var best_score := -INF
	for point: CoverPoint in bb.world.cover_points_near(bb.host_pos(), radius):
		var value := cover_value(bb, point, threat_pos)
		if value > best_score:
			best_score = value
			best = point
	return best

## Higher is better. Protection comes first, then lane coverage, spacing, danger.
static func cover_value(bb: Blackboard, point: CoverPoint, threat_pos: Vector2) -> float:
	var stand := point.stand_position()
	var value := point.quality * COVER_ALIGN_WEIGHT
	if threat_pos != Vector2.ZERO:
		var to_threat := (threat_pos - point.global_position).normalized()
		value += clampf(point.lean_dir.normalized().dot(to_threat), -1.0, 1.0) * 0.9
		# The stand spot must not sit inside the remembered killzone.
		value -= bb.danger_at(stand) * DANGER_COVER_PENALTY
	if not point.lanes.is_empty():
		value += 0.15
	var spacing := bb.nearest_teammate_dist()
	if spacing < COVER_SPACING_MIN:
		value -= 0.5
	elif spacing > COVER_SPACING_MAX:
		value -= 0.25
	value -= bb.host_pos().distance_to(stand) / COVER_RADIUS * 0.4
	return value

## Safe to do a long channel (bandage/reload): nothing seen in the last couple
## of seconds and no hidden threat heard.
static func calm(bb: Blackboard) -> bool:
	if bb.has_target():
		return false
	var contact_age := bb.memory.freshest_age()
	return contact_age < 0.0 or contact_age > 2.5