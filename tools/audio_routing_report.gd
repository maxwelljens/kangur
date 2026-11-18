extends SceneTree
## Prints the audio routing table for representative sources — the non-visual
## "screenshot" for the audio module. Run:
##   tools/godot.sh --headless --path . -s tools/audio_routing_report.gd
## Occlusion off is reported too, so a reviewer can see the bypass path.

const SOURCES: Array[Dictionary] = [
	{"label": "open ground, 0 walls", "pos": Vector2(30, 0)},
	{"label": "room, 1 wall", "pos": Vector2(90, 0)},
	{"label": "room, 2 walls", "pos": Vector2(210, 0)},
	{"label": "far wing, 3 walls", "pos": Vector2(330, 0)},
	{"label": "far wing, 4 walls", "pos": Vector2(450, 0)},
	{"label": "outside gunshot range", "pos": Vector2(5000, 0)},
]

const KINDS: Array[StringName] = [&"gunshot", &"gunshot:kestrel", &"gunshot:judge", &"gunshot:breve", &"impact", &"footstep", &"reload", &"bandage", &"bodyfall", &"explosion", &"unknown_kind"]

func _initialize() -> void:
	var director: Node = load("res://src/audio/audio_director.gd").new()
	root.add_child(director)
	await physics_frame
	director.set_listener(Vector2.ZERO)

	# One wall per probe point, 120 px apart along +X.
	for i: int in 4:
		var body := StaticBody2D.new()
		body.collision_layer = Layers.WORLD_BIT
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8, 400)
		shape.shape = rect
		body.add_child(shape)
		body.global_position = Vector2(60.0 + i * 120.0, 0.0)
		root.add_child(body)
	await physics_frame

	print("\n=== AUDIO ROUTING (listener at origin, walls on WORLD layer) ===")
	print("wall_count | bus          | cutoff Hz | gain dB | occluded gunshot reach")
	for walls: int in [0, 1, 2, 3, 4]:
		print("%10d | %-12s | %9.0f | %7.1f | %6.0f px" % [
			walls,
			OcclusionMath.bus_name_for_walls(walls),
			OcclusionMath.cutoff_for_walls(walls),
			OcclusionMath.volume_offset_for_walls(walls),
			OcclusionMath.occluded_loudness(OcclusionMath.LOUDNESS_GUNSHOT, walls),
		])

	print("\n=== BUS GRAPH ===")
	for i: int in AudioServer.bus_count:
		var effects: Array[String] = []
		for e: int in AudioServer.get_bus_effect_count(i):
			effects.append(AudioServer.get_bus_effect(i, e).get_class())
		print("%2d %-11s -> %-8s %6.2f dB %s" % [
			i, AudioServer.get_bus_name(i), AudioServer.get_bus_send(i),
			AudioServer.get_bus_volume_db(i), ", ".join(effects),
		])

	print("\n=== SOURCE ROUTING ===")
	for source: Dictionary in SOURCES:
		var pos: Vector2 = source["pos"]
		print("%-24s %-22s audible=%s bus=%s" % [
			source["label"], str(pos),
			director.is_audible(pos, OcclusionMath.LOUDNESS_GUNSHOT),
			director.bus_for_source(pos),
		])

	print("\n=== SOUND MAPPING (kind -> stream resolved?) ===")
	for kind: StringName in KINDS:
		var stream: AudioStream = director._stream_for(kind, Enums.Surface.CONCRETE)
		print("%-18s %s" % [kind, stream.resource_path if stream else "MISSING"])

	print("\n=== WEAPON SETS (WeaponDef.sound_set -> data/sounds/<set> -> stream) ===")
	var sets: Dictionary = director._weapon_sets()
	var weapon_ids: Array = sets.keys()
	weapon_ids.sort()
	for weapon_id: StringName in weapon_ids:
		var shot: AudioStream = director._stream_for(&"gunshot:" + String(weapon_id), Enums.Surface.CONCRETE)
		print("%-9s set=%-8s shot=%s" % [weapon_id, sets[weapon_id],
			shot.resource_path if shot else "MISSING"])

	print("\n=== IMPACTS BY SURFACE ===")
	for surface: int in director.IMPACT_FOLDERS:
		var stream: AudioStream = director._stream_for(&"impact", surface)
		var label: String = Enums.Surface.keys()[surface] if surface >= 0 else "FLESH"
		print("%-10s %s" % [label, stream.resource_path if stream else "MISSING"])

	print("\n=== FOOTSTEPS BY SURFACE ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for surface: int in Enums.Surface.size():
		var stream := Footsteps.surface_stream(surface, rng)
		print("%-10s step=%.2fs %s" % [
			Enums.Surface.keys()[surface], Footsteps.step_interval(130.0),
			stream.resource_path if stream else "MISSING",
		])

	print("")
	quit()