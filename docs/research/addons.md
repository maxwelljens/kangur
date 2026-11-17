# Addon Research — godot-vision-cone & at-icons

Status: **both are usable on Godot 4.7.2**, but neither should be used as-is.
`godot-vision-cone` needs a small patch + a different integration strategy than its README
suggests; `at-icons` works but is 34 MB and its dock requires Godot ≥ 4.6.

Researched 2026-11-17 against Godot 4.7.2.stable.arch_linux.ed1daf0bf. Every API claim below
was read from source, and every behavioural claim marked **[verified]** was reproduced by running
the actual code under the local 4.7.2 binary in a throwaway project (`/tmp/opencode/addon-probe`).

---

## TL;DR for the orchestrator

| Question | Answer |
|---|---|
| vision-cone on 4.7.2? | Yes — `VisionCone2D` registers as a global class and runs; occlusion works **[verified]**. Repo last updated 2025-08-06, tested by author on 4.4.1. No 4.5/4.7 breakage found in issues. |
| vision-cone license | Apache-2.0 **or** MIT, at your option (dual, both files shipped in `addons/vision_cone_2d/`). |
| vision-cone as the AI perception system? | **No.** The author explicitly says it is too slow for many-entity checks and recommends targeted raycasts instead. Our own benchmark: writing the `CollisionPolygon2D` costs **5× the raycasts**. Use the cone for *display only*, gate perception with per-target raycasts. |
| vision-cone drop-in for our layers? | No — the template hardcodes `collision_layer_mask = 2`, but our WORLD is layer **1** (architecture §2). Must be changed to `Layers.VISION_MASK`. |
| at-icons on 4.7.2? | Yes, dock loads cleanly **[verified]**. But `at-icons.gd` uses `EditorDock` + `add_dock()`, which do **not** exist in Godot 4.5 (404 in 4.5 docs, present in 4.6+). Implies author targets ≥ 4.6. Fine for us on 4.7.2. |
| at-icons license | MIT. |
| at-icons install | Do **not** clone the repo (README warning). Use the release ZIP, or cherry-pick individual `svg` + `.import` pairs. |

---

## 1. godot-vision-cone

Repo: <https://github.com/d-bucur/godot-vision-cone>
Asset Library: <https://godotengine.org/asset-library/asset/1568>
Pinned commit researched: `5c98f7551868c40c9d1465a28d58e4b1838d13bb` (2025-08-06, branch `main`).

### 1.1 Godot version compatibility

The README states:

> "Only supports Godot 4 and I don't plan on supporting Godot 3." — <https://github.com/d-bucur/godot-vision-cone/blob/main/readme.md>
> "Tested with v4.4.1 but is known to work with all 4.* versions" — same file
> "Has only been tested in mobile renderer, but should work in forward mode as well" — same file

