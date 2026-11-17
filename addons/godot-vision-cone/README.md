# Vision Cone 2D — vendored, locally patched

Upstream: <https://github.com/d-bucur/godot-vision-cone>, commit
`5c98f7551868c40c9d1465a28d58e4b1838d13bb` (2025-08-06, `main`).
License: Apache-2.0 **or** MIT at your option; both files kept here. Kangur uses MIT.
Keep this folder's `.gd` filenames and `.uid` files together — `vision_cone_2d_template.tscn`
resolves them by UID. Folder was renamed from upstream `vision_cone_2d/`; the template's
`path=` strings were updated to match.

Vendored: all 9 runtime/template/license files from the research manifest, including `icon.png`
(upstream only used it for its own demo; nothing here references it, but it keeps the folder a
clean upstream subset). Not vendored: `examples/` — it hardcodes `res://addons/vision_cone_2d/…`
paths and UIDs that cannot resolve under the renamed folder.

## Facing convention: local +Y (down), unchanged from upstream

The cone bisector is local **+Y**, not Godot's usual +X. This is upstream behaviour and has
deliberately *not* been patched (patched facing would diverge from upstream maths and issue #6).

Consumers must rotate by **`aim_angle - PI / 2`** to make the cone point along a world-space
aim direction:

```gdscript
cone.rotation = aim_dir.angle() - PI / 2.0   # +Y cone -> +X aim
```

`cone_editor_helper.gd` draws its editor preview along +Y too, so the preview agrees.
Do not parent a cone under a flip-able sprite node: `scale` is ignored by design (upstream #2).

## Local patches (marked inline with `# Kangur patch:`)

1. **Live FOV** — `_angle`/`_angle_half`/`_angular_delta` were `@onready` constants (frozen at
   `_ready()`); they are now recomputed by `_refresh_angles()` at the top of
   `calculate_vision_shape()`. `angle_deg` and `ray_count` are runtime-settable (stance/focus cones).
2. **`ray_count` guard** — `maxi(ray_count, 1)` before dividing; upstream produced `NaN` points and
   an infinite angular delta at `ray_count = 0`.
3. **Collision mask default = 1** — Kangur's WORLD layer. Upstream defaulted to `0` (sees through
   everything) and its template hardcoded `2`. Template now also stores `1`.
4. **`origin_offset`** — new `@export var origin_offset: Vector2`, used as the ray start
   (`to_global(origin_offset)`) and as the wedge apex; upstream had a `# TODO add offset to origin`
   and always started at the node origin. Leaving the apex at `Vector2.ZERO` would put a spike back
   to the node origin, so both closing points use `origin_offset`.

Not patched: `scale` handling (upstream wontfix), naive uniform fan (corners between rays are
rounded — display only, never use the polygon for hit determination), per-cone cost
(~0.133 ms per 50 rays per cone).

`plugin.cfg` is present but this plugin is a no-op: `class_name VisionCone2D` is why the node type
exists. Do not enable it in `[editor_plugins]`.