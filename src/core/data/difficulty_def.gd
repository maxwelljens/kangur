class_name DifficultyDef
extends Resource
## Difficulty preset. Scales reaction/error/aggression, NEVER sensors (design §9).
## Instances live in `res://data/difficulty/*.tres`.

@export var id: StringName = &""
@export var display_name: String = ""
## Reaction delay range in milliseconds, rolled per NPC per stimulus.
@export var reaction_range: Vector2 = Vector2(240.0, 360.0)
## Aim error range in degrees; converges toward truth over an engagement.
@export var aim_error_range: Vector2 = Vector2(2.5, 5.0)
## Aim turn-rate range in degrees/second.
@export var turn_rate_range: Vector2 = Vector2(320.0, 520.0)
## Utility-scorer biases added to aggressive / disciplined actions.
@export var aggression_bias: float = 0.0
@export var discipline_bias: float = 0.0
## Rounds per burst range (x = min, y = max).
@export var burst_range: Vector2i = Vector2i(3, 6)