# Godot 4.7 Technical Patterns for Kangur

Research for a production topdown 2D tactical shooter on **Godot 4.7.2.stable**
(`/usr/bin/godot`, `4.7.2.stable.arch_linux.ed1daf0bf`, verified `godot --version`).

**Method.** Every API signature below is copied from the official 4.7 class
reference (`docs.godotengine.org/en/4.7/classes/...`) — the `/en/4.7/` docs tree
exists and is the authority for our version. Load-bearing runtime claims were
additionally *executed* against the installed 4.7.2 binary in a throwaway
project under `/tmp/opencode`; those are marked **[verified on 4.7.2]**. Claims
that are inference or opinion are labelled **[inference]** / **[opinion]**.

Scope: only the nine topics in the brief. Kangur-specific integration advice is
phrased against `docs/architecture.md` contracts (§3 autoloads, §9 audio, §10
match runtime, §11 verification) so it drops into the existing design.

---

## 0. Executive answers

| Question | Answer |
|---|---|
| TileMap or TileMapLayer? | **TileMapLayer only.** `TileMap` is `Deprecated:` in 4.7 docs. |
| Navigation for 24 agents | `NavigationAgent2D` + RVO (`avoidance_enabled`, `radius`, `neighbor_distance`, `max_neighbors`, `time_horizon_agents`, `avoidance_priority`). Beware: whole navigation stack is marked **Experimental**. |
| Baked nav vs TileMap nav layers? | Bake a real `NavigationPolygon` into a `NavigationRegion2D`; TileMap's built-in nav has "many practical limitations". |
| Audio occlusion | Pre-created buses + per-bus `AudioEffectLowPassFilter`; route by wall-count. All bus APIs work headless (`Dummy` driver). |
| Bullets | Single `ProjectileSystem` doing one `intersect_ray` per bullet per tick, segment = `vel * delta`. **Never** Area2D-overlap-only (proven to tunnel in probe). |
| Test framework | **gdUnit4 v7.0.0** (4.7 branch) — *but* with a caveat: the stable release line v6.2.3 refuses `--headless` without a flag. See §5 for the full trade-off. |
| Screenshots | `get_viewport().get_texture().get_image().save_png()` **after** `await RenderingServer.frame_post_draw`. Works on `:0`; in `--headless` the await never returns (verified — it hangs, it does not error). |
| Content | `class_name XDef extends Resource` + `@export`, `.tres` under `data/`, `DirAccess` scan. Commit `*.import`, ignore `.godot/`. |
| LFS | **Plain git** for ~200 MB of audio. Official docs treat LFS as optional; adds clone friction and CI setup for no benefit at that size. |

---

## 1. TileMapLayer (4.3+ replacement for TileMap)

### 1.1 Status and workflow

`TileMap` is deprecated in 4.7:

> `Deprecated: Use multiple TileMapLayer nodes instead. To convert a TileMap to a set of TileMapLayer nodes, open the TileMap bottom panel with the node selected, click the toolbox icon in the top-right corner and choose 'Extract TileMap layers as individual TileMapLayer nodes'.`
> — <https://docs.godotengine.org/en/4.7/classes/class_tilemap.html>

`TileMapLayer` is one layer per node; stack nodes for layers:

> `Unlike the TileMap node, which is deprecated, TileMapLayer has only one layer of tiles. You can use several TileMapLayer to achieve the same result as a TileMap node.`
> — <https://docs.godotengine.org/en/4.7/classes/class_tilemaplayer.html>

Key properties (same page): `tile_set`, `enabled`, `collision_enabled` (default
`true`), `navigation_enabled` (default `true`), `occlusion_enabled` (default
`true`), `physics_quadrant_size` (default `16`), `rendering_quadrant_size`
(default `16`), `use_kinematic_bodies`, `y_sort_origin`,
`x_draw_order_reversed`, `tile_map_data` (PackedByteArray).

Updates are batched at frame end:

> `For performance reasons, all TileMap updates are batched at the end of a frame. ... To force an update earlier on, call update_internals().`

Coordinates are 16-bit signed, `-32768..32767`, and out-of-range tiles **wrap
silently** on save. For Kangur's `maps/` that is a non-issue at 1 tile = 1
metre-ish scale, but worth a note for procedural map generators.

### 1.2 Building the map pipeline (Kangur shape)

Recommended node layout per `docs/architecture.md` §7, all as `TileMapLayer`
children of the map root:

```
Map (Node2D)
├─ Ground      TileMapLayer   # no physics, no nav
├─ Walls       TileMapLayer   # physics layer 1 + nav layer + custom data
├─ Deco        TileMapLayer   # y-sorted, no collision
├─ Nav         NavigationRegion2D  # baked NavigationPolygon from Walls
├─ Spawns      Node2D > Marker2D
├─ Cover       Node2D > CoverPoint
└─ Objectives  Node2D > ObjectiveZone (Area2D, layer 3)
```

The official tutorial explicitly recommends this split for background vs
foreground and confirms per-layer toggles:

> `When working with tilemaps it's generally advised that you use multiple TileMapLayer nodes when appropriate. ... Each TileMapLayer node has several properties you can adjust: Enabled ... TileSet ... Collision Enabled ... Navigation Enabled ...`
> — <https://docs.godotengine.org/en/4.7/tutorials/2d/using_tilemaps.html>

### 1.3 Physics / navigation / occlusion layers live on the **TileSet**

Layers are TileSet-level, and each tile paints into them. Exact signatures:

```gdscript
# TileSet — add layers at runtime (or author in the TileSet editor)
var ts: TileSet = load("res://data/tilesets/compound.tres")

ts.add_physics_layer(-1)          # collision polygons per tile
ts.add_navigation_layer(-1)       # nav polygons per tile
ts.add_occlusion_layer(-1)        # light occluders per tile
ts.add_custom_data_layer(-1)      # arbitrary per-tile data

ts.set_physics_layer_collision_layer(0, 1)         # -> layer 1 = WORLD
ts.set_physics_layer_collision_mask(0, 0)
ts.set_navigation_layer_layers(0, 1)               # nav layer bitmask
ts.set_occlusion_layer_light_mask(0, 1)
```

Signatures confirmed at
<https://docs.godotengine.org/en/4.7/classes/class_tileset.html>:
`void add_physics_layer(to_position: int = -1)`,
`void add_navigation_layer(to_position: int = -1)`,
`void add_occlusion_layer(to_position: int = -1)`,
`void add_custom_data_layer(to_position: int = -1)`,
`void set_physics_layer_collision_layer(layer_index: int, layer: int)`,
`void set_navigation_layer_layers(layer_index: int, layers: int)`,
`void set_occlusion_layer_light_mask(layer_index: int, light_mask: int)`.

**Important for Kangur:** the architecture now defines **six** collision layers
(§2): `1 WORLD`, `2 CHARACTER`, `3 INTERACT`, `4 EQUIPMENT`, `5 LOW_COVER`,
`6 GLASS`. Each needs its **own TileSet physics layer**, because a single TileSet
physics layer carries one `collision_layer` value for all tiles painted through
it — you cannot vary the layer per tile within one physics layer:

```gdscript
ts.add_physics_layer(-1)   # 0 -> WORLD (high walls)
ts.add_physics_layer(-1)   # 1 -> LOW_COVER (crates/cars/sandbags)
ts.add_physics_layer(-1)   # 2 -> GLASS (windows)
ts.set_physics_layer_collision_layer(0, Layers.WORLD_BIT)
ts.set_physics_layer_collision_layer(1, Layers.LOW_COVER_BIT)
ts.set_physics_layer_collision_layer(2, Layers.GLASS_BIT)
```

All three still navigate off the same nav layer: LOW_COVER and GLASS block
movement, so bake them as obstructions too (i.e. include layers 1, 5, 6 in
`parsed_collision_mask`). That is a TileSet setting, not a per-map setting — get
it wrong once and every bullet/vision/sound ray in every map silently passes
through walls. Worth an editor-time assert in `World`.

### 1.4 Custom data layers for surface type (footsteps)

Custom data is authored per-tile and read per-cell. Exact signatures:

```gdscript
# TileData
Variant get_custom_data(layer_name: String) const
Variant get_custom_data_by_layer_id(layer_id: int) const
void set_custom_data(layer_name: String, value: Variant)
bool has_custom_data(layer_name: String) const
```

Source: <https://docs.godotengine.org/en/4.7/classes/class_tiledata.html> — the
`get_custom_data` description confirms: `Returns the custom data value for
custom data layer named layer_name.`

The TileMapLayer class ref ships this exact idiom:

```gdscript
func get_clicked_tile_power():
    var clicked_cell = tile_map_layer.local_to_map(tile_map_layer.get_local_mouse_position())
    var data = tile_map_layer.get_cell_tile_data(clicked_cell)
    if data:
        return data.get_custom_data("power")
    else:
        return 0
```

Our version, with the architecture's `Enums.Surface` and a typed helper. Note
that `get_custom_data` returns `Variant`, so it must be cast/validated — a typo'd
layer name returns `null`, not an error:

```gdscript
# src/world/world.gd  (excerpt)
const SURFACE_LAYER := &"surface"
const PENETRABLE_LAYER := &"penetrable"
const BLOCKS_SOUND_LAYER := &"blocks_sound"

@export var walls: TileMapLayer

## Returns Enums.Surface for a world position; CONCRETE if unmapped.
func surface_at(global_pos: Vector2) -> int:
    var cell: Vector2i = walls.local_to_map(walls.to_local(global_pos))
    var data: TileData = walls.get_cell_tile_data(cell)
    if data == null:
        return Enums.Surface.CONCRETE
    var v: Variant = data.get_custom_data(SURFACE_LAYER)
    if v == null:
        # Loud in debug: a tile missing the layer is a content bug, not a default.
        assert(false, "tile at %s has no '%s' custom data" % [cell, SURFACE_LAYER])
        return Enums.Surface.CONCRETE
    return int(v)

func is_penetrable(global_pos: Vector2) -> bool:
    var cell: Vector2i = walls.local_to_map(walls.to_local(global_pos))
    var data: TileData = walls.get_cell_tile_data(cell)
    return data != null and bool(data.get_custom_data(PENETRABLE_LAYER))
```

Authoring sequence (editor): select the TileSet → *Custom Data Layers* → add
`surface` with type `int`, `penetrable` (bool), `blocks_sound` (bool) → then per
tile in the *Select* inspector set the values. Alternatively build them at load
time with `set_custom_data_layer_name` / `set_custom_data_layer_type`:

```
void set_custom_data_layer_name(layer_index: int, layer_name: String)
void set_custom_data_layer_type(layer_index: int, layer_type: Variant.Type)
```
(When the name `is already taken it will fail and raise an error.`)

### 1.5 Runtime tile queries — exact signatures

All from <https://docs.godotengine.org/en/4.7/classes/class_tilemaplayer.html>:

```
Vector2i local_to_map(local_position: Vector2) const
Vector2  map_to_local(map_position: Vector2i) const
TileData get_cell_tile_data(coords: Vector2i) const
int      get_cell_source_id(coords: Vector2i) const
Vector2i get_cell_atlas_coords(coords: Vector2i) const
int      get_cell_alternative_tile(coords: Vector2i) const
Vector2i get_coords_for_body_rid(body: RID) const
bool     has_body_rid(body: RID) const
RID      get_navigation_map() const
void     set_navigation_map(map: RID)
Array[Vector2i] get_used_cells() const
Array[Vector2i] get_used_cells_by_id(source_id: int = -1, atlas_coords: Vector2i = Vector2i(-1,-1), alternative_tile: int = -1) const
Rect2i   get_used_rect() const
Array[Vector2i] get_surrounding_cells(coords: Vector2i)
Vector2i get_neighbor_cell(coords: Vector2i, neighbor: TileSet.CellNeighbor) const
bool     is_cell_flipped_h(coords: Vector2i) const
void     set_cell(coords: Vector2i, source_id: int = -1, atlas_coords: Vector2i = Vector2i(-1,-1), alternative_tile: int = 0)
void     erase_cell(coords: Vector2i)
void     clear()
void     update_internals()
void     notify_runtime_tile_data_update()
```

**`local_to_map` takes LOCAL coordinates.** The docs are explicit:

> `Returns the map coordinates of the cell containing the given local_position. If local_position is in global coordinates, consider using Node2D.to_local() before passing it to this method.`

This is the single most common TileMapLayer bug; the `surface_at` helper above
does the `to_local` conversion once, centrally.

**`get_coords_for_body_rid` caveat (4.5 behaviour change).** It returns the
*physics quadrant* coords, not the exact cell:

> `This impacts the value returned by get_coords_for_body_rid(). Higher values will make that function less precise. To get the exact cell coordinates, you need to set physics_quadrant_size to 1, which disables physics chunking.`

And the 4.5 migration guide calls this out as a breaking behavioural change:

> `TileMapLayer.get_coords_for_body_rid() will return different values in 4.5 compared to 4.4, as TileMapLayer physics chunking is enabled by default.`
> — <https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.5.html>

For Kangur we do **not** need `get_coords_for_body_rid` for bullet impacts —
`intersect_ray` already returns `position` and `normal`, and `position` feeds
`surface_at()` directly (§4). So keep `physics_quadrant_size = 16` for the
collision-merge performance win and treat RID→cell as unavailable. **[opinion]**

### 1.6 Scene tiles (props placed by the map)

`TileSetScenesCollectionSource` lets a tile instantiate a scene (crates, doors,
light fixtures). Initialisation is deferred like everything else:

> `Notably, this means that scene tiles from a TileSetScenesCollectionSource are initialized after their parent. This is only queued when inside the scene tree.`

Practical rule: never `get_node()` a scene-tile instance in `_ready()`; use
`await get_tree().process_frame` or `call_deferred`. **[inference from the
above quote]** Kangur's `Cover`/`Objectives` markers should stay as plain
`Marker2D`/`Area2D` nodes rather than scene tiles, exactly as §7 specifies —
they need editor-authored exported properties and stable names.

---

## 2. NavigationServer2D

### 2.1 Status warning (read this first)

The **entire 2D navigation stack is marked Experimental in 4.7**, and has been
since 4.3:

> `Experimental: This class may be changed or removed in future versions.`
> — on `NavigationServer2D`, `NavigationAgent2D`, `NavigationRegion2D`,
> `NavigationPolygon`, `NavigationObstacle2D`, `NavigationLink2D`,
> `NavigationPathQueryParameters2D` (all fetched; all carry the banner in
> 4.3 → 4.7).

Consequence for Kangur: navigation APIs can change in a minor release. Mitigate
by (a) pinning the Godot version in `project.godot`/CI as we already do, and
(b) keeping nav calls behind `src/world/navigation.gd` so a rename touches one
file. **[opinion]**

### 2.2 Baking a NavigationPolygon from a TileMapLayer

Two routes.

**Route A — `NavigationRegion2D.bake_navigation_polygon()` (editor + runtime).**

```
void bake_navigation_polygon(on_thread: bool = true)
signal bake_finished()
bool is_baking() const
```
— <https://docs.godotengine.org/en/4.7/classes/class_navigationregion2d.html>

