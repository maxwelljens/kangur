# Kangur — Architecture & Contracts

Godot 4.7.2, GDScript (typed everywhere), renderer **GL Compatibility**,
2D physics 60 Hz, gravity 0. Design authority: `docs/design/game-design.md`.
Research inputs: `docs/research/*.md`.

This document defines the **stable contracts** all modules code against.
Change a contract only deliberately (it ripples); everything else is module-local.

---

## 1. Directory Layout & Ownership

```
project.godot
addons/                  # vendored: godot-vision-cone, at-icons, test framework
assets/                  # curated copies from asset library (see research/asset-inventory.md)
  audio/{weapons,sfx,ui,music,ambience,footsteps,voice}/
  sprites/{characters,weapons,tiles,decals,effects}/
  ui/{hud,menus,icons,crosshairs,fonts}/
data/                    # ALL content definitions (.tres) — designer-facing
  weapons/ classes/ equipment/ factions/ maps/ difficulty/ radio/
src/
  core/                  # autoloads, enums, Intent, EventBus, Settings, Game, Dev, Defs
  combat/                # WeaponModel, Ballistics, ProjectileSystem, EquipmentSystem
  health/                # BodyModel, wound logic
  movement/              # MovementModel, stamina
  vision/                # cone integration, fog, team sharing, visibility gating
  audio/                 # AudioDirector, occlusion, sound events, footsteps
  ai/                    # perception, memory, blackboard, utility scorer, behaviors,
                         # personality, squad coordinator, team intel, danger map
  entities/              # Character scene+script, components, rig, controllers
  world/                 # map loading, TileMapLayer helpers, cover points, objectives,
                         # navigation, surface queries, minimap baking
  modes/                 # MatchRules base, EliminationRules, BattleRules, Match runtime
  ui/                    # theme, HUD, minimap, menus (title/lobby/settings/credits/
                         # pause/debrief), scoreboard, killfeed, radio
maps/                    # map scenes: dustworks/ compound/ terminal/ oldtown/ range/
tests/
  unit/                  # mirrors src/ modules; pure-logic tests
  simulation/            # battle sims, balance harness, fairness probes
tools/                   # screenshot harness, minimap baker, asset import scripts
docs/                    # design, architecture, research, adding-content
reports/                 # gitignored: screenshots, sim metrics, test output
.opencode/skill/         # project skills: kangur-content, kangur-ai, kangur-verify
```

**Dependency rule** (enforced by review):
`core` ← everything; `combat/health/movement/vision/audio/ai` are siblings that
communicate via **EventBus + interfaces**, never by reaching into each other's
nodes; `entities` composes them; `modes` orchestrates; `ui` reads models and
listens to EventBus, never mutates gameplay except through `Game`/Intent.
Pure model classes (below) depend on **nothing** except `core` enums/math.

## 2. Collision Layers (project-wide constants in `core/layers.gd`)

| Layer | Name | Used by |
|---|---|---|
| 1 | WORLD | high walls/static geometry (TileMapLayer physics), blocks bullets+vision+sound |
| 2 | CHARACTER | CharacterBody2D bodies |
| 3 | INTERACT | doors, objective zones (Area2D) |
| 4 | EQUIPMENT | grenades (RigidBody2D) |
| 5 | LOW_COVER | crates/cars/sandbags: blocks movement+bullets, NOT sound; vision stance-conditional |
| 6 | GLASS | windows: blocks movement, 1-wall sound, NOT vision; penetrable, shatters after 2 hits |

Masks (constants in `core/layers.gd`): characters `1|2|3|5|6`; bullet sweep
`1|2|5|6`; entity-gating vision rays `1|3|5|6` (filtered: glass passes, low
cover stance rules); player fog cone polygon `1|3` standing / `1|3|5` crouched;
sound occlusion `1|6`; equipment `1|2|4|5|6`. `Layers` exposes all as named
consts. VisionSystem filters ray hits by tile custom data + endpoint stances.

## 3. Autoloads (registration order)

1. **EventBus** (`core/event_bus.gd`) — signals only, no state (contract §5).
2. **Defs** (`core/defs.gd`) — scans `res://data/**` at boot, indexes all
   `*Def` resources by `id: StringName`. API: `Defs.weapon(id) -> WeaponDef`,
   `.cls(id)`, `.equipment(id)`, `.faction(id)`, `.map(id)`, `.difficulty(id)`,
   `.all_weapons() -> Array[WeaponDef]` etc. Missing id → push_error + null.
