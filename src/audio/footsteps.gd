class_name Footsteps
extends RefCounted
## Footstep cadence + per-surface sample selection. Pure/static apart from the
## directory listing cache, so headless tests can call it.
## The owning Motor decides stance/loudness and emits EventBus.sound_emitted.

## Distance covered per footfall at full speed (px). Tuned against
## MovementModel walk 130 / sprint 215 → 0.46 / 0.28 s; crouch 65 clamps to 0.9.
const STRIDE_PX := 60.0
const MIN_INTERVAL := 0.22
const MAX_INTERVAL := 0.9
const AUDIO_DIR := "res://assets/audio/footsteps"
## Enums.Surface index → sample folder. Glass has no recordings (see credits §2)
## and maps glass floors to concrete.
const SURFACE_DIRS: Array[StringName] = [
	&"concrete", &"sand", &"metal", &"grass", &"wood", &"concrete", &"water",
]

static var _cache: Dictionary[String, Array] = {}

## Seconds between footfalls at `speed` (px/s). Stationary clamps to MAX_INTERVAL.
static func step_interval(speed: float) -> float:
	return clampf(STRIDE_PX / maxf(speed, 1.0), MIN_INTERVAL, MAX_INTERVAL)

## Random sample for a surface, or null when the folder is empty/missing.
static func surface_stream(surface: int, rng: RandomNumberGenerator) -> AudioStream:
	var dir := AUDIO_DIR.path_join(String(SURFACE_DIRS[clampi(surface, 0, SURFACE_DIRS.size() - 1)]))
	if not _cache.has(dir):
		var files: Array = []
		for name: String in DirAccess.get_files_at(dir):
			if name.get_extension() in ["ogg", "wav", "mp3"]:
				files.append(name)
		_cache[dir] = files
	var files: Array = _cache[dir]
	if files.is_empty():
		return null
	return load(dir.path_join(files[rng.randi_range(0, files.size() - 1)]))