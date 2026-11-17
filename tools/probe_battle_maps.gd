extends Node
## Battle + Training map probe: the contracts BattleRules, AI and the Range
## scenes depend on. Run:
##   tools/godot.sh --headless --path . tools/probe_battle_maps.tscn
##   tools/godot.sh --headless --path . tools/probe_battle_maps.tscn -- --map=oldtown
##
## Probes every map in MAPS by default. Prints PASS/FAIL per check and
## `BATTLE_PROBE_OK` / `BATTLE_PROBE_FAIL <n>`.

const MAPS: Array[StringName] = [&"terminal", &"oldtown", &"range"]
const EXPECTED_SPAWNS_PER_TEAM := 12
const EXPECTED_MIN_COVER := 40
const NAV_WAIT_FRAMES := 90

## Per-map spec from docs/design/maps.md: [objective id, order, capture_time].
const OBJECTIVES := {
	&"terminal": [[&"a", 1, 20.0], [&"b", 2, 24.0], [&"c", 3, 28.0]],
	&"oldtown": [[&"a", 1, 20.0], [&"b", 2, 24.0], [&"c", 3, 28.0]],
}
## Spawn-zone surfaces straight from the carve rects (both Battle maps: concrete).
const SPAWN_SURFACE := {
	&"terminal": Enums.Surface.CONCRETE,
	&"oldtown": Enums.Surface.CONCRETE,
}
const MINIMAP_HEADER_BYTES := 8
## Spot checks of the spec's surfaces: [tile x, y, expected Enums.Surface,
## expected solid]. From the maps.md carve rects + palette rules.
const SURFACE_SAMPLES := {
	&"terminal": [
		[12, 22, Enums.Surface.GRASS, false],      # crane_yard (west flank)
		[62, 26, Enums.Surface.METAL, false],      # obj_b_zone warehouse floor
		[48, 52, Enums.Surface.CONCRETE, false],   # main_road by the south docks
		[14, 40, Enums.Surface.CONCRETE, false],   # dock_lane (west flank, open)
		[11, 35, Enums.Surface.METAL, true],       # dock container stack (HIGH_WALL)
	],
	&"oldtown": [
		[44, 20, Enums.Surface.CONCRETE, false],   # main_street
		[26, 26, Enums.Surface.CONCRETE, true],    # west building (brick HIGH_WALL)
		[44, 36, Enums.Surface.CONCRETE, true],    # church solid core
		[43, 56, Enums.Surface.SAND, true],        # fountain low cover
	],
	&"range": [
		[24, 16, Enums.Surface.CONCRETE, false],   # range floor
	],
}
## maps.md Range: firing line x 8/16/24/32/40 at y=26; targets y=20/14/6/lane.
const RANGE_FIRING_X: Array[int] = [8, 16, 24, 32, 40]
const RANGE_TARGET_Y: Array[int] = [20, 14, 6]
const RANGE_MIN_RACKS := 1

var _failures: Array[String] = []


func _ready() -> void:
	var maps: Array[StringName] = MAPS
	var args := OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--map="):
			maps = [StringName(arg.trim_prefix("--map="))]
	for map_id: StringName in maps:
		await _run(map_id)
	if _failures.is_empty():
		print("BATTLE_PROBE_OK")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			print("  FAIL %s" % failure)
		print("BATTLE_PROBE_FAIL %d" % _failures.size())
		get_tree().quit(1)


func _run(map_id: StringName) -> void:
	print("probe: map=%s" % map_id)
	var world := World.new()
	world.map_scene_path = "res://maps/%s/map.tscn" % map_id
	add_child(world)
	if not _check(world.map != null, "%s: map loads" % map_id):
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wait_nav(world.nav)

	_check_bounds(world, map_id)
	_check_cover(world, map_id)
	_check_minimap(map_id)
	_check_surfaces(world, map_id)
	if map_id == &"range":
		_check_range(world, map_id)
		return
	await _check_battle(world, map_id)
	world.queue_free()