3. **Settings** (`core/settings.gd`) — ConfigFile `user://settings.cfg`.
   Sections: video, audio, controls, gameplay. Applies on change; emits
   `EventBus.settings_changed`. Owns InputMap defaults + rebinds (§8).
4. **AudioDirector** (`audio/audio_director.gd`) — buses, music, pooled
   spatial players, occlusion routing (§9). Headless-safe (no-op when
   `DisplayServer.get_name() == "headless"`).
5. **Game** (`core/game.gd`) — app flow. `Game.to_title() / to_lobby() /
   to_match(config: MatchConfig) / to_debrief(result) / quit()`. Holds
   `MatchConfig` (mode id, map id, player team/class/loadout, bot counts,
   difficulty, rules overrides, seed) and last `MatchResult`. Scene transitions
   with fade; captures/releases mouse.
6. **Dev** (`core/dev.gd`) — CLI user args (`OS.get_cmdline_user_args()`),
   screenshot harness (§11), debug overlays (F3: AI state, vision cones,
   nav paths, danger map), F12 screenshot, sim fast-forward. Active in debug
   builds; stripped behavior in release except `--shot`.

## 4. Core Contracts (`src/core/`)

### enums.gd (`class_name Enums`)
```gdscript
enum Team { BASTION = 0, SIROCCO = 1 }
enum Stance { STAND, CROUCH }
enum Part { HEAD, TORSO, ARM_L, ARM_R, LEG_L, LEG_R }
enum FireMode { SEMI, BURST, AUTO, BOLT, PUMP }
enum Surface { CONCRETE, SAND, METAL, GRASS, WOOD, GLASS, WATER }
enum Mode { ELIMINATION, BATTLE, TRAINING }
```

### intent.gd (`class_name Intent extends RefCounted`)
The **single control interface** for player and AI. Controllers produce it;
`Character` consumes it each physics tick. Reset per tick by controller.
```gdscript
var move: Vector2 = Vector2.ZERO        # desired dir, len 0..1
var aim: Vector2 = Vector2.RIGHT        # desired world aim dir (normalized by consumer)
var fire: bool = false                  # trigger held (auto)
var fire_press: bool = false            # trigger edge (semi/bolt/pump)
var focus: bool = false                 # RMB brace
var sprint: bool = false
var stance: Enums.Stance = Enums.Stance.STAND
var reload: bool = false
var bandage: bool = false               # hold-to-channel
var switch_slot: int = -1               # 0 primary, 1 sidearm, -1 none
var cycle_fire_mode: bool = false
var throw_equipment: int = -1           # index into kit, -1 none
var cook: bool = false                  # hold frag fuse
var interact: bool = false
```

### Pure models (RefCounted, zero node deps → headless-testable)
Each has `tick(dt: float)` and explicit state; **no** EventBus inside models —
the owning node translates model outputs into events. This is what makes
thousands of battle sims cheap.

- `MovementModel` — state: velocity, stamina, stance, speed_mults.
  `tick(intent, dt) -> Vector2 velocity`. Source-style accel/friction.
  Config injected (walk/sprint/crouch speeds, accel, friction, stamina rates).
- `WeaponModel` — one equipped weapon instance. State: mag, reserve, bloom,
  recoil_offset, cycle timer, reload timer, fire mode, burst counter.
  `tick(dt, intent_ctx)`, `try_fire() -> Array[ShotRequest]` (pellets),
  `start_reload()`, `switch_mode()`. Spread/recoil math in `Ballistics` (static).
  `ShotRequest { origin: Vector2, dir: Vector2, speed: float, damage: float,
  penetration: float, falloff_start/end, min_mult, tracer_len, weapon_id }`.
- `BodyModel` — parts HP, armor durability, bleed stacks, regen timer,
  bandage channel. `apply_hit(part, damage, penetration, attacker_info) ->
  HitResult { died, fatal_part, bleed_added, crippled, absorbed }`,
  `tick(dt)`, `start_bandage() -> bool`, `interrupt_bandage()`,
  getters for HUD + modifiers (`speed_mult()`, `spread_mult()`, `reload_mult()`).
- `MemoryModel` — per-NPC: contacts `{team, pos, time, confidence, entity_id}`,
  heard sounds, decay. `see(pos, id, team)`, `hear(pos, loudness, kind)`,
  `tick(dt)`, `best_threat()`, `last_seen(id)`.
