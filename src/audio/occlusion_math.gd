class_name OcclusionMath
extends RefCounted
## Spatial-audio occlusion + audibility math. Pure, static, headless-testable.
## Contract: docs/architecture.md §4, §9; design: docs/design/game-design.md §12.
##
## Every table is indexed by occlusion level (0 = line of sight … 3 = muffled),
## which is the wall count clamped to 3+. `for_walls()` returns the level as
## `bus` because AudioServer bus indices depend on the loaded layout — resolve a
## name with `bus_name_for_walls()`.

## Occlusion buses, ordered by level. Names are a contract: StreamPlayers look
## buses up by name (renaming silently reroutes to Master).
const BUS_NAMES: Array[StringName] = [&"SFX_Open", &"SFX_Light", &"SFX_Heavy", &"SFX_Muffled"]
## Low-pass cutoff per level, Hz (architecture §9).
const CUTOFF_HZ: Array[float] = [20500.0, 4200.0, 1300.0, 550.0]
## Gain per level, dB. Applied as the BUS gain in `default_bus_layout.tres`;
## players stay at 0 dB so the attenuation is never applied twice.
const VOLUME_DB: Array[float] = [0.0, -4.0, -9.0, -14.0]
## Levels are 0..3; 3 walls or more all sound identical.
const MAX_WALLS := 3

## Audible radius in px per source kind (design §12). Emitters pass the matching
## value as `loudness` on EventBus.sound_emitted; NPC hearing uses the same unit.
const LOUDNESS_GUNSHOT := 1600.0
const LOUDNESS_SPRINT_STEP := 420.0
const LOUDNESS_WALK_STEP := 260.0
const LOUDNESS_CROUCH_STEP := 120.0
const LOUDNESS_RELOAD := 200.0
const LOUDNESS_BANDAGE := 140.0
const LOUDNESS_EXPLOSION := 2000.0
const LOUDNESS_BODYFALL := 180.0
## Sanity clamp for rendered players; above the loudest legitimate source.
const MAX_RENDER_DISTANCE := 2400.0

## Wall count → occlusion level, saturating at MAX_WALLS.
static func occlusion_level(wall_count: int) -> int:
	return clampi(wall_count, 0, MAX_WALLS)

static func bus_name_for_walls(wall_count: int) -> StringName:
	return BUS_NAMES[occlusion_level(wall_count)]

static func cutoff_for_walls(wall_count: int) -> float:
	return CUTOFF_HZ[occlusion_level(wall_count)]

static func volume_offset_for_walls(wall_count: int) -> float:
	return VOLUME_DB[occlusion_level(wall_count)]

## Contract-shaped result: { bus: int, volume_db: float, cutoff: float }.
static func for_walls(wall_count: int) -> Dictionary:
	var level := occlusion_level(wall_count)
	return {"bus": level, "volume_db": VOLUME_DB[level], "cutoff": CUTOFF_HZ[level]}

## `loudness` is already an audible radius in px (EventBus contract), so this is
## a clamp, not a curve.
static func max_distance(loudness: float) -> float:
	return clampf(loudness, 0.0, MAX_RENDER_DISTANCE)

## Radius at which an NPC still hears a source through `wall_count` walls.
## Reuses the render gains so perception and the mix agree (architecture §9).
static func occluded_loudness(base_loudness: float, wall_count: int) -> float:
	return base_loudness * db_to_linear(VOLUME_DB[occlusion_level(wall_count)])