## Battle contract: 3 chained objectives, 24 spawns + forward spawns, and a
## nav route through the chain south→north (the attacker's advance).
func _check_battle(world: World, map_id: StringName) -> void:
	var zones := world.objectives()
	_check(zones.size() == OBJECTIVES[map_id].size(),
		"%s: objectives=%d (want %d)" % [map_id, zones.size(), OBJECTIVES[map_id].size()])
	for spec: Array in OBJECTIVES[map_id]:
		var zone := world.objective(spec[0])
		if not _check(zone != null, "%s: objective %s exists" % [map_id, spec[0]]):
			continue
		_check(zone.order == int(spec[1]),
			"%s: objective %s order=%d (want %d)" % [map_id, spec[0], zone.order, spec[1]])
		_check(is_equal_approx(zone.capture_time, float(spec[2])),
			"%s: objective %s capture_time=%.1f (want %.1f)"
				% [map_id, spec[0], zone.capture_time, spec[2]])
		_check(zone.collision_layer == Layers.INTERACT_BIT,
			"%s: objective %s on INTERACT layer" % [map_id, spec[0]])
		_check(zone.capture_rect().size.x >= Tiles.SIZE * 4.0,
			"%s: objective %s capture rect %s" % [map_id, spec[0], zone.capture_rect()])

	# 12 spawns per team, none inside geometry, on the spec surface.
	var surface: int = SPAWN_SURFACE[map_id]
	for team: int in [Enums.Team.BASTION, Enums.Team.SIROCCO]:
		var points := world.spawn_points(team)
		_check(points.size() == EXPECTED_SPAWNS_PER_TEAM,
			"%s: %s spawns=%d (want %d)"
				% [map_id, Enums.team_name(team), points.size(), EXPECTED_SPAWNS_PER_TEAM])
		var blocked := 0
		var wrong_surface := 0
		for pos: Vector2 in points:
			if world.is_wall(pos):
				blocked += 1
			if world.surface_at(pos) != surface:
				wrong_surface += 1
		_check(blocked == 0, "%s: %s spawns inside geometry=%d"
			% [map_id, Enums.team_name(team), blocked])
		_check(wrong_surface == 0, "%s: %s spawn surface mismatches=%d"
			% [map_id, Enums.team_name(team), wrong_surface])

	# Forward spawns: spawn_fwd_<obj> markers for every objective but the last.
	var fwd := _forward_spawns(world)
	var want := zones.size() - 1
	_check(fwd.size() == want,
		"%s: forward spawn groups=%d (want %d)" % [map_id, fwd.size(), want])
	for obj_id: StringName in fwd:
		var markers: Array = fwd[obj_id]
		_check(not markers.is_empty(), "%s: spawn_fwd_%s markers=%d"
			% [map_id, obj_id, markers.size()])
		var zone := world.objective(obj_id)
		for child: Node in markers:
			var marker := child as SpawnMarker
			_check(marker != null and marker.team == Enums.Team.SIROCCO,
				"%s: %s is a SIROCCO SpawnMarker" % [map_id, child.name])
			var pos := (child as Node2D).global_position
			_check(not world.is_wall(pos), "%s: %s clear of geometry" % [map_id, child.name])
			# Attackers advance south→north: a forward spawn must sit behind the
			# objective (south of it), never past it toward the defender.
			_check(zone != null and pos.y > zone.capture_rect().end.y,
				"%s: %s south of objective %s" % [map_id, child.name, obj_id])

	# Nav chain: attacker spawn → A → B → C, each leg routable.
	var attacker := world.spawn_points(Enums.Team.SIROCCO)
	if attacker.is_empty():
		return
	var from := attacker[0]
	for zone: ObjectiveZone in zones:
		var to := zone.global_position
		var path := world.find_path(from, to)
		_check(path.size() >= 2, "%s: nav path -> %s nodes=%d" % [map_id, zone.obj_id, path.size()])
		# Oldtown's church objective is a ring around a solid core, so a path can
		# never end on the zone centre: assert it ends inside the capture rect.
		_check(path.size() < 2 or zone.capture_rect().grow(Tiles.SIZE).has_point(path[path.size() - 1]),
			"%s: nav path enters objective %s capture rect" % [map_id, zone.obj_id])
		from = to


func _check_bounds(world: World, map_id: StringName) -> void:
	var rect := world.bounds()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0, "%s: bounds %s" % [map_id, rect])
	var spec := {"terminal": Vector2i(96, 64), "oldtown": Vector2i(88, 72), "range": Vector2i(48, 32)}
	var want: Vector2i = spec[String(map_id)]
	_check(Vector2i(rect.size / Tiles.SIZE) == want,
		"%s: bounds=%s tiles (want %s)" % [map_id, rect.size / Tiles.SIZE, want])


func _check_cover(world: World, map_id: StringName) -> void:
	var cover := world.cover_points()
	# The Range is a sandbox: its lanes tag only the few edge props, and maps.md
	# asks for no cover there, so the 40-point floor is a Battle-map contract.
	if map_id == &"range":
		_check(world.cover_points_near(Vector2(24, 26) * Tiles.SIZE, 4000.0).size() == cover.size(),
			"%s: cover_points_near scans the map" % map_id)
		return
	_check(cover.size() > EXPECTED_MIN_COVER,
		"%s: cover points=%d (want > %d)" % [map_id, cover.size(), EXPECTED_MIN_COVER])
	var tagged := 0
	for point: CoverPoint in cover:
		if not point.lanes.is_empty():
			tagged += 1
	_check(tagged > cover.size() / 2, "%s: lane-tagged cover=%d/%d" % [map_id, tagged, cover.size()])