- `Personality` — rolled traits (0..1): aggression, caution, discipline,
  aim_skill, reaction, campiness, curiosity, independence. `static roll(rng)`.
- `UtilityAI` (static) — `choose(candidates: Array[Action], bb) -> Action`
  with scores + hysteresis; `Action { id: StringName, score: float, data: Dictionary }`.
- `MatchRules` (base, RefCounted) — `tick(snapshot: MatchSnapshot, dt) ->
  Array[RuleEvent]`; subclasses EliminationRules / BattleRules. Snapshot is a
  plain data struct (alive counts, tickets, objective states, elapsed).
- `OcclusionMath` (static) — `wall_count -> { bus: int, volume_db: float,
  cutoff: float }`, `loudness -> max_distance`.

### Character (scene `entities/character.tscn`, CharacterBody2D)
Composition (children, each a small Node script wrapping a pure model):
`Motor` (MovementModel + move_and_slide), `Body` (BodyModel),
`Arsenal` (WeaponModel ×2 + equipment state), `Aim` (aim dir state, recoil
offset application, turn-rate limit for AI), `Perception` (cone + hearing +
MemoryModel; player: drives fog/minimap; NPC: drives blackboard),
`Controller` (PlayerController | AIController — both fill an Intent),
`Rig` (procedural vector character: single Node2D `_draw`, parts = shadow/
legs/torso/head/arms/weapon, free rotation to aim, walk/stance/recoil/reload/
bandage/death animations, faction palettes + class silhouette cues; weapon
silhouette from WeaponDef visual params so muzzle visual = ballistic muzzle;
optional texture-overlay hooks for future art; see docs/design/art-direction.md).
Muzzle flash, brass, blood decals spawned via EventBus.
Character exposes: `team`, `callsign`, `class_def`, `is_player`, `alive`,
`intent` (read-only for debug), model getters for HUD/AI.
**Fairness**: NPC aim goes through the same `Aim` turn-rate/error pipeline and
the same `WeaponModel` spread as the player.

### AI runtime (per NPC)
`AIController` (Node) owns `Blackboard` (RefCounted): self-ref, personality,
memory, `TeamIntel` ref (shared per team), danger map ref, current action +
timer, nav target, squad role. Decision tick 5–10 Hz (staggered per NPC);
intent produced every physics tick (continuous aim tracking, movement).
Behaviors are small classes implementing `score(bb) -> float` and
`enter/tick/exit(bb, controller)` producing intent fields:
Advance, Engage, Suppress, TakeCover, Peek, Flank, HoldAngle (camp),
CheckSix, Investigate, Retreat, Regroup, Bandage, Reload, AvoidDanger,
UseEquipment, CaptureObjective, DefendObjective.
`SquadCoordinator` (Node, per team) owns `TeamIntel` (radio-delayed sightings,
danger map grid 64 px cells with decay) and assigns loose roles per phase.

## 5. EventBus Signals (exact contract)

Loose types (Node/Variant) to avoid class cycles; concrete types documented.
```gdscript
# combat
signal shot_fired(shooter: Node, weapon_id: StringName, origin: Vector2, dir: Vector2, pellets: int)
signal bullet_impact(pos: Vector2, normal: Vector2, surface: int, penetrated: bool)
signal character_hit(victim: Node, attacker: Node, part: int, damage: float, fatal: bool, pos: Vector2)
signal character_died(victim: Node, attacker: Node, weapon_id: StringName, pos: Vector2, distance: float)
signal weapon_reloaded(who: Node, weapon_id: StringName)
signal weapon_switched(who: Node, weapon_id: StringName)
signal fire_mode_changed(who: Node, mode: int)
signal bandage_started(who: Node)
signal bandage_finished(who: Node, part: int)
signal equipment_thrown(who: Node, kind: StringName, pos: Vector2)
signal equipment_detonated(kind: StringName, pos: Vector2, radius: float)
signal flash_effect(who: Node, strength: float)   # applied to characters in LOS
# perception / world
signal sound_emitted(pos: Vector2, loudness: float, kind: StringName, source: Node, surface: int)
signal enemy_spotted(spotter: Node, enemy: Node, pos: Vector2)   # immediate local; radio delayed via TeamIntel
signal radio_message(team: int, from_callsign: String, text: String, priority: int)
signal objective_progress(obj_id: StringName, team: int, progress: float, contested: bool)
signal objective_captured(obj_id: StringName, team: int)
signal tickets_changed(team: int, tickets: int)
signal match_ended(winner: int, reason: StringName)
signal spawn_requested(team: int, pos: Vector2)   # modes → world
# meta
signal settings_changed(section: StringName)
signal match_state_changed()                      # HUD refresh hint
```
Rules: emitters never assume listeners; no return values; high-frequency
events (shot_fired) are fine — listeners must be cheap. `sound_emitted` is the
ONLY audio gameplay path (footsteps, guns, foley, explosions); AudioDirector
renders it for the player, Perception hears it for NPCs.

