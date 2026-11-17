# Adding Content to Kangur (Designer Guide)

Kangur is **data-driven**: adding weapons, classes, equipment, factions, maps,
difficulty presets, or radio lines requires **no code**. This guide is for
humans using the Godot editor; AI agents should load the `kangur-content` skill
(the machine-precise version). Contracts: `docs/architecture.md` §6–§7.

## Where things live

| Content | Definition schema | Instances | Art/audio |
|---|---|---|---|
| Weapon | `src/core/data/weapon_def.gd` | `data/weapons/*.tres` | procedural rig params + `assets/audio/weapons/` |
| Class | `src/core/data/class_def.gd` | `data/classes/*.tres` | icon + rig silhouette cue |
| Equipment | `src/core/data/equipment_def.gd` | `data/equipment/*.tres` | procedural visuals |
| Faction | `src/core/data/faction_def.gd` | `data/factions/*.tres` | `assets/ui/art/*.svg` emblem + colors |
| Map | `src/core/data/map_def.gd` | `data/maps/*.tres` | `maps/<id>/` scene + minimap |
| Difficulty | `src/core/data/difficulty_def.gd` | `data/difficulty/*.tres` | — |
| Sound set | `src/core/data/sound_set_def.gd` | `data/sounds/*.tres` | `assets/audio/**` |
| Palette | `src/world/palette_def.gd` | `data/palettes/*.tres` | tile/HUD colors |

The `Defs` autoload scans `data/` at boot and indexes everything by `id`.
New `.tres` files are picked up automatically — no registration list to edit.

## Add a weapon (≈10 min)

1. In the FileSystem dock, right-click `data/weapons/` → **New Resource** →
   `WeaponDef`. Save as `<id>.tres` (id = snake_case, e.g. `kestrel`).
2. Fill the Inspector fields. Ground stats in `docs/design/game-design.md` §6
   and `docs/research/genre-mechanics.md`. Key fields: category, fire_modes,
   rpm, mag_size, damage, bullet_speed (4000–9000), spread/recoil/falloff,
   sound_set, and the **visual params** (body_len, barrel_len, width, mag,
   stock, scope, colors) — the procedural rig draws the weapon from these, so
   the muzzle you see is the muzzle bullets come from.
3. Point `sound_set` at a `SoundSetDef` mapping fire/reload/action sounds to
   files in `assets/audio/weapons/` (see `docs/credits.md` for shippable audio).
4. Press **F5** (or run a weapon test). The weapon appears in class loadout
   pools whose `primary_categories` include its category. Done.

**TTK sanity**: torso 80 HP. rifle 30 dmg → 3 hits ≈ 0.18 s; pistol 24 → 4 hits
≈ 0.43 s; sniper 110 → 1 hit. Keep new weapons in this lethality band.

## Add a map (≈30–60 min)

1. Copy `maps/_template/` → `maps/<id>/`.
2. **Blockout** (fast): author `maps/<id>/blockout.tres` (`BlockoutDef`) with
   carve/block rects (see `docs/design/maps.md` for the format and five worked
   examples), then run `tools/godot.sh --headless --path . -s tools/build_map.gd
   -- --map=<id>`. This generates TileMapLayers with correct collision layers
   (walls=1, low cover=5, glass=6), navigation, spawns, cover points.
   **Or paint by hand**: open the scene, paint the Ground/Walls/Deco
   TileMapLayers. Set tile custom data: `surface`, `penetrable`, `low_cover`,
   `blocks_sound`. Low cover = crates you can crouch behind / shoot over.
3. Place markers: **Spawns** (12 per team, `spawn_bastion_NN` /
   `spawn_sirocco_NN`; Battle maps add forward spawns), **Cover** points
   (lean_dir, quality, lanes), **Objectives** (Battle: obj_id, order,
   capture_time), **Bounds**, optional **Lights** (dusk maps).
4. Bake the minimap: `tools/godot.sh --headless --path . -s tools/bake_minimap.gd
   -- --map=<id>`.
5. Author `data/maps/<id>.tres` (`MapDef`): supported_modes, briefing (dry
   corporate-proxy-war tone), ambience/music ids, lighting preset.
6. Verify: run a seeded sim on the map and screenshot it (see
   `docs/adding-content.md` → Verification, or the `kangur-verify` skill).

## Add a class / faction / difficulty

- **Class** (`data/classes/<id>.tres`): speed_mult, armor, bandages,
  primary_categories (must match weapon categories), sidearm, equipment, perk.
  Reuse an existing `perk_id` from `src/entities/perks.gd`; a brand-new perk
  mechanic needs code.
- **Faction** (`data/factions/<id>.tres`): colors (keep colorblind-safe vs the
  existing blue/orange), emblem SVG, callsign pool (European names), radio line
  sets (`docs/design/radio-lines.md` lists events + tone), doctrine weights.
- **Difficulty** (`data/difficulty/<id>.tres`): reaction/aim-error/turn-rate
  ranges + aggression/discipline biases. **Never** scales sensor range or info
  accuracy — that breaks the fairness rule (NPCs perceive exactly like you).

## Restyle the game

- **Colors/tiles**: edit `data/palettes/*.tres` → re-run `tools/gen_tiles.gd`.
- **HUD/menus**: one theme resource + `src/ui/theme.gd` palette consts. Change
  there, not in individual widgets.
- **Characters**: rig params are procedural (`docs/design/art-direction.md` §1);
  faction colors come from FactionDef. Optional texture overlays per part let
  you replace vectors with hand-drawn art without code.

## Verification (always before committing)

Run `tools/verify.sh` (unit tests + quick sims + screenshots). Content-specific:
weapon → TTK sim; map → seeded battle sim in each supported mode; class →
loadout sim. See the `kangur-verify` skill for commands and the fairness
invariants every sim must satisfy. Commit scoped: `feat(content): add <id>`.

## Rules that keep the game good

1. No code changes for content — if you need one, the schema is missing a field.
2. NPCs must stay fair: no content that gives them wallhacks or perfect info.
3. Every match fresh: content feeds seeded per-match variety, not choreography.
4. Respect asset licenses: only CC0/CC-BY audio/art ships; attribute in
   `docs/credits.md` + the in-game Credits screen.
