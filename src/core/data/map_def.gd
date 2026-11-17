class_name MapDef
extends Resource
## Map schema. Instances live in `res://data/maps/*.tres`.
## Contract: docs/architecture.md §6–§7.

@export var id: StringName = &""
@export var display_name: String = ""
## Authored map scene (root Node2D per architecture §7).
@export var scene_path: String = ""
## Enums.Mode values this map supports.
@export var supported_modes: Array[int] = [Enums.Mode.ELIMINATION, Enums.Mode.BATTLE]
@export var briefing: String = ""
@export var minimap_path: String = ""
@export var ambience_id: StringName = &""
@export var music_id: StringName = &""
## Lighting preset name resolved by the world/camera rig.
@export var lighting_preset: StringName = &"day"

func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("id is empty")
	if display_name.is_empty():
		errors.append("display_name is empty")
	if scene_path.is_empty():
		errors.append("scene_path is empty")
	elif not scene_path.begins_with("res://"):
		errors.append("scene_path must be a res:// path")
	elif not ResourceLoader.exists(scene_path):
		errors.append("scene_path does not exist: %s" % scene_path)
	if supported_modes.is_empty():
		errors.append("supported_modes is empty")
	for mode: int in supported_modes:
		if not Enums.Mode.values().has(mode):
			errors.append("invalid mode %d" % mode)
	return errors