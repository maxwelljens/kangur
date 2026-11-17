class_name BlockoutDef
extends Resource
## Blockout spec consumed by `tools/build_map.gd`. Tile coordinates, origin
## top-left, 1 tile = 32 px; format and specs: `docs/design/maps.md`.
## The generated `map.tscn` is what ships — this resource is the layout source
## of truth for the builder and stays small enough to review.

@export var id: StringName = &""
@export var size: Vector2i = Vector2i(80, 64)
## Open floor. `{x, y, w, h, surface: String}` (surface = Enums.Surface name).
@export var carve: Array[Dictionary] = []
## Solid geometry, painted into the Walls layer.
## `{x, y, w, h, material: String, low_cover: bool[, penetrable: bool]}`
## material: concrete_block | brick | container | glass. Low-cover blocks set
## `"cover": "crate" | "sandbag" | "car"` to pick the prop tile.
@export var blocks: Array[Dictionary] = []
## Spawn areas. `{team, x, y, w, h, count}` (team = Enums.Team).
@export var spawn_rects: Array[Dictionary] = []
## AI lane hints. `{id: StringName, from: Vector2i, to: Vector2i}`.
@export var lanes: Array[Dictionary] = []
## Battle objectives. `{id, order, x, y, w, h, capture_time}`.
@export var objectives: Array[Dictionary] = []

const MATERIALS: Array[String] = ["concrete_block", "brick", "container", "glass"]
const COVER_KINDS: Array[String] = ["crate", "sandbag", "car"]

## Throws (assert) on a malformed spec: the builder is a trust boundary and a
## silent typo here would ship an unplayable map.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if size.x <= 0 or size.y <= 0:
		errors.append("size must be positive")
	if carve.is_empty():
		errors.append("carve is empty")
	for rect: Dictionary in carve:
		_check_rect(errors, rect, "carve")
		if not Tiles.SURFACE_NAMES.has(StringName(str(rect.get("surface", "")))):
			errors.append("carve %s: bad surface '%s'" % [rect, rect.get("surface", "")])
	for rect: Dictionary in blocks:
		_check_rect(errors, rect, "blocks")
		var material := str(rect.get("material", ""))
		if not MATERIALS.has(material):
			errors.append("block %s: bad material '%s'" % [rect, material])
		if bool(rect.get("low_cover", false)) and not COVER_KINDS.has(str(rect.get("cover", "crate"))):
			errors.append("block %s: bad cover kind" % rect)
	for rect: Dictionary in spawn_rects:
		_check_rect(errors, rect, "spawn")
		if int(rect.get("count", 0)) <= 0:
			errors.append("spawn %s: count must be > 0" % rect)
		if not Enums.Team.values().has(int(rect.get("team", -1))):
			errors.append("spawn %s: bad team" % rect)
	for rect: Dictionary in objectives:
		_check_rect(errors, rect, "objective")
		if str(rect.get("id", "")).is_empty():
			errors.append("objective %s: id is empty" % rect)
	return errors

func _check_rect(errors: Array[String], rect: Dictionary, what: String) -> void:
	for key: String in ["x", "y", "w", "h"]:
		if not rect.has(key) or not (rect[key] is int):
			errors.append("%s %s: '%s' must be an int" % [what, rect, key])
			return
	if int(rect["w"]) <= 0 or int(rect["h"]) <= 0:
		errors.append("%s %s: w/h must be > 0" % [what, rect])
		return
	if int(rect["x"]) < 0 or int(rect["y"]) < 0 \
			or int(rect["x"]) + int(rect["w"]) > size.x \
			or int(rect["y"]) + int(rect["h"]) > size.y:
		errors.append("%s %s: outside map %s" % [what, rect, size])

static func rect(entry: Dictionary) -> Rect2i:
	return Rect2i(int(entry["x"]), int(entry["y"]), int(entry["w"]), int(entry["h"]))