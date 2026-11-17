class_name EquipmentDef
extends Resource
## Throwable equipment schema. Instances live in `res://data/equipment/*.tres`.
## Contract: docs/architecture.md §6; design numbers: game-design.md §6.

@export var id: StringName = &""
@export var display_name: String = ""
## Enums.EquipKind: FRAG / FLASH / SMOKE.
@export var kind: int = Enums.EquipKind.FRAG
## Seconds until detonation after the throw (cook can shorten it).
@export var fuse: float = 2.2
## Lethal (frag) or effect (flash/smoke) radius, px.
@export var radius: float = 90.0
@export var damage: float = 110.0
## Seconds the effect blocks vision (smoke) or blinds (flash).
@export var vision_block_time: float = 12.0
@export var sprite_path: String = ""
@export var icon_path: String = ""
@export var sound_set: StringName = &""