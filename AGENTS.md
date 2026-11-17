# AGENTS.md — Kangur Development Manual

Kangur: production-grade singleplayer topdown 2D tactical shooter (Godot 4.7.2,
GDScript). CS2D aesthetics, Hotline Miami lethality, Tarkov-ish firearm handling,
Door Kickers-ish tactics. **NPCs are the product** — organic, fair, unpredictable.

Read order for any task: this file → `docs/architecture.md` (contracts) →
`docs/design/game-design.md` (design authority) → relevant `docs/research/*.md`.
Project skills (load via skill tool): `kangur-content` (add weapons/maps/classes),
`kangur-ai` (NPC behavior work), `kangur-verify` (tests/sims/screenshots).

## Environment

- Godot **4.7.2** at `/usr/bin/godot` (Arch). Display `:0` available → real
  rendering + screenshots work. Headless (`--headless`) for logic tests only
  (no rendering, audio no-ops — code must tolerate both).
- Repo: `master` branch, EUPL-1.2 (`LICENSE`). Conventional commits, scoped,
  tests green before commit. Never commit `reports/`, `.godot/`.
- Asset library (read-only source): `/home/mjensen/Obrazy/Assets` — curated
  copies live in `assets/`. Inventory + licenses: `docs/research/asset-inventory.md`.
  **Check license before copying any pack**; attribution → `docs/credits.md`.
- Prefer `/tmp/opencode` for scratch. 16 cores — parallel subagents fine.

## Golden Rules

1. **Contracts first**: `docs/architecture.md` §4–§6 (Intent, pure models,
   EventBus, Defs) are stable interfaces. Code against them; don't invent
   parallel systems. Changing a contract = deliberate, documented, rippling.
2. **Fairness is sacred**: NPCs perceive ONLY via cone vision + occluded hearing
   + delayed/noisy team radio. No reading enemy positions directly. Every NPC
   shot must be justified by perception (sim tests assert this).
3. **Pure logic, node shells**: gameplay math lives in RefCounted models
   (`WeaponModel`, `BodyModel`, `MovementModel`, `UtilityAI`, `MatchRules`…).
   Nodes wrap models, translate to/from EventBus. This is what makes headless
   battle sims and thousands of unit tests possible. Keep it that way.
4. **Data-driven content**: weapons/classes/maps/factions/difficulty are `.tres`
   Resources under `data/` loaded by `Defs`. Zero hardcoded content lists.
   New content must not require code changes (see `kangur-content` skill).
5. **Typed GDScript**, official style guide. No magic numbers — named consts or
   data fields. No `../../..` node reaching — inject refs.
6. **Verify, don't assume**: run unit tests + relevant sim + screenshot after
   changes (commands below). Godot API problems → fetch official docs
   (docs.godotengine.org), never fuzz arguments blindly.
7. **Every match fresh**: per-match seeded RNG, rolled NPC personalities,
   route/linger jitter. Never deterministic bot choreography.

## Commands

**ALWAYS invoke Godot via `tools/godot.sh`** (flock-serialized wrapper) —
concurrent godot runs race on the `.godot` cache and corrupt imports.
Parallel agents share this lock; never call `/usr/bin/godot` directly.

```bash
# Editor
godot --path . -e

# Run game (display :0)
godot --path .

# Unit tests (headless) — framework CLI per docs/research/godot-tech.md
# (gdUnit4 example; actual command pinned in tools/verify.sh once installed)
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/unit

# Battle simulation (headless, seeded, metrics to reports/sim/)
godot --headless --path . -- --sim=<map>:<mode>:<seed>:<count>

# Screenshot any scene (needs display)
godot --path . -- --shot=res://src/ui/title/title_screen.tscn:20:reports/screenshots/title.png
# In-game: F12 → reports/screenshots/, F3 → debug overlays

# Full gate: unit + quick sims + UI screenshots
tools/verify.sh
```

## Layout (ownership map)

`src/core` autoloads+contracts · `src/combat` weapons/ballistics/projectiles ·
`src/health` BodyModel/wounds · `src/movement` MovementModel/stamina ·
`src/vision` cones/fog/team-sharing · `src/audio` occlusion pipeline ·
`src/ai` perception→memory→blackboard→utility→behaviors + squad/intel/danger ·
`src/entities` Character composition + controllers + rig · `src/world` maps/nav/
cover/objectives · `src/modes` rules + Match runtime · `src/ui` theme/HUD/menus ·
`maps/` authored map scenes · `data/` content · `tests/unit|simulation` ·
`tools/` harnesses. Full detail: architecture §1.

## Workflow for changes

1. Locate module + contract; check `docs/research/` if API/mechanic uncertainty.
2. Implement pure-model change first + unit test (red→green), then node shell.
3. Run module tests; if gameplay-affecting, run a seeded battle sim and compare
   metrics vs baseline in `reports/sim/` (fairness invariants MUST hold).
4. UI/aesthetic change → screenshot before/after, inspect visually.
5. Update docs if contract/content-workflow changed; commit scoped.

## Known Pitfalls

- Godot 4.7: TileMapLayer (not TileMap); `NavigationServer2D` avoidance needs
  `NavigationAgent2D.avoidance_enabled`; physics queries inside
  `_physics_process` only (space state direct access).
- GL Compatibility renderer: no compute shaders, canvas_item shaders fine;
  test any shader visually via screenshot.
- Headless: `get_viewport().get_texture()` is unusable; AudioDirector must
  no-op; never gate gameplay logic on audio/rendering success.
- Class cycles: EventBus uses loose types; `class_name` sparingly (contracts
  only); preload module-local helpers.
- Fast bullets (4000–9000 px/s) MUST be swept raycasts per tick — never
  Area2D-overlap-only (tunneling). See combat module.
- `.import` files ARE committed; `.godot/` is NOT. New assets need an editor
  import pass (`godot --headless --path . --import`) before headless runs.
