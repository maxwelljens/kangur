# Battle Simulation Harness — Contract

Headless, seeded, deterministic full-match sims for correctness, fairness, and
balance. Implements architecture §11. Consumed by `src/modes/` (Match runtime),
`src/ai/` (metrics), `src/vision/` (shot provenance). CLI:
`tools/godot.sh --headless --path . -- --sim=<map>:<mode>:<seed>:<count>`
(Dev parses → `SimRequest` → `EventBus`/handler; `src/modes/sim_runner.gd`).

## Determinism rules
- Fixed `dt = 1.0/60.0`. **Manual tick loop**, NOT `Engine.time_scale`
  (research-verified: time_scale coarsens steps, doesn't speed wall-clock).
  Sim advances N ticks per frame without rendering waits.
- One master `RandomNumberGenerator` seeded from `seed`; each subsystem derives
  a child stream (`rng.seed = hash(seed, subsystem_id)`) so adding a subsystem
  doesn't shift others' rolls. Personalities, routes, linger, spread all seeded.
- Headless: audio no-ops, no viewport texture. Gameplay logic MUST NOT depend
  on rendering/audio success. `sound_emitted` still fires (AI hearing works).
- Same seed + same data ⇒ identical kill timeline. Flakiness = a determinism bug.

## Fairness provenance (the sacred invariant)
`VisionSystem` logs, for EVERY NPC shot fired:
```
ShotProvenance {
  shooter_id: int, target_id: int, weapon_id: StringName,
  had_los_at_fire: bool,          # cone + stance-aware LOS to target at fire tick
  prior_sighting_age: float,      # seconds since last confirmed sighting (-1 = never)
  suppressing: bool,              # firing at last-seen/cover edge, not fresh target
  wall_penetrated: bool, pen_surface_penetrable: bool,
}
```
Sim asserts for every NPC **kill**:
1. `had_los_at_fire` OR `prior_sighting_age >= 0` (saw them recently) OR
   `suppressing` with a prior sighting. A fresh blind kill = VIOLATION.
2. No damage applied through a non-penetrable wall (`wall_penetrated` ⇒
   `pen_surface_penetrable` must be true).
3. NPC never read enemy position without perception (audited: AI code path
   only touches MemoryModel/TeamIntel, never enemy nodes directly — enforced
   by a debug guard that flags direct reads in sim builds).
Violations → sim FAILS (exit 100), logged with tick + ids. Zero tolerance.

## Hard invariants (every sim asserts)
- **Termination**: match ends within `time_limit + grace` (grace 30 s for last
  life / objective contest). No stalls. A stall is a BUG (check rules timeout +
  AI stalemate breaker: Suppress/Flank scores rise after 6 s no-progress).
- **Fairness**: zero provenance violations (above).
- **No bunching**: mean nearest-teammate distance > 48 px during movement
  phases (sampled every 0.5 s while team is advancing). Conga lines = FAIL.
- **No friendly fire through walls**: same penetration rule as enemies.

## Metrics (logged, soft gates)
Per sim → `reports/sim/<map>_<mode>_<seed>.json`; aggregate over `count` →
`reports/sim/aggregate_<map>_<mode>.json`:
```
{
  seed, map, mode, duration_s, winner, reason,
  kills: [{tick, killer, victim, weapon, part, distance, provenance_ok}],
  fairness_violations: [],
  bunching_mean_px, cover_pct_engaged_time, flank_count, check_six_count,
  killzone_reactions, bandages_used, retreats, regroups,
  weapon_ttk: {weapon_id: {median_s, hits_median, shots_fired, hits}},
  faction_winrate,   # over count seeds
  objective_timeline, tickets_remaining,
  ai_action_histogram: {behavior_id: ticks_spent},
}
```
Balance gates (flag regressions, don't hard-fail unless egregious):
- faction winrate 45–55% over ≥200 seeds/map/mode (symmetric maps ~50/50).
- weapon TTK within design §6 targets ±15%.
- cover_pct ≥ 30% of engaged time; check_six/flank/killzone reactions > 0
  (behaviors actually trigger); bandages_used > 0 (wound system exercised).
- ai_action_histogram: no single behavior > 60% (bots aren't one-trick).

## Baseline & regression
- `reports/sim/baseline.json` = last accepted aggregate (committed? NO —
  reports/ gitignored; baseline regenerated on demand, stored as a fixture in
  tests/simulation/baseline/ if a permanent reference is needed).
- Balance changes: run before/after aggregates, quote the deltas (winrate,
  TTK, cover%) with seed counts. Fairness invariants must hold in BOTH.

## Quick gate (tools/verify.sh)
3 quick sims (dustworks elimination seed 1, compound elimination seed 1,
terminal battle seed 1), count=1 each, assert hard invariants only (fast).

Implementation notes pinned by `src/modes/sim_runner.gd`:
- `--count` is the number of seeded matches (`seed`, `seed+1`, …), **not** the
  roster. The roster is the full 12/team; `--bots=N` (after `--`) shrinks it
  for quick local runs.
- `--fixed-fps 60` is required. The harness advances one sim tick per physics
  frame because bullet sweeps and LOS rays read the physics space state, which
  only answers inside the step; real-time pacing would make a gate run take the
  full match duration in wall clock.
- Exit 0 = all hard invariants held; 100 = failure (`SIM_FAIL` + per-seed lines).
Full balance suite (200 seeds) is a separate, slower invocation — not in the
per-commit gate.

## Implementation notes
- `sim_runner.gd` builds a Match with all-AI combatants (no player), ticks
  manually, collects metrics from EventBus + model getters, writes JSON
  (FileAccess), quits with exit code (0 pass / 100 fail).
- Match must expose a `sim_tick(dt)` path that bypasses rendering-dependent
  nodes (Rig draws are no-ops headless; VisionSystem still computes LOS for
  provenance; AudioDirector no-ops).
- Provenance logging is cheap (append to array); enabled in sim + debug builds,
  stripped in release.
