extends CanvasLayer
## FogOverlay — CS2D-style fog of war (design §5).
##
## Technique (pieces verified on 4.7.2 GL Compatibility):
##  * `FogMask`: a half-res SubViewport, cleared and repainted every frame with
##    the player's cone polygon + peripheral disc (white on black), then smoke
##    punched out as black discs. Both teams are blinded by the same geometry.
##  * `MemoryMask`: explored terrain is a coarse CPU grid (EXPLORE_CELL px per
##    cell) baked into an ImageTexture that only ever gains pixels. A second
##    SubViewport was rejected: render-target accumulation (CLEAR_MODE_NEVER /
##    ONCE) does not persist on this renderer (verified by probe), and the grid
##    is both renderer-independent and cheaper than a per-frame full-map pass.
##  * One world-space ColorRect in a `follow_viewport_enabled` CanvasLayer
##    multiplies the world by the sampled brightness (fog.gdshader, blend_mul):
##    visible 1.0, explored memory 0.35, unknown 0.08 (~92% dark).
##  * Headless: nothing is created (no viewport texture, tech §6.2); gating
##    logic lives in VisionSystem and keeps running.
##
## Perf: the raycast fan is in VisionSystem (30 rays @ 10 Hz). Here: one
## half-res polygon pass + one 32px-cell ImageTexture update only when new
## ground is discovered + one full-screen multiply. No CollisionPolygon2D
## (addons.md §1.7: it costs ~5× the fan).

const FOG_SHADER: Shader = preload("res://src/vision/fog.gdshader")

## Mask texels per world px. Half resolution by design (research §1.7 budget).
const MASK_SCALE := 0.5
## Cap so a huge map cannot allocate an absurd render target.
const MAX_MASK_PX := 2048
const SMOKE_SLOTS := 8
const CIRCLE_SEGMENTS := 20
## Explored-memory resolution in world px per cell (coarse: memory, not sight).
const EXPLORE_CELL := 24.0

## Brightness of remembered-but-not-visible terrain.
const EXPLORED_LEVEL := 0.35
## Brightness of never-seen terrain (1.0 - 0.92 as designed).
const UNEXPLORED_LEVEL := 0.08

var _bounds: Rect2 = Rect2()
var _scale: float = MASK_SCALE
var _mask_vp: SubViewport = null
var _mask_root: Node2D = null
var _cone_poly: Polygon2D = null
var _disc_poly: Polygon2D = null
var _smoke_cutouts: Array[Polygon2D] = []

var _memory_image: Image = null
var _memory_texture: ImageTexture = null
var _memory_size: Vector2i = Vector2i.ZERO
var _memory_dirty: bool = false
var _memory_cells: Dictionary[Vector2i, bool] = {}

var _fog_rect: ColorRect = null
var _enabled: bool = false


## `bounds` is the map rect in world px (World.bounds()).
func setup(bounds: Rect2) -> void:
	_bounds = bounds
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	# Headless has no viewport texture and never emits frame_post_draw (tech §6.2).
	if DisplayServer.get_name() == "headless":
		return
	_scale = minf(MASK_SCALE, minf(float(MAX_MASK_PX) / bounds.size.x,
		float(MAX_MASK_PX) / bounds.size.y))
	var mask_size := Vector2i(maxi(int(bounds.size.x * _scale), 1),
		maxi(int(bounds.size.y * _scale), 1))
	_build_mask(mask_size)
	_build_memory()
	_build_fog_rect(mask_size)
	_enabled = true


## Player-visible polygons in world space (cone + wall-clipped peripheral disc).
## Called at the cone refresh rate (10 Hz by default), not per frame.
func set_visible_shape(cone_world: PackedVector2Array,
		disc_world: PackedVector2Array) -> void:
	if not _enabled:
		return
	_cone_poly.polygon = cone_world
	_disc_poly.polygon = disc_world
	_remember(cone_world, disc_world)


## [{pos: Vector2, radius: float}] — current smoke clouds, both teams.
func set_smoke(circles: Array[Dictionary]) -> void:
	if not _enabled:
		return
	for i: int in _smoke_cutouts.size():
		var cutout := _smoke_cutouts[i]
		if i >= circles.size():
			cutout.visible = false
			continue
		var cloud: Dictionary = circles[i]
		cutout.position = cloud[&"pos"]
		cutout.polygon = circle_points(Vector2.ZERO, float(cloud[&"radius"]))
		cutout.visible = true


## True when the fog layer is actually rendering (false headless).
func is_rendering() -> bool:
	return _enabled


## Explored-memory cell count (tests + debug introspection).
func explored_cells() -> int:
	return _memory_cells.size()