## 6. Data Resources (`src/core/data/*.gd` schemas, `data/**/*.tres` instances)

All defs: `class_name XDef extends Resource`, `@export var id: StringName`,
`@export var display_name: String`, plus typed fields per design doc §6–§8.
- `WeaponDef`: category, fire_modes: Array[int], rpm, burst_count, mag_size,
  reserve_mags, reload_time, equip_time, bullet_speed, damage, pellets,
  spread_base/bloom_per_shot/bloom_max/bloom_recovery, move_penalty_scale,
  recoil_kick/recoil_recovery, penetration, falloff_start/end/min_mult,
  focus_mult, move_speed_mult, sound_set: StringName, sprite paths,
  tracer_color, shell_color, weight.
- `ClassDef`: speed_mult, armor_vest/armor_helmet (durability), bandages,
  primary_categories: Array[StringName], sidearm_id, equipment: Array[StringName],
  perk_id: StringName, icon, description.
- `EquipmentDef`: kind (FRAG/FLASH/SMOKE), fuse, radius, damage, vision_block_time,
  sprite, sounds.
- `FactionDef`: colors (primary/accent), emblem, callsigns: Array[String],
  radio line sets, doctrine weights (AI flavor).
- `MapDef`: scene_path, supported_modes: Array[int], briefing, minimap_path,
  ambience_id, music_id, lighting preset.
- `DifficultyDef`: reaction_range, aim_error_range, turn_rate_range,
  aggression_bias, discipline_bias, burst_range.
- `SoundSetDef`: action → Array[AudioStream] (fire, cycle, reload_start/end,
  dry, draw, impact sets by surface).
Content is loaded by `Defs` via DirAccess scan; **no hardcoded content lists**.

## 7. World & Maps

Map scene template (`maps/_template/`): root `Node2D` named Map with children:
- `Ground`, `Walls`, `Deco` — TileMapLayer (Walls: physics layer 1 + navigation
  layer + custom data `surface: int`, `penetrable: bool`, `low_cover: bool`,
  `blocks_sound: bool`). Low cover (crates/cars): blocks movement+bullets, not
  sound; vision blocked only vs crouched targets or for crouched observers —
  VisionSystem filters ray hits by tile data + endpoint stances (design §5).
  Glass: blocks movement, 1-wall sound, not vision; shatters after 2 hits.
- `Nav` — NavigationRegion2D (baked from Walls navigation layer; agents radius 10).
- `Spawns` — Node2D of Marker2D: `spawn_bastion_01…`, `spawn_sirocco_01…`.
- `Cover` — Node2D of `CoverPoint` (Marker2D script): `lean_dir: Vector2`,
  `quality: float 0..1`, `lanes: Array[StringName]`.
- `Objectives` — Node2D of `ObjectiveZone` (Area2D + CollisionShape2D, layer 3):
  `obj_id`, `order`, `capture_time`, `lock_on_capture`.
- `Bounds` — Rect2 via marker pair or Area2D for camera clamp + minimap extent.
- `Lights` — optional CanvasModulate + PointLight2D for dusk maps.
`World` node loads map scene, exposes queries: `surface_at(pos)`,
`cover_points_near(pos, radius)`, `spawn_points(team)`, `objective(id)`,
`random_patrol_point(rng, team)`, `is_wall(pos)`. Minimap PNG baked by
`tools/bake_minimap.gd` (renders Walls+Ground silhouette to Image at 4 px/tile).
Navigation: NavigationAgent2D per character + NavigationServer2D avoidance
(RVO) enabled, radius 12, max neighbors 6, time horizon 1.5 — spacing without
conga lines. Personal goal offsets (±40 px) per NPC per order.

## 8. Input (defaults defined in code, `core/input_defaults.gd`)

