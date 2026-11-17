class_name ObjectiveZone
extends Area2D
## Battle objective capture area. Tracks which characters are inside and
## exposes occupancy per team; `BattleRules` (modes) polls this and owns all
## capture/contest decisions. Placed and painted by `tools/build_map.gd`,
## retunable in the editor.

const LAYER := Layers.INTERACT
const MASK := Layers.CHARACTER_BIT

@export var obj_id: StringName = &"a"
## Capture order for chained Battle maps (1-based).
@export var order: int = 1
@export var capture_time: float = 20.0
@export var lock_on_capture: bool = false

## Live occupancy: team -> number of character bodies inside.
var _occupants: Dictionary[int, int] = {}


func _ready() -> void:
	collision_layer = Layers.INTERACT_BIT
	collision_mask = MASK
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func occupancy(team: int) -> int:
	return _occupants.get(team, 0)


## +1 when only `team` is present, -1 when only the enemy is, 0 when contested
## or empty. Capture progress direction for BattleRules.
func control() -> int:
	var own := occupancy(Enums.Team.BASTION)
	var enemy := occupancy(Enums.Team.SIROCCO)
	if own > 0 and enemy == 0:
		return 1
	if enemy > 0 and own == 0:
		return -1
	return 0


## World-space rect of the capture area, read from its collision shape.
func capture_rect() -> Rect2:
	var shape := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape == null or not (shape.shape is RectangleShape2D):
		return Rect2(global_position, Vector2.ZERO)
	var rect: RectangleShape2D = shape.shape
	return Rect2(shape.global_position - rect.size * 0.5, rect.size)


func _on_body_entered(body: Node2D) -> void:
	var team := _team_of(body)
	if team < 0:
		return
	_occupants[team] = occupancy(team) + 1


func _on_body_exited(body: Node2D) -> void:
	var team := _team_of(body)
	if team < 0:
		return
	_occupants[team] = maxi(occupancy(team) - 1, 0)


## Characters carry `team` (Enums.Team). Anything else is ignored, so props and
## projectiles wandering in cannot swing a capture.
func _team_of(body: Node2D) -> int:
	if body == null or not body.has_method(&"get_team"):
		return -1
	return int(body.get_team())