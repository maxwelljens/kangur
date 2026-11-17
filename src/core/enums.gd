class_name Enums
extends RefCounted
## Project-wide enumerations. Contract: docs/architecture.md §4.
## Keep values stable — they are serialized in data resources and sim reports.

enum Team { BASTION = 0, SIROCCO = 1 }
enum Stance { STAND = 0, CROUCH = 1 }
enum Part { HEAD = 0, TORSO = 1, ARM_L = 2, ARM_R = 3, LEG_L = 4, LEG_R = 5 }
enum FireMode { SEMI = 0, BURST = 1, AUTO = 2, BOLT = 3, PUMP = 4 }
enum Surface { CONCRETE = 0, SAND = 1, METAL = 2, GRASS = 3, WOOD = 4, GLASS = 5, WATER = 6 }
enum Mode { ELIMINATION = 0, BATTLE = 1, TRAINING = 2 }
enum EquipKind { FRAG = 0, FLASH = 1, SMOKE = 2 }

## Number of body parts (Part enum size).
const PART_COUNT := 6

## Human-readable part names for HUD/killcam.
const PART_NAMES: Array[StringName] = [
	&"head", &"torso", &"left arm", &"right arm", &"left leg", &"right leg",
]

## Body-part damage multipliers applied to weapon base damage (design §7).
const PART_DAMAGE_MULT: Array[float] = [3.5, 1.0, 0.75, 0.75, 0.8, 0.8]

static func team_name(team: int) -> StringName:
	return &"BASTION" if team == Team.BASTION else &"SIROCCO"

static func other_team(team: int) -> int:
	return Team.SIROCCO if team == Team.BASTION else Team.BASTION
