class_name SoundSetDef
extends Resource
## Audio set schema. Instances live in `res://data/sounds/*.tres`.
## Contract: docs/architecture.md §6; usage: architecture §9.

@export var id: StringName = &""
@export var display_name: String = ""
## Action name -> alternate AudioStreams. Keys: fire, cycle, reload_start,
## reload_end, dry, draw, impact. AudioDirector picks a random variant.
@export var actions: Dictionary[StringName, Array] = {}
## Enums.Surface -> alternate impact streams (concrete chip, metal ping, …).
@export var impacts: Dictionary[int, Array] = {}

## Streams for an action, empty when the set does not define it.
func streams(action: StringName) -> Array[AudioStream]:
	var list: Array[AudioStream] = []
	var raw: Array = actions.get(action, [])
	list.assign(raw.filter(func(s: Variant) -> bool: return s is AudioStream))
	return list

## Impact streams for a surface, empty when undefined.
func surface_streams(surface: int) -> Array[AudioStream]:
	var list: Array[AudioStream] = []
	var raw: Array = impacts.get(surface, [])
	list.assign(raw.filter(func(s: Variant) -> bool: return s is AudioStream))
	return list