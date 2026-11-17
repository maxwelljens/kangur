extends Node
## AudioDirector — autoload. Buses, music, ambience, UI/voice, pooled spatial
## players with wall occlusion. Contract: docs/architecture.md §3.4, §9.
##
## Headless: buses, layout and math still run (the Dummy driver keeps the audio
## graph alive), only PLAYBACK no-ops. Gameplay never depends on this: if the
## director is absent or muted, `sound_emitted` still fires for AI hearing.
##
## Weapon-id gap: EventBus.sound_emitted has no weapon parameter, so gunshots
## encode it in the kind as `&"gunshot:<weapon_id>"` (`&"gunshot"` alone uses the
## generic rifle set). Documented in the integration notes; see `_stream_for`.

const BUS_LAYOUT_PATH := "res://assets/audio/default_bus_layout.tres"
const POOL_SIZE := 32
const ATTENUATION := 1.6
const MUSIC_FADE := 1.5
const AMBIENCE_DB := -12.0
const SILENT_DB := -80.0
## Occlusion rays: high walls + glass (glass = 1 wall, architecture §2).
const OCCLUSION_MASK := Layers.SOUND_MASK
## Nudge past a counted wall so the next ray starts on the far side.
const RAY_SKIN := 1.0
const MUSIC_DIR := "res://assets/audio/music"
const AMBIENCE_DIR := "res://assets/audio/ambience"
const UI_DIR := "res://assets/audio/ui"
const VOICE_DIR := "res://assets/audio/voice"
const WEAPON_DIR := "res://assets/audio/weapons"
const SFX_DIR := "res://assets/audio/sfx"
## Fallback gunshot set: 5.56 is the only complete rifle set (credits §1).
const DEFAULT_GUNSHOT_SET := "556"

## kind → [folder, filename filter]. The filter keeps rustle and thud apart
## inside the shared body-foley folder; "" means any file.
const KIND_STREAMS: Dictionary[StringName, Array] = {
	&"reload": [WEAPON_DIR + "/shared/reload", ""],
	&"bandage": [SFX_DIR + "/body", "cloth"],
	&"bodyfall": [SFX_DIR + "/body", "body_fall"],
}
## Kinds with no folder of their own; falls back to the verified metal impacts.
const FALLBACK_DIR := SFX_DIR + "/impacts/metal"
## Adaptive match score (design §12). `clutch` ships as a standalone track.
const TENSION_TRACKS: Dictionary[StringName, StringName] = {
	&"calm": &"match_calm", &"engaged": &"match_engaged", &"clutch": &"clutch",
}
## weapon id → fire/reload folder (credits §1 mapping).
const WEAPON_SETS: Dictionary[StringName, StringName] = {
	&"adder": &"9mm", &"vespa": &"9mm", &"kedr": &"9mm",
	&"kestrel": &"556",
	&"volk": &"308", &"falx": &"308", &"sokol": &"308", &"lynx": &"308", &"mule": &"308",
	&"breve": &"20ga", &"automa": &"20ga",
	## No .357 recording exists (credits §1: action/reload only). The .308
	## single is the closest heavy-bore boom available.
	&"judge": &"308",
}
## Explosion has no verified recording yet; the 20-gauge blast is the closest
## available low boom (body foley read as cloth rustle through walls).
## shortcut: no explosion asset, upgrade when a licence-clean boom is sourced.
const EXPLOSION_DIR := "res://assets/audio/weapons/20ga/fire"

var _headless := false
var _listener_pos := Vector2.ZERO
var _listener: AudioListener2D

var _pool: Array[AudioStreamPlayer2D] = []
var _next_player := 0
var _pending: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## `dir|filter` → audio filenames. Never mutated by Settings or gameplay.
var _file_cache: Dictionary[String, Array] = {}

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_on_a := true
var _music_track: StringName = &""
var _tension: StringName = &""
var _ambience: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _voice: AudioStreamPlayer

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_rng.randomize()
	_load_bus_layout()
	_apply_settings()
	_build_pool()
	_build_players()
	EventBus.sound_emitted.connect(_on_sound_emitted)
	EventBus.settings_changed.connect(_on_settings_changed)

func _physics_process(_dt: float) -> void:
	if _pending.is_empty():
		return
	var batch := _pending
	_pending = []
	for item: Dictionary in batch:
		_play_item(item["pos"], item["reach"], item["stream"])

## Player camera position (px). Match/CameraRig calls this each frame; without it
## the listener sits at the world origin.
func set_listener(pos: Vector2) -> void:
	_listener_pos = pos
	if _listener != null:
		_listener.global_position = pos

func _load_bus_layout() -> void:
	if ResourceLoader.exists(BUS_LAYOUT_PATH):
		var layout := load(BUS_LAYOUT_PATH) as AudioBusLayout
		if layout != null:
			AudioServer.set_bus_layout(layout)
	var required: Array = Array(OcclusionMath.BUS_NAMES) + [&"SFX", &"Music", &"Voice"]
	for bus_name: StringName in required:
		if AudioServer.get_bus_index(bus_name) < 0:
			push_error("AudioDirector: bus '%s' missing from %s" % [bus_name, BUS_LAYOUT_PATH])

