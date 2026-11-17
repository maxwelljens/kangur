class_name FactionDef
extends Resource
## Faction identity + AI flavor. Instances live in `res://data/factions/*.tres`.
## Contract: docs/architecture.md §6.

@export var id: StringName = &""
@export var display_name: String = ""
@export var color_primary: Color = Color(0.24, 0.42, 0.6, 1.0)
@export var color_accent: Color = Color(0.95, 0.65, 0.25, 1.0)
@export var emblem_path: String = ""
## Pool for bot callsigns; picked without replacement per match.
@export var callsigns: Array[String] = []
## Radio line set id (`data/radio/`), read by the radio chatter layer.
@export var radio_set: StringName = &""
## Doctrine weights for the AI scorer, trait name -> weight (design §9).
@export var doctrine: Dictionary[StringName, float] = {}