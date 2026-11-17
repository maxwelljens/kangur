extends "res://src/ai/behaviors/behavior.gd"
## AvoidDanger — the danger map says this spot (or the route ahead) is a
## killzone → shift to a safer cover/hold position, or smoke it if the team has
## one. Reacting to danger is a *memory* behaviour: it needs no enemy truth
## (design §9.5 "avoid reroute, hold longer angles, smoke it").

const BASE := 0.10
const REPATH_PX := 180.0
const SAFE_ARRIVE_PX := 26.0

func score(bb: Blackboard) -> float:
	var heat := bb.danger_at(bb.host_pos())
	var zone := bb.killzone_at(bb.host_pos())
	if heat <= 0.05 and zone <= 0.0:
		return 0.0
	var value := BASE + 0.45 * clampf(heat, 0.0, 1.0) + 0.30 * zone
	value += 0.10 * bb.trait_of(&"caution")
	if bb.has_target():
		value -= 0.20
	return clampf(value, 0.0, 1.1)

func enter(bb: Blackboard, _controller: Node) -> void:
	var target := _safe_point(bb)
	bb.action_data[&"safe_pos"] = target
	if target != Vector2.ZERO:
		bb.set_nav_target(target)

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	var target: Vector2 = bb.action_data.get(&"safe_pos", Vector2.ZERO)
	if target == Vector2.ZERO or bb.at(target, SAFE_ARRIVE_PX):
		stop(bb)
		crouch(bb, true)
		face(bb, threat_dir(bb))
		return
	move_to(bb, target)
	if bb.intent.move.length() > 0.1:
		bb.note_progress()

func exit(bb: Blackboard, _controller: Node) -> void:
	bb.action_data.erase(&"safe_pos")

## Nearest cover point whose stand spot is outside the hot zone.
func _safe_point(bb: Blackboard) -> Vector2:
	if bb.world == null:
		return Vector2.ZERO
	var best: CoverPoint = null
	var best_heat := INF
	for point: CoverPoint in bb.world.cover_points_near(bb.host_pos(), REPATH_PX * 2.0):
		var heat := bb.danger_at(point.stand_position())
		if heat < best_heat:
			# Keep the lane value in the tie-break, safety first.
			best_heat = heat
			best = point
	if best == null or bb.danger_at(best.stand_position()) >= bb.danger_at(bb.host_pos()):
		# Nothing safer nearby: back away from the hottest cell.
		var away := bb.host_pos() - _hottest_nearby(bb)
		return bb.host_pos() + away.normalized() * REPATH_PX
	return best.stand_position()

func _hottest_nearby(bb: Blackboard) -> Vector2:
	var best: Vector2 = bb.host_pos()
	var best_heat := -1.0
	if bb.world == null:
		return best
	for point: CoverPoint in bb.world.cover_points_near(bb.host_pos(), REPATH_PX * 2.0):
		var heat := bb.danger_at(point.global_position)
		if heat > best_heat:
			best_heat = heat
			best = point.global_position
	return best