func _apply_settings() -> void:
	var buses: Array[StringName] = [&"Master", &"SFX", &"Music", &"Voice"]
	var keys: Array[StringName] = [&"master", &"sfx", &"music", &"voice"]
	for i: int in buses.size():
		var idx := AudioServer.get_bus_index(buses[i])
		if idx < 0:
			continue
		var linear := float(Settings.get_value(&"audio", keys[i], 1.0))
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))

func _on_settings_changed(section: StringName) -> void:
	if section == &"audio":
		_apply_settings()

func _build_pool() -> void:
	for i: int in POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		p.name = "SFX%d" % i
		p.bus = String(OcclusionMath.BUS_NAMES[0])
		p.attenuation = ATTENUATION
		p.area_mask = 0  # 4.7 default: ignore Area2D bus overrides, we route by ray
		add_child(p)
		_pool.append(p)

func _build_players() -> void:
	_listener = AudioListener2D.new()
	_listener.name = "Listener"
	add_child(_listener)
	_listener.make_current()
	_music_a = _make_player(&"Music", "MusicA")
	_music_b = _make_player(&"Music", "MusicB")
	_ambience = _make_player(&"SFX", "Ambience")
	_ui = _make_player(&"SFX_Open", "UI")
	_ui.max_polyphony = 4  # hover + click + confirm overlap in menus
	_voice = _make_player(&"Voice", "Radio")

func _make_player(bus: StringName, node_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.bus = String(bus)
	add_child(p)
	return p

# --- gameplay sounds ---------------------------------------------------------

## Queue rather than play: the wall raycast needs a physics frame, and signals
## may arrive from idle or from inside a query flush.
func _on_sound_emitted(pos: Vector2, loudness: float, kind: StringName, _source: Node, surface: int) -> void:
	if _headless or _pending.size() >= POOL_SIZE or not is_audible(pos, loudness):
		return  # headless: no output device, skip the queue (gameplay unaffected)
	_pending.append({"pos": pos, "reach": OcclusionMath.max_distance(loudness), "stream": _stream_for(kind, surface)})

## Would a source at `pos` with this loudness be heard at the listener at all?
func is_audible(pos: Vector2, loudness: float) -> bool:
	return _listener_pos.distance_to(pos) <= OcclusionMath.max_distance(loudness)

## Testable seam: counts walls for a source at `pos`, then plays on that bus.
func _play_item(pos: Vector2, reach: float, stream: AudioStream) -> void:
	if _headless or stream == null:
		return  # headless: the audio graph is built but nothing is rendered
	var p := _take_player()
	p.stream = stream
	p.global_position = pos
	p.max_distance = reach
	p.bus = String(bus_for_source(pos))
	p.play()

## Bus a source at `pos` is mixed into: occlusion setting off ⇒ open air.
func bus_for_source(pos: Vector2) -> StringName:
	if not _occlusion_enabled():
		return OcclusionMath.bus_name_for_walls(0)
	return OcclusionMath.bus_name_for_walls(count_walls(_listener_pos, pos))

func _take_player() -> AudioStreamPlayer2D:
	for i: int in POOL_SIZE:
		var index := (_next_player + i) % POOL_SIZE
		if not _pool[index].playing:
			_next_player = (index + 1) % POOL_SIZE
			return _pool[index]
	var stolen: AudioStreamPlayer2D = _pool[_next_player]  # cap: steal round-robin
	_next_player = (_next_player + 1) % POOL_SIZE
	return stolen

func _occlusion_enabled() -> bool:
	return bool(Settings.get_value(&"audio", &"occlusion", true))

## Wall crossings between two points, saturating at OcclusionMath.MAX_WALLS.
## Glass is in SOUND_MASK, so a window counts as one wall without tile lookup.
func count_walls(from: Vector2, to: Vector2) -> int:
	if not is_inside_tree():
		return 0
	var space := get_viewport().world_2d.direct_space_state
	var dir := (to - from).normalized()
	var origin := from
	var walls := 0
	while walls < OcclusionMath.MAX_WALLS:
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(origin, to, OCCLUSION_MASK))
		if hit.is_empty():
			break
		walls += 1
		origin = (hit["position"] as Vector2) + dir * RAY_SKIN
		if origin.distance_to(to) <= RAY_SKIN:
			break
	return walls