## Surfaces + solidity at the spec's key spots, straight from maps.md. Catches
## the costly class of typo: right-looking layout, wrong floor under a lane.
func _check_surfaces(world: World, map_id: StringName) -> void:
	for sample: Array in SURFACE_SAMPLES[map_id]:
		var pos := Vector2(sample[0] + 0.5, sample[1] + 0.5) * Tiles.SIZE
		var surface: int = world.surface_at(pos)
		_check(surface == int(sample[2]), "%s: surface at %s=%d (want %d)"
			% [map_id, sample.slice(0, 2), surface, sample[2]])
		_check(world.is_wall(pos) == bool(sample[3]), "%s: solid at %s=%s (want %s)"
			% [map_id, sample.slice(0, 2), world.is_wall(pos), sample[3]])


func _check_minimap(map_id: StringName) -> void:
	var path := "res://maps/%s/minimap.png" % map_id
	if not _check(FileAccess.file_exists(path), "%s: minimap exists" % map_id):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	_check(file.get_length() > MINIMAP_HEADER_BYTES,
		"%s: minimap nonzero (%d bytes)" % [map_id, file.get_length()])


## maps.md Range: five lanes, firing line at y=26, three fixed dummies per lane
## at y=20/14/6, a weapon rack row on the south wall and a bandage dummy.
func _check_range(world: World, map_id: StringName) -> void:
	var markers := world.map.get_node_or_null(^"Markers")
	if not _check(markers != null, "%s: Markers node exists" % map_id):
		return
	var by_kind := _markers_by_kind(markers)
	for kind: StringName in [&"firing_line", &"target_dummy", &"weapon_rack", &"bandage_dummy"]:
		_check(by_kind.has(kind), "%s: has %s markers" % [map_id, kind])
	_check(by_kind.get(&"firing_line", []).size() == RANGE_FIRING_X.size(),
		"%s: firing line markers=%d (want %d)"
			% [map_id, by_kind.get(&"firing_line", []).size(), RANGE_FIRING_X.size()])
	for marker: Marker2D in by_kind.get(&"firing_line", []):
		_check(int(marker.position.y / Tiles.SIZE) == 26,
			"%s: %s on y=26" % [map_id, marker.name])
	var xs: Array[int] = []
	for marker: Marker2D in by_kind.get(&"firing_line", []):
		xs.append(int(marker.position.x / Tiles.SIZE))
	xs.sort()
	_check(xs == RANGE_FIRING_X, "%s: firing line x=%s (want %s)" % [map_id, xs, RANGE_FIRING_X])
	# 5 lanes × 3 distances.
	_check(by_kind.get(&"target_dummy", []).size() == RANGE_FIRING_X.size() * RANGE_TARGET_Y.size(),
		"%s: target dummies=%d (want %d)" % [map_id, by_kind.get(&"target_dummy", []).size(),
			RANGE_FIRING_X.size() * RANGE_TARGET_Y.size()])
	var ys := {}
	for marker: Marker2D in by_kind.get(&"target_dummy", []):
		ys[int(marker.position.y / Tiles.SIZE)] = true
	for y: int in RANGE_TARGET_Y:
		_check(ys.has(y), "%s: dummies on y=%d" % [map_id, y])
	_check(by_kind.get(&"weapon_rack", []).size() >= RANGE_MIN_RACKS,
		"%s: weapon rack markers=%d" % [map_id, by_kind.get(&"weapon_rack", []).size()])
	# Practice sandbox: the floor is walkable and the shooting lanes are clear.
	_check(not world.is_wall(Vector2(24, 16) * Tiles.SIZE),
		"%s: shooting lane is walkable" % map_id)
	_check(world.surface_at(Vector2(24, 16) * Tiles.SIZE) == Enums.Surface.CONCRETE,
		"%s: floor surface is concrete" % map_id)


func _markers_by_kind(root: Node) -> Dictionary[StringName, Array]:
	var out: Dictionary[StringName, Array] = {}
	for child: Node in root.get_children():
		var marker := child as Marker2D
		if marker == null or not marker.has_meta(&"kind"):
			continue
		var kind := StringName(str(marker.get_meta(&"kind")))
		if not out.has(kind):
			out[kind] = [] as Array
		out[kind].append(marker)
	return out


func _forward_spawns(world: World) -> Dictionary[StringName, Array]:
	var out: Dictionary[StringName, Array] = {}
	var node := world.map.get_node_or_null(^"ForwardSpawns")
	if node == null:
		return out
	for child: Node in node.get_children():
		if not (child is SpawnMarker):
			continue
		# spawn_fwd_<obj>_<NN>
		var parts := str(child.name).split("_")
		if parts.size() < 4:
			continue
		var obj_id := StringName(parts[2])
		if not out.has(obj_id):
			out[obj_id] = [] as Array
		out[obj_id].append(child)
	return out


func _wait_nav(nav: MapNavigation) -> void:
	if nav == null:
		return
	# The polygon loads baked with the scene; the server still needs to serve it
	# (`map_ready`), and path queries before that return empty.
	var served := [false]
	nav.map_ready.connect(func() -> void: served[0] = true, CONNECT_ONE_SHOT)
	for i: int in NAV_WAIT_FRAMES:
		if served[0]:
			return
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> bool:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures.append(label)
	return condition