Actions: move_up/down/left/right (WASD+arrows), sprint (Shift hold), crouch
(Ctrl toggle, setting), fire (LMB), focus (RMB), reload (R), bandage (B hold),
use (E), slot_primary (1), slot_sidearm (2), cycle_mode (X), equip_1 (G),
equip_2 (F), cook (hold G), scoreboard (Tab), pause (Esc), screenshot (F12),
debug_overlay (F3), spectate_next (Space, when dead). Rebinds persisted by
Settings; conflicts detected. Mouse captured in match only.

## 9. Audio Occlusion Pipeline

Buses: `Master → Music, SFX, Voice`; SFX children: `SFX_Open, SFX_Light,
SFX_Heavy, SFX_Muffled` (lowpass cutoffs 20500/4200/1300/550 Hz, gains
0/−4/−9/−14 dB). On `sound_emitted`: if listener (player camera pos) within
loudness-derived max distance → raycast (SOUND_MASK) count walls → pick bus →
pooled `AudioStreamPlayer2D` (position, max_distance, attenuation 1.6,
bus). Moving sources (footsteps are one-shots; equipment loop) update per tick.
NPC hearing: `Perception` computes occluded loudness at NPC pos (same math,
no rendering) → `MemoryModel.hear` if above threshold. Headless: AudioDirector
no-ops; game logic unaffected (sound_emitted still fires for AI).

## 10. Match Runtime

`match.tscn` root `Match` (Node2D): World, Characters (Node2D), Projectiles
(ProjectileSystem: single _physics_process sweeps all active bullets, pooled
tracer Line2D/Node2D visuals), EquipmentSystem, VisionSystem (fog overlay +
visibility gating + team sharing), SquadCoordinators ×2, RulesRunner (wraps
MatchRules, builds MatchSnapshot each tick, applies RuleEvents: spawns,
objective updates, match end), HUD (CanvasLayer), CameraRig.
`Match.start(config: MatchConfig)`: load map, spawn combatants (player +
bots with rolled personalities/loadouts), init rules, seed RNG
(`RandomNumberGenerator` per subsystem from match seed — determinism for sims).
Death → drop decals, radio kill call, rules notified; Elimination: spectate;
Battle: respawn waves via `spawn_requested`. `MatchResult` → Game.to_debrief.

## 11. Verification (tests + screenshots + sims)

- **Unit tests**: framework per `docs/research/godot-tech.md` recommendation,
  headless CLI. Pure models tested exhaustively (spread curves, TTK tables,
  bleed/bandage math, movement feel constants, rules logic: tickets, timeouts,
  capture contest/recapture, utility scoring sanity, memory decay).
- **Battle sims** (`tests/simulation/`): full Match headless with 24 AI,
  fixed seeds, manual fast-forward (Dev sim mode: tick loop without rendering
  waits). Invariants asserted every sim:
  1. match terminates (no stalls) within time limit + grace;
  2. **fairness**: every NPC kill had LOS-or-prior-sighting at fire time
     (VisionSystem logs shot provenance); no damage through non-penetrable walls;
  3. no bunching: mean nearest-teammate distance > 48 px during movement phases;
  4. coverage: NPCs used cover (≥30% of engaged time), checked six, flanked,
     bandaged, reacted to killzones (metrics, not hard asserts, logged to JSON);
  5. balance: faction win rates within 45–55% over 200 seeded sims per map/mode;
     weapon TTK within design targets ±15%.
  Metrics → `reports/sim/*.json`; balance harness prints tables.
- **Screenshots**: `Dev` harness: `godot --path . -- --shot=<scene_path>:<frames>:<out.png>`
  loads scene, waits frames (await RenderingServer.frame_post_draw), captures
  viewport texture, saves, quits (exit code 0/1). In-game F12 →
  `reports/screenshots/`. UI verification = screenshot + visual inspection.
  Menu flow smoke test drives Game transitions headless-with-display.
- **CI-style gate**: `tools/verify.sh` runs unit tests + 3 quick sims +
  screenshots of title/lobby/match HUD; nonzero exit on failure.

## 11a. UI Module (`src/ui/`)

Landed UI wave. Paths are fixed by `Game` (§3.5) — rename only together.