## Weapon-aware stream lookup. `kind` is `&"gunshot"`, `&"gunshot:<weapon_id>"`,
## `&"footstep"` (surface drives the set) or a plain SFX kind.
func _stream_for(kind: StringName, surface: int) -> AudioStream:
	var parts := String(kind).split(":")
	var base := StringName(parts[0])
	var weapon_id := StringName(parts[1]) if parts.size() > 1 else &""

	match base:
		&"footstep":
			return Footsteps.surface_stream(surface, _rng)
		&"explosion":
			return _random_stream(EXPLOSION_DIR)
		&"gunshot", &"reload":
			var set_dir := String(WEAPON_SETS.get(weapon_id, &""))
			if set_dir.is_empty():
				set_dir = DEFAULT_GUNSHOT_SET if base == &"gunshot" else "shared"
			var sub := "fire" if base == &"gunshot" else "reload"
			var stream := _random_stream("%s/%s/%s" % [WEAPON_DIR, set_dir, sub])
			if stream == null and base == &"gunshot":
				stream = _random_stream("%s/%s/fire" % [WEAPON_DIR, DEFAULT_GUNSHOT_SET])
			return stream
	var entry: Array = KIND_STREAMS.get(base, [])
	if not entry.is_empty():
		return _random_stream(entry[0], entry[1])
	return _random_stream(FALLBACK_DIR)  # unknown kind stays audible

## Random audio file in `dir`, optionally only names containing `filter`.
## Listings are cached: this runs on every gunshot.
func _random_stream(dir: String, filter: String = "") -> AudioStream:
	var key := "%s|%s" % [dir, filter]
	if not _file_cache.has(key):
		var names: Array = []
		for name: String in DirAccess.get_files_at(dir):
			if name.get_extension() in ["ogg", "wav", "mp3"] and (filter.is_empty() or name.contains(filter)):
				names.append(name)
		_file_cache[key] = names
	var files: Array = _file_cache[key]
	if files.is_empty():
		push_warning("AudioDirector: no audio files in %s" % dir)
		return null
	return load(dir.path_join(files[_rng.randi_range(0, files.size() - 1)]))

# --- music -------------------------------------------------------------------

## Crossfades to `track_id` (file stem under assets/audio/music). Empty id stops
## music. No-op when that track is already the target.
func play_music(track_id: StringName) -> void:
	if track_id == _music_track:
		return
	_music_track = track_id
	var stream := _loop_stream(MUSIC_DIR, String(track_id))
	var from: AudioStreamPlayer = _music_a if _music_on_a else _music_b
	var to: AudioStreamPlayer = _music_b if _music_on_a else _music_a
	_music_on_a = not _music_on_a
	if stream == null:
		_fade_out(from)
		return
	to.stream = stream
	to.volume_db = SILENT_DB
	to.play()
	_crossfade(from, to)

## Adaptive match score: `&"calm"`, `&"engaged"`, `&"clutch"` (design §12).
func set_tension(level: StringName) -> void:
	if level == _tension:
		return
	_tension = level
	play_music(TENSION_TRACKS.get(level, StringName("match_" + String(level))))

func _loop_stream(dir: String, id: String) -> AudioStream:
	if id.is_empty():
		return null
	var path := _find_audio_file(dir, id)
	if path.is_empty():
		push_warning("AudioDirector: missing stream %s/%s" % [dir, id])
		return null
	var stream := load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true  # per-instance; .import keeps loop=false
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	return stream

## First existing `<dir>/<id>.<ext>`; ambience ships as .mp3, music as .ogg.
func _find_audio_file(dir: String, id: String) -> String:
	for ext: String in ["ogg", "mp3", "wav"]:
		var path := "%s/%s.%s" % [dir, id, ext]
		if ResourceLoader.exists(path):
			return path
	return ""

func _crossfade(from: AudioStreamPlayer, to: AudioStreamPlayer) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(to, "volume_db", 0.0, MUSIC_FADE)
	if from.playing:
		tween.tween_property(from, "volume_db", SILENT_DB, MUSIC_FADE)
		tween.chain().tween_callback(from.stop)

func _fade_out(p: AudioStreamPlayer) -> void:
	if not p.playing:
		return
	var tween := create_tween()
	tween.tween_property(p, "volume_db", SILENT_DB, MUSIC_FADE)
	tween.tween_callback(p.stop)

# --- ambience / UI / voice ---------------------------------------------------

## Loops `id` (file stem under assets/audio/ambience) quietly on the SFX bus.
func play_ambience(id: StringName) -> void:
	var current := _ambience.stream.resource_path.get_file().get_basename() if _ambience.stream else ""
	if _ambience.playing and current == String(id):
		return
	_ambience.stop()
	var stream := _loop_stream(AMBIENCE_DIR, String(id))
	if stream == null:
		return
	_ambience.stream = stream
	_ambience.volume_db = AMBIENCE_DB
	_ambience.play()

func stop_ambience() -> void:
	_ambience.stop()

## Fire-and-forget UI blip on SFX_Open: never positional, never occluded.
func play_ui(name: StringName) -> void:
	var path := "%s/%s.ogg" % [UI_DIR, name]
	if not ResourceLoader.exists(path):
		push_warning("AudioDirector: missing UI sound %s" % path)
		return
	_ui.stream = load(path)
	_ui.play()

## Radio bark on the Voice bus (bandpass is a bus effect). Teams differ in pitch.
func play_radio(team: int, category: StringName) -> void:
	var stream := _random_stream("%s/%s" % [VOICE_DIR, category])
	if stream == null:
		return
	_voice.stream = stream
	_voice.pitch_scale = 1.0 if team == Enums.Team.BASTION else 1.08
	_voice.play()