class_name WeaponDef
extends Resource
## Weapon schema. Instances live in `res://data/weapons/*.tres`.
## Contract: docs/architecture.md §6; design numbers: game-design.md §6.

## Design §6: degrees are half-angle spread units used by Ballistics.
@export var id: StringName = &""
@export var display_name: String = ""
## pistol / smg / ar / br / dmr / sniper / lmg / shotgun.
@export var category: StringName = &"ar"
## Enums.FireMode values; first entry is the spawn mode.
@export var fire_modes: Array[int] = [Enums.FireMode.AUTO, Enums.FireMode.SEMI]
@export var rpm: float = 650.0
## Rounds per burst when BURST mode is selected.
@export var burst_count: int = 3
@export var mag_size: int = 30
@export var reserve_mags: int = 5
@export var reload_time: float = 2.4
@export var equip_time: float = 0.6
## Projectile speed, px/s (design §6: 4000–9000).
@export var bullet_speed: float = 6200.0
@export var damage: float = 30.0
## Pellets per trigger pull; 1 for single-projectile weapons.
@export var pellets: int = 1

## Base spread (deg) + bloom added per shot, capped, recovering at this rate.
@export var spread_base: float = 1.2
@export var bloom_per_shot: float = 0.35
@export var bloom_max: float = 6.0
@export var bloom_recovery: float = 4.0
## Multiplier applied to the movement spread penalty (heavier = more).
@export var move_penalty_scale: float = 1.0
## Recoil kick (deg) per shot and recovery rate toward pre-fire aim.
@export var recoil_kick: float = 1.4
@export var recoil_recovery: float = 3.5

## Wall penetration power (design §6: concrete/wood thresholds per surface).
@export var penetration: float = 1.0
## Damage falloff is linear from start to end px, down to min_mult.
@export var falloff_start: float = 500.0
@export var falloff_end: float = 1400.0
@export var min_mult: float = 0.6
## Spread multiplier while focusing (RMB). Class perks may override the maths.
@export var focus_mult: float = 0.55
@export var move_speed_mult: float = 1.0
@export var weight: float = 3.5

## Defs sound-set id (data/sounds). Empty = silent in dev builds.
@export var sound_set: StringName = &""
@export var sprite_path: String = ""
@export var icon_path: String = ""
@export var tracer_color: Color = Color(0.95, 0.65, 0.25, 1.0)
@export var shell_color: Color = Color(0.78, 0.62, 0.32, 1.0)

func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("id is empty")
	if display_name.is_empty():
		errors.append("display_name is empty")
	if rpm <= 0.0:
		errors.append("rpm must be > 0")
	if mag_size <= 0:
		errors.append("mag_size must be > 0")
	if damage <= 0.0:
		errors.append("damage must be > 0")
	if pellets < 1:
		errors.append("pellets must be >= 1")
	if bullet_speed <= 0.0:
		errors.append("bullet_speed must be > 0")
	if fire_modes.is_empty():
		errors.append("fire_modes is empty")
	for mode: int in fire_modes:
		if not Enums.FireMode.values().has(mode):
			errors.append("invalid fire mode %d" % mode)
	if falloff_end <= falloff_start:
		errors.append("falloff_end must be > falloff_start")
	return errors