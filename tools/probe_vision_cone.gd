extends Node2D
## Kangur probe for the vendored VisionCone2D (addons/godot-vision-cone).
## Asserts, in order: occluded fan on mask 1, finite points, nothing past the wall,
## and that angle_deg is live at runtime. Prints PROBE_OK / PROBE_FAIL <reason>.
## Run: godot --headless --path . tools/probe_vision_cone.tscn

const WALL_Y := 150.0        ## wall centre; 20 px thick, so its top face sits at y = 140
const HALF_ANGLE_DEG := 45.0 ## probe cone is 90 deg wide, so +/-45 around +Y

@onready var _cone: VisionCone2D = $VisionCone2D
@onready var _render: Polygon2D = $VisionCone2D/VisionConeRenderer


func _ready() -> void:
	# The addon recomputes in its own _physics_process; read its Polygon2D output
	# instead of calling calculate_vision_shape() (space state is locked outside physics).
	await _physics_frames(2)
	var wide: PackedVector2Array = _render.polygon

	var err := _check_fan(wide, "angle 90")
	if err.is_empty():
		_cone.angle_deg = 45
		await _physics_frames(2)
		var narrow: PackedVector2Array = _render.polygon
		var span_wide := _span_deg(wide)
		var span_narrow := _span_deg(narrow)
		if narrow.size() <= 3:
			err = "angle 45: polygon has %d points" % narrow.size()
		elif not _all_finite(narrow):
			err = "angle 45: non-finite polygon point"
		elif span_narrow < HALF_ANGLE_DEG or span_narrow > span_wide * 0.75:
			err = "angle 45: span %.1f deg, expected ~45 (was %.1f)" % [span_narrow, span_wide]
		else:
			# Kangur patch: ray_count = 0 must not yield NaN points.
			_cone.ray_count = 0
			await _physics_frames(2)
			if not _all_finite(_render.polygon):
				err = "ray_count 0: non-finite polygon point"
			else:
				err = await _check_origin_offset()
			if err.is_empty():
				print("PROBE_OK points=%d span90=%.1f span45=%.1f" % [wide.size(), span_wide, span_narrow])
				get_tree().quit(0)
				return

	print("PROBE_FAIL %s" % err)
	get_tree().quit(1)


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Kangur patch 4: origin_offset moves the whole wedge (apex included), not just the far arc.
func _check_origin_offset() -> String:
	var offset := Vector2(0, 60)
	_cone.origin_offset = offset
	_cone.angle_deg = 90
	_cone.ray_count = 30
	await _physics_frames(2)
	var pts: PackedVector2Array = _render.polygon
	if not _all_finite(pts) or pts.size() <= 3:
		return "origin_offset: bad polygon (%d pts)" % pts.size()
	if pts[0].distance_to(offset) > 0.01 or pts[pts.size() - 1].distance_to(offset) > 0.01:
		return "origin_offset: apex %s, expected %s" % [str(pts[0]), str(offset)]
	return ""


func _check_fan(pts: PackedVector2Array, label: String) -> String:
	if pts.size() <= 3:
		return "%s: polygon has %d points" % [label, pts.size()]
	if not _all_finite(pts):
		return "%s: non-finite polygon point" % label
	var max_y := -INF
	for p in pts:
		max_y = maxf(max_y, p.y)
	if max_y >= WALL_Y:
		return "%s: point at y=%.1f reached past the wall" % [label, max_y]
	return ""


func _all_finite(pts: PackedVector2Array) -> bool:
	for p in pts:
		if not p.is_finite():
			return false
	return true


## Angular width of the fan around local +Y (the addon's facing convention).
func _span_deg(pts: PackedVector2Array) -> float:
	var lo := INF
	var hi := -INF
	for p in pts:
		if p.length_squared() < 1.0:
			continue  # wedge apex / closing points
		var a := rad_to_deg(atan2(p.x, p.y))
		lo = minf(lo, a)
		hi = maxf(hi, a)
	return hi - lo