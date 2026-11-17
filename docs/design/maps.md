# Kangur — Map Design Specs

Maps are authored TileMapLayer scenes (`maps/<id>/`) per architecture §7.
This doc gives **blockout specs**: carve rects (open floor) and block rects
(crates/props/buildings) in tile coordinates, origin top-left, 1 tile = 32 px.
`tools/build_map.gd` (world wave) generates a base scene from these specs;
designers then polish in the editor. Specs are the source of truth for layout;
editor polish may adjust props but must keep lanes/spawns/objectives intact.

## Tile palette & the low-cover rule

Tile custom data (Walls layer): `surface: Enums.Surface`, `penetrable: bool`,
`low_cover: bool`, `blocks_sound: bool`.

- **HIGH_WALL** (buildings, concrete walls, container stacks ≥2 tiles):
  blocks movement, bullets, vision, sound. Not penetrable (sniper exception:
  thin concrete `penetrable=true, pen_mult=0.35` — mark sparingly).
- **LOW_COVER** (crates, sandbags, cars, planters, 1-tile props): blocks
  movement; blocks bullets (wood `penetrable=true` ×0.55); blocks sound NOT;
  **vision rule**: a crouched character behind low cover is hidden from ALL
  observers; a crouched OBSERVER cannot see over low cover (their rays block);
  standing observers see over it. → Stance is a real tactical verb: crouch to
  vanish behind a crate, stand to shoot over it. NPCs must reason about this
  (cover quality is stance-dependent).
- **GLASS** (windows): blocks movement + sound partially (1 wall equivalent),
  NOT vision; penetrable ×0.8, shatters after 2 hits (becomes open, sound spike).
- Floors: concrete/sand/metal/grass/wood/water per zone (footsteps + minimap tint).

Minimap: baked silhouette (walls dark, floor tinted by surface, low cover
mid-tone), objectives/ spawns overlaid at runtime.

---

## Dustworks (TDM Elimination) — de_dust2 homage, 80×64 tiles

Sandy industrial depot. SIROCCO spawns south, BASTION north. Three-lane
classic: mid / long A / tunnels B, with catwalk + window connectors.

**Carve** (x, y, w, h, surface):
```
spawn_sirocco   30 54 20  8  sand
spawn_bastion   30  2 20  8  concrete
mid             37 10  6 44  sand
a_site          58  8 18 14  sand
b_site           4  8 18 14  sand
long_south      50 52 24  6  sand
long_east       68 14  6 42  sand
catwalk         43 20 15  4  concrete
ct_ramp         50  8  8  4  concrete
lower_tunnels    6 52 24  6  sand
upper_tunnels    6 22  6 34  sand
window          22 12  8  4  concrete
```
**Block** (low_cover unless noted):
```
xbox(mid)       39 30  2  2
a_site          62 12  2  2 | 69 16  3  2 | 60 18  2  1 | 72  9  2  2
b_site           8 12  3  3 | 16 10  2  2 | 12 18  2  1
long            70 30  2  2 | 68 44  2  1 | 60 53  2  2
tunnels          8 36  2  2 | 10 26  1  2
catwalk         48 21  2  1
long_south      56 54  2  2
spawns          32 56  2  2 | 46 56  2  2 | 32  4  2  2 | 46  4  2  2
```
**Chokes / lane graph** (AI navigation hotspots):
mid_doors (mid y28–32) · long_doors (long_east y40–44) · tunnel_exit
(upper_tunnels y22–26) · catwalk (x43–58 y20–24) · window (x22–30 y12–16).
Lanes: T→mid→CT · T→long_south→long_east→A · T→lower→upper_tunnels→B ·
CT→ramp→A · CT→window→B · mid→catwalk→A.
**Spawns**: 12 markers/team spread inside spawn rects (grid jitter).
**Cover points**: crate edges facing lanes, site corners (goose = a_site
60,18 crate north face), choke off-angles, xbox both sides. ~60 points.
**Notes**: mid is the killzone magnet — danger-map logic must shine here.
A site favors rifles (long sightlines), B favors shotguns/SMGs (tight yard).

## Compound (TDM Elimination) — industrial estate, 72×56, symmetric W/E

BASTION west, SIROCCO east. Central warehouse + north dock lane + south yard
lane; container stacks everywhere. Mirror-symmetric for fairness.

**Carve**:
```
spawn_bastion    2 20  8 16  concrete
spawn_sirocco   62 20  8 16  concrete
central_hall    24 18 24 20  concrete
north_lane      10  6 52  6  metal
south_lane      10 44 52  6  concrete
west_yard       10 12 14 32  grass
east_yard       48 12 14 32  grass
north_gap       30 12 12  6  concrete
south_gap       30 38 12  6  concrete
```
**Block**:
```
north containers  20  8  3  2 | 40  7  4  2 | 52  9  2  2
south containers  18 46  3  2 | 38 45  4  2 | 54 46  2  2
hall pillars      28 22  2  2 | 42 22  2  2 | 28 32  2  2 | 42 32  2  2 | 35 27  2  2
west yard         14 16  2  3 | 16 36  2  3
east yard         54 16  2  3 | 52 36  2  3
```
**Lanes**: west_yard→north_lane→east_yard · west_yard→south_lane→east_yard ·
spawns→yards→gaps→central_hall (hall = close-quarters pivot).
**Notes**: hall pillars create peek-a-boo angles; containers = low-cover
stance fights. Symmetry ⇒ balance sims should show ~50/50.

