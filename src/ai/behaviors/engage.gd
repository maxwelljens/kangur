extends "res://src/ai/behaviors/behavior.gd"
## Engage — the fight. Aim through the shared Aim pipeline (acquire/tracking),
## brace at range, and fire in bursts whose length comes from discipline +
## DifficultyDef.burst_range. Never fires without the controller's provenance
## gate; this behavior only *requests* the trigger (design §9.7).

const BURST_GAP_MIN_S := 0.18
const BURST_GAP_MAX_S := 0.55
const BASE := 0.55

func score(bb: Blackboard) -> float:
	if not bb.has_target():
		return 0.0
	# A dry weapon cannot win a firefight: hand the tick to Reload instead.
	if bb.mag_ratio() <= 0.0:
		return 0.05
	var visible := bb.visible_enemy_count()
	var value := BASE + 0.30 * bb.trait_of(&"aggression") + 0.10 * float(mini(visible, 3))
	# Discipline pulls the trigger less eagerly at silly ranges.
	if threat_dist(bb) > FOCUS_RANGE_PX * 2.0:
		value -= 0.15 * (1.0 - bb.trait_of(&"discipline"))
	return clampf(value, 0.0, 1.4)

func enter(bb: Blackboard, _controller: Node) -> void:
	bb.action_data[&"burst_left"] = _burst_len(bb)
	bb.action_data[&"burst_gap"] = 0.0

func tick(bb: Blackboard, _controller: Node, dt: float) -> void:
	var contact := bb.primary_visible()
	if contact.is_empty():
		return
	var pos: Vector2 = contact[&"pos"]
	stop(bb)
	face(bb, pos - bb.host_pos())
	crouch(bb, threat_dist(bb) > FOCUS_RANGE_PX and bb.trait_of(&"caution") > 0.5)
	bb.intent.focus = threat_dist(bb) > FOCUS_RANGE_PX
	bb.action_data[&"aim_pos"] = pos
	bb.note_progress()

	var gap: float = float(bb.action_data.get(&"burst_gap", 0.0)) - dt
	var left: int = int(bb.action_data.get(&"burst_left", 0))
	if gap > 0.0:
		bb.action_data[&"burst_gap"] = gap
		bb.intent.fire = false
		return
	if left <= 0:
		bb.action_data[&"burst_left"] = _burst_len(bb)
		bb.action_data[&"burst_gap"] = bb.rng().randf_range(BURST_GAP_MIN_S, BURST_GAP_MAX_S)
		bb.intent.fire = false
		return
	bb.action_data[&"burst_left"] = left - 1
	bb.intent.fire = true

## Burst length: disciplined NPCs use the preset's short end.
func _burst_len(bb: Blackboard) -> int:
	var difficulty := bb.difficulty
	var low := 3
	var high := 6
	if difficulty != null:
		low = difficulty.burst_range.x
		high = difficulty.burst_range.y
	var t := clampf(bb.trait_of(&"discipline"), 0.0, 1.0)
	return int(round(lerpf(high, low, t)))