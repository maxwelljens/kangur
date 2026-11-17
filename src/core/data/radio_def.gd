class_name RadioDef
extends Resource
## Radio chatter line set, one per faction. Instances live in `res://data/radio/*.tres`.
## Contract: docs/architecture.md §6; lines: docs/design/radio-lines.md.
## Event name -> candidate lines. Placeholders are substituted by the radio layer:
## {callsign} {grid} {weapon} {count} {obj}.
## Value array is untyped: GDScript rejects nested typed collections
## (Dictionary[StringName, Array[String]] does not compile); same shape as SoundSetDef.

@export var id: StringName = &""
@export var display_name: String = ""
## Event key -> lines. Events are the ones listed in docs/design/radio-lines.md.
@export var lines: Dictionary[StringName, Array] = {}