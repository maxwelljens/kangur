class_name ClassDef
extends Resource
## Playable class schema. Instances live in `res://data/classes/*.tres`.
## Contract: docs/architecture.md §6; design numbers: game-design.md §8.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
## Movement multiplier (design §3: class multipliers 0.92–1.08).
@export var speed_mult: float = 1.0
## Armor durability; 0 = no armor. Vest absorbs 40% torso, helmet 50% head.
@export var armor_vest: float = 60.0
@export var armor_helmet: float = 0.0
@export var bandages: int = 3
## Weapon categories this class may take as primary (WeaponDef.category).
@export var primary_categories: Array[StringName] = [&"ar", &"br"]
@export var sidearm_id: StringName = &"adder"
## EquipmentDef ids in kit order.
@export var equipment: Array[StringName] = [&"frag", &"flash"]
@export var perk_id: StringName = &""
@export var icon_path: String = ""

func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("id is empty")
	if display_name.is_empty():
		errors.append("display_name is empty")
	if speed_mult <= 0.0:
		errors.append("speed_mult must be > 0")
	if armor_vest < 0.0 or armor_helmet < 0.0:
		errors.append("armor values must be >= 0")
	if bandages < 0:
		errors.append("bandages must be >= 0")
	if primary_categories.is_empty():
		errors.append("primary_categories is empty")
	if sidearm_id == &"":
		errors.append("sidearm_id is empty")
	return errors