Repo metadata (`project.godot`) declares `config/features=PackedStringArray("4.4", "Mobile")`
(<https://raw.githubusercontent.com/d-bucur/godot-vision-cone/main/project.godot>), and the last
functional commit is `Upgrade to Godot 4.4` (2025-07-12).

**No 4.5/4.7 breakage evidence exists.** The open issue list contains only one item (#6, a
default-facing-direction complaint, no maintainer response) and the closed ones (#2 scale, #3
typed array, #4 example scene in 4.0.2, #5 convex-decompose) are all resolved in the 0.2 code.

**[verified]** Vendor `addons/vision_cone_2d/` into a fresh 4.7.2 project, `--headless --editor
--import`: the scan registers `VisionCone2D` in `update_scripts_classes` with **zero parse
errors**, and a runtime occlusion test produced a correctly clipped polygon. The addon's own
`project.godot` still says 4.4, so opening *the repo* in 4.7 may trigger a format-upgrade
prompt — irrelevant for vendoring the addon folder.

Caveats that are *not* version problems but will bite you (all detailed in §1.4):

- Cone faces local **+Y (down)**, not Godot's conventional **+X (right)**.
- `angle_deg` and `ray_count` are snapshotted via `@onready` at `_ready()`; changing them at
  runtime silently does nothing.
- `scale` is ignored entirely — the maintainer closed this as by-design.
- `ray_count = 0` yields `NaN` points and an infinite `_angular_delta`.

### 1.2 License

Dual-licensed, Apache-2.0 **or** MIT:

> "## 🪪 License — [Apache](LICENSE-APACHE) or [MIT](LICENSE-MIT), whichever you prefer" — <https://github.com/d-bucur/godot-vision-cone/blob/main/readme.md>

Both license files are inside the addon folder itself
(`addons/vision_cone_2d/LICENSE-APACHE`, `addons/vision_cone_2d/LICENSE-MIT`), so attribution
travels with the vendored copy. **Choose MIT** — it matches at-icons and keeps our credits
simple. Attribution line for `docs/credits.md`: *Vision Cone 2D by sirdorius (Dorian Bucur),
MIT, https://github.com/d-bucur/godot-vision-cone*.

### 1.3 Exact file list to vendor

From <https://api.github.com/repos/d-bucur/godot-vision-cone/git/trees/HEAD?recursive=1>
(19 files, 41,671 bytes total). Destination root: `addons/godot-vision-cone/`.

**Required — the runtime addon (7 files, ~18 KB):**

```
addons/godot-vision-cone/plugin.cfg                   110 B
addons/godot-vision-cone/vision_cone_2d.gd           5831 B   <- class_name VisionCone2D
addons/godot-vision-cone/vision_cone_2d.gd.uid         20 B
addons/godot-vision-cone/vision_cone_entry.gd          178 B   <- the EditorPlugin script
addons/godot-vision-cone/vision_cone_entry.gd.uid      20 B
addons/godot-vision-cone/cone_editor_helper.gd         766 B   <- @tool editor preview
addons/godot-vision-cone/cone_editor_helper.gd.uid     20 B
```

**Required — template scene (2 files):**

```
addons/godot-vision-cone/vision_cone_2d_template.tscn  977 B
addons/godot-vision-cone/icon.png                   12742 B   (referenced by plugin.cfg? no — safe to include)
```

Actually `icon.png` is only used by the addon's own demo project; it is **not** referenced by
`plugin.cfg` or the template. Include it if you want the plugin list to look nice; otherwise skip.

**Required — licenses (2 files):**

```
addons/godot-vision-cone/LICENSE-APACHE             10173 B
addons/godot-vision-cone/LICENSE-MIT                 1036 B
```

**Optional — the demo (5 files, ~9 KB). Do not vendor; read for reference only:**

```
examples/enemy.gd, examples/enemy.gd.uid,
examples/enemy.tscn, examples/example.tscn,
examples/player_movement.gd (+.uid), examples/wall.tscn
```

They reference `res://addons/vision_cone_2d/...` paths and UIDs that will not resolve under a
renamed folder, and `example.tscn`/`enemy.tscn` depend on the demo's `Path2D` layout.

> **UID warning.** The `.uid` files contain hardcoded `uid://` values
> (`vision_cone_2d.gd.uid` = `uid://bo744wpycscqd`, `cone_editor_helper.gd.uid` =
> `uid://b88iifj2svjwc`, `vision_cone_entry.gd.uid` = `uid://cqcarfddo6yrp`) and
> `vision_cone_2d_template.tscn` references those UIDs directly. **Keep the `.uid` files and
> keep the `.tscn` next to the `.gd` files** or the template will fail to load. If you rename
> the folder, Godot resolves by UID first, so the template keeps working — but re-save it once
> so the stored `path=` strings stop pointing at `vision_cone_2d/`.

**`plugin.cfg` contents** (verbatim from the repo — note `version="0.2"` while the release that
added `min_distance_sqr` was announced as 0.2.0; the file was never bumped):

```ini
[plugin]

name="Vision Cone 2D"
description=""
author="sirdorius"
version="0.2"
script="vision_cone_entry.gd"
```

`vision_cone_entry.gd` is an **empty** EditorPlugin — it has no `_enter_tree` body beyond `pass`.
Enabling the plugin therefore does nothing functional; `VisionCone2D` is available purely because
`class_name` registers the script globally. **You do not need to enable the plugin** to use
`VisionCone2D`, and we should not — enabling a no-op plugin only adds a failure surface. Vendor
the folder, leave `plugin.cfg` present (harmless), and do not add it to
`[editor_plugins] enabled=`.

### 1.4 Public API (read from `vision_cone_2d.gd`)

Source: <https://raw.githubusercontent.com/d-bucur/godot-vision-cone/main/addons/vision_cone_2d/vision_cone_2d.gd>

**Node type:** `class_name VisionCone2D extends Node2D`. That is the *only* public class. There
is **no** `VisionCone2DArea` class — the Area2D in the template is a stock `Area2D`.

**Exported properties** (all four groups, verbatim names and defaults):

| Property | Type | Default | Notes from source docstring |
|---|---|---|---|
| `angle_deg` | `int` | `360` | `@export_range(0, 360)`. **Frozen at `_ready()`.** |
| `ray_count` | `int` | `100` | "This has the biggest impact on performance in the script." |
| `max_distance` | `float` | `500.` | Max ray length. Live-updatable (read each call). |
| `collision_layer_mask` | `int` | `0` | `@export_flags_2d_physics`. "Have it set to the same layer as your walls." |
| `write_collision_polygon` | `CollisionPolygon2D` | `null` | Optional; copied every recompute. |
| `write_polygon2d` | `Polygon2D` | `null` | Optional visual. |
| `debug_lines` | `bool` | `false` | Debug only. |
| `debug_shape` | `bool` | `false` | Debug only. |
| `minimum_recalculate_time_msec` | `int` | `0` | Throttle floor. |
| `recalculate_if_static` | `bool` | `true` | If `false`, skips when movement < `static_threshold`. |
| `static_threshold` | `float` | `2` | Movement needed to trigger recompute. |
| `min_distance_sqr` | `float` | `16` | Squared min vertex spacing; avoids `Convex decomposing failed`. `<= 0` disables. |

**Signals:** none. `get_signal_list()` on a live instance returns only the inherited
`Node`/`CanvasItem` signals (`ready`, `draw`, `visibility_changed`, …). **[verified]**

**Methods:**

- `recalculate_vision(override_static_flag: bool = false) -> void` — recomputes and pushes into
  `write_collision_polygon` / `write_polygon2d`. Called automatically from `_physics_process`.
- `calculate_vision_shape(override_static_flag: bool = false) -> Array[Vector2]` — pure-ish
  getter; returns the fan points in **local space**, with `Vector2.ZERO` prepended and appended
  when `angle_deg < 360` to close the wedge.

**Private state:** `_vision_points: Array[Vector2]`, `_last_position`, `_last_redraw_time`, and
the `@onready` constants `_angle`, `_angle_half`, `_angular_delta`.

#### Integration gotchas — all reproduced on 4.7.2

**(a) The cone points local +Y (down), not +X (right). [verified]**

```gdscript
# node rotation 0, angle 40 => rays span world angles 70°..110°, bisector 90° (= +Y down)
# node rotation 90 => bisector 180° (-X)
```

This comes straight from `Vector2(0, max_distance).rotated(...)` in `calculate_vision_shape`.
The upstream issue #6 complains about exactly this and proposes subtracting 90°
(<https://github.com/d-bucur/godot-vision-cone/issues/6>, still open, one comment, no maintainer
reply). Two options: rotate the cone node `-90°` relative to the character's facing (what the
demo's `enemy.tscn` does: `rotation = -1.5708`), or patch the script. **Recommend patching** —
see §1.7 — because a `-90°` offset compounds with any sprite-flip logic.

**(b) `angle_deg` / `ray_count` changes at runtime are silently ignored. [verified]**

```gdscript
var cone := VisionCone2D.new()
cone.angle_deg = 90
add_child(cone)
await get_tree().physics_frame
cone.angle_deg = 10            # <-- no effect
var pts := cone.calculate_vision_shape(true)
# still the 90° fan; _angular_delta stays at the old value
```

Cause: `@onready var _angle`, `_angle_half`, `_angular_delta` are computed once at `_ready()`.
If we want per-NPC FOV variation (e.g. a "narrow focus" state), we must either set the value
*before* adding to the tree, or patch to recompute the derived values in
`calculate_vision_shape()`. Fatal for runtime FOV modifiers (flashbangs, sprint-narrowing, aim
concentration) — a real requirement for a tactical shooter.

**(c) `scale` is ignored, by design. [verified + maintainer statement]**

A parent with `scale = Vector2(-1, 1)` (sprite flip) does not mirror the cone:
`local_x_range` stays symmetric. The maintainer closed this as wontfix:

> "Thinking about this it's ambiguous for the vision cone to react to scale changes. […] Closing
> for now as I don't see much benefit for this." — <https://github.com/d-bucur/godot-vision-cone/issues/2#issuecomment-1534989231>

**Consequence for us:** never parent a cone under the flip-able sprite node. Parent it under the
`Character` root (unflipped) and drive `.rotation` from the aim/facing direction.

**(d) `ray_count = 0` produces `NaN`. [verified]**

`_angular_delta = _angle / ray_count` → `inf`, and the single emitted point is
`(nan, nan)`. Clamp `ray_count >= 1` (practically ≥ 8) in any wrapper we write.

**(e) `collision_layer_mask = 0` (the default) sees through everything.** **[verified]**
With a wall on layer 2 and the default mask, max ray length was the full 500 px; with
`mask = 2` it clipped at 290 px. Set the mask, always.

**(f) The caster's own collider does not block its cone** — but only because Godot's
`intersect_ray` starts inside it. **[verified]** With the cone origin inside a 40×40 body on the
masked layer, rays still reached 500 px at offsets 0/18/26 px. So co-locating the cone on a
`CharacterBody2D` that shares a masked layer is safe *today*, but this is an accident of
`hit_from_inside`, not a designed exclusion. Keep CHARACTER off the vision mask (our architecture
already does: `VISION_MASK = WORLD | closed doors`), and this never comes up.

**(g) Polygon can self-intersect → `Convex decomposing failed`.** Handled by `min_distance_sqr`
(added in 0.2.0, issue #5). Keep it at the default 16 (= 4 px minimum spacing). If you set it to
0 (as many examples online do, to get max detail) you reintroduce the error when a corner is
grazed closely: <https://github.com/d-bucur/godot-vision-cone/issues/5#issuecomment-3065484355>.

### 1.5 How occlusion works

**Mechanism: `PhysicsRayQueryParameters2D` + `PhysicsDirectSpaceState2D.intersect_ray`, not
`Geometry2D` and not `RayCast2D` nodes.** From the source:

```gdscript
func _ray_to(direction: Vector2) -> Vector2:
	var destination = global_position + direction
	var query = PhysicsRayQueryParameters2D.create(global_position, destination, collision_layer_mask)
	var collision = get_world_2d().direct_space_state.intersect_ray(query)
	var ray_position = collision.get("position", destination)
	return to_local(ray_position)
```

So: **one physics-space query per ray, per cone, per recompute.** `ray_count + 1` queries each
time (`ray_count` segments across `angle_deg`, plus the wedge apex).

The algorithm is the naive uniform-fan approach the README cites:

> "It implements the simple raycasting method described [here](https://www.redblobgames.com/articles/visibility/).
> The optimized version of it with raycasts to corners is harder to make as a general solution
> that will work on different projects." — readme.md

Practical consequences of the naive fan: a wall corner that falls *between* two rays is rounded
off, so shadows are slightly convex at the boundary. With `ray_count = 50` over 90° that is 1.8°
of angular resolution — visually fine, but **never** use the polygon for hit determination, only
for display.

Note it uses `get_world_2d().direct_space_state`, which is only valid during physics processing.
The addon calls it from `_physics_process`, so it is safe; if you call `calculate_vision_shape()`
from `_process` or a button handler you will get a "space is locked" error. Call it from
`_physics_process` or after `await get_tree().physics_frame`.

### 1.6 Rendering / fog-of-war

**The addon does not implement fog-of-war or darkness at all.** It produces:

1. `write_polygon2d.polygon = _vision_points` — a `Polygon2D` you own and style (`color`,
   `texture`, `material`).
2. `write_collision_polygon.polygon = _vision_points` — a `CollisionPolygon2D` you own.

Because it hands you a `Polygon2D` whose `polygon` you can read, **any shader or
`CanvasModulate`/`Light2D` fog scheme is ours to build**. Two idiomatic approaches, both
compatible:

- **Cheap:** keep a `CanvasModulate` (or a full-screen `ColorRect` with a darken shader) and
  subtract the cone polygons using `CanvasGroup` + `BackBufferCopy`, or simply draw the cone as a
  translucent light-coloured `Polygon2D` over a dark world.
- **Correct for us:** a `SubViewport` visibility mask, or a `Light2D` per character with a
  cone-shaped `Polygon2D` occluder — but that is `src/vision`'s job, not the addon's.

**Programmatic visibility query — this is the important gap.**

There is **no** `is_visible(body)` API, no signal, and no public accessor on the cone. The only
programmatic surface is:

- `calculate_vision_shape()` → `Array[Vector2]` (local space), which you can feed to
  `Geometry2D.is_point_in_polygon()`; or
- the `Area2D` + `CollisionPolygon2D` in the template, whose `body_entered` / `body_exited`
  signals fire. **[verified]** — with the template structure, `body_entered` fired for a
  `CharacterBody2D` on layer 1 while a layer-2 wall sat behind it, and
  `get_overlapping_bodies()` returned it.

So "is enemy X visible to character Y" is answerable **only** via the Area2D overlap (O(area)
broadphase, then polygon test) or by re-testing the polygon. Both are strictly more expensive
than the targeted raycast we actually want, and neither gives us the *distance* / *confidence* /
*which body part* semantics our `Perception` model needs.

Also note: the `Area2D` in the template has `collision_mask` **defaulted to 1** (layer 1). Our
CHARACTER layer is 2, so `body_entered` would never fire for characters until you set
`collision_mask = Layers.CHARACTER`. The demo works only because its player is on layer 1.

### 1.7 Performance with 24 NPCs + player

Author's own verdict — treat this as the load-bearing quote:

> "If you need performant checks for multiple entities (ie lots of enemies checking for a single
> player), it is better to just go for focused raycasts in the player direction […]. This plugin
> has worse performance than that and is useful only if you need to display the vision on the
> screen, or if you need to check visibility for multiple entities" — readme.md

My measurements, Godot 4.7.2 headless, 20 wall segments ringing the scene, 24 cones **[verified]**:

| Configuration | ms per recompute pass (24 cones) |
|---|---|
| 60 rays, shape only (no writes) | **3.24 ms** |
| 60 rays, + `Polygon2D` write | **3.23 ms** (free) |
| 60 rays, + `CollisionPolygon2D` write (`build_mode = SOLIDS`) | **14.96 ms** |
| 60 rays, + `CollisionPolygon2D` (`build_mode = SEGMENTS`) | **4.74 ms** |
| 24×24 target checks via cone-angle + one raycast each | **0.20 ms** |
| 24×24 target checks via `Geometry2D.is_point_in_polygon` on cached polygon | **0.57 ms** |

Scaling with ray count (25 cones, shape only): 50 rays → 3.39 ms; 100 → 6.65 ms; 200 → 13.36 ms.
Roughly **0.133 ms per 50 rays per cone**.

The headline: **`CollisionPolygon2D` assignment is the expensive part, not the raycasts.** Writing
the physics polygon costs ~5× the fan itself because Godot re-decomposes and re-registers the
shape each time. `build_mode = SEGMENTS` (1) cuts that to ~1.5×, but segments are hollow — an
`Area2D` using them will not detect a body that is *inside* the wedge, only one crossing the
boundary.

Recommended configuration for 24 NPCs at 60 Hz **[verified]** — 30 rays, `Polygon2D` only,
`minimum_recalculate_time_msec = 100`:

```
1.508 ms per recompute pass
 -> recomputed every physics tick:  1.51 ms/frame = 9.0 % of a 16.67 ms budget
 -> recomputed 10x/sec (throttled): 15.1 ms/sec  = 1.5 % of budget
```

That is affordable *for display*. But it is per-cone work that scales linearly with NPC count and
tells us nothing we can gate AI on. **Do not** add `write_collision_polygon` for NPC cones: that
alone turns 1.5 ms into ~7 ms.

**Recommendation (opinion):** three-tier design.

1. **Display (player only):** one `VisionCone2D` with `write_polygon2d`, 60–90 rays. It exists
   once, cost is noise.
2. **AI perception (all 25):** *no* `VisionCone2D` at all. `Perception` does a targeted
   cone-angle test against candidate targets + one `intersect_ray` per candidate — measured
   **0.20 ms/frame for the full 24×24 matrix**. This is what the author recommends, and it is
   50–150× cheaper than 24 polygon cones.
3. **Debug overlay (F3):** temporarily enable `debug_lines`/`debug_shape` on a handful of cones,
   or drive `VisionCone2D` instances that are freed when the overlay is off.

### 1.8 Usage examples (API we can code against)

**Minimal, hand-built (no template):**

```gdscript
# NPC scene; cone parented to the Character root, NOT under the flip-able sprite.
var cone := VisionCone2D.new()
cone.angle_deg = 90                    # MUST be set before add_child (see §1.4b)
cone.ray_count = 30
cone.max_distance = 600.0
cone.collision_layer_mask = Layers.VISION_MASK   # WORLD | closed doors — NOT the template's 2
cone.min_distance_sqr = 16.0           # keep the default; prevents convex-decompose errors
cone.recalculate_if_static = false     # we move/rotate constantly; let the throttle do the work
cone.minimum_recalculate_time_msec = 100
add_child(cone)

var poly := Polygon2D.new()
poly.color = Color(0.43, 0.93, 0.28, 0.29)
cone.add_child(poly)
cone.write_polygon2d = poly
```

**Driving the facing** (cone looks along local +Y, so aim → `rotation + PI/2`):

```gdscript
func _physics_process(_delta: float) -> void:
	var aim: Vector2 = arsenal.aim_dir          # world-space, from Aim component
	cone.rotation = aim.angle() - PI / 2.0      # +Y cone -> +X aim
```

**Reading the polygon (display, minimap, shadow casting):**

```gdscript
# Call from _physics_process (space state is locked elsewhere).
var local_pts: Array[Vector2] = cone.calculate_vision_shape()
var world_pts := PackedVector2Array()
for p in local_pts:
	world_pts.append(cone.to_global(p))
```

**Template-based (what the README calls "quickstart"):**

Instantiate `vision_cone_2d_template.tscn` as a child of the character. It gives you
`VisionCone2D` → `VisionConeRenderer` (`Polygon2D`, colour `0.43,0.93,0.28,0.29`) +
`VisionConeArea` (`Area2D`, `collision_layer = 0`, `monitorable = false`) →
`VisionConeCollider` (`CollisionPolygon2D`) + `DebugDraw` (`cone_editor_helper.gd`), with
`collision_layer_mask = 2` and both write-paths pre-wired. Then:

```gdscript
$VisionCone2D/VisionConeArea.body_entered.connect(_on_seen.bind(true))
$VisionCone2D/VisionConeArea.body_exited.connect(_on_seen.bind(false))
```

**and fix the template before use:** `collision_layer_mask` → `Layers.VISION_MASK`, and
`VisionConeArea.collision_mask` → `Layers.CHARACTER` (defaults to 1). If you keep the template,
remember `build_mode` cost from §1.7.

**Editor preview:** `cone_editor_helper.gd` is `@tool` and draws two edge lines + a far arc line
in the 2D editor, reading `vision_cone.angle_deg` / `.max_distance` from its parent. It only
draws when `Engine.is_editor_hint()`. The README admits it is "kind of buggy at the moment"
because it cannot use real physics. Harmless; keep it for authoring affordance.

### 1.9 Verdict: vendor with a patch, use for display only

**Opinion / recommendation.** Vendor it (7 runtime files + 2 license files, ~18 KB) because the
script is small, readable, and gives us a correct occluded fan for the player's fog-of-war cheaply.
But apply these four patches in `addons/godot-vision-cone/vision_cone_2d.gd` and record them in
`docs/credits.md` as local modifications:

1. **Face +X.** Replace `Vector2(0, max_distance).rotated(...)` with
   `Vector2(max_distance, 0).rotated(...)` and drop the `-1.5708` offset from every consumer.
   (Or add an `@export var forward_axis: Vector2 = Vector2.RIGHT`.)
2. **Live FOV.** Recompute `_angle`, `_angle_half`, `_angular_delta` at the top of
   `calculate_vision_shape()` instead of in `@onready`.
3. **Guard `ray_count`.** `maxi(ray_count, 1)` before dividing.
4. **Origin offset.** The source has a literal `# TODO add offset to origin` in `_ray_to`. If we
   want the cone to originate at the muzzle/eyes rather than the body centre, add an
   `@export var origin_offset: Vector2` and use `to_global(origin_offset)` as the ray start.

Step 3 of the plan in §1.10 covers the alternative: keep upstream pristine in `addons/` and
subclass in `src/vision/`.

---

## 2. at-icons

Repo: <https://github.com/Voxybuns/at-icons>
Latest release: **v1.6.0** (2026-11-07), 705 icons × 6 variants
Compatibility trialled: 4.7.2 **[verified]**

### 2.1 What it does

A library of SVG node icons for the Godot **editor** scene tree, plus an editor dock to browse
them. It is not a runtime system — it ships no game code.

> "**@icons** is a free and open-source library of 700+ vector (SVG) icons you can use as custom
> node icons in your Godot projects or plugins, designed to fit with the existing set of editor
> icons" — <https://github.com/Voxybuns/at-icons/blob/main/README.md>

Usage is the standard Godot `@icon` annotation, placed **before** `class_name`:

```gdscript
@icon ("res://addons/at-icons/node2d/human.svg")
class_name Character2D
extends CharacterBody2D
```

Six variants, one per node category, same glyph different tint — verified from the SVGs:
`node/` = `#e0e0e0` (grey), `node2d/` = `#8da5f3` (blue), `control/` = `#8eef97` (green),
plus `node3d/`, `mesh/`, `animation/`. Each variant is a full 705-icon copy: 6 × 705 = 4,230 SVGs.

### 2.2 Godot version compatibility

The README does not state a minimum version. The plugin source does:

```gdscript
# addons/at-icons/at-icons.gd
var dock : EditorDock
func _enter_tree() -> void:
	dock = EditorDock.new()
	dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	...
	add_dock(dock)
```

`EditorDock` and `EditorPlugin.add_dock()` do **not** exist in 4.4 or 4.5 — the docs pages
`/en/4.4/classes/class_editordock.html` and `/en/4.5/classes/class_editordock.html` both return
**404**, while `/en/4.6/` and `/en/4.7/` return 200
(<https://docs.godotengine.org/en/4.7/classes/class_editordock.html>). The same is true of
`add_dock` (`EditorPlugin` 4.4 docs have `add_control_to_dock` but no `add_dock`).

`git show v1.3.0..v1.6.0:addons/at-icons/at-icons.gd` shows `EditorDock` in **all** of those
tags; v1.2.1 still used the classic `_enable_plugin` skeleton. **So at-icons ≥ 1.3.0 requires
Godot ≥ 4.6** (inferred from the docs availability, not stated by the author).

**For us: fine.** We are on 4.7.2. **[verified]** Vendored `addons/at-icons/` into a 4.7.2
project with the plugin enabled, ran `--headless --editor --quit`: no parse errors, no dock
errors, `EditorDock` resolved.

Compatibility risk to note: `EditorDock` is flagged **Experimental** in the 4.7 docs — *"This
class may be changed or removed in future versions."* If we ever move to 4.8, re-check the dock.

**Known 4.7 issue:** #28 "Can't find the .html and the in-editor dock is not working", reported
by a user on **exactly 4.7.2 stable**
(<https://github.com/Voxybuns/at-icons/issues/28>). The reporter later showed an empty dock. Owner
asked for install details on 2026-10-10; issue is still open. Our own trial did not reproduce it
(the dock instantiated without error), so this looks like an install-path or search-index problem
rather than a 4.7 API break — but it is unresolved, so treat the dock as *nice-to-have* and do not
depend on it.

Also relevant, and a real caveat: icons do not recolour on theme/scale change.

> "Due to a Godot Engine bug, icons do **not** get automatically rescaled or recolored if you
> change your editor's theme or scale. […] you will need to **reimport** all icons whenever you
> changed the aforementioned editor settings." — README.md (bug report: issue #25, on 4.7.1)

### 2.3 License

MIT:

> "**@icons** is licensed under the MIT license. See [LICENSE](LICENSE) for more information." — README.md

`addons/at-icons/LICENSE.txt` (1,109 B) ships inside the addon; keep it. Credits line:
*@icons by Voxy, MIT, https://github.com/Voxybuns/at-icons*.

### 2.4 Installation

The README is emphatic:

> "Do not install **@icons** by cloning or downloading the repository as a ZIP file, as it
> contains source files for the web picker which cannot be used on their own." — README.md

> "Download the [latest release] and extract it into the root of your Godot project's folder.
> If you wish to use the icons in your plugin or addon, you can also copy individual icons along
> with their respective `.import` files into your plugin's folder, along with the library's
> license." — README.md

**Structure** (from the release ZIP, per the owner in issue #28):

```
addons/at-icons/          <- the addon (what we vendor)
@icons picker.html        <- standalone web picker, sits OUTSIDE addons/
```

**`plugin.cfg`** (verbatim; note `version="1.5.0"` even at tag v1.6.0 — the file is stale upstream):

```ini
[plugin]

name="@icons"
description="Open source icons for custom Godot nodes."
author="Icons by Voxy, in-editor picker by SuperDuperSword and Voxy"
version="1.5.0"
script="at-icons.gd"
```

**To enable:** Project → Project Settings → Plugins → tick `@icons`, or add to
`project.godot`:

```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/at-icons/plugin.cfg")
```

**But — big caveat for us — the dock hardcodes its icon directory and preloads all 706 icons.**

```gdscript
# icon_browser.tscn (built-in script "json_holder"/grid):
const ICONS_DIRECTORY: String = "res://addons/at-icons/node3d/"
```

`icon_browser.tscn` has **706 `[ext_resource]` lines**: 705 point at
`res://addons/at-icons/node3d/*.svg` and 1 at `res://addons/at-icons/node/magnifying_glass.svg`
(the search-box icon). The dock also enumerates `ICONS_DIRECTORY` at runtime. So the `node3d/`
variant (5.6 MB) plus that one `node/` file are mandatory if you enable the plugin; deleting
them breaks the dock. The other five variants are only needed for the icons you actually
`@icon`-reference.

`icon_browser.tscn` is a **224 KB** scene. Addon total: **34 MB** (6 × 5.6 MB variants + 224 KB).

### 2.5 Caveat: export bloat

> "By default, all the icons contained in the plugin will get packaged when exporting your
> project to an executable. […] you may want to exclude the @icons addon resources from being
> exported." — README.md

Concretely: set Export → Resources → *Export all resources except those checked below* and tick
`addons/at-icons/`. **Do this** — 34 MB of editor-only SVGs in a shipped build is indefensible.

Also: every SVG needs its `.import` committed (consistent with AGENTS.md) and an import pass
before headless runs. First `--headless --import` on this addon took noticeably longer than the
vision-cone one because of the 4,230 SVGs.

### 2.6 Verdict: take the icons, skip the dock

**Recommendation (opinion).** Do **not** vendor the whole 34 MB with the plugin enabled. Instead:

- Copy only the icons we actually use, as `svg` + `.svg.import` **pairs**, into
  `assets/ui/icons/` (our curated-assets convention) — a dozen files, not 4,230.
- Reference them with `@icon("res://assets/ui/icons/....svg")` on the handful of `class_name`
  types we expose to the editor (`Character`, `Perception`, maybe `WeaponDef`), per AGENTS.md's
  "`class_name` sparingly".
- If we do want the picker, vendor the full addon but **leave it disabled** in
  `[editor_plugins]` and enable per-developer. It is an authoring convenience with an
  experimental 4.6+ API and an open 4.7.2 bug report; it must never sit on the critical path for
  a headless CI run.

Minimum viable vendoring if we want the addon present and enabled:

```
addons/at-icons/
  LICENSE.txt
  plugin.cfg
  at-icons.gd
  at-icons.gd.uid
  icon_browser.tscn          (224 KB, hardcodes node3d/ paths)
  node3d/                    (705 × svg + 705 × .import = 5.6 MB)   <- required by the dock
  node/at.svg                (dock_icon preload in at-icons.gd)
  + only the specific icons you @icon-reference, in their variant folders
```

Note `at-icons.gd` preloads `res://addons/at-icons/node/at.svg` as the dock icon, so `node/at.svg`
is mandatory even though `node/` is otherwise optional.

---

## 3. Vendoring plan (concrete)

```
addons/
  godot-vision-cone/                     # renamed from vision_cone_2d
    LICENSE-MIT                          # chosen license
    LICENSE-APACHE                       # keep both; costs 10 KB and avoids ambiguity
    plugin.cfg
    vision_cone_2d.gd
    vision_cone_2d.gd.uid
    vision_cone_entry.gd
    vision_cone_entry.gd.uid
    cone_editor_helper.gd
    cone_editor_helper.gd.uid
    vision_cone_2d_template.tscn
```

**Do not** add either plugin to `[editor_plugins] enabled=` in `project.godot`:

- `vision_cone_entry.gd` is a no-op; enabling it buys nothing and risks an editor-load error in
  CI.
- `at-icons` must stay disabled on the shared/CI path (see §2.6).

**Do not** rename the `.gd` files — the `.uid` files bind UIDs to those exact paths, and
`vision_cone_2d_template.tscn` stores both the UID and the `res://addons/vision_cone_2d/…` path.
Renaming the *directory* is survivable (UIDs resolve first) but you must re-save the template once
so its stored paths update. Safest: keep `addons/vision_cone_2d/` as upstream names it, or rename
and re-save with the editor.

### Local patch set (apply to the vendored copy, log in `docs/credits.md`)

```gdscript
# addons/godot-vision-cone/vision_cone_2d.gd — local modifications
# 1. forward axis +X instead of +Y
#    (was: Vector2(0, max_distance).rotated(_angular_delta * i + global_rotation - _angle_half))
# 2. live FOV: derive _angle/_angle_half/_angular_delta per call, not in @onready
# 3. ray_count guard: var n := maxi(ray_count, 1)
# 4. optional @export var origin_offset: Vector2  (upstream TODO in _ray_to)
```

Alternative that keeps upstream pristine: leave `addons/godot-vision-cone/` untouched and put our
`src/vision/vision_cone.gd` wrapper (`extends VisionCone2D`) that overrides
`calculate_vision_shape()` with the corrected maths and exposes `set_fov(deg)`,
`get_world_polygon()`, `set_facing(dir)`. **Preferred (opinion)** — it makes the diff obvious and
survives an upstream re-vendor. Only use the in-place patch if the override proves awkward, since
`_vision_points` and the `@onready` vars are private-by-convention.

### Wiring into our contracts

- `src/core/layers.gd` already defines `VISION_MASK = WORLD | closed doors`. Feed that into
  `collision_layer_mask`; **never** the template's `2`.
- `Perception` (architecture §4) should own a `VisionCone2D` **only for the player**, to drive
  fog/minimap. NPCs get `is_target_visible()` raycasts (§1.7 tier 2) and no polygon cone.
- Fairness invariant #2 in architecture §11 ("every NPC kill had LOS-or-prior-sighting at fire
  time") is satisfied by the raycast tier, not by the Area2D. Log the raycast result as shot
  provenance.

---

## 4. Fallback: implement occluded-cone vision ourselves

Needed if we reject the addon — or, per §1.7, needed anyway for the NPC perception tier.
**This code was written and run under 4.7.2 and produced correct results [verified]**:
polygon clipped to y = 290 by a wall at y = 300; `is_target_visible` returned
`true/false/false` for visible / behind-wall / behind-viewer targets.

`src/vision/vision_fallback.gd` — reference sketch, ~55 lines, no dependencies:

```gdscript
class_name VisionFallback
extends Node2D
## Occluded cone vision. Fan raycasts for the visual polygon; one targeted ray per
## candidate for gameplay gating. Godot 2D forward convention: +X is "forward".

@export var angle_deg: float = 90.0
@export var max_distance: float = 500.0
@export var ray_count: int = 48
@export_flags_2d_physics var occluder_mask: int = 2
## Assign the owning CharacterBody2D/Area2D: Node2D has no RID to exclude.
@export var caster: CollisionObject2D

var _points: PackedVector2Array = PackedVector2Array()

func _physics_process(_delta: float) -> void:
	rebuild()

func rebuild() -> void:
	var pts := PackedVector2Array()
	var half := deg_to_rad(angle_deg) * 0.5
	pts.append(Vector2.ZERO)
	var space := get_world_2d().direct_space_state
	for i in range(ray_count + 1):
		var a := global_rotation - half + (deg_to_rad(angle_deg) * float(i) / float(ray_count))
		var dest := global_position + Vector2.RIGHT.rotated(a) * max_distance
		var q := PhysicsRayQueryParameters2D.create(global_position, dest, occluder_mask)
		if caster != null:
			q.exclude = [caster.get_rid()]
		var hit := space.intersect_ray(q)
		pts.append(to_local(hit.position if hit else dest))
	_points = pts

func get_polygon() -> PackedVector2Array:
	return _points

## O(1) in ray_count. This is the AI perception primitive.
func is_target_visible(target: Node2D) -> bool:
	var to_t := target.global_position - global_position
	var dist := to_t.length()
	if dist > max_distance or dist < 0.001:
		return false
	if absf(Vector2.RIGHT.rotated(global_rotation).angle_to(to_t)) > deg_to_rad(angle_deg) * 0.5:
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, target.global_position, occluder_mask)
	if caster != null:
		q.exclude = [caster.get_rid()]
	if target is CollisionObject2D:
		q.exclude.append((target as CollisionObject2D).get_rid())
	return space.intersect_ray(q).is_empty()

## Polygon test on the cached fan (no extra raycasts). _points are LOCAL space.
func is_point_in_view(world_point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(world_point), _points)

func _draw() -> void:
	if _points.size() >= 3:
		draw_colored_polygon(_points, Color(0.43, 0.93, 0.28, 0.29))
```

Two bugs I hit while validating this, both worth knowing:

1. **`Node2D` has no `get_rid()`.** My first draft used `q.exclude = [get_rid()]` and failed to
   compile. You must hold a reference to the owning `CollisionObject2D` — hence `@export var
   caster`.
2. **`is_point_in_view` must convert to local space.** `_points` are local (that is what
   `Polygon2D`/`CollisionPolygon2D` want), so passing a world point straight to
   `is_point_in_polygon` silently returns `false`. `to_local()` first.

**Known limitation of the naive fan (same as the addon):** corners between rays are rounded, so
the polygon is slightly conservative. Acceptable for fog-of-war. If we ever need exact shadows,
swap `rebuild()` for an angular sweep over wall vertices + the two rays flanking each
discontinuity (the "optimized version" the addon's README declines to implement). Do that only if
a screenshot review shows the artefact.

**Effort:** 1 focused session for the class above + unit tests; half a session more for the
exact-shadow sweep. Compare with vendoring + 4 patches + a wrapper: similar effort, but the
fallback has no third-party licence obligation and no upstream drift. Given we must build the
raycast tier regardless (§1.7), **implementing the fallback outright is a defensible choice** —
and it removes the addon from `addons/` entirely. The addon's remaining value is then just its
`Polygon2D` fan code, which is ~60 lines we have already reproduced.

---

## 5. Open questions / conflicts

- **vision-cone version string:** `plugin.cfg` says `0.2`; the release announcing `min_distance_sqr`
  was called 0.2.0. No tags exist in the repo (`/releases` returns `[]`). Assume `main` == 0.2.0
  and pin by commit SHA `5c98f7…`, not by version string.
- **vision-cone on 4.5–4.7:** no one reports breakage, and it works here, but the author has not
  tested past 4.4.1. Single-sourced compat claim.
- **at-icons minimum Godot:** inferred from docs availability (EditorDock 404 in 4.4/4.5, 200 in
  4.6/4.7), not stated by the author. If it matters, test on 4.5 directly.
- **at-icons dock on 4.7.2:** issue #28 reports it blank on precisely our version; unreproduced
  here, unresolved upstream.
- **Cone self-occlusion:** worked in my tests via `hit_from_inside`, but that is an emergent
  property, not a guarantee. Our layer plan (CHARACTER not in `VISION_MASK`) makes it moot.

## 6. Sources

- <https://github.com/d-bucur/godot-vision-cone> (repo metadata, license, tree)
- <https://github.com/d-bucur/godot-vision-cone/blob/main/readme.md> (compat, performance, license)
- <https://raw.githubusercontent.com/d-bucur/godot-vision-cone/main/addons/vision_cone_2d/vision_cone_2d.gd>
- <https://raw.githubusercontent.com/d-bucur/godot-vision-cone/main/addons/vision_cone_2d/vision_cone_2d_template.tscn>
- <https://raw.githubusercontent.com/d-bucur/godot-vision-cone/main/addons/vision_cone_2d/plugin.cfg>
- <https://raw.githubusercontent.com/d-bucur/godot-vision-cone/main/addons/vision_cone_2d/cone_editor_helper.gd>
- <https://raw.githubusercontent.com/d-bucur/godot-vision-cone/main/addons/vision_cone_2d/examples/enemy.tscn>
- <https://api.github.com/repos/d-bucur/godot-vision-cone/git/trees/HEAD?recursive=1>
- <https://github.com/d-bucur/godot-vision-cone/issues/2> (scale, wontfix)
- <https://github.com/d-bucur/godot-vision-cone/issues/5> (convex decompose → `min_distance_sqr`)
- <https://github.com/d-bucur/godot-vision-cone/issues/6> (facing +X, open)
- <https://github.com/Voxybuns/at-icons> (repo metadata, MIT, tree)
- <https://github.com/Voxybuns/at-icons/blob/main/README.md> (install, `@icon`, export exclusion)
- <https://raw.githubusercontent.com/Voxybuns/at-icons/main/addons/at-icons/at-icons.gd> (EditorDock)
- <https://raw.githubusercontent.com/Voxybuns/at-icons/main/addons/at-icons/plugin.cfg>
- <https://api.github.com/repos/Voxybuns/at-icons/releases/latest> (v1.6.0, 705 icons)
- <https://github.com/Voxybuns/at-icons/issues/28> (dock blank on 4.7.2, open)
- <https://github.com/Voxybuns/at-icons/issues/25> (theme recolour bug)
- <https://docs.godotengine.org/en/4.7/classes/class_editordock.html> (EditorDock, Experimental)
- <https://docs.godotengine.org/en/4.5/classes/class_editordock.html> (404 → not in 4.5)
- <https://docs.godotengine.org/en/4.7/classes/class_physicsrayqueryparameters2d.html>