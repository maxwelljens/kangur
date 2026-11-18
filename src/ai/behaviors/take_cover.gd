extends "res://src/ai/behaviors/behavior.gd"
## TakeCover — break contact to the best scored cover point: protection from the
## threat, lane coverage, spacing, danger penalty (design §9.6). Crouches on
## arrival; standing up is Peek's or Engage's job.
##
## Sims measured cover% at 27% on open maps (Dustworks) against a 30% gate:
## the score was too polite to beat HoldAngle/Advance on a map with few angles,
## so threat contact now weighs more than temperament. A bot under fire that
## stays in the open is not "brave", it is dead weight.

const BASE := 0.26
const ARRIVE_PX := 20.0
## Under fire: the single strongest reason to move (any personality).
const UNDER_FIRE_BONUS := 0.26
## Merely seeing an enemy: a small pull, well below Engage's weight.
const SIGHTED_BONUS := 0.06
## Sighted, in the open, at range: get behind something BEFORE trading. This is
## the one cue that must outrank Engage, or bots duel in the lane and cover%
## never leaves single digits (sims: 11–16% on Dustworks).
const EXPOSED_BONUS := 0.45
## Inside this range there is no time to reach cover: fight where you stand.
const POINT_BLANK_PX := 180.0
const CAUTION_W := 0.26
const WOUNDED_W := 0.22
const OUTNUMBERED_BONUS := 0.20
const KILLZONE_BONUS := 0.22
## Already in cover: staying is cheaper than re-running the search.
const IN_COVER_PENALTY := 0.20
## No usable cover nearby: do not oscillate toward nothing.
const NO_COVER_PENALTY := 0.30
## Second-hand-only threat (radio) is worth at most this much: enough to duck a
## covered lane, not enough to outrank advancing on the reported position.
const HIDE_SCORE := 0.22
## A personal sighting older than this is "heard about it", not "under fire".
const HEARD_THREAT_MAX_AGE_S := 2.0

func score(bb: Blackboard) -> float:
	var threat := threat_dist(bb)
	if threat == INF and bb.intel_contact().is_empty():
		return 0.0
	# Radio contact is not incoming fire. Hiding from a second-hand sighting is
	# how a squad sits in cover for a whole match: only a personally-seen threat
	# (a fresh own sighting) gets full cover weight.
	var own_age := _own_sighting_age(bb)
	if not bb.has_target() and (own_age < 0.0 or own_age > HEARD_THREAT_MAX_AGE_S):
		return clampf(HIDE_SCORE, 0.0, HIDE_SCORE)
	var hp := bb.torso_ratio()
	var value := BASE + CAUTION_W * bb.trait_of(&"caution") \
		+ WOUNDED_W * (1.0 - hp)
	# Seeing somebody is Engage's business; being shot at is cover's. Without
	# this distinction a bot ducks every time an enemy enters the cone and the
	# fight never happens (sims: 41–81% of ticks in cover, 4 kills in 8 min).
	if bb.hit_timer > 0.0:
		value += UNDER_FIRE_BONUS
	elif bb.has_target():
		value += SIGHTED_BONUS
		if not bb.in_cover and threat_dist(bb) > POINT_BLANK_PX:
			value += EXPOSED_BONUS
	if bb.visible_enemy_count() >= 2:
		value += OUTNUMBERED_BONUS
	if bb.killzone_at(bb.host_pos()) > 0.0:
		value += KILLZONE_BONUS
	if bb.in_cover:
		value -= IN_COVER_PENALTY
	if best_cover(bb) == null:
		value -= NO_COVER_PENALTY
	return clampf(value, 0.0, 1.2)

## Age of the NPC's own freshest sighting (-1 = never). Personal memory only.
func _own_sighting_age(bb: Blackboard) -> float:
	return bb.memory.freshest_age() if bb.memory != null else -1.0

func enter(bb: Blackboard, _controller: Node) -> void:
	bb.leave_cover()
	var point := best_cover(bb)
	if point == null:
		return
	bb.action_data[&"cover_pos"] = point.stand_position()
	bb.action_data[&"cover_lean"] = point.lean_dir
	bb.set_nav_target(point.stand_position())

func tick(bb: Blackboard, _controller: Node, _dt: float) -> void:
	var cover_pos: Vector2 = bb.action_data.get(&"cover_pos", Vector2.ZERO)
	if cover_pos == Vector2.ZERO:
		stop(bb)
		return
	if bb.at(cover_pos, ARRIVE_PX):
		stop(bb)
		crouch(bb, true)
		bb.take_cover_at(cover_pos, bb.action_data.get(&"cover_lean", Vector2.ZERO))
		bb.note_progress()
		face(bb, bb.cover_lean if bb.cover_lean.length() > 0.001 else threat_dir(bb))
		return
	move_to(bb, cover_pos, bb.torso_ratio() < 0.5)
	if bb.intent.move.length() > 0.1:
		bb.note_progress()

func exit(bb: Blackboard, _controller: Node) -> void:
	# The spot stays claimed until the NPC leaves it (Blackboard derives
	# `in_cover` from the anchor), so Peek can follow TakeCover immediately.
	pass