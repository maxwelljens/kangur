---
name: kangur-content
description: Add or modify Kangur game content — weapons, classes, equipment, factions, maps, difficulty presets, radio lines, palettes. Use when asked to add a weapon/map/class, rebalance content, or extend the game data-drivenly without code changes.
---

# Kangur Content Authoring

All content is `.tres` Resources under `data/`, loaded by the `Defs` autoload
(`src/core/defs.gd`). Schemas: `src/core/data/*.gd`. Contracts:
`docs/architecture.md` §6–§7. Design numbers: `docs/design/game-design.md`.
Map blockouts: `docs/design/maps.md`. Art params: `docs/design/art-direction.md`.

**Rule: adding content must not require code changes.** If it does, the schema
is missing a field — extend the schema (a contract change: document it), don't
hardcode the content.

## Add a weapon
1. Create `data/weapons/<id>.tres` (script `WeaponDef`). Required: `id`
   (StringName, unique, snake_case), `display_name`, `category`
   (pistol/smg/ar/br/dmr/sniper/lmg/shotgun), `fire_modes` (Enums.FireMode
   array), rpm, mag_size, reserve_mags, reload_time, bullet_speed (4000–9000
   px/s), damage, pellets (1 except shotguns), spread fields (base degrees,
   bloom_per_shot, bloom_max, bloom_recovery), move_penalty_scale, recoil
   (kick, recovery), penetration, falloff (start/end px, min_mult), focus_mult,
   move_speed_mult, sound_set (id of a SoundSetDef), visual params (body_len,
   barrel_len, width, mag_offset/len, stock, scope, colors), tracer_color.
2. Ground stats in `docs/research/genre-mechanics.md` + design §6 TTK targets
   (rifle 3-hit torso ≈0.3–0.4 s; sniper torso one-shot; shotgun ≤1 close).
3. Sounds: map a `SoundSetDef` in `data/sounds/` to curated files in
   `assets/audio/weapons/` (see `docs/credits.md` for what's shippable).
4. Validate: `WeaponDef.validate()` must return no errors.
5. Verify: run weapon unit tests (`tests/unit/combat/`), a TTK table sim, and
   screenshot the rig holding it (`tools/shot_rig.tscn` fixture).

## Add a class
`data/classes/<id>.tres` (ClassDef): speed_mult (0.92–1.08), armor vest/helmet
durability, bandages (2–4), primary_categories (must match weapon categories),
sidearm_id, equipment ids (2), perk_id, icon, description. Perk effects are
implemented in `src/entities/perks.gd` — a NEW perk mechanic needs code; reuse
existing perk ids where possible. Bots auto-pick loadouts from class pools.

## Add equipment
`data/equipment/<id>.tres` (EquipmentDef): kind (Enums.EquipKind), fuse, radius,
damage, vision_block_time (smoke), sprite/visual params, sounds. New throw
physics/visuals beyond frag/flash/smoke archetypes need `src/combat/equipment_*`
work — extend an archetype first.

## Add a map
Follow `docs/design/maps.md` authoring workflow exactly:
1. Copy `maps/_template/` → `maps/<id>/`.
2. Blockout: write carve/block rect spec (maps.md format) → `tools/build_map.gd`
   generates TileMapLayers with correct collision layers (architecture §2:
   walls=1, low cover=5, glass=6) + custom data (surface, penetrable,
   low_cover, blocks_sound) → polish in editor.
3. Markers: Spawns (12/team, `spawn_<faction>_NN` + Battle forward spawns),
   Cover points (lean_dir, quality 0..1, lanes), Objectives (Battle: obj_id,
   order, capture_time, capture rect), Bounds, optional Lights.
4. Bake minimap: `tools/bake_minimap.gd maps/<id>`.
5. `data/maps/<id>.tres` (MapDef): supported_modes, briefing (lore: corporate
   proxy war, dry tone), ambience/music ids, lighting preset.
6. Verify: seeded sim on the map (no-stall + fairness invariants), screenshot
   minimap + spawn views, cover-point density check (≥1 per 3 lanes).

## Add faction / difficulty / radio / palette
- Faction: `data/factions/<id>.tres` — colors (colorblind-safe vs existing),
  emblem, callsign pool (European names), radio line sets (see
  `docs/design/radio-lines.md` for tone/events), doctrine weights (AI flavor:
  hold-vs-push bias).
- Difficulty: `data/difficulty/<id>.tres` — reaction/aim-error/turn-rate ranges,
  aggression/discipline biases. NEVER scales sensors (fairness rule).
- Radio: lines live in FactionDef dictionaries event→Array[String];
  placeholders {callsign} {grid} {weapon}. Events list: radio-lines.md.
- Palette: `data/palettes/<id>.tres` — tile/HUD colors; rig reads faction colors.

## Verification gate (always)
`tools/verify.sh` (unit + quick sims + screenshots). Content-specific: weapon →
TTK sim; map → seeded battle sim both modes it supports; class → loadout sim.
Commit scoped: `feat(content): add <id> …`. Update docs/credits.md if new assets.
