extends "res://src/ai/behaviors/behavior.gd"
## UseEquipment — situational frag/flash/smoke. Frag a remembered position when
## it is out of sight and within throw range, smoke a killzone or a sightline,
## flash before pushing a contested objective. Throws go through the shared
## Arsenal (same EquipmentDef fuse/radius as the player).

const BASE := 0.04
const FRAG_RANGE_PX := 420.0
const FRAG_MIN_PX := 120.0
const SMOKE_RANGE_PX := 520.0
const FLASH_RANGE_PX := 320.0
const THROW_COOLDOWN_S := 6.0

func score(bb: Blackboard) -> float:
	var value := BASE
	if bb.kit_count(&"frag") > 0 and bb.trait_of(&"aggression") > 0.45:
		var contact := bb.best_contact()
		if not contact.is_empty() and not bb.has_target():
			var dist := threat_dist(bb)
			if dist > FRAG_MIN_PX and dist < FRAG_RANGE_PX:
				value += 0.32
	if bb.kit_count(&"smoke") > 0 and (bb.killzone_at(bb.host_pos()) > 0.0
			or (bb.has_target() and bb.torso_ratio() < 0.5)):
		value += 0.28
	if bb.kit_count(&"flash") > 0 and bb.has_target():
		var contact := bb.primary_visible()
		var pos: Vector2 = contact.get(&"pos", Vector2.ZERO)
		if pos != Vector2.ZERO and bb.host_pos().distance_to(pos) < FLASH_RANGE_PX:
			value += 0.22
	return clampf(value, 0.0, 0.8)

func enter(bb: Blackboard, _controller: Node) -> void:
	bb.action_data[&"throw_started"] = false
	bb.action_data[&"throw_timer"] = 0.0

func tick(bb: Blackboard, _controller: Node, dt: float) -> void:
	if bb.action_data.get(&"throw_started", false):
		stop(bb)
		return
	# A beat of wind-up so the throw reads as a decision, not a teleport.
	var timer: float = float(bb.action_data.get(&"throw_timer", 0.0)) + dt
	bb.action_data[&"throw_timer"] = timer
	if timer < 0.25:
		stop(bb)
		return
	bb.action_data[&"throw_started"] = true
	var index := _pick_kit(bb)
	if index >= 0:
		bb.intent.throw_equipment = index
		stop(bb)

func _pick_kit(bb: Blackboard) -> int:
	if bb.has_target() and bb.kit_count(&"flash") > 0:
		return bb.kit_index(&"flash")
	if bb.killzone_at(bb.host_pos()) > 0.0 and bb.kit_count(&"smoke") > 0:
		return bb.kit_index(&"smoke")
	if bb.kit_count(&"frag") > 0:
		return bb.kit_index(&"frag")
	return -1