In-editor: select the `Nav` `NavigationRegion2D`, assign a `NavigationPolygon`
resource, set `parsed_geometry_type = STATIC_COLLIDERS` (or `BOTH` if you want
visual outlines), `parsed_collision_mask` to `WORLD|LOW_COVER|GLASS` (layers 1,
5, 6 — everything that blocks movement), `agent_radius = 10`,
`cell_size` matching the map, then press Bake. The nav mesh is produced from the
**TileMapLayer physics colliders**, which is why §1.3's per-layer collision setup
matters.

**Route B — explicit `NavigationServer2D` parse+bake** (recommended for Kangur:
lets us cache parsed geometry per map and re-bake per agent radius, and is the
documented fix for TileMap parse cost):

```
void parse_source_geometry_data(navigation_polygon: NavigationPolygon,
                                source_geometry_data: NavigationMeshSourceGeometryData2D,
                                root_node: Node, callback: Callable = Callable())
void bake_from_source_geometry_data(navigation_polygon: NavigationPolygon,
                                    source_geometry_data: NavigationMeshSourceGeometryData2D,
                                    callback: Callable = Callable())
void bake_from_source_geometry_data_async(...)   # same args, background thread
bool is_baking_navigation_polygon(navigation_polygon: NavigationPolygon) const
```
— <https://docs.godotengine.org/en/4.7/classes/class_navigationserver2d.html>

Constraints quoted from the docs:

> `Note: This function needs to run on the main thread or with a deferred call as the SceneTree is not thread-safe.`

> `Performance: While convenient, reading data arrays from Mesh resources can affect the frame rate negatively. The data needs to be received from the GPU, stalling the RenderingServer in the process. For performance prefer the use of e.g. collision shapes or creating the data arrays entirely in code.`