## Pure polygon helper shared with the smoke cutouts and the debug overlay.
static func circle_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in CIRCLE_SEGMENTS:
		var angle := TAU * float(i) / float(CIRCLE_SEGMENTS)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _build_mask(size: Vector2i) -> void:
	_mask_vp = SubViewport.new()
	_mask_vp.name = "FogMask"
	_mask_vp.size = size
	_mask_vp.transparent_bg = false
	_mask_vp.disable_3d = true
	# Cleared and fully repainted from CPU geometry every frame: never relies
	# on render-target accumulation, which does not persist on GL Compatibility.
	_mask_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_mask_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_mask_vp.gui_disable_input = true
	add_child(_mask_vp)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(size)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask_vp.add_child(bg)
	_mask_root = Node2D.new()
	_mask_root.position = -_bounds.position * _scale
	_mask_root.scale = Vector2(_scale, _scale)
	_mask_vp.add_child(_mask_root)
	_cone_poly = _shape_poly(Color.WHITE)
	_mask_root.add_child(_cone_poly)
	_disc_poly = _shape_poly(Color.WHITE)
	_mask_root.add_child(_disc_poly)
	for _i: int in SMOKE_SLOTS:
		var cutout := _shape_poly(Color.BLACK)
		cutout.visible = false
		_mask_root.add_child(cutout)
		_smoke_cutouts.append(cutout)


func _build_memory() -> void:
	_memory_size = Vector2i(maxi(int(ceil(_bounds.size.x / EXPLORE_CELL)), 1),
		maxi(int(ceil(_bounds.size.y / EXPLORE_CELL)), 1))
	_memory_image = Image.create_empty(_memory_size.x, _memory_size.y, false,
		Image.FORMAT_L8)
	_memory_image.fill(Color.BLACK)
	_memory_texture = ImageTexture.create_from_image(_memory_image)


## Marks every unexplored cell whose centre the player has now seen. Only new
## cells touch the image, so this is a no-op on most refreshes.
func _remember(cone_world: PackedVector2Array, disc_world: PackedVector2Array) -> void:
	for poly: PackedVector2Array in [cone_world, disc_world]:
		if poly.size() < 3:
			continue
		var rect := _bounds_of(poly)
		var lo := Vector2i((rect.position / EXPLORE_CELL).floor())
		var hi := Vector2i((rect.end / EXPLORE_CELL).ceil())
		for y: int in range(lo.y, hi.y + 1):
			for x: int in range(lo.x, hi.x + 1):
				if x < 0 or y < 0 or x >= _memory_size.x or y >= _memory_size.y:
					continue
				var key := Vector2i(x, y)
				if _memory_cells.has(key):
					continue
				var center := (Vector2(key) + Vector2(0.5, 0.5)) * EXPLORE_CELL
				if not Geometry2D.is_point_in_polygon(center, poly):
					continue
				_memory_cells[key] = true
				_memory_image.set_pixel(x, y, Color.WHITE)
				_memory_dirty = true
	if _memory_dirty:
		_memory_texture.update(_memory_image)
		_memory_dirty = false


func _build_fog_rect(mask_size: Vector2i) -> void:
	layer = 1  # above the world, below vision markers (2) and the HUD (10)
	follow_viewport_enabled = true
	var material := ShaderMaterial.new()
	material.shader = FOG_SHADER
	material.set_shader_parameter(&"cone_mask", _mask_vp.get_texture())
	material.set_shader_parameter(&"explored_mask", _memory_texture)
	material.set_shader_parameter(&"mask_origin", _bounds.position)
	material.set_shader_parameter(&"mask_size", _bounds.size)
	material.set_shader_parameter(&"memory_origin", _bounds.position)
	material.set_shader_parameter(&"memory_size",
		Vector2(_memory_size) * EXPLORE_CELL)
	material.set_shader_parameter(&"rect_pos", _bounds.position)
	material.set_shader_parameter(&"rect_size", _bounds.size)
	material.set_shader_parameter(&"explored_level", EXPLORED_LEVEL)
	material.set_shader_parameter(&"unexplored_level", UNEXPLORED_LEVEL)
	# Blur radius in world px, expressed in mask texels of the actual scale.
	material.set_shader_parameter(&"soft_texels", 3.0 / maxf(_scale, 0.01))
	_fog_rect = ColorRect.new()
	_fog_rect.name = "FogRect"
	_fog_rect.material = material
	_fog_rect.position = _bounds.position
	_fog_rect.size = _bounds.size
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fog_rect)
	# Keep the texture sampler bound to the live mask viewport.
	material.set_shader_parameter(&"cone_mask", _mask_vp.get_texture())


func _shape_poly(color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	poly.antialiased = false
	return poly


func _bounds_of(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		rect = rect.expand(p)
	return rect