```
src/ui/theme.gd            KangurTheme: palette consts + Theme builder (source of truth)
src/ui/kangur_theme.tres   the one Theme resource; every screen assigns it
src/ui/holo_widgets.gd     custom _draw widgets (Plate, Bar, BodyDiagram, ArmorPips,
                           MinimapFrame, ObjectiveChain, Crosshair, Hitmarker,
                           DamageArcs, LowHpVignette, KillfeedEntry, RadioLine,
                           WeaponGlyph, EquipIcon, Rule)
src/ui/holo_button.gd      HoloButton (Button subclass: bracket plate, hover glow)
src/ui/menu_screen.gd      MenuScreen base: theme, scanlines, entrance, Esc→back
src/ui/ui_fx.gd            UiFx: 120–180 ms eases, staggered entrances, UI blips
src/ui/title/…             title_screen + port_diorama (procedural dusk port)
src/ui/menus/…             lobby, settings, credits, debrief
src/ui/pause/pause_menu.tscn   overlay, Esc-toggled, inside the HUD CanvasLayer
src/ui/hud/hud.tscn|gd     match HUD (CanvasLayer, layer 10)
tools/shot_ui_*.tscn       screenshot fixtures (HUD mock, debrief, pause, tabbed settings)
```

**HUD ↔ entity wiring (thin bind layer, no Character dependency).**
`hud.bind_character(character)` reads, defensively via `get()`:
`team:int`, `callsign:String`, `class_def:ClassDef`,
`get_body_model()->BodyModel` (fallback property `body_model`),
`get_weapon_model()->WeaponModel` (fallback `weapon_model`),
`get_bandages()->int` (fallback `bandages`, then `class_def.bandages`),
`get_equipment_counts()->Array[Dictionary]` of `{kind: Enums.EquipKind, count: int}`
(optional). Everything is null-tolerant: an unbound HUD renders a healthy
silhouette and empty blocks, so menus/tests never depend on a spawned entity.
`hud.refresh()` is safe at any rate; the HUD also self-ticks at 10 Hz.

**Feeds the match runtime pushes** (no EventBus invented for these):
`set_roster(rows)` (MatchResult.characters shape + `alive:bool`),
`set_minimap_blips([{pos:Vector2 0..1, kind:&"player|ally|enemy|sound",
color:Color, dir:Vector2}])`, `set_minimap_cone({pos, dir, half_deg, dist})`,
`set_objectives([{id, letter, state, team, progress, contested, pos}])`,
`set_alive_counts(bastion, sirocco)`, `set_tickets(bastion, sirocco)`,
`set_equipment([...])`, `show_damage_angle(rad)`, `show_killcam(...)`,
`clear_killcam()`.

EventBus listeners already wired: `character_died` (killfeed + killcam),
`character_hit` (kill hitmarker), `radio_message` (lines, own team only),
`objective_progress` (chain + minimap), `tickets_changed` (bars + warning),
`settings_changed` (HUD scale relayout, crosshair style/colour).

**VisionSystem / minimap hook**: `MinimapFrame` owns the holo frame, grid,
objective markers and a normalised blip API. The world module only has to hand
it normalised positions (`pos - bounds.position / bounds.size`) — it never
draws the frame itself. Baked `MapDef.minimap_path` textures are used as the
floor layer when present.

**UI audio** goes through `UiFx.play_sound(key)` on `assets/audio/ui/*.ogg`
(one shared `AudioStreamPlayer` on the tree root, headless no-op). Music is
still AudioDirector's job; screens only play interface blips.

**Screenshot gate**: `tools/shot_ui_all.sh` captures every screen at
2560×1440 (1.6 stretch = the 1600×900 design viewport) into
`reports/screenshots/ui_*.png`.

## 12. Conventions

- GDScript official style: snake_case funcs/vars, PascalCase classes/nodes,
  SCREAMING_SNAKE consts, `StringName` for ids (`&"kestrel"`).
- **Static typing everywhere** (`var x: float`, `-> void`, typed arrays).
  No untyped Dictionary soup across module borders — use structs/Resources.
- Signals past tense (`character_died`), methods imperative (`try_fire`).
- One class per file, `class_name` only for widely-used contracts; module-local
  helpers use `const X = preload(...)`.
- No `get_node("../../..")` — inject refs via `setup()`/exports; composition over
  inheritance for entities.
- Pure models never touch nodes/singletons; nodes translate models ↔ EventBus.
- Every gameplay constant lives in data or a named const — no magic numbers
  in behavior code.
- Comments explain WHY; docs/adding-content.md explains HOW for designers.
- Commits: conventional (`feat(ai): …`, `fix(combat): …`, `test(sim): …`,
  `docs: …`, `chore: …`). Small, scoped, green tests before commit.
- Asset licenses: only curated packs with verified licenses ship; attribution
  in `docs/credits.md` + in-game Credits (EUPL compatibility checked per pack).
