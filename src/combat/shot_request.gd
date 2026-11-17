class_name ShotRequest
extends RefCounted
## One projectile to spawn. Pure data; the weapon node turns it into a bullet.
## Contract: docs/architecture.md §4.

var origin: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.RIGHT
var speed: float = 6000.0
var damage: float = 30.0
var penetration: float = 1.0
var falloff_start: float = 500.0
var falloff_end: float = 1400.0
var min_mult: float = 0.6
## Visual tracer length in px; the tracer still stops at the first hit.
var tracer_len: float = 1400.0
var weapon_id: StringName = &""

func _to_string() -> String:
	return "ShotRequest(%s origin=%s dir=%s dmg=%.1f)" % [weapon_id, origin, dir, damage]