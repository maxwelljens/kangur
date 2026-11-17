class_name Intent
extends RefCounted
## The single control interface for player and AI. Contract: architecture §4.
## Controllers fill an Intent each physics tick; Character consumes it.
## AI and player produce IDENTICAL intent structures — this is the fairness
## seam: everything downstream (movement, aim, weapons) is shared code.

## Desired movement direction, length 0..1 (world space).
var move: Vector2 = Vector2.ZERO
## Desired aim direction (world space); consumer normalizes.
var aim: Vector2 = Vector2.RIGHT
## Trigger held (auto fire).
var fire: bool = false
## Trigger pressed this tick (semi/bolt/pump edge).
var fire_press: bool = false
## Brace/focus (RMB): tighter spread, slower move, narrower longer cone.
var focus: bool = false
## Sprint request (stamina permitting).
var sprint: bool = false
## Desired stance.
var stance: Enums.Stance = Enums.Stance.STAND
## Reload request (edge).
var reload: bool = false
## Bandage channel held.
var bandage: bool = false
## Weapon slot switch: 0 primary, 1 sidearm, -1 none.
var switch_slot: int = -1
## Cycle fire mode (edge).
var cycle_fire_mode: bool = false
## Throw equipment at kit index, -1 none.
var throw_equipment: int = -1
## Cook grenade (hold throw).
var cook: bool = false
## Interact (doors, objective-related prompts).
var interact: bool = false

## Clear per-tick edge fields; held fields are rewritten by controllers.
func clear_edges() -> void:
	fire_press = false
	reload = false
	switch_slot = -1
	cycle_fire_mode = false
	throw_equipment = -1
	interact = false

func _to_string() -> String:
	return "Intent(move=%s aim=%s fire=%s focus=%s sprint=%s stance=%d)" % [
		move, aim, fire, focus, sprint, stance,
	]