`NavigationPolygon` knobs that matter (all defaults quoted from
<https://docs.godotengine.org/en/4.7/classes/class_navigationpolygon.html>):
`agent_radius = 10.0`, `cell_size = 1.0`, `parsed_geometry_type = 2`
(`PARSED_GEOMETRY_BOTH`), `parsed_collision_mask = 4294967295`,
`sample_partition_type = 0` (convex), `baking_rect`, `border_size`.

> `The distance to erode/shrink the walkable surface when baking the navigation mesh.`
> `float agent_radius = 10.0`

> `The cell size used to rasterize the navigation mesh vertices. Must match with the cell size on the navigation map.`

Map cell size must match: `NavigationServer2D.map_set_cell_size(map, cell_size)`
— `Must match with the cell size of the used navigation meshes.`

Working bake (adapted from the official 2D template, which is exactly our
case — "Some mega-nodes like TileMap are often not ready on the first frame"):

```gdscript
# src/world/navigation.gd
extends Node2D

var nav_polygon: NavigationPolygon
var source_geometry: NavigationMeshSourceGeometryData2D
var region_rid: RID
@export var agent_radius: float = 10.0
@export var bake_root: Node2D

func _ready() -> void:
    nav_polygon = NavigationPolygon.new()
    nav_polygon.agent_radius = agent_radius
    nav_polygon.cell_size = 1.0
    nav_polygon.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
    nav_polygon.parsed_collision_mask = (1 << 0) | (1 << 4) | (1 << 5)  # WORLD|LOW_COVER|GLASS
    source_geometry = NavigationMeshSourceGeometryData2D.new()
    region_rid = NavigationServer2D.region_create()
    NavigationServer2D.region_set_enabled(region_rid, true)
    NavigationServer2D.region_set_map(region_rid, get_world_2d().get_navigation_map())
    bake.call_deferred()          # TileMapLayer not ready on frame 1

func bake() -> void:
    source_geometry.clear()
    NavigationServer2D.parse_source_geometry_data(
        nav_polygon, source_geometry, bake_root, _on_parsed)

func _on_parsed() -> void:
    # Obstruction-only parse needs at least one traversable outline to cut into.
    source_geometry.add_traversable_outline(PackedVector2Array([
        Vector2(0, 0), Vector2(0, 4096), Vector2(4096, 4096), Vector2(4096, 0)]))
    NavigationServer2D.bake_from_source_geometry_data_async(
        nav_polygon, source_geometry, _on_baked)

func _on_baked() -> void:
    NavigationServer2D.region_set_navigation_polygon(region_rid, nav_polygon)
    # Map must be synchronised before any path query returns anything.
    await get_tree().physics_frame
```

The `add_traversable_outline` line is from the official template and is
non-obvious — without it, a collider-only parse yields obstructions with nothing
to cut into:

> `If we did not parse a TileMap with navigation mesh cells we may now only have obstruction outlines so add at least one traversable outline so the obstructions outlines have something to "cut" into.`
> — <https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_using_navigationmeshes.html>

**TileMap built-in nav is a trap for us.** Official guidance:

> `TileMap built-in navigation has many practical limitations that result in inferior pathfinding performance and pathfollowing quality. After designing the TileMap consider baking it to a more optimized navigation mesh (and disabling the TileMap NavigationLayer) using a NavigationRegion2D or the NavigationServer2D.`
> — <https://docs.godotengine.org/en/4.7/tutorials/2d/using_tilemaps.html>

Also a hard warning that kills any "one nav layer per floor" idea:

> `Warning: 2D navigation meshes can not be "layered" or stacked on top of each other like visuals or physics shapes. Attempting to stack navigation meshes on the same navigation map will result in merge and logical errors that break the pathfinding.`

So: **one flat nav mesh per map**, `Walls.navigation_enabled = false`, bake from
colliders into `Nav`. This matches §7 already; keep it.

### 2.3 NavigationAgent2D pathfinding

Properties (`<https://docs.godotengine.org/en/4.7/classes/class_navigationagent2d.html>`),
defaults quoted:

| Property | Default | Use for Kangur |
|---|---|---|
| `target_position: Vector2` | `Vector2(0,0)` | set once per order, not per tick |
| `path_desired_distance` | `20.0` | ~half a tile |
| `target_desired_distance` | `10.0` | arrival slack |
| `path_max_distance` | `100.0` | repath when shoved off |
| `radius` | `10.0` | **avoidance body**, not pathfinding |
| `neighbor_distance` | `500.0` | shrink to ~120 for crowd spacing |
| `max_neighbors` | `10` | drop to ~6 for 24 agents |
| `max_speed` | `100.0` | must be ≥ actual speed |
| `time_horizon_agents` | `1.0` | 1.0–2.0 |
| `time_horizon_obstacles` | `0.0` | 0.2 if using obstacles |
| `avoidance_enabled` | `false` | **must be true** for RVO |
| `avoidance_priority` | `1.0` | higher = others dodge you |
| `navigation_layers` | `1` | region bitmask |
| `path_postprocessing` | `0` | `CORRIDORFUNNEL`; use `EDGECENTERED` (1) for tile grids |
| `simplify_path` / `simplify_epsilon` | `false` / `0.0` | helps open-field steering |

Note the `radius` caveat, which is the difference between "agents clip corners"
and "agents path cleanly":

> `The radius of the avoidance agent. This is the "body" of the avoidance agent and not the avoidance maneuver starting radius (which is controlled by neighbor_distance). Does not affect normal pathfinding. To change an actor's pathfinding radius bake NavigationPolygon resources with a different NavigationPolygon.agent_radius property and use different navigation maps for each actor size.`

The mandatory per-frame contract:

> `After setting the target_position property, the get_next_path_position() method must be used once every physics frame to update the internal path logic of the navigation agent.`

> `The navigation system never moves the parent node of a NavigationAgent. The movement is entirely in the hands of users and their custom scripts.`
> — <https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_using_navigationagents.html>

And the guard that prevents the classic "empty path on first frame" bug — this
exact check appears in the official templates:

```gdscript
if NavigationServer2D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
    return
```

Agent script for Kangur (CharacterBody2D variant from the templates, plus an
RVO tuning that produces spacing rather than conga lines):

```gdscript
# src/entities/components/nav_agent.gd  (attached to a NavigationAgent2D child)
extends NavigationAgent2D

@export var move_speed: float = 120.0     # px/s, from MovementModel

func _ready() -> void:
    avoidance_enabled = true
    radius = 12.0
    neighbor_distance = 96.0              # < 2 tiles: only nearby bodies matter
    max_neighbors = 6                     # 24 agents -> ~144 pair checks total
    time_horizon_agents = 1.5
    time_horizon_obstacles = 0.0
    max_speed = move_speed
    avoidance_priority = 1.0
    path_postprocessing = NavigationPathQueryParameters2D.PATH_POSTPROCESSING_EDGECENTERED
    simplify_path = true
    simplify_epsilon = 2.0
```

```gdscript
# owner: Character._physics_process
func _physics_process(delta: float) -> void:
    if nav.get_navigation_map().is_valid() == false:
        return
    if NavigationServer2D.map_get_iteration_id(nav.get_navigation_map()) == 0:
        return                            # map never synchronised yet
    if nav.is_navigation_finished():
        nav.velocity = Vector2.ZERO        # stops jitter on a standing agent
        return
    var next: Vector2 = nav.get_next_path_position()
    var desired: Vector2 = global_position.direction_to(next) * movement_model.speed
    if nav.avoidance_enabled:
        nav.velocity = desired            # RVO answers via velocity_computed
    else:
        _move(desired)

func _on_velocity_computed(safe: Vector2) -> void:
    _move(safe)

func _move(v: Vector2) -> void:
    velocity = v
    move_and_slide()
```

The docs warn about the two failure modes we will actually hit:

> `The agent is stuck dancing between two positions — This is usually caused by very frequent path updates every single frame, either deliberate or by accident (e.g. max path distance set too short).`

> `The agent is backtracking sometimes — If an agent moves very fast it might overshoot the path_desired_distance check without ever advancing the path index. ... Increase the desired distances accordingly for your agent speed and update rate...`

For 24 agents at ~120 px/s, `path_desired_distance = 20` and
`path_max_distance = 100` are safely above the 2 px/tick movement, so neither
applies. But if a sprinting NPC ever exceeds ~60 px/tick (i.e. > 3600 px/s —
never for characters, only bullets), revisit. **[inference]**

**Crowd spacing for 24 agents.** The architecture's §7 targets "mean nearest
teammate distance > 48 px". RVO alone does not guarantee that; it guarantees
non-overlap at `radius`. The real separation comes from three things working
together: `radius` (hard body ~12), `neighbor_distance` (lookahead ~96),
`time_horizon_agents` (how early they yield), and the **personal goal offset**
already in §7 (±40 px). Tuning advice, marked as such:

> `The prediction time should be kept as low as possible as agents will slow down their velocities to avoid collision in that timeframe.`

Also critical, and a real footgun — the agent **must** have a target even when
you only want avoidance:

> `Note: The NavigationAgent must be supplied with a target_position attribute, even if you are only using the agent for avoidance. Otherwise, the safe_velocity received from the velocity_computed signal will always be the zero vector.`

And the honest disclaimer about clinical tests, which will bite our
`tests/simulation` invariants:

> `Note: RVO avoidance makes implicit assumptions about natural agent behavior. E.g. that agents move on reasonable passing sides that can be assigned when they encounter each other. This means that very clinical avoidance test scenarios will commonly fail. E.g. agents moved directly against each other with perfect opposite velocities will fail because the agents can not get their passing sides assigned.`

**[opinion]** Do not write a unit test that asserts two agents walking
head-on swap sides. Assert the aggregate: over 200 seeded sims, no two living
teammates overlap by more than `2*radius`, and mean nearest-teammate distance
during movement phases exceeds 48 px.

### 2.4 Synchronous path queries without an agent

For AI that wants a path once (cover search, flank route) rather than continuous
following, use the query objects — cheaper than spinning up an agent:

```
void query_path(parameters: NavigationPathQueryParameters2D,
                result: NavigationPathQueryResult2D, callback: Callable = Callable())
PackedVector2Array map_get_path(map: RID, origin: Vector2, destination: Vector2,
                                optimize: bool, navigation_layers: int = 1)
```
Signatures: <https://docs.godotengine.org/en/4.7/classes/class_navigationserver2d.html>.
`map_get_path` is the blunt synchronous call: `Returns the navigation path to
reach the destination from the origin.`

`NavigationPathQueryParameters2D` members we care about (`start_position`,
`target_position`, `map`, `navigation_layers`, `metadata_flags = 7`,
`path_postprocessing = 0`, `path_search_max_polygons = 4096`,
`excluded_regions`, `included_regions`) —
<https://docs.godotengine.org/en/4.7/classes/class_navigationpathqueryparameters2d.html>.

**Synchronous quirk you must handle:** queries made before the map's first
synchronisation return empty, silently.

> `If an agent queries a path before the navigation map synchronisation, e.g. in a _ready() function, the path might return empty. ... This is fixed by making a deferred call or using a callback e.g. waiting for the navigation map changed signal.`

`map_force_update()` exists as the immediate-sync hammer but is deprecated:

> `Deprecated: This method is no longer supported, as it is incompatible with asynchronous updates. It can only be used in a single-threaded context, at your own risk.`

And 4.5 made regions async **by default**, adding latency:

> `By default, the regions in a NavigationServer map now update asynchronously using threads to improve performance. This can cause additional delay in the update due to thread synchronisation. The asynchronous region update can be toggled with the navigation/world/region_use_async_iterations project setting.`
> — <https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.5.html>

**[opinion]** For deterministic headless battle sims, set
`navigation/world/region_use_async_iterations = false` in `project.godot` (and
`map_set_use_async_iterations(map, false)` if we create our own map). Async
region updates introduce a thread-timing dependency into what is supposed to be
a fixed-step deterministic simulation. **This is the single most important
determinism finding in this section**, and it is a 4.5+ behaviour change, so it
would not show up in older tutorials.

### 2.5 Navigation links and runtime obstacle carving (doors)

**Links** — `NavigationLink2D` is a scene node with
`start_position`, `end_position`, `bidirectional = true`, `enabled = true`,
`navigation_layers = 1`, `enter_cost = 0.0`, `travel_cost = 1.0`, and
`get_rid()`; server-side it is `link_create()` +
`link_set_start_position/end_position/map/enabled/bidirectional/navigation_layers`.
— <https://docs.godotengine.org/en/4.7/classes/class_navigationlink2d.html>

The crucial semantic for Kangur's doors:

> `A navigation link does not provide any specialized movement through the link. Instead, when an agent reaches the position of a link, game code needs to react (e.g. through area triggers) and provide means for the agent to move through the link to end up at the links other position (e.g. through teleport or animation). Without that an agent will attempt to move itself along the path of the link. You could end up with an agent walking over a bottomless pit instead of waiting for a moving platform, or walking through a teleporter and proceeding through a wall.`
> — <https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_using_navigationlinks.html>

So a link is a *pathfinding annotation*, not a door. For a 2D topdown door, do
**not** use a link — links are for teleports, ladders, jump gaps (things where
the straight line is not walkable). A door is walkable when open.

**Doors: two viable designs.**

*Design 1 — toggle a nav region (recommended).* Give each doorway its own small
`NavigationRegion2D` covering the threshold, `enabled = true` when open,
`false` when shut, and rely on the surrounding regions' edge connections.
`NavigationRegion2D.enabled`:

> `Determines if the NavigationRegion2D is enabled or disabled.`

Caveat, quoted:

> `Note: Existing paths will not be automatically updated when a region gets enabled / disabled.`
> — <https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_using_navigationregions.html>

Meaning: after toggling, agents already in flight keep their stale path —
acceptable (they walk to the door and stop), but the AI must re-issue
`target_position` (or set it again) when the door state changes for anyone
targeting through it. **[opinion]**

*Design 2 — dynamic `NavigationObstacle2D` with a radius.* Docs:

> `An avoidance obstacle is considered dynamic when its radius property is greater than zero.` … `Dynamic obstacles act as a soft please-move-away for avoidance controlled agents.`

Obstacles with `vertices` are static only:

> `Static obstacles can not change their position. They can only be warped to a new position and rebuilt from scratch. Static obstacles as a result are ill-suited for usages where the position is changed every frame, as the constant rebuild has a high performance cost.`

So: vertices-based obstacles are for **baking-time carving** (e.g. blasting a hole
in a wall), not runtime doors. Radius-based obstacles are soft and do *not* affect
pathfinding at all:

> `Avoidance does not affect the pathfinding. It should be seen as an additional option for constantly moving objects that cannot be (re)baked to a navigation mesh efficiently in order to move around them.`

**Conclusion for Kangur:** doors = per-doorway `NavigationRegion2D` toggled
`enabled`. Blast holes = re-bake (async) with `add_projected_obstruction` /
`NavigationObstacle2D.affect_navigation_mesh`. Record this in the `kangur-content`
skill so map authors do not reach for links.

---

## 3. 2D audio occlusion

### 3.1 What the nodes expose

`AudioStreamPlayer2D` properties (`<https://docs.godotengine.org/en/4.7/classes/class_audiostreamplayer2d.html>`):

| Property | Default | Notes |
|---|---|---|
| `bus: StringName` | `&"Master"` | falls back to Master if name missing |
| `max_distance: float` | `2000.0` | `Maximum distance from which audio is still hearable.` |
| `attenuation: float` | `1.0` | `The volume is attenuated over distance with this as an exponent.` |
| `area_mask: int` | **`0`** | which Area2D layers override its bus |
| `panning_strength: float` | `1.0` | scaled by project `audio/general/2d_panning_strength` (default `0.5`) |
| `volume_db` / `volume_linear` | `0.0` / — | interchangeable |
| `max_polyphony` | `1` | |
| `pitch_scale` | `1.0` | |
| `playing` | `false` | |

Two things to note.

**`area_mask` default is now 0, not 1.** This is a 4.7 breaking-behaviour change:

> `The default area_mask for AudioStreamPlayer was changed from 1 to 0 (disabled) (GH-107679). If you use the audio_bus_override feature on Area2D or Area3D, and you use the AudioStreamPlayer default area_mask (just layer 1 ticked), you will need to reset the mask to layer 1 — otherwise, the bus overrides will stop working.`
> — <https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html>

Kangur does not use `Area2D.audio_bus_override` (we route by raycast), so the
default 0 is actually what we want — it prevents a stray water/vent Area2D from
hijacking our carefully chosen occlusion bus. Verify with an assert in
`AudioDirector` that each pooled player has `area_mask == 0`. **[opinion]**

**`AudioListener2D` is optional.** By default audio is heard from the screen
centre; add a listener to follow the player camera:

> `By default, audio is heard from the screen center. This can be changed by adding an AudioListener2D node to the scene and enabling it by calling AudioListener2D.make_current() on it.`

> `Only one AudioListener2D can be current. Using make_current() will disable the previous AudioListener2D.`

For Kangur, parent an `AudioListener2D` to the camera and call `make_current()`
in `_ready()`; the camera already follows the player, so panning and attenuation
both track the listener. Without it, a 1600×900 viewport means sounds pan
relative to the window centre, which is wrong for a camera that scrolls.

### 3.2 The bus API — exact names verified

All from <https://docs.godotengine.org/en/4.7/classes/class_audioserver.html>:

```
void add_bus(at_position: int = -1)
void remove_bus(index: int)
void move_bus(index: int, to_index: int)
int  get_bus_index(bus_name: StringName) const          # -1 if missing
String get_bus_name(bus_idx: int) const
void set_bus_name(bus_idx: int, name: String)
void set_bus_send(bus_idx: int, send: StringName)
StringName get_bus_send(bus_idx: int) const
void set_bus_volume_db(bus_idx: int, volume_db: float)
void set_bus_volume_linear(bus_idx: int, volume_linear: float)
void set_bus_mute(bus_idx: int, enable: bool)
void set_bus_solo(bus_idx: int, enable: bool)

void add_bus_effect(bus_idx: int, effect: AudioEffect, at_position: int = -1)
void remove_bus_effect(bus_idx: int, effect_idx: int)
AudioEffect get_bus_effect(bus_idx: int, effect_idx: int)
int  get_bus_effect_count(bus_idx: int)
bool is_bus_effect_enabled(bus_idx: int, effect_idx: int) const
void set_bus_effect_enabled(bus_idx: int, effect_idx: int, enabled: bool)
AudioEffectInstance get_bus_effect_instance(bus_idx: int, effect_idx: int, channel: int = 0)
void swap_bus_effects(bus_idx: int, effect_idx: int, by_effect_idx: int)

AudioBusLayout generate_bus_layout() const
void set_bus_layout(bus_layout: AudioBusLayout)
int  bus_count            # property
```

**Answers to the exact questions in the brief:**

- There is **no** `AudioServer.set_bus_effect_param`. Effects are `Resource`s;
  you mutate the object you get back from `get_bus_effect(bus_idx, effect_idx)`
  (e.g. `lp.cutoff_hz = 700.0`), or keep your own reference from when you added
  it. `set_bus_effect_enabled(bus_idx, effect_idx, enabled)` exists — it toggles
  the whole effect, it does not set a parameter.
- `AudioServer.get_bus_effect_instance(bus_idx, effect_idx, channel = 0)` exists
  and returns `AudioEffectInstance`. It is **not** the way to change parameters —
  its own docs say it is `automatically created by an AudioEffect when it is
  added to a bus, and should usually not be created directly.`
- `AudioServer.set_bus_effect_enabled` — correct name, 3 args. Verified
  **[verified on 4.7.2]**: returned `enabled=true` on a freshly added low-pass.

Buses added at runtime start with the name from `set_bus_name` only; ordering
matters because routing goes right→left:

> `The rest of the audio buses can be flexibly routed. After modifying the sound, they send it to another bus to the left. The destination bus can be specified for each of the non-master audio buses. Routing always passes audio from buses on the right to buses further to the left. This avoids infinite routing loops.`
> — <https://docs.godotengine.org/en/4.7/tutorials/audio/audio_buses.html>

Also useful: buses auto-disable when silent (`Godot detects that the bus has been
silent for a few seconds and disables it (including all effects)`), and renaming
a bus breaks player references:

> `Stream Players use bus names to identify a bus, which allows adding, removing and moving buses around while the reference to them is kept. However, if a bus is renamed, the reference will be lost and the Stream Player will output to Master.`

So our bus names are effectively a contract. Hardcode them as `const
StringName` in one file, never rename casually.

### 3.3 The filter and EQ resources

`AudioEffectLowPassFilter` inherits `AudioEffectFilter`:
<https://docs.godotengine.org/en/4.7/classes/class_audioeffectlowpassfilter.html> —
`A "low-pass" filter attenuates frequencies higher than AudioEffectFilter.cutoff_hz and allows lower frequencies to pass unchanged. This filter can be used to muffle sounds.`

`AudioEffectFilter` parameters (<https://docs.godotengine.org/en/4.7/classes/class_audioeffectfilter.html>):

```
float cutoff_hz = 2000.0     # range 1..20500
FilterDB db = 0              # FILTER_6DB/12DB/18DB/24DB
float gain = 1.0             # shelf filters only; range 0..4
float resonance = 0.5        # range 0..1
```

Setter names on the resource are `set_cutoff`, `set_db`, `set_gain`,
`set_resonance` (property assignment is the idiomatic form).

`AudioEffectEQ` / `AudioEffectEQ6/10/21`
(<https://docs.godotengine.org/en/4.7/classes/class_audioeffecteq.html>):

```
int   get_band_count() const
float get_band_gain_db(band_idx: int) const
void  set_band_gain_db(band_idx: int, volume_db: float)
```

**[opinion]** Use `AudioEffectEQ6` + low-pass for the heavy-occlusion bus if
gunshots through two walls sound "underwater" rather than "distant". A 6-band EQ
with a gentle high-shelf cut plus the low-pass gives a more physical result than
low-pass alone. Keep the EQ out of the light-occlusion bus; it does not need it.

### 3.4 The occlusion pipeline for Kangur (§9 restated as code)

Architecture §9 already specifies: buses `Master → Music, SFX, Voice`, with
`SFX_Open, SFX_Light, SFX_Heavy, SFX_Muffled` children and cutoffs
20500/4200/1300/550 Hz, gains 0/−4/−9/−14 dB. That is a sound design, and this
section just proves the API supports it.

Build the buses **once**, in `AudioDirector._ready()`, from a single table so the
numbers live in one place. Author the same layout in the editor's Audio panel and
commit `res://default_bus_layout.tres` — the docs say the layout is saved there
automatically — so a sound designer can edit it without touching code. The code
below is the "bus is missing → create it" fallback; the
`get_bus_index(name) != -1` guard lets both paths coexist:

> `The default bus layout is automatically saved to the res://default_bus_layout.tres file. Custom bus arrangements can be saved and loaded from disk.`
> — <https://docs.godotengine.org/en/4.7/tutorials/audio/audio_buses.html>

```gdscript
# src/audio/audio_director.gd
extends Node

## Order matters: a bus can only send to a bus that already exists to its LEFT.
const BUS_TABLE: Array[Dictionary] = [
    {"name": &"SFX",          "send": &"Master", "db":   0.0, "cutoff": 20500.0},
    {"name": &"Music",        "send": &"Master", "db":  -6.0, "cutoff": 20500.0},
    {"name": &"Voice",        "send": &"Master", "db":  -3.0, "cutoff": 20500.0},
    {"name": &"SFX_Open",     "send": &"SFX",    "db":   0.0, "cutoff": 20500.0},
    {"name": &"SFX_Light",    "send": &"SFX",    "db":  -4.0, "cutoff":  4200.0},
    {"name": &"SFX_Heavy",    "send": &"SFX",    "db":  -9.0, "cutoff":  1300.0},
    {"name": &"SFX_Muffled",  "send": &"SFX",    "db": -14.0, "cutoff":   550.0},
]

var _bus_index: Dictionary = {}          # StringName -> int
var _lowpass: Dictionary = {}            # StringName -> AudioEffectLowPassFilter
var _headless: bool = false

func _ready() -> void:
    _headless = DisplayServer.get_name() == "headless"
    _build_buses()

func _build_buses() -> void:
    # Create the SFX parent first so children can send to it.
    for entry in BUS_TABLE:
        var name: StringName = entry["name"]
        if AudioServer.get_bus_index(name) != -1:
            continue                                   # already in default_bus_layout
        AudioServer.add_bus(-1)
        var idx: int = AudioServer.bus_count - 1
        AudioServer.set_bus_name(idx, name)
        AudioServer.set_bus_send(idx, entry["send"])
        AudioServer.set_bus_volume_db(idx, entry["db"])
        _bus_index[name] = idx
        if entry["cutoff"] < 20500.0:
            var lp := AudioEffectLowPassFilter.new()
            lp.cutoff_hz = entry["cutoff"]
            lp.resonance = 0.5
            lp.db = AudioEffectFilter.FILTER_12DB
            AudioServer.add_bus_effect(idx, lp, 0)
            _lowpass[name] = lp
```

Routing a sound by wall count (the `OcclusionMath` static in §4 of the
architecture):

```gdscript
# src/audio/occlusion_math.gd
class_name OcclusionMath
extends RefCounted

## Wall count -> bus + distance budget. Pure; no nodes, no audio.
static func bus_for_walls(walls: int) -> StringName:
    match walls:
        0: return &"SFX_Open"
        1: return &"SFX_Light"
        2: return &"SFX_Heavy"
        _: return &"SFX_Muffled"

static func volume_offset_for_walls(walls: int) -> float:
    return 0.0 if walls == 0 else -3.0 * float(walls)

static func max_distance_for(loudness: float) -> float:
    return clampf(loudness * 400.0, 200.0, 4000.0)
```

Counting walls — one ray per candidate, `SOUND_MASK` per §2 = `WORLD | GLASS`
(low cover explicitly does **not** block sound, and glass counts as exactly one
wall before it shatters):

```gdscript
# src/audio/audio_director.gd (cont.)
const SOUND_MASK: int = Layers.WORLD_BIT | Layers.GLASS_BIT

func _count_walls(from: Vector2, to: Vector2) -> int:
    if _headless:
        return 0                                # no space state needed headless
    var space := get_viewport().world_2d.direct_space_state
    var count := 0
    var origin := from
    # March one ray per wall; cap at 3 (3 walls => muffled regardless).
    for i in 3:
        var q := PhysicsRayQueryParameters2D.create(origin, to, SOUND_MASK)
        q.collide_with_areas = false
        q.hit_from_inside = false
        var hit := space.intersect_ray(q)
        if hit.is_empty():
            break
        count += 1
        # Glass contributes exactly one wall, then the ray continues through it.
        # Low cover is not in SOUND_MASK at all, so it never appears here.
        origin = hit.position + (to - from).normalized() * 1.0
    return count
```

**Constraint on `_count_walls`: space-state access belongs in `_physics_process`.**
`World2D.direct_space_state` is documented as `When using multi-threaded
physics, access is limited to Node._physics_process() in the main thread.` A
`sound_emitted` signal can fire from `_process`, an animation callback, or a
deferred call. Safer: **queue the request** and drain it at the top of the next
`_physics_process`, or emit `sound_emitted` only from gameplay code that is
already in the physics tick (which §5's "listeners must be cheap" implies
anyway). **[opinion — the queue is 5 lines and removes a whole class of "works
until you enable threaded physics" bugs]**

**Cost check [inference].** One sound event per gunshot with 3 rays worst case,
24 NPCs firing at ~600 rpm worst case would be far too many. But `sound_emitted`
is only rendered for the player, one event at a time, and the AI's hearing math
is separate (`Perception`, no rendering — per §9). So the raycast budget is
bounded by "sounds audible to the player this tick", realistically < 20. Fine.

Note the space-state accessor: `AudioDirector` extends `Node`, so
`get_world_2d()` (a `CanvasItem` method, `Returns the World2D this node is
registered to.`) is **not** available. Use the `Viewport` property instead:
`World2D world_2d` on `Viewport`
(<https://docs.godotengine.org/en/4.7/classes/class_viewport.html>,
<https://docs.godotengine.org/en/4.7/classes/class_canvasitem.html>). Inside a
`Node2D` (e.g. `ProjectileSystem`, §4.3) `get_world_2d()` is the shorter form.

Pooled players, so a firefight does not allocate:

```gdscript
# src/audio/audio_director.gd (cont.)
const POOL_SIZE := 32
var _pool: Array[AudioStreamPlayer2D] = []

func _make_pool() -> void:
    for i in POOL_SIZE:
        var p := AudioStreamPlayer2D.new()
        p.area_mask = 0                     # 4.7 default; do not inherit Area2D buses
        p.attenuation = 1.6
        p.max_distance = 2000.0
        p.panning_strength = 1.0
        add_child(p)
        _pool.append(p)

func _take_player() -> AudioStreamPlayer2D:
    for p in _pool:
        if not p.playing:
            return p
    return _pool[0]                          # steal oldest
```

**Moving sources.** Footsteps are one-shots and need nothing. Equipment loops
(grenade fuse hiss, generator hum) must be re-evaluated, but *not* by raycasting
every tick — that is wasted work and causes bus chatter. **[opinion]** Re-evaluate
on a 4 Hz timer (or on zone change), set `position` every tick, and change `bus`
only when the wall count actually changes:

```gdscript
func _on_sound_emitted(pos: Vector2, loudness: float, kind: StringName,
                       source: Node, surface: int) -> void:
    if _headless:
        return
    var listener := _listener_pos()
    var max_d := OcclusionMath.max_distance_for(loudness)
    if listener.distance_to(pos) > max_d:
        return
    var walls := _count_walls(listener, pos)
    var p := _take_player()
    p.stream = _stream_for(kind, surface)
    p.global_position = pos
    p.max_distance = max_d
    p.bus = OcclusionMath.bus_for_walls(walls)
    p.volume_db = OcclusionMath.volume_offset_for_walls(walls)
    p.play()
```

Note `panning_strength` is *multiplied* by the project setting, so leaving the
project default at `0.5` and the node at `1.0` gives a total of 0.5 — a
deliberately gentle pan. If the mix sounds mono-ish, raise the project setting,
not the per-node one. **[inference from the property description]**

### 3.5 Headless safety — verified behaviour

**[verified on 4.7.2]** In `--headless`:

- `AudioServer.get_driver_name()` → `Dummy`
- `AudioServer.bus_count` → `1`
- `add_bus` / `set_bus_name` / `set_bus_send` / `add_bus_effect` all succeed
- `get_bus_index(&"HeavyOccluded")` → `1`
- `get_bus_effect_count(idx)` → `1`, `get_bus_effect(idx,0)` → the
  `AudioEffectLowPassFilter`, `is_bus_effect_enabled` → `true`
- `get_bus_effect_instance(idx, 0)` → non-null

So **the audio *graph* works headless; only output is null.** The docs confirm
the driver swap: `--headless` / `Also automatically sets the audio driver to
Dummy.` (<https://docs.godotengine.org/en/4.7/classes/class_audioserver.html>,
`get_driver_name`).

**[opinion]** Two implications, and they argue against a blanket "no-op when
headless" in `AudioDirector`:

1. `AudioDirector` should still build its buses headless, so a headless test can
   assert bus layout (a real, cheap regression test for a file that is otherwise
   hard to test). Only *playback* should no-op.
2. The bus-building code must not crash without an audio device — verified it
   does not.

Guard playback, not construction:

```gdscript
func _play(...) -> void:
    if _headless:
        return                 # no output, but buses/params already validated above
```

And never gate gameplay on audio: `sound_emitted` fires regardless, so AI
hearing is unaffected (already §9's rule, now empirically justified).

The `AudioServer` docs also warn `get_output_latency()` `can be expensive; it is
not recommended to call [it] every frame` — do not put it in a debug overlay
that updates per frame.

---

## 4. Fast projectile ballistics in 2D

### 4.1 Why the naive approach fails (proven, not assumed)

At 4000–9000 px/s and 60 Hz, a bullet moves **67–150 px per tick**. Wall
colliders are 1–2 tiles thick (~32–64 px). Any scheme that only asks "is the
bullet inside a wall *now*" misses most impacts.

**[verified on 4.7.2]** Probe: 2 px-thick `StaticBody2D` wall at x=300, bullet
traveling 8000 px/s (133.3 px/tick):

```
P3 tick 1 NO HIT pos=(153.0, 100.0)   point-overlap at end pos: 0 hits
P3 tick 2 NO HIT pos=(287.0, 100.0)   point-overlap at end pos: 0 hits   <-- passes through wall
P3 tick 3 HIT at (299.0, 100.0) normal=(-1.0, 0.0) collider=StaticBody2D
```

At tick 2 the bullet's end position (x=287) is 13 px *before* the wall and the
next segment (286→420) crosses it entirely. A point/Area2D overlap test at the
end position reports **0 hits** — the wall is never detected. The raycast
against the *segment* catches it at x=299. This is exactly the failure mode
`AGENTS.md` calls out ("never Area2D-overlap-only"), now with a reproducible
demonstration.

### 4.2 The query APIs, exact

`PhysicsDirectSpaceState2D`
(<https://docs.godotengine.org/en/4.7/classes/class_physicsdirectspacestate2d.html>):

```
Dictionary        intersect_ray(parameters: PhysicsRayQueryParameters2D)
Array[Dictionary] intersect_shape(parameters: PhysicsShapeQueryParameters2D, max_results: int = 32)
Array[Vector2]    collide_shape(parameters: PhysicsShapeQueryParameters2D, max_results: int = 32)
PackedFloat32Array cast_motion(parameters: PhysicsShapeQueryParameters2D)
Dictionary        get_rest_info(parameters: PhysicsShapeQueryParameters2D)
Array[Dictionary] intersect_point(parameters: PhysicsPointQueryParameters2D, max_results: int = 32)
```

`intersect_ray` returns (`If the ray did not intersect anything, then an empty
dictionary is returned instead.`):

```
collider, collider_id, normal, position, rid, shape
```
plus: `normal: The object's surface normal at the intersection point, or
Vector2(0, 0) if the ray starts inside the shape and
PhysicsRayQueryParameters2D.hit_from_inside is true.`

`PhysicsRayQueryParameters2D`
(<https://docs.godotengine.org/en/4.7/classes/class_physicsrayqueryparameters2d.html>):

```
bool collide_with_areas = false
bool collide_with_bodies = true
int  collision_mask = 4294967295
Array[RID] exclude = []
Vector2 from = Vector2(0, 0)
Vector2 to = Vector2(0, 0)
bool hit_from_inside = false

static PhysicsRayQueryParameters2D create(from: Vector2, to: Vector2,
        collision_mask: int = 4294967295, exclude: Array[RID] = [])
```

`PhysicsShapeQueryParameters2D` adds `shape: Resource`, `shape_rid: RID`,
`transform: Transform2D`, `motion: Vector2`, `margin: float`,
`collide_with_areas/bodies`
(<https://docs.godotengine.org/en/4.7/classes/class_physicsshapequeryparameters2d.html>).

**`cast_motion` semantics** — this is the one that is easy to misread:

> `Returns an array with the safe and unsafe proportions (between 0 and 1) of the motion. The safe proportion is the maximum fraction of the motion that can be made without a collision. The unsafe proportion is the minimum fraction of the distance that must be moved for a collision. If no collision is detected a result of [1.0, 1.0] will be returned.`

For a *thick* projectile (shotgun pellet modelled as a 2 px circle, grenade),
`cast_motion` gives the safe fraction, then `get_rest_info` at that transform
gives `normal`/`point`. For a *point* bullet, `intersect_ray` is strictly cheaper
and gives everything we need. **[opinion]**

**Space-state access restriction** — must be inside `_physics_process`:

> `When using multi-threaded physics, access is limited to Node._physics_process() in the main thread.`
> — <https://docs.godotengine.org/en/4.7/classes/class_world2d.html>

That page also confirms the accessor: `Direct access to the world's physics 2D
space state.`

### 4.3 The design: one system, one ray per bullet per tick

Per architecture §10, `ProjectileSystem` is a single `_physics_process` that
sweeps all active bullets and owns pooled visuals. That is also the fastest
design, because:

- One ray per bullet per tick — 30 bullets = 30 rays. Negligible.
- No per-bullet `Area2D`, no `_physics_process` overhead per bullet, no
  signal fan-out, no scene-tree churn on fire.
- Deterministic order (array iteration), which the sims need.

**[opinion]** Do *not* use `Area2D` bullets. Beyond tunnelling, each `Area2D` is a
node with its own monitor list, and 30 concurrent bullets would mean 30 nodes
plus 30 `body_entered` connections — more work than 30 dictionary lookups for
strictly worse correctness.

```gdscript
# src/combat/projectile_system.gd
extends Node2D

# §2: bullet sweep = 1|2|5|6 (walls, characters, low cover, glass).
const BULLET_MASK: int = (Layers.WORLD_BIT | Layers.CHARACTER_BIT
        | Layers.LOW_COVER_BIT | Layers.GLASS_BIT)

class Bullet:
    var pos: Vector2
    var vel: Vector2
    var travelled: float = 0.0
    var max_range: float = 4096.0
    var damage: float
    var penetration: float
    var falloff_start: float
    var falloff_end: float
    var min_mult: float
    var shooter: Node
    var weapon_id: StringName
    var tracer: Line2D          # pooled visual, or null

var _active: Array[Bullet] = []
var _visual_pool: Array[Line2D] = []

func _physics_process(delta: float) -> void:
    var space := get_world_2d().direct_space_state
    var i := _active.size() - 1
    while i >= 0:
        var b := _active[i]
        var from := b.pos
        var to := from + b.vel * delta
        var q := PhysicsRayQueryParameters2D.create(from, to, BULLET_MASK)
        q.collide_with_areas = false        # walls + bodies only
        q.hit_from_inside = false
        if b.shooter != null:
            q.exclude = [b.shooter.get_rid()]     # never hit your own body
        var hit := space.intersect_ray(q)
        if hit.is_empty():
            b.pos = to
            b.travelled += from.distance_to(to)
            if b.travelled >= b.max_range:
                _retire(i)
            i -= 1
            continue

        b.pos = hit.position
        _resolve_hit(b, hit)
        # Penetration: continue from just past the surface, with reduced damage.
        if b.penetration > 0.0 and _try_penetrate(b, hit):
            b.pos = hit.position + (to - from).normalized() * 1.0
            i -= 1
            continue
        _retire(i)
        i -= 1

func _resolve_hit(b: Bullet, hit: Dictionary) -> void:
    var mult := _falloff(b)
    var normal: Vector2 = hit.normal
    var pos: Vector2 = hit.position
    if hit.collider is CharacterBody2D:
        EventBus.character_hit.emit(hit.collider, b.shooter, 0,
                b.damage * mult, false, pos)
    else:
        # Wall/tile: surface type for decals + impact sound.
        var surface: int = world.surface_at(pos)
        EventBus.bullet_impact.emit(pos, normal, surface, false)

func _falloff(b: Bullet) -> float:
    if b.travelled <= b.falloff_start:
        return 1.0
    if b.travelled >= b.falloff_end:
        return b.min_mult
    var t := (b.travelled - b.falloff_start) / (b.falloff_end - b.falloff_start)
    return lerpf(1.0, b.min_mult, t)
```

Notes on that code, tying back to §4.2:

- `q.exclude = [b.shooter.get_rid()]` — `exclude` is `Array[RID]` and the docs
  say `Use CollisionObject2D.get_rid() to get the RID`. Note the doc warning:
  `The returned array is copied and any changes to it will not update the
  original property value.` — assigning a fresh array (as above) is correct;
  `q.exclude.append(x)` would silently do nothing.
- `hit.collider is CharacterBody2D` is the cheap discriminator because §3 says
  characters are `CharacterBody2D`. Walls are `StaticBody2D` (TileMapLayer
  generates those), glass would be its own layer or a custom-data flag.
- `b.pos = hit.position` then `_retire` — the impact point is recorded exactly;
  no "bullet ends up inside the wall" frames.

### 4.4 Collision masks: walls vs characters vs low cover vs glass

Architecture §2 (current) is:

> `bullet sweep 1|2|5|6` … walls=1, character=2, LOW_COVER=5, GLASS=6
> `GLASS | windows: blocks movement, 1-wall sound, NOT vision; penetrable, shatters after 2 hits`
> `LOW_COVER | crates/cars/sandbags: blocks movement+bullets, NOT sound; vision stance-conditional`

So the mask is `BULLET_MASK = WORLD | CHARACTER | LOW_COVER | GLASS`
(`Layers.BULLET_MASK` already encodes exactly this — use the constant, not a
literal). Glass is a **separate layer**, not a `penetrable` flag on WORLD, and
that is the better design: it lets glass be a distinct `TileData` entity with its
own hit counter, and it keeps vision rays able to *filter* glass hits (`glass
passes`) without also re-filtering plain walls.

Keep `penetrable: bool` on the tile custom data for genuinely penetrable
**walls** (thin drywall, fences); use the GLASS layer for windows. They are
different mechanics:

```gdscript
func _try_penetrate(b: Bullet, hit: Dictionary) -> bool:
    if hit.collider is CharacterBody2D:
        b.damage *= 0.75                 # body shots bleed energy
        return b.penetration >= 1.0
    var layer: int = (hit.collider as CollisionObject2D).collision_layer
    if layer & Layers.GLASS_BIT:
        # Glass always lets the bullet through, and records a hit for shattering.
        glass_registry.register_hit(hit.position)
        b.damage *= 0.7
        return true
    if layer & Layers.LOW_COVER_BIT:
        # Crates/cars stop rifle rounds unless the weapon penetrates cover.
        if not world.is_penetrable(hit.position):
            return false
        b.damage *= 0.5
        b.penetration -= 1.0
        return b.penetration >= 0.0
    # WORLD: high walls, only penetrable if content says so.
    if not world.is_penetrable(hit.position):
        return false
    b.damage *= 0.6
    b.penetration -= 1.0
    return b.penetration >= 0.0
```

`world.is_penetrable()` is the `TileData.get_custom_data("penetrable")` helper
from §1.4 — so "can this bullet go through that wall" is answered by *content*,
not code. That is exactly rule 4 in `AGENTS.md` ("Zero hardcoded content lists").

**Note on `collision_layer` at runtime.** `intersect_ray` returns `collider`, so
`(hit.collider as CollisionObject2D).collision_layer` is a legitimate way to
distinguish layer 5 from 6 at runtime. A cheaper and equally correct alternative
is `TileMapLayer.has_body_rid(hit.rid)` plus a single custom-data lookup — one
property read instead of a tile query. **[opinion — prefer the custom-data path,
since it also gives you `surface` for the decal in the same lookup]**

### 4.5 Ricochet

`hit.normal` is all you need. `Vector2.bounce(normal)` mirrors the velocity about
the surface normal. Gate it on angle of incidence and a per-weapon/surface
ricochet chance, and **cap the number of bounces** (otherwise a bullet can ping
around a corridor for seconds and cost rays forever):

```gdscript
func _maybe_ricochet(b: Bullet, normal: Vector2) -> bool:
    if b.bounces >= 1:
        return false
    var incidence: float = absf(b.vel.normalized().dot(normal))
    if incidence > 0.35:                 # too head-on: it penetrates or stops
        return false
    b.vel = b.vel.bounce(normal) * 0.55  # energy loss
    b.damage *= 0.5
    b.bounces += 1
    return true
```

**[inference]** `incidence` here is `|dot(dir, normal)|`: 1.0 = perpendicular
impact (head-on), 0.0 = grazing. The threshold therefore rejects near-head-on
hits and allows shallow-angle ricochets, which is the physically correct way
round.

### 4.6 Performance envelope for Kangur

- Ray budget: 24 NPCs × ~10 rps sustained (bursts, not auto-spam) ≈ 240 bullets/s
  spawned; flight time across a 4096 px map at 6000 px/s ≈ 0.7 s → **~170
  concurrent bullets**, not 30. At one `intersect_ray` each per tick that is
  170 rays/tick × 60 = ~10 k rays/s. Godot 2D raycasts are cheap, but this is
  the number to profile, not "30 bullets". **[inference — arithmetic, must be
  measured with `--print-fps`/profiler on a real map]**
- Mitigations if it bites: cap `max_range` (already), retire on first wall hit
  unless penetrating, and skip the ray entirely for bullets whose segment stays
  inside a "no geometry" coarse grid cell. **[opinion — do not build this until
  measured]**
- Tracers must be pooled `Line2D`s (or a single `MultiMesh`/`_draw()` batch), not
  one `Line2D` per bullet. §10 already says "pooled tracer".

---

## 5. Testing frameworks

### 5.1 Current versions and 4.7 support (checked 2026-11-17)

| | GUT (bitwes/Gut) | gdUnit4 (MikeSchulze/gdUnit4) |
|---|---|---|
| Latest stable release | **v9.7.1** (2026-07-10) | **v6.2.3** (2026-11-01) |
| `master` / next line | `godot_4_7` branch = 9.7.1 | `master` = **7.0.0** (plugin.cfg) |
| Godot 4.7 support | 9.7.x is **the 4.7.x line** | v6.2.x lists 4.7, 4.7.1; master lists 4.7, 4.7.1, 4.8.dev7 |
| Godot 4.7.2 | **[verified on 4.7.2]** works | v6.2.3 **[verified]** with flag; 7.0.0 **[verified]** plain |
| Headless CLI | yes, works | v6.2.3 **refuses** without `--ignoreHeadlessMode`; 7.0.0 works |
| Mock / spy | doubles, partial doubles, stubbing, spies | `mock()`, `spy()`, `verify()` |
| Scene runner | yes (`add_child_autofree` + manual frames) | yes (`scene_runner`, `simulate_frames`, input sim) |
| JUnit XML | yes (`-gjunit_xml_file`) | yes (`results.xml` + HTML report) |
| Exit codes | 0 pass / 1 any fail (**[verified]**) | 0 pass / 100 fail / 101 warnings (**[verified]**) |

GUT's own README dates the line explicitly:

> `9.7.1 (godot_4_7 branch) — 4.7.x`
> `Main Branch — 4.6.x`
> `9.6.1 — 4.6.x`
> — <https://github.com/bitwes/Gut/blob/main/README.md>

And its 4.7 compatibility issue explains the real breakage (return-type
enforcement in doubles), resolved in 9.7.0:

> `Godot has become more strict with function return types. In previous versions you could return null in overriden methods. This is no longer possible. ... A new static class called GutConstants has been introduced ... If a function has a defined return type and has not been stubbed, these values will be returned.`
> — <https://github.com/bitwes/Gut/issues/816>

That is a behavioural caveat worth knowing: on 4.7, an unstubbed double method
returning `int` yields `0`, not `null`. Tests that relied on `null` will need
updating.

gdUnit4's README table:

> `master (v7.0.0) — v4.7, v4.7.1, v4.8.dev7`
> `v6.2.x — v4.5, v4.5.1, v4.5.2, v4.6, v4.6.1, v4.6.2, v4.6.3, v4.7, v4.7.1`
> — <https://github.com/MikeSchulze/gdUnit4/blob/master/README.md>

### 5.2 The headless conflict (this decides the recommendation)

This is the finding that matters and that no comparison blog would tell you.

**gdUnit4 v6.2.3** (the current *stable* release) aborts in `--headless`:

```
Headless mode is not supported!
Please note that tests that use UI interaction do not work correctly in headless mode.
Godot 'InputEvents' are not transported by the Godot engine in headless mode and therefore
have no effect in the test!
You can run with '--ignoreHeadlessMode' to swtich off this check.
Abnormal exit with 103
```
— **[verified on 4.7.2]**, gdUnit4 6.2.3

With `--ignoreHeadlessMode` it runs fine (**[verified]**: 2/2 tests, exit 100 on
failure as documented). Its docs still say the flag is a no-op:

> `The option --ignoreHeadlessMode is deprecated and has no effect anymore, headless mode is supported by default.`
> — <https://github.com/MikeSchulze/gdUnit4/blob/master/documentation/doc/_advanced_testing/cmd.md>

So **the documentation and the released v6.2.3 binary disagree.** The docs
describe `master` (7.0.0). **[verified]** 7.0.0 runs headless with no flag and
prints a sane warning instead of aborting:

```
Running in headless mode, Godot does not render anything.
Tests that depend on rendered output, e.g. screenshots or viewport textures, will not work.
```

**GUT v9.7.1** runs headless with no flag and no special option
(**[verified]**: 250-test bench, exit 0; failing suite, exit 1).

Also note: **both** frameworks need an `--import` pass before their first
headless run. GUT fails loudly and correctly:

```
ERROR: Some GUT class_names have not been imported.  Please restart the Editor or run godot --headless --import
Missing class_names: ["GutErrorTracker", ... "GutTest", ...]
```
— **[verified on 4.7.2]**; after `godot --headless --path . --import` it ran.

gdUnit4 7.0.0 without the import pass **segfaulted** (`timeout: monitowane
polecenie zrobiło zrzut pamięci`); after `--import` it ran cleanly. That is a
meaningful robustness difference in a CI pipeline: GUT tells you what is wrong,
gdUnit4 crashed. **[verified on 4.7.2]**

### 5.3 Headless CLI invocations (verbatim, both verified)

GUT:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests/unit -ginclude_subdirs -gexit -glog=1
```
> `godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd`
> `When running from command line, 0 will be returned if all tests pass and 1 will be returned if any fail (pending doesn't affect the return value).`
> — <https://gut.readthedocs.io/en/latest/Command-Line.html>

Other GUT flags we will use (`-gh` output, same page): `-gtest=` full path to
one script, `-gselect=` filename substring, `-gunit_test_name=` substring,
`-gexit_on_success`, `-gjunit_xml_file=`, `-gconfig=` to bypass
`res://.gutconfig.json`, `-gdouble_strategy=SCRIPT_ONLY|INCLUDE_NATIVE`.

gdUnit4:

```bash
godot --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
      res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit
```
(the `--remote-debug` form is the one gdUnit4 documents; the bare
`-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd` form also works — **[verified]**)

> `godot --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test`
> `0 = all tests success / 100 = ends with test failures / 101 = ends with test warnings`
> — <https://github.com/MikeSchulze/gdUnit4/blob/master/documentation/doc/_advanced_testing/cmd.md>

Other gdUnit4 flags: `-a` (add dir/suite, repeatable), `-i` (ignore
`SuiteName` or `SuiteName:test_name`), `-c/--continue` (default is fail-fast —
`By default GdUnit will abort on first test failure`), `-conf`, `-rd` report dir
(default `res://reports/`), `-rc` report count.

**[verified on 4.7.2]** The long forms work too — the command already written in
`AGENTS.md` runs unchanged, so it does not need rewriting:

```bash
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/unit
```

(`--add` is accepted as an alias of `-a` and bare relative paths resolve against
`res://`, though `-a res://tests/unit` is the form the docs use.) The one thing
that command is missing is `--import` before it, per §5.2.

Note the `-c` default is **fail-fast**, which is wrong for a `tools/verify.sh`
gate that should report all failures at once. Pass `-c`.

### 5.4 Test discovery

- GUT: scans `-gdir` for files matching `-gprefix` (default `test_`) and
  `-gsuffix` (default `.gd`), with `-ginclude_subdirs`. So `tests/unit/test_*.gd`.
- gdUnit4: `-a <directory>` scans recursively; suite files must `extends
  GdUnitTestSuite` and be named `*Test.gd` by convention (configurable template).

**[opinion]** For Kangur, name suites `*_test.gd` and keep them under
`tests/unit/<module>/`, mirroring `src/`. Both frameworks can be configured to
that; do not mix conventions.

### 5.5 Performance for hundreds of simulation tests — measured

Benchmark: 250 test cases, each running a 300-tick pure-model loop
(`x += v*dt; v *= 0.999`), i.e. 75 000 model ticks total. Same workload, both
frameworks, headless, 4.7.2, warm cache:

| Framework | Framework-reported time | Wall clock (process start → exit) |
|---|---|---|
| GUT 9.7.1 | **0.404 s** | **1 629 ms** |
| gdUnit4 7.0.0 | **707 ms** | **2 408 ms** |

**[verified on 4.7.2]**, single run each — treat as order-of-magnitude, not a
precise ratio. Both are comfortably fast enough: even at ~1.6–2.4 s of process
overhead, a thousand pure-logic tests is seconds, and the per-test cost of the
model loop dominates in real suites. The delta is mostly framework startup
(gdUnit4 installs session hooks and writes HTML+XML reports by default).

The relevant conclusion is that **neither framework will be the bottleneck for
thousands of pure-logic tests**; the bottleneck will be scene-tree tests, which
is why §11's "pure models in RefCounted" design matters more than the framework
choice. **[inference]**

### 5.6 Recommendation

**gdUnit4 v7.0.0 is the pick — conditional on using the 7.0.0 line from the
start, not v6.2.3.**

Reasons, in order of weight:

1. **Scene runner is materially better suited to Kangur's UI work.** gdUnit4's
   `scene_runner()` + `simulate_frames()` + input simulation is one API;
   it can drive mouse/keyboard/action input and wait on signals or return values,
   which is exactly the `tools/verify.sh` "menu flow smoke test" in §11. GUT's
   `Simulate` helpers exist but the ergonomics are visibly older.
   > `Simulate different kinds of inputs and actions: Mouse clicks and movements, Keyboard inputs, Touch screen interactions, Custom input actions, Wait for specific signals or function return values.` — gdUnit4 README
2. **`mock`/`spy`/`verify` are first-class**, with explicit modes
   (`RETURN_DEFAULTS`, `CALL_REAL_FUNC`) and `do_return(...).on(x).method()`.
   GUT's doubles are similarly capable, so this is a tie, not a win.
3. **Reporting**: gdUnit4 emits HTML *and* JUnit XML by default with a report
   directory; GUT needs `-gjunit_xml_file`. Minor, but free.
4. **Failure exit codes are richer** (100 vs 101 for warnings), which lets
   `verify.sh` distinguish "broken" from "flaky/ignored".

Reasons against, stated honestly:

- **The stable release (6.2.3) is broken in headless without a flag, and its own
  docs say the flag is deprecated.** That is a documentation/behaviour mismatch
  in the exact mode we depend on. Using 7.0.0 sidesteps it, but 7.0.0 is the
  `master` line, not a tagged release (tags stop at v6.2.3) — it is not a
  released artifact you can pin by tag today. **[verified: tag list]**
- **gdUnit4 7.0.0 segfaulted on first run without an `--import` pass**, whereas
  GUT failed with a clear, actionable message. In CI this difference is real.
- GUT is measurably faster to start (1.6 s vs 2.4 s wall).

**[opinion] Final call for Kangur:** use **gdUnit4 7.0.0**, vendored into
`addons/gdUnit4/` and pinned by committing the exact tree (plus a note of the
upstream commit SHA, since there is no tag), because the scene runner is the
capability we will lean on for UI smoke tests and because the headless story is
clean on 7.0.0. Put `godot --headless --path . --import` as the **first** line
of `tools/verify.sh` — mandatory for any framework, and it prevents the
first-run segfault. If the 7.0.0 pin ever becomes untenable, GUT 9.7.1 is a
credible fallback with a slightly worse scene runner and a much better failure
message; the test bodies themselves port in minutes (both use
`assert_x(actual).is_equal(expected)`-ish fluent form).

That last point is the hedge that makes the recommendation low-risk: the test
*logic* is portable, so the framework is not a one-way door.

### 5.7 Pure-logic simulation tests without a scene tree

Both frameworks can run tests with no scene tree — GUT suites `extends GutTest`
(a `Node`, added to the tree by the runner but your models need nothing), gdUnit4
suites `extends GdUnitTestSuite`. The models are `RefCounted`, so:

```gdscript
# tests/unit/combat/test_weapon_model.gd
extends GdUnitTestSuite

func test_auto_fire_respects_rpm() -> void:
    var def := WeaponDef.new()
    def.rpm = 600.0                      # 10 rounds/s -> 6 ticks between shots
    def.fire_modes = [Enums.FireMode.AUTO]
    def.mag_size = 30
    var m := WeaponModel.new(def)
    var shots := 0
    var ctx := IntentCtx.new()
    ctx.fire = true
    for tick in 60:                      # one simulated second at 60 Hz
        m.tick(1.0 / 60.0, ctx)
        shots += m.try_fire().size()
    assert_int(shots).is_equal(10)
```

**Fixed-step manual simulation, not `Engine.time_scale`.** Reasons:

- `Engine.time_scale` scales delta, it does not change the tick count:
  > `The speed multiplier at which the in-game clock updates, compared to real time. ... This value affects Timer, SceneTreeTimer, and all other simulations that make use of delta time`
  > `Note: This does not automatically adjust physics_ticks_per_second. With values above 1.0 physics simulation may become less precise, as each physics tick will stretch over a larger period of engine time.`
  > — <https://docs.godotengine.org/en/4.7/classes/class_engine.html>

  At `time_scale = 8`, each tick still runs at 60 Hz wall-clock but represents
  8/60 s of game time — so a "fast-forwarded" sim is *not* the same simulation,
  it is a coarser one. For determinism that is fatal.

  **[verified on 4.7.2]** Measured directly: with `Engine.time_scale = 8.0`,
  60 `_physics_process` ticks took **1.001 s wall clock** and their deltas summed
  to **8.000 s** (`avg_delta = 0.13333` = 8/60). So `time_scale` changed *only*
  the size of each step; it did **not** make ticks happen faster. It is not a
  fast-forward, it is a different simulation. Do not reach for it in the sim
  harness — it buys no speed and destroys the baseline comparison.

- Instead, drive the models directly in a loop with a fixed `dt`, as above. No
  `SceneTree`, no `_physics_process`, no rendering — thousands of iterations per
  second. This is the same mechanism §11 already describes ("manual
  fast-forward ... tick loop without rendering waits"). The `Engine.max_physics_steps_per_frame = 8` cap
  (`The maximum number of physics steps that can be simulated each rendered
  frame.`) would otherwise silently slow a scene-tree-based fast-forward.

**[opinion]** For full-match sims that genuinely need scene-tree nodes (physics
for bullets, nav for agents), run a `SceneTree` script that calls
`_physics_process`-equivalent stepping manually and set
`Engine.max_physics_steps_per_frame` high; but keep the *decisions* in pure
models so most invariants are testable without any of that.

### 5.8 Determinism: seeding `RandomNumberGenerator`

`RandomNumberGenerator` (<https://docs.godotengine.org/en/4.7/classes/class_randomnumbergenerator.html>):

```
int seed = 0        # set_seed(value: int) / get_seed()
int state = 0       # set_state(value: int) / get_state()
void randomize()
int   randi()
int   randi_range(from: int, to: int)
float randf()
float randf_range(from: float, to: float)
float randfn(mean: float = 0.0, deviation: float = 1.0)
int   rand_weighted(weights: PackedFloat32Array)
```

Two warnings from the docs that matter for reproducibility:

> `Note: Setting this property produces a side effect of changing the internal state, so make sure to initialize the seed before modifying the state: var rng = RandomNumberGenerator.new(); rng.seed = hash("Godot"); rng.state = 100`

> `Note: Do not set state to arbitrary values, since the random number generator requires the state to have certain qualities to behave properly. It should only be set to values that came from the state property itself. To initialize the random number generator with arbitrary input, use seed instead.`

> `Note: The RNG does not have an avalanche effect, and can output similar random streams given similar seeds. Consider using a hash function to improve your seed quality if they're sourced externally.`

That third note is why `rng.seed = seed` with a user-supplied small integer is a
bad idea — seeds 1, 2, 3 produce visibly correlated streams. Hash first:

```gdscript
# src/core/deterministic_rng.gd
class_name DeterministicRng
extends RefCounted

## One RNG per subsystem, all derived from the match seed (§10).
static func for_subsystem(match_seed: int, tag: StringName) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash("%d|%s" % [match_seed, tag])
    return rng
```

Then: `var ai_rng := DeterministicRng.for_subsystem(cfg.seed, &"ai")`,
`&"ballistics"`, `&"personality"`, `&"spawn"` — never a shared global RNG, or
adding one call in one system shifts every other system's stream and every
baseline metric in `reports/sim/` becomes incomparable. **[opinion — this is the
single highest-leverage determinism rule for the sim harness]**

For test *isolation*, gdUnit4 offers a seed-reset helper; but for pure models,
constructing `DeterministicRng` per test is clearer and framework-independent.

---

## 6. Viewport screenshots for automated UI verification

### 6.1 The core call, and the only safe place to make it

```
ViewportTexture get_texture() const
```
> `Returns the viewport's texture.`
> `Note: When trying to store the current texture (e.g. in a file), it might be completely black or outdated if used too early, especially when used in e.g. Node._ready(). To make sure the texture you get is correct, you can await RenderingServer.frame_post_draw signal.`
> — <https://docs.godotengine.org/en/4.7/classes/class_viewport.html>

Official snippet (verbatim):

```gdscript
func _ready():
    await RenderingServer.frame_post_draw
    $Viewport.get_texture().get_image().save_png("user://Screenshot.png")
```

> `Note: When use_hdr_2d is true the returned texture will be an HDR image using linear encoding.`

Kangur uses GL Compatibility with no HDR 2D, so `get_image()` is fine as-is.

### 6.2 Headless: confirmed unusable, and it *hangs*

`--headless` means `--display-driver headless --audio-driver Dummy`:

> `--headless — Enable headless mode (--display-driver headless --audio-driver Dummy). Useful for servers and with --script.`
> — <https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html>

**[verified on 4.7.2]**, three separate observations:

1. `await RenderingServer.frame_post_draw` **never returns**. The process hung
   until `timeout` killed it (exit 124). It does not raise, error, or return an
   empty image — it simply never signals.
2. Without the await, `get_viewport().get_texture().get_image()` returns an
   **empty** image: `P2 immediate_empty=true size=(0, 0)`, and the viewport rect
   is `S: (64.0, 64.0)` while `DisplayServer.window_get_size()` is `(0, 0)`.
3. An engine error is printed once: `ERROR: Parameter "t" is null.`

gdUnit4's docs state the same, independently:

> `In headless mode Godot does not render anything, so tests that depend on rendered output do not work. A viewport texture returns an empty image and the signal RenderingServer.frame_post_draw is never emitted.`
> — <https://github.com/MikeSchulze/gdUnit4/blob/master/documentation/doc/_advanced_testing/cmd.md>

**Therefore the screenshot harness must detect headless and fail fast**, not
hang. `DisplayServer.get_name()` returns `"headless"` (**[verified]**:
`PROBE display=headless driver=Dummy`), which is the reliable check. gdUnit4's
own example uses exactly that predicate for skipping:

```gd
func test_scene_screenshot(_do_skip := DisplayServer.get_name() == "headless", ...)
```
— same page

### 6.3 CLI user args

```
PackedStringArray get_cmdline_user_args()
```
> `Returns the command-line user arguments passed to the engine. User arguments are ignored by the engine and reserved for the user. They are passed after the double dash -- argument. ++ may be used when -- is intercepted by another program (such as startx).`
> ```
> # godot --fullscreen --custom -- --level=2 --hardcore
> OS.get_cmdline_args()      # Returns ["--custom"]
> OS.get_cmdline_user_args() # Returns ["--level=2", "--hardcore"]
> ```
— <https://docs.godotengine.org/en/4.7/classes/class_os.html>

**[verified on 4.7.2]**: `godot --headless --path . -- --shot=1` →
`OS.get_cmdline_user_args()` = `["--shot=1"]`.

**Colon-parsing trap (found by probe, worth recording).** The architecture's
`--shot=<scene>:<frames>:<out>` format cannot be parsed with
`String.split(":")` because `res://` contains a colon:

```gdscript
"res://maps/dust.tscn:20:reports/screenshots/dust.png".split(":")
# -> ["res", "//maps/dust.tscn", "20", "reports/screenshots/dust.png"]   BROKEN

"res://maps/dust.tscn:20:reports/screenshots/dust.png".rsplit(":", true, 2)
# -> ["res://maps/dust.tscn", "20", "reports/screenshots/dust.png"]      correct
```

**[verified on 4.7.2]**. `String.rsplit(delimiter: String = "", allow_empty:
bool = true, maxsplit: int = 0)` — the `maxsplit` argument is what makes this
work (<https://docs.godotengine.org/en/4.7/classes/class_string.html>).

Also: `--shot=` may produce `res://` *or* a `uid://` path if a scene is dragged
from the editor. Use `ResourceUID.ensure_path()` to normalise:

```
String ensure_path(path_or_uid: String) static    # Returns a path, converting path_or_uid if necessary.
String uid_to_path(uid: String) static
String path_to_uid(path: String) static
```
— <https://docs.godotengine.org/en/4.7/classes/class_resourceuid.html>

### 6.4 The boot-time screenshot harness (verified end-to-end)

Design goals from §11: load a target scene, wait N frames, capture, quit with an
exit code. Run as a `SceneTree` script (not a scene) so it can be invoked with
`-s` before any `main_scene` exists.

```gdscript
# tools/screenshot_harness.gd
extends SceneTree
## godot --path . -s tools/screenshot_harness.gd -- \
##     --shot=res://src/ui/title/title_screen.tscn:20:reports/screenshots/title.png
##
## Exit codes: 0 ok, 2 cannot load scene, 3 no rendering (headless), 4 save failed.

const DEFAULT_FRAMES := 10

var _target := ""
var _frames := DEFAULT_FRAMES
var _out := ""
var _have_args := false

func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if not a.begins_with("--shot="):
            continue
        var parts := a.trim_prefix("--shot=").rsplit(":", true, 2)
        if parts.size() != 3:
            push_error("--shot expects res://scene.tscn:frames:out.png, got '%s'" % a)
            quit(2); return
        _target = ResourceUID.ensure_path(parts[0])
        _frames = maxi(1, int(parts[1]))
        _out = parts[2]
        _have_args = true

    if not _have_args:
        return                      # normal game run: do nothing, let main_scene play

    # Fail fast instead of hanging: frame_post_draw never fires without a display.
    if DisplayServer.get_name() == "headless":
        push_error("screenshot harness needs a display (DISPLAY=:0); --headless cannot render")
        quit(3)
        return

    var packed := load(_target) as PackedScene
    if packed == null:
        push_error("cannot load scene: " + _target)
        quit(2)
        return

    root.add_child(packed.instantiate())
    _capture.call_deferred()

func _capture() -> void:
    for i in _frames:
        await process_frame
    await RenderingServer.frame_post_draw

    var img: Image = root.get_texture().get_image()
    if img == null or img.is_empty():
        push_error("empty viewport image")
        quit(3)
        return

    var abs_dir := ProjectSettings.globalize_path(_out.get_base_dir())
    if abs_dir != "" and not DirAccess.dir_exists_absolute(abs_dir):
        DirAccess.make_dir_recursive_absolute(abs_dir)

    var err := img.save_png(_out)
    if err != OK:
        push_error("save_png failed (%d) for %s" % [err, _out])
        quit(4)
        return

    print("screenshot ok: %s %dx%d" % [_out, img.get_width(), img.get_height()])
    print("SHOT_OK %s %dx%d" % [_out, img.get_width(), img.get_height()])
    quit(0)
```

**[verified on 4.7.2]**, display `:0`:

```
SHOT target=res://calm.tscn frames=10 out=reports/screenshots/probe2.png
CALM ready
SHOT saved err=0 size=(444, 1548) path=reports/screenshots/probe2.png
```
The PNG existed afterwards (5 926 bytes). Note the size `(444, 1548)` is the
*window* size in that probe project (portrait-ish override), not the 640×360
viewport — i.e. `root.get_texture()` returns the whole window. For deterministic
screenshots, set the window size explicitly (`--resolution 1600x900`) or read
`get_viewport().get_visible_rect()`. **[inference from the measured values]**

**[verified]** the same harness under `--headless` no longer hangs once the
guard is in place — it exits 3 immediately (the probe without the guard hung to
a 124 timeout, which is exactly the bug the guard prevents).

Alternative for animated/`--write-movie` captures:

> `--write-movie <file> — Run the engine in a way that a movie is written (usually with .avi or .png extension). --fixed-fps is forced when enabled, but can be used to change movie FPS. --disable-vsync can speed up movie writing but makes interaction more difficult. --quit-after can be used to specify the number of frames to write.`

Useful for motion verification, not needed for static UI checks. **[opinion]**

### 6.5 Practical notes for `verify.sh`

- Run with `DISPLAY=:0` explicitly; the harness will refuse otherwise.
- `xvfb-run` is **not installed** on this machine (**[verified]**: `which
  xvfb-run` empty), so a headless-CI fallback would need `xvfb` installed or a
  real display. gdUnit4's docs suggest exactly that:
  > `Run these tests with a display, on Linux you can use a virtual display with xvfb-run, or skip them in headless mode.`
- Deterministic UI screenshots need fixed window size + fixed theme + no
  time-dependent animation. Prefer capturing at a known frame count and, for
  anything animated, at a specific `Engine.get_process_frames()` value.
- Exit codes should be checked: `quit(0)` on success is what makes
  `tools/verify.sh` usable (`Quits the application at the end of the current
  iteration, with the given exit_code.` — <https://docs.godotengine.org/en/4.7/classes/class_scenetree.html>).
- The harness prints a `SHOT_OK <path> <w>x<h>` line on success so
  `verify.sh` and the `kangur-verify` skill can grep for it without parsing
  engine noise. **[opinion]** — cheap, and it makes the gate's failure mode
  "missing token" rather than "exit code looked fine but nothing was captured".

---

## 7. Data-driven content

### 7.1 Custom Resource classes

> `Like any Object in Godot, users can also script Resources. Resource scripts inherit the ability to freely translate between object properties and serialized text or binary data (*.tres, *.res).`
> `Note: To make the new resource class appear in the Create Resource GUI you need to provide a class name for GDScript`
> — <https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html>

The docs give this exact skeleton, including the constructor requirement:

```gdscript
class_name BotStats
extends Resource

@export var health: int
@export var sub_resource: Resource
@export var strings: PackedStringArray

# Make sure that every parameter has a default value.
# Otherwise, there will be problems with creating and editing
# your resource via the inspector.
func _init(p_health = 0, p_sub_resource = null, p_strings = []):
    health = p_health
    sub_resource = p_sub_resource
    strings = p_strings
```

Our `WeaponDef` follows the same shape, and the "every parameter has a default
value" rule is the one that bites — it is why `_init()` must be callable with no
args by the Inspector.

Why Resources and not JSON, from the same page (paraphrased list): typed
properties guaranteed to exist, methods/setters for derived values, signals,
recursive sub-resources, built-in (de)serialization, editor GUI for free, and
`.tres` is version-control friendly because it is text:

> `Users can save Resources as version-control-friendly text files (*.tres). Upon exporting a game, Godot serializes resource files as binary files (*.res) for increased speed and compression.`

That last sentence matters for us: designers edit `.tres`, we ship `.res` — so
never rely on the on-disk format at runtime beyond `load()`.

### 7.2 Loading every resource in a directory (`Defs`)

`DirAccess` (<https://docs.godotengine.org/en/4.7/classes/class_diraccess.html>):

```
static PackedStringArray get_files_at(path: String)
static PackedStringArray get_directories_at(path: String)
static bool dir_exists_absolute(path: String)
static Error make_dir_recursive_absolute(path: String)
Error list_dir_begin()
String get_next()
bool current_is_dir() const
void list_dir_end()
```

Two facts that shape `Defs`:

> `Note: When used on a res:// path in an exported project, only the files actually included in the PCK at the given folder level are returned. In practice, this means that since imported resources are stored in a top-level .godot/ folder, only paths to *.gd and *.import files are returned (plus a few files such as project.godot or project.binary and the project icon). In an exported project, the list of returned files will also vary depending on whether ProjectSettings.editor/export/convert_text_resources_to_binary is true.`

This is the load-bearing caveat: **`get_files_at("res://data/weapons")` in an
export returns `*.gd` and `*.import` names — not the `.tres`** if resources were
converted to binary. The robust pattern is to enumerate `*.import` and map to the
source path, or (simpler and what I would do) **not scan at all in exported
builds** — generate an index Resource at import time and `load()` that single
file. **[opinion]**

For the editor and headless-sim workflow (which is where `Defs` matters most),
scanning is fine:

```gdscript
# src/core/defs.gd
extends Node
## Loads all *Def resources under res://data/** at boot. Contract: architecture §3.
## Missing id -> push_error + null (never crash).

var _by_kind: Dictionary = {}          # StringName -> Dictionary[StringName, Resource]

const ROOTS := {
    &"weapon":    "res://data/weapons",
    &"class":     "res://data/classes",
    &"equipment": "res://data/equipment",
    &"faction":   "res://data/factions",
    &"map":       "res://data/maps",
    &"difficulty":"res://data/difficulty",
    &"radio":     "res://data/radio",
}

func _ready() -> void:
    for kind: StringName in ROOTS:
        _by_kind[kind] = _load_dir(ROOTS[kind])

func _load_dir(root: String) -> Dictionary:
    var out := {}
    var stack: Array[String] = [root]
    while not stack.is_empty():
        var dir_path: String = stack.pop_back()
        for d in DirAccess.get_directories_at(dir_path):
            stack.push_back(dir_path.path_join(d))
        for f in DirAccess.get_files_at(dir_path):
            if not f.ends_with(".tres"):
                continue
            var res := load(dir_path.path_join(f))
            if res == null:
                push_error("Defs: failed to load %s/%s" % [dir_path, f])
                continue
            var id: Variant = res.get("id")
            if id == null or String(id).is_empty():
                push_error("Defs: %s has no id" % [dir_path.path_join(f)])
                continue
            if out.has(id):
                push_error("Defs: duplicate id '%s' (%s)" % [id, dir_path.path_join(f)])
                continue
            out[id] = res
    return out

func weapon(id: StringName) -> WeaponDef:
    var d: Dictionary = _by_kind.get(&"weapon", {})
    if not d.has(id):
        push_error("Defs: unknown weapon '%s'" % id)
        return null
    return d[id] as WeaponDef
```

The duplicate-id check is important: two designer-authored `.tres` with `id =
&"kestrel"` is a content bug that must be loud at boot, not a silent
last-one-wins. **[opinion]**

### 7.3 `ResourceUID` caveats

```
int   create_id()
int   create_id_for_path(path: String)
String path_to_uid(path: String) static
String uid_to_path(uid: String) static
String id_to_text(id: int) const
int   text_to_id(text_id: String) const
String ensure_path(path_or_uid: String) static
bool  has_id(id: int) const
```
— <https://docs.godotengine.org/en/4.7/classes/class_resourceuid.html>

Key behaviours:

> `Resource UIDs (Unique IDentifiers) allow the engine to keep references between resources intact, even if files are renamed or moved. They can be accessed with uid://.`

The 4.7 page documents `path_to_uid` as: `Converts the provided resource path to a
UID. Returns the unchanged path if it has no associated UID.` — no export
restriction is stated on that page. Practical caveats for Kangur:

- **`.tres` references to other resources are stored as `uid://` in 4.7.** If a
  designer copies a `.tres` from another project, its `uid://` references may
  resolve to nothing. `Defs`' `load()` will return `null` and log — make sure the
  error message names the file, not just the uid.
- **Never hardcode `uid://` in code.** Use `res://` paths for code references and
  let the editor manage uids inside scenes/resources. Code that uses uid paths
  breaks the moment CI regenerates `.godot/` with a different mapping.
  **[opinion]**
- `ensure_path()` is the right normaliser for CLI args (§6.3).
- `create_id_for_path(path)` is deterministic per project+path — useful if we
  ever generate resources in a tool script and want stable uids, since
  `create_id()` is random (`Generates a random resource UID`).

### 7.4 Hot-reload friendliness for designers

The realistic workflow: designer edits `data/weapons/kestrel.tres` in the
Inspector, hits save, and wants to see the change without restarting the game.
**[opinion]** Three rules make this mostly work:

1. **`Defs` holds references; the Inspector mutates the same `Resource`
   instance.** Because `load()` caches, editing a `.tres` in the editor while the
   game runs and re-`load()`-ing returns the *cached* object, not the new file.
   So add an explicit reload path for dev builds:

   ```gdscript
   # src/core/defs.gd (dev only)
   func reload_all() -> void:
       if not OS.is_debug_build():
           return
       _by_kind.clear()
       _ready()
       EventBus.match_state_changed.emit()     # let HUD/AI re-read
   ```
   Wire it to an F5-style dev key via `Dev`, not to a per-frame check.

2. **No content data cached in `const`.** Anything derived from a `Def` should be
   computed on read (or on an explicit `rebuild()`), never baked into a
   `const` at parse time. That is already the §6 contract; enforce it in review.

3. **Resource properties must be self-validating.** A `WeaponDef` with
   `mag_size = 0` should fail loudly. Use `_get_configuration_warnings()` on
   nodes, and for Resources add a `validate() -> PackedStringArray` called by
   `Defs` at load, logging warnings. **[opinion — small cost, catches the most
   common designer error before it becomes a weird runtime behaviour]**

For map authors, the analogous rule is in §1.4: a tile missing its `surface`
custom data asserts in debug, so a new tile is either authored correctly or
fails immediately rather than producing silent `CONCRETE` footsteps.

---

## 8. Godot 4.5 → 4.7 specifics that touch this project

### 8.1 TileMap / 2D

- **`TileMap` deprecated**; `TileMapLayer` is the node (4.3+). See §1.
- **4.5: `TileMapLayer.get_coords_for_body_rid()` changed meaning** because
  physics chunking became default. `To get the exact cell coordinates, you need
  to set physics_quadrant_size to 1`. Verified quote in §1.5.
- **4.7: `CanvasItem` lines no longer get an antialiasing feather**:
  > `CanvasItem now avoids adding the antialiasing feather when drawing lines (GH-105122). The feather made lines appear thicker than intended, projects that relied on this behavior will have to be updated to draw a thicker line width.`
  This affects any custom `_draw()` used for debug overlays, vision cones, or
  tracer fallbacks — they will render ~1 px thinner than in 4.6. Re-check F3
  overlays visually. **[inference]**
- **4.6: `AStar2D`/`AStar3D`/`AStarGrid2D` return an empty path when the start is
  a disabled/solid point**:
  > `AStar2D.get_point_path, AStar3D.get_point_path, AStarGrid2D.get_id_path and AStarGrid2D.get_point_path will now return an empty path when from_id is a disabled/solid point (GH-113988).`
  Relevant if any tactical AI uses `AStarGrid2D` for local micro-pathing instead
  of the nav mesh — which is plausible for door/cover logic. Handle the empty
  path explicitly.

### 8.2 Physics interpolation 2D

New/important for 4.7-era projects, and **relevant to a 60 Hz tactical shooter
that renders at 144 Hz**:

- Off by default: `bool physics_interpolation = false` on `SceneTree`, and
  `physics/common/physics_interpolation` defaults to `false`
  (<https://docs.godotengine.org/en/4.7/classes/class_scenetree.html>,
  `ProjectSettings`).
- Turn it on in *Project Settings > Physics > Common > Physics Interpolation*.
- **All movement must happen in `_physics_process`**, or interpolation jitters:
  > `If you attempt to set the transform of interpolated objects outside the physics tick, the calculations for the interpolated position will be incorrect, and you will get jitter.`
  > `Move (almost) all game logic from _process to _physics_process`
  > — <https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/using_physics_interpolation.html>
- Teleports need `Node.reset_physics_interpolation()`:
  > `Call reset_physics_interpolation() when teleporting objects ... The solution to this is to call the Node.reset_physics_interpolation function.`
  This applies directly to Kangur: respawns, spectate camera cuts, door
  teleports, and *bullet spawns*:
  > `Moving start (e.g. bullet) — Set the initial transform; Call reset_physics_interpolation(); Immediately set the transform expected after the first tick of motion`
- 2D-specific:
  > `Physics interpolation in 2D is implemented on the server side, which means it's effective on physics bodies created using low-level servers.`
  > `Currently only CPUParticles2D are supported for physics interpolation in 2D. ... Particles2D (GPU particles) are not yet interpolated`
  > `get_global_transform_interpolated() is currently only available for 3D.`
  — <https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/2d_and_3d_physics_interpolation.html>

  So: use `CPUParticles2D` for muzzle smoke/blood if interpolation is enabled,
  and use `Node.reset_physics_interpolation()` (not the 3D-only
  `get_global_transform_interpolated`).
- `Node.physics_interpolation_mode`:
  > `Only effective if ProjectSettings.physics/common/physics_interpolation or SceneTree.physics_interpolation is true.`
  Use it to opt *out* on nodes you animate in `_process` (menus, HUD).

**[opinion]** Enable physics interpolation for Kangur. A 24-agent tactical
shooter at 60 Hz on a 144 Hz monitor without it will show visible staircasing on
every NPC; the discipline cost (all movement in `_physics_process`) is already
mandated by §4's pure-model design, so almost nothing in our code needs to
change — only teleports need `reset_physics_interpolation()`. Gate it behind a
one-match A/B screenshot + a sim run before committing, because it changes
visual smoothness only, not simulation results.

### 8.3 Audio

- **4.7: `AudioStreamPlayer.area_mask` default changed 1 → 0.** Full quote and
  consequences in §3.1. This is the audio change most likely to affect us, and
  it is *in our favour* (see §3.1 conclusion).
- **4.7: `AudioEffectSpectrumAnalyzer.tap_back_pos` was removed** (breaking, no
  GDScript shim):
  > `AudioEffectSpectrumAnalyzer — Property tap_back_pos removed`
  Irrelevant unless a spectrum visualiser is added later.
- `AudioServer.get_output_latency()` is expensive; don't call per-frame (§3.5).
- `AudioStreamPlayer2D.playback_type` is `Experimental` and the `PLAYBACK_TYPE_*`
  enum carries `Experimental: This constant may be changed or removed in future
  versions.` — do not set it; leave the default.

### 8.4 UI / Window content scale

`Window` has the content-scale knobs we need for a scalable HUD
(<https://docs.godotengine.org/en/4.7/classes/class_window.html>):

```
ContentScaleMode   content_scale_mode   = 0
ContentScaleAspect content_scale_aspect = 0
float              content_scale_factor = 1.0
Vector2i           content_scale_size   = Vector2i(0, 0)
```
> `Specifies how the content is scaled when the Window is resized.`
> `The content's base size in "virtual" pixels. Not to be confused with size, which sets the actual...`

**4.7 changed the project defaults for new projects**, which is a trap when
copying settings between projects:

> `The default stretch mode and stretch aspect for newly created projects is now canvas_items and expand respectively (previously disabled and keep). This can be changed in the Project Settings under display/window/stretch/mode and display/window/stretch/aspect.`
> — <https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html>

Kangur's `project.godot` already sets `window/stretch/mode="canvas_items"` and
`window/stretch/aspect="expand"`, which now matches the engine default — good,
but it means a diff of `project.godot` against a fresh 4.7 project will show no
difference there. Do not "clean up" those lines thinking they are redundant;
being explicit protects against future default changes. **[opinion]**

Also 4.7 GUI: `Control` gained `offset_transform_*` properties (translate/rotate/
scale a Control without disturbing its container) — relevant for the pause menu
and HUD animations, and it can be made input-aware or purely visual:

> `Control's new offset_transform_* properties aim to address this limitation in a self-contained manner, similar to the CSS transform property. You can choose whether the transform offset affects mouse input. By default, transform offset is purely visual...`
> — <https://godotengine.org/releases/4.7/>

### 8.5 Project settings defaults worth pinning

| Setting | 4.7 default | Kangur value | Why |
|---|---|---|---|
| `physics/common/physics_ticks_per_second` | 60 | 60 | fixed-step sims (§5.7) |
| `physics/common/physics_interpolation` | `false` | **`true`** (recommended) | §8.2 |
| `physics/common/max_physics_steps_per_frame` | 8 | 8 | caps catch-up; raise only for sims |
| `navigation/world/region_use_async_iterations` | `true` (4.5+) | **`false`** | determinism (§2.4) |
| `audio/general/2d_panning_strength` | 0.5 | 0.5 | §3.4 |
| `rendering/renderer/rendering_method` | platform | `gl_compatibility` | architecture |
| `display/window/stretch/mode` | `canvas_items` (4.7) | explicit | §8.4 |

Everything above is an opinion about *our* project, informed by the quoted
facts; none of it is forced by the engine.

### 8.6 4.6 change that will produce a big diff

> `The TSCN file format has changed in two ways in Godot 4.6: load_steps is no longer written in scene files (GH-103352) ... Unique node IDs are now saved to scene files to help track nodes when they are moved or renamed (GH-106837). ... As a result, when saving a scene that was last edited in Godot 4.5 in Godot 4.6, significant diffs will occur in version control programs. These diffs are expected.`
> — <https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.6.html>

Since Kangur starts on 4.7 there is nothing to migrate, but any scene imported
from a tutorial or asset pack will produce this diff on first save. Commit it
separately so real changes stay reviewable. **[opinion]**

### 8.7 GDScript behaviour changes that can break existing snippets

- 4.7: `Setting the element of packed arrays no longer calls the setter for the
  entire packed array property (GH-113228).`
- 4.7: `Methods that inherit from a method with a typed return now inherit the
  return type as well, requiring an explicit return statement in the override
  (GH-115763). Add return null to the end of the method to fix the error.`
  This directly hit GUT's doubles (§5.1) and will hit any of our base-class
  overrides where the parent declares `-> Something`.
- 4.7: `Object.is_class` parameter type `String → StringName` (compatible).
- 4.7: mouse/keyboard device IDs are now `InputEvent.DEVICE_ID_MOUSE` (32) /
  `DEVICE_ID_KEYBOARD` (16) rather than 0:
  > `The device IDs for mouse and keyboard were changed from 0 to InputEvent.DEVICE_ID_MOUSE and InputEvent.DEVICE_ID_KEYBOARD because some joypads may use 0 as their ID (GH-116274).`
  Do not compare `event.device == 0`; compare by type or against the constants.

---

## 9. Project conventions

### 9.1 Folder layout

Official guidance is deliberately loose:

> `Since Godot has no restrictions on project structure or filesystem usage, organizing files when learning the engine can seem challenging. This tutorial suggests a workflow which should be a good starting point.`
> `the most common approach is to group assets as close to scenes as possible; when a project grows, it makes it more maintainable.`
> — <https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html>

And the two naming rules that are not negotiable:

> `Use snake_case for folder and file names (with the exception of C# scripts). This sidesteps case sensitivity issues that can crop up after exporting a project on Windows.`
> `Use PascalCase for node names, as this matches built-in node casing.`

> `In general, keep third-party resources in a top-level addons/ folder, even if they aren't editor plugins.`

The `docs/.gdignore` trick from that page is directly useful for us — the
`docs/` and `reports/` trees must never be imported:

```bash
# docs/.gdignore and reports/.gdignore, both empty
```
> `To prevent Godot from importing files contained in a specific folder, create an empty file called .gdignore in the folder (the leading . is required).`
> `Note that the .gdignore file's contents are ignored, which is why the file should be empty. It does not support patterns like .gitignore files do.`

**Note the difference vs `.gitignore`**: `.gdignore` has no patterns. For a
directory tree you want Git to ignore but Godot to leave alone, use `.gitignore`
instead.

For Kangur, `docs/architecture.md` §1 already defines a good module layout. Two
additions recommended by the official style rules and by our own pitfalls list:

1. `docs/.gdignore`, `reports/.gdignore`, `tools/.gdignore` (tools are scripts,
   not content; they do not need importing).
2. `addons/` **must not** be linted or formatted by our own rules — it is
   third-party. Add `addons/` to any gdformat/lint exclusions and to
   `.gitattributes` (see §9.3).

### 9.2 Autoloads and the signal bus

The existing §3 order (EventBus → Defs → Settings → AudioDirector → Game → Dev)
is sound. Two engine-level notes:

- Autoloads are added before the main scene, in registration order, so anything
  in `_ready()` of `AudioDirector` can rely on `EventBus` and `Defs` existing —
  which the §9 pipeline needs.
- `EventBus` as signals-only is the right call (no state). It also avoids the
  class-cycle problem in `AGENTS.md`: signal parameters typed as `Node`/`Variant`
  rather than concrete classes.

One practical pattern for the bus, given "no return values" and
"listeners must be cheap":

```gdscript
# src/core/event_bus.gd
extends Node
## Signals only. No state, no logic. Contract: architecture §5.

signal shot_fired(shooter: Node, weapon_id: StringName, origin: Vector2,
                  dir: Vector2, pellets: int)
signal bullet_impact(pos: Vector2, normal: Vector2, surface: int, penetrated: bool)
signal character_hit(victim: Node, attacker: Node, part: int, damage: float,
                     fatal: bool, pos: Vector2)
signal sound_emitted(pos: Vector2, loudness: float, kind: StringName,
                     source: Node, surface: int)
# ... etc, exactly as §5
```

**Opinion: do not add a `connect` helper or a typed "bus" wrapper.** Godot's
signals already are the bus; a wrapper adds an indirection that makes
`--debug` stack traces worse and complicates teardown. The single rule that
matters is the one already in §5: *emitters never assume listeners*.

### 9.3 `.gitignore` — verified against official docs

The 4.7 VCS page is explicit and **differs from the common folklore in one
important way**:

> `There are some files and folders Godot automatically creates when opening a project in the editor for the first time. To avoid bloating your version control repository with generated data, you should add them to your VCS ignore:`
> `.godot/: This folder stores various project cache data.`
> `*.translation: These files are binary imported translations generated from CSV files.`
> — <https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html>

And for `.import` — **they ARE committed**:

> `Importing will add an extra <asset>.import file next to the source file, containing the import configuration. Make sure to commit these files to your version control system, as these files contain important metadata.`
> — <https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/import_process.html>

> `As such, committing the .godot/ folder to the version control system is not recommended.`

The widely-used `github/gitignore/Godot.gitignore` agrees and adds a few extras:

```
# Godot 4.2+ specific ignores
~*.dll

# Godot 4+ specific ignores
.godot/
.nomedia

# Godot-specific ignores
.import/
export.cfg
export_credentials.cfg
*.tmp

# Imported translations (automatically generated from CSV files)
*.translation

# Mono-specific ignores
.mono/
data_*/
mono_crash.*.json
```
— <https://raw.githubusercontent.com/github/gitignore/main/Godot.gitignore>

**Answer to the brief's question:** `.import` files **are** committed (they are
the import *configuration*, without which collaborators get different import
settings). What is **not** committed is `.import/` — note the trailing slash, a
Godot 3 legacy directory — and `.godot/imported/`, which holds the generated
binary assets. Kangur's current `.gitignore` is already correct on the important
points (`.godot/` ignored, `reports/` ignored) but is **missing** `*.translation`
and `.nomedia`; add them.

Recommended complete `.gitignore` for Kangur:

```gitignore
# Godot import cache (regenerated on import; *.import metadata IS committed)
.godot/
.nomedia

# Imported binary translations generated from CSV
*.translation

# Export presets may contain secrets; never commit credentials
export_credentials.cfg

# Build/export output
build/
export/
*.x86_64
*.exe
*.pck
*.zip

# Test/screenshot/balance reports (generated artifacts)
reports/

# Junk from crash dumps / temp writes
*.tmp
mono_crash.*.json

# OS/editor noise
.DS_Store
Thumbs.db
*.swp
*~
```

Do **not** add `*.import` (would be wrong) and do **not** add `assets/` or
`data/` — those are the game.

### 9.4 Git LFS: plain git vs LFS for ~200 MB of assets

Official docs present LFS as an option, not a requirement, and list a long set of
tracks including audio:

> `Git LFS (Large File Storage) is a Git extension that allows you to manage large files in your repository. ... This is useful for managing large assets, such as textures, audio files, and 3D models, without bloating your Git repository.`
> `When using Git LFS you will want to ensure it is setup before you commit any files to your repository.`
> — <https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html>

**Recommendation for Kangur: plain git, no LFS.** Reasoning, explicitly
opinion:

- **200 MB is small.** A full clone is a couple of minutes on any reasonable
  connection and roughly the size of a single modern game build. LFS's benefit
  starts when individual files are hundreds of MB or when the *history* of
  binary churn is large. **[opinion]**
- **LFS is a hard dependency for every clone** — `git lfs install` plus the
  remote actually serving LFS objects. The docs say so directly:
  > `keep in mind that LFS files are stored separately from the rest of your Git history. This means that you may need to install Git LFS on any machine that you clone the repository to in order to access the LFS files.`
  For a solo/small project this is pure friction.
- **CI and subagents** (this repo uses parallel subagents and worktrees) would
  each need LFS working. Plain git just works with `git worktree`. **[opinion]**
- **LFS make migrations painful.** If we start with LFS and want out (or start
  without and want in), the docs acknowledge `git lfs migrate` `is more in-depth
  and requires a good understanding of Git`. Starting plain and migrating later,
  once we actually know our asset weight, is the cheaper direction. **[opinion]**

**When to revisit:** if `assets/` exceeds ~1–2 GB, or if a single `.wav`/`.ogg`
source file exceeds ~50 MB, or if asset history (repeatedly replaced audio)
starts dominating `git gc` size. At that point, `git lfs track "*.wav" "*.ogg"`
and migrate in one deliberate commit. **[opinion]**

If we do adopt it, the official starting `.gitattributes` is the right template,
and note the mandatory normalisation line:

```
# Normalize EOL for all files that Git considers text files.
* text=auto eol=lf
```
(quoted from the same docs page, followed by per-type `filter=lfs diff=lfs
merge=lfs -text` lines for `*.png`, `*.wav`, `*.ogg`, `*.ttf`, etc.)

One important consequence of *not* using LFS: **do not track `*.res`/`*.scn`
with LFS** as that template suggests. Those are our compiled outputs and belong
in `.gitignore` alongside `reports/`, not in LFS. That template line is a
sensible default for projects that *do* ship binary resources, but for Kangur
`.res` files are export-time artefacts. **[opinion]**

---

## 10. Recommended stack (summary)

### 10.1 Testing

- **gdUnit4 7.0.0**, vendored into `addons/gdUnit4/`, pinned by committing the
  tree plus the upstream commit SHA (no tag exists — tags stop at v6.2.3).
- `tools/verify.sh` begins with `godot --headless --path . --import` — this is
  mandatory and prevents gdUnit4's first-run segfault (**[verified]**).
- Headless invocation:
  ```bash
  godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
        -c -a res://tests/unit -rd res://reports/tests
  ```
  `-c` because gdUnit4 defaults to fail-fast.
- Exit codes 0 / 100 / 101 → `verify.sh` maps 100 to "failure", 101 to "warning".
- **Escape hatch:** if 7.0.0 ever breaks, GUT 9.7.1 is a drop-in replacement for
  the *test bodies* (both fluent-assertion style); only the runner command and
  the suite base class change. Budget: under an hour for a few hundred tests.
- Pure-logic tests use `RefCounted` models with manual fixed-step loops (§5.7).
  `Engine.time_scale` is for the player-facing fast-forward, never for sims.
- Seed each subsystem from the match seed via `hash()` (§5.8), never a shared
  global RNG.

### 10.2 Audio occlusion

- Buses built once in `AudioDirector._ready()` from a single `BUS_TABLE`:
  `Master → SFX → {SFX_Open, SFX_Light, SFX_Heavy, SFX_Muffled}` plus `Music`,
  `Voice`; each occluded bus carries one `AudioEffectLowPassFilter`
  (cutoffs 20500 / 4200 / 1300 / 550 Hz, gains 0/−4/−9/−14 dB per §9).
- Route on `sound_emitted` by wall-count from listener→source,
  `SOUND_MASK = Layers.SOUND_MASK` (= `1|6`; low cover does not block sound),
  capped at 3 rays. `OcclusionMath` stays pure so NPC hearing reuses it.
- Pooled `AudioStreamPlayer2D` (32), `area_mask = 0` (4.7 default — do not
  inherit Area2D bus overrides), `attenuation = 1.6`, `max_distance` from
  loudness.
- `AudioListener2D` on the camera, `make_current()`.
- **Headless:** buses and effects *are* built and queryable (**[verified]**);
  only playback no-ops. Guard `_play()`, not bus construction — that gives a free
  headless regression test of the bus layout.

### 10.3 Projectiles

- One `ProjectileSystem._physics_process`; `Array[Bullet]` of plain objects;
  one `PhysicsRayQueryParameters2D.create(from, to, BULLET_MASK)` per bullet per
  tick, segment = `vel * delta`.
- `exclude = [shooter.get_rid()]` (assign a fresh array — `append` on the copy is
  silently lost).
- `intersect_ray` gives `position` + `normal` + `collider` + `rid`; `position`
  feeds `World.surface_at()` for decals/footstep surfaces, `normal` feeds
  ricochet (`Vector2.bounce`).
- `BULLET_MASK = Layers.BULLET_MASK` (= `1|2|5|6`); glass shatters on the 2nd hit,
  low cover only penetrates per tile data.
- Penetration and ricochet decided from **content** (`TileData` custom data
  `penetrable`) and the GLASS layer, not hardcoded per-material logic.
- Never `Area2D`-per-bullet — proven to tunnel at 8000 px/s (**[verified]**).
- Profile at realistic concurrency (~170 bullets, not 30) before optimising.

### 10.4 Map pipeline

- `TileMapLayer` per visual/logical layer: `Ground`, `Walls`, `LowCover`, `Glass`,
  `Deco` (four colliding layers per §2: WORLD=1, LOW_COVER=5, GLASS=6 — three
  physics layers on the TileSet, one per collidable kind).
- `Walls` carries the WORLD physics layer; `LowCover` and `Glass` each carry
  their own physics layer, because one TileSet physics layer has a single
  `collision_layer` for all tiles painted through it.
- Custom data on the collidable TileSets: `surface: int`, `penetrable: bool`,
  `blocks_sound: bool`, `low_cover: bool`. Read via
  `get_cell_tile_data(local_to_map(to_local(pos)))`.
- `Walls.navigation_enabled = false`; bake a real `NavigationPolygon` from
  colliders into a sibling `NavigationRegion2D` with `agent_radius = 10`,
  `cell_size = 1.0`, `parsed_collision_mask = WORLD|LOW_COVER|GLASS`, via
  `parse_source_geometry_data` → `bake_from_source_geometry_data_async`.
- One nav mesh per map; 2D nav meshes cannot be stacked.
- Doors = per-doorway `NavigationRegion2D` toggled `enabled`; re-issue
  `target_position` after toggling (existing paths are not updated).
- Navigation links only for genuine teleports/ladders/jumps, and game code must
  implement the traversal.

### 10.5 Screenshot harness

- `tools/screenshot_harness.gd`, `extends SceneTree`, run with
  `godot --path . -s tools/screenshot_harness.gd -- --shot=<scene>:<frames>:<out>`.
- Parse with `String.rsplit(":", true, 2)` (**not** `split(":")` — `res://` has a
  colon; **[verified]**).
- Normalise the scene path with `ResourceUID.ensure_path()`.
- **Guard `DisplayServer.get_name() == "headless"` → exit 3 immediately.** In
  headless, `await RenderingServer.frame_post_draw` never returns and the process
  hangs (**[verified]**: exit 124 under `timeout`).
- Capture: N × `await process_frame`, then `await RenderingServer.frame_post_draw`,
  then `root.get_texture().get_image().save_png(out)`.
- Create the output directory with `DirAccess.make_dir_recursive_absolute()`.
- Exit 0/2/3/4 so `verify.sh` can distinguish causes.
- Run under `DISPLAY=:0`; `xvfb-run` is not installed here (**[verified]**).

---

## Appendix A — Probe log (reproducibility)

All probes ran against `/usr/bin/godot 4.7.2.stable.arch_linux.ed1daf0bf`, in
throwaway projects under `/tmp/opencode/` (not in this repo). What was executed:

| Claim | Probe | Result |
|---|---|---|
| Headless audio graph works | build bus + low-pass, query it | bus idx 1, effect count 1, enabled true, instance non-null |
| `DisplayServer.get_name()` == "headless" | print in `_ready` | `headless`, driver `Dummy` |
| `frame_post_draw` never fires headless | `await` it, no guard | process hung → `timeout` exit 124 |
| Empty image headless | `get_image()` without await | `is_empty() == true`, size `(0,0)`, viewport `64×64`, window `0×0` |
| Screenshot works on `:0` | full harness | saved PNG, `err=0`, non-empty |
| Fast bullet tunnels point-checks | 8000 px/s vs 2 px wall | point overlap 0 at x=287; raycast hit at x=299 |
| GUT 9.7.1 on 4.7.2, headless | 2-test suite | runs; 0 pass / 1 fail exit codes correct |
| GUT needs `--import` | first run | clear `class_names have not been imported` error |
| GUT bench 250×300 ticks | — | 0.404 s framework, 1 629 ms wall |
| gdUnit4 6.2.3 refuses headless | `-a` run | `Abnormal exit with 103`, tells you about `--ignoreHeadlessMode` |
| gdUnit4 6.2.3 with flag | `--ignoreHeadlessMode` | runs, exit 100 on failure |
| gdUnit4 7.0.0 runs headless | no flag | runs, warning only, exit 100/0 correct |
| gdUnit4 7.0.0 without import | first run | **segfault** |
| gdUnit4 bench 250×300 ticks | — | 707 ms framework, 2 408 ms wall |
| `rsplit(":", true, 2)` parse | string probe | correct 3-way split incl. `res://` |
| `get_cmdline_user_args()` | `-- --shot=1` | `["--shot=1"]` |
| `Engine.time_scale = 8` is *not* a fast-forward | 60 ticks with `time_scale 8` | 1.001 s wall, deltas summing 8.000 s (0.1333 each) |
| §3.4 BUS_TABLE snippet runs headless | build all 7 buses + 3 filters | sends resolve (`SFX_Light → SFX`), dB applied, 1 effect on each occluded bus |

## Appendix B — Open questions / things not verified

1. **4.7.2 is not a release I could find release notes for.** The docs tree is
   `/en/4.7/` and the migration page covers 4.6→4.7; the point release 4.7.2
   changelog was not fetched. Anything fixed between 4.7.0 and 4.7.2 is unknown.
   *Why it matters:* if a nav or audio bug was fixed in 4.7.2 specifically, my
   "still broken" assumptions could be stale. Everything I claim was verified on
   4.7.2 directly, so this affects only the release-note narrative, not the API
   facts.
2. **gdUnit4 7.0.0 has no git tag.** I pinned by `master` HEAD at the time of
   writing. *Why it matters:* a future `master` could break; the committed
   `addons/gdUnit4/` tree is the real pin. Record the SHA when vendoring.
3. **`--headless --import` semantics for a *fresh* clone of Kangur** (with
   `addons/gdUnit4` present but `.godot/` absent) were tested on a probe
   project, not on Kangur itself, because Kangur has no `project.godot`
   autoloads wired yet. *Why it matters:* a first-run CI failure would be
   confusing; re-test once `src/core/` autoloads exist.
4. **Bullet concurrency estimate (~170)** is arithmetic, not measured. *Why it
   matters:* if real maps are smaller or NPC fire rates lower, the perf section
   over-warns. Measure on `maps/compound` once it exists.
5. **`AudioEffectEQ6` vs low-pass-only** for the heavy-occlusion bus is a sound
   design judgement I did not test audibly. *Why it matters:* it changes the
   *feel* of gunfire through walls; needs an ear, not a doc.
6. **`physics_interpolation = true` interaction with Kangur's multi-layer
   character rig** (separate legs/torso/head sprites, each a `Node2D`) was not
   tested. *Why it matters:* interpolation is per-node, so a rig whose parts are
   positioned relative to the body should be fine, but the aim-rotation on
   head/arms (`Aim` component) may need `_process`-free handling. Verify with a
   screenshot pair at 60 Hz physics / 144 Hz display.
7. **GUT's 4.7 return-type change** (`unstubbed int double returns 0`) may
   affect any doubles written against 4.6 semantics. *Why it matters:* only if we
   fall back to GUT; noted so the fallback is not a surprise.
8. **Architecture §2 grew from 4 to 6 layers while this doc was being written.**
   I reconciled §1.3, §4.3, §4.4 and §10 against the *current* `architecture.md`
   (WORLD=1, CHARACTER=2, INTERACT=3, EQUIPMENT=4, LOW_COVER=5, GLASS=6), but
   this is exactly the kind of drift to re-check: if §2 changes again, the
   TileSet physics-layer count in §1.3, `BULLET_MASK` in §4.3 and
   `parsed_collision_mask` in §2.2 all need to change with it. *Why it matters:*
   these are the settings that fail silently (rays pass through walls) rather
   than loudly.