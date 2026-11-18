extends RefCounted
## Weapon silhouette geometry, shared by the rig (what gets drawn) and Arsenal
## (where the bullet leaves) so the visual muzzle IS the ballistic muzzle.
## Authored `WeaponDef` visual params (art-direction §1) win; a def still carrying
## the schema defaults predates them and falls back to its `category`.

## Rear of the receiver, rig-local X. Also the hand grip position and the start
## of the ballistic muzzle measurement, so drawing and shot origin agree.
const GRIP_X := 8.0
## `WeaponDef` schema defaults (weapon_def.gd). Matching the whole tuple means
## nothing visual was authored: fall back to the category table.
const SCHEMA_GEOMETRY := Vector4(14.0, 10.0, 3.5, 6.0)  # body, barrel, width, mag
const SCHEMA_FEATURES := Vector2(2.0, 5.0)              # mag offset, stock
## x = body_len, y = barrel_len, z = receiver width, w = magazine length.
const CATEGORY_GEOMETRY: Dictionary[StringName, Vector4] = {
	&"pistol": Vector4(7.0, 3.0, 3.2, 3.0),
	&"smg": Vector4(9.0, 5.0, 4.0, 4.5),
	&"ar": Vector4(12.0, 7.0, 4.4, 5.0),
	&"br": Vector4(13.0, 9.0, 4.6, 5.0),
	&"dmr": Vector4(14.0, 11.0, 4.6, 4.0),
	&"sniper": Vector4(15.0, 14.0, 4.8, 3.0),
	&"lmg": Vector4(15.0, 9.0, 5.4, 6.0),
	&"shotgun": Vector4(13.0, 10.0, 5.0, 2.0),
}
## x = stock length, y = scope length (0 = none).
const CATEGORY_FEATURES: Dictionary[StringName, Vector2] = {
	&"pistol": Vector2(0.0, 0.0),
	&"smg": Vector2(3.0, 0.0),
	&"ar": Vector2(5.0, 0.0),
	&"br": Vector2(5.0, 3.0),
	&"dmr": Vector2(5.0, 4.0),
	&"sniper": Vector2(5.0, 5.0),
	&"lmg": Vector2(5.0, 0.0),
	&"shotgun": Vector2(4.0, 0.0),
}
const DEFAULT_CATEGORY := &"ar"
const WEIGHT_REF := 3.5
const WIDTH_PER_KG := 0.25
const WIDTH_DELTA_MAX := 1.0
const MIN_WIDTH := 2.0
## Magazine well forward of the grip when the def does not author one.
const DEFAULT_MAG_OFFSET := 2.0
## Optic length drawn when `has_scope` is set (has_scope is a bool, not a length).
const SCOPE_LEN := 5.0
## Fallback gunmetal for defs with no authored colour (same tone the rig used
## before visual params existed: readable against both floor tints).
const GUNMETAL := Color(0.38, 0.40, 0.43)

## Drawn silhouette parameters for `def` (never null-safe-hostile).
## Keys: body_len, barrel_len, width, mag_len, mag_offset, stock, scope, color.
static func profile(def: WeaponDef) -> Dictionary:
	if def == null:
		return _geometry(DEFAULT_CATEGORY, WEIGHT_REF)
	if not _authored(def):
		var key: StringName = def.category if CATEGORY_GEOMETRY.has(def.category) \
			else DEFAULT_CATEGORY
		return _geometry(key, def.weight)
	return {
		&"body_len": def.body_len,
		&"barrel_len": def.barrel_len,
		&"width": maxf(MIN_WIDTH, def.body_width),
		&"mag_len": def.mag_len,
		&"mag_offset": def.mag_offset,
		&"stock": def.stock_len,
		&"scope": SCOPE_LEN if def.has_scope else 0.0,
		&"color": def.gun_color,
	}

## Distance from the character centre to the barrel tip, pixels.
static func muzzle_len(def: WeaponDef) -> float:
	var p := profile(def)
	return GRIP_X + float(p[&"body_len"]) + float(p[&"barrel_len"])

## True when the def overrides any of the schema's visual defaults.
static func _authored(def: WeaponDef) -> bool:
	return Vector4(def.body_len, def.barrel_len, def.body_width, def.mag_len) \
			!= SCHEMA_GEOMETRY \
		or Vector2(def.mag_offset, def.stock_len) != SCHEMA_FEATURES \
		or def.has_scope

static func _geometry(category: StringName, weight: float) -> Dictionary:
	var geometry: Vector4 = CATEGORY_GEOMETRY[category]
	var features: Vector2 = CATEGORY_FEATURES[category]
	var width := maxf(MIN_WIDTH, geometry.z + clampf(
		(weight - WEIGHT_REF) * WIDTH_PER_KG, -WIDTH_DELTA_MAX, WIDTH_DELTA_MAX))
	return {
		&"body_len": geometry.x,
		&"barrel_len": geometry.y,
		&"width": width,
		&"mag_len": geometry.w,
		&"mag_offset": DEFAULT_MAG_OFFSET,
		&"stock": features.x,
		&"scope": features.y,
		&"color": GUNMETAL,
	}