## Terminal (Battle) — port logistics, 96×64. Attackers SIROCCO (south docks)

Objective chain: **A gatehouse → B warehouse → C control tower**.
West crane-yard flank, east container-yard flank, central main road.

**Carve**:
```
spawn_sirocco   36 56 24  6  concrete
spawn_bastion   36  2 24  6  concrete
obj_a_zone      40 42 16 10  concrete   (capture rect 42 44 12 6)
obj_b_zone      60 24 24 16  metal      (capture rect 64 28 16 8)
obj_c_zone      36  8 20 12  concrete   (capture rect 40 10 12 8)
main_road       44 10  8 46  concrete
dock_lane        8 30  8 26  concrete
crane_yard       8 20 20 10  grass
container_yard  76 36 16 20  concrete
east_yard       80 24 12 12  metal
a_to_road       44 42 16  8  concrete
road_to_b       52 28 12  6  concrete
b_to_c          52 18 10  6  concrete
west_link       28 24 16  6  concrete
```
**Block**:
```
dock containers   10 34  3  2 | 12 44  3  2 | 10 52  3  2
east containers   78 40  3  2 | 84 44  3  2 | 80 50  3  2 | 86 36  2  2
warehouse pillars 64 28  2  2 | 76 28  2  2 | 64 36  2  2 | 76 36  2  2 | 70 32  2  2
gatehouse         44 44  2  2 | 52 46  2  2
control           40 10  2  2 | 50 14  2  2
```
**Objectives**: capture_time A 20 s, B 24 s, C 28 s; +8 tickets per capture;
defender recapture 2× before lock. Attacker spawn advances to last captured
objective's forward spawn markers (place `spawn_fwd_a/b` near each zone).
**Defender rotates**: main_road (fast, exposed) · west_link (safe, slow) ·
east yards (contested). **Notes**: B warehouse is the meat grinder — pillars +
metal floor (loud footsteps). C control has glass frontage (see-in, shoot-through).

## Oldtown (Battle) — European streets, 88×72. Attackers SIROCCO (south)

Chain: **A plaza → B church → C administration**. Narrow main street, west
alley flank, east lane flank. Buildings are solid HIGH_WALL blocks.

**Carve**:
```
spawn_sirocco   34 64 20  6  concrete
spawn_bastion   34  2 20  6  concrete
obj_a_zone      32 50 24 12  concrete   (capture rect 36 52 16 8)
obj_b_zone      36 28 16 16  concrete   (capture rect 38 30 12 12)
obj_c_zone      32  6 24 14  concrete   (capture rect 36 8 16 10)
main_street     40 12  8 52  concrete
west_alley      12 20  6 40  concrete
east_lane       70 16  6 44  concrete
plaza_west      18 52 14  6  concrete
church_west     18 32 18  6  concrete
admin_west      18 10 14  6  concrete
plaza_east      56 54 14  6  concrete
church_east     52 34 18  6  concrete
admin_east      56 10 14  6  concrete
```
**Block** (buildings = HIGH_WALL; props low_cover):
```
buildings   20 22 14  8 | 20 40 14  8 | 54 22 14  8 | 54 42 14  8 |
            24  6  8  4 | 56  6  8  4 |  8 56 10  6 | 70 56 10  6
church      40 32  8  8  HIGH_WALL (ambulatory carved around it = obj_b zone ring)
fountain    42 55  4  4  low_cover (plaza centerpiece)
admin desks 38 10  2  1 | 48 14  2  1
```
**Notes**: church ambulatory = circular close-quarters fight around a solid
core; alleys are SMG/shotgun territory; main street favors DMR overwatch from
admin windows (GLASS tiles on admin south face). Capture zones are open
plazas — attackers must smoke or die crossing.

## Range (Training) — 48×32 sandbox

```
floor        2  2 44 28  concrete
firing_line  y=26 (markers x 8/16/24/32/40)
targets      static dummies y=20 (10 m), y=14 (20 m), y=6 (30 m) per lane;
             one rail-moving dummy per outer lane (x oscillation)
weapon_rack  markers along south wall (all weapons switchable)
bandage_dummy  dummy that bleeds you on touch (practice channel)
```
Infinite-ammo toggle, live spread/recoil readout panel, TTK dummy with
body-part HP display. No AI. Accessible from Title → Training.

---

## Authoring workflow (for docs/adding-content.md)

1. Copy `maps/_template/` → `maps/<id>/`, rename root.
2. Either paint tiles in editor OR write a blockout spec (this doc's format)
   and run `tools/build_map.gd` to generate, then polish.
3. Place Spawns (12/team), Cover points (lean_dir + quality + lanes),
   Objectives (Battle), Bounds, optional Lights.
4. Bake minimap: `tools/bake_minimap.gd maps/<id>`.
5. Author `data/maps/<id>.tres` (MapDef): modes, briefing, ambience, music.
6. Verify: run a seeded sim on the map (fairness + no-stall invariants) and
   screenshot the minimap + spawn views.
