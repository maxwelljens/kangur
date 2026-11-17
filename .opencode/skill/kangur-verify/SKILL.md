---
name: kangur-verify
description: Verify Kangur changes — unit tests, headless battle simulations, fairness invariants, balance metrics, screenshots, the full verify gate. Use after any gameplay/UI change, before commits, when debugging balance or NPC fairness, or when asked to test/screenshot the game.
---

# Kangur Verification

Contracts: `docs/architecture.md` §11. Commands live in `tools/verify.sh`
(pinned there once the test framework is installed — check it first).

## Layers of verification
1. **Parse/boot**: `godot --headless --path . --import` clean;
   `--check-only --script <file>` for new scripts; `tools/smoke_core.tscn`
   boots autoloads → CORE_SMOKE_OK.
2. **Unit tests** (headless): pure models first — WeaponModel spread/recoil/
   TTK, BodyModel wounds/bleed/bandage, MovementModel accel/friction/stamina,
   MatchRules tickets/capture/timeouts, UtilityAI scoring, MemoryModel decay.
   Framework CLI per `docs/research/godot-tech.md` (see tools/verify.sh).
3. **Battle sims** (headless, seeded): `godot --headless --path . --
   --sim=<map>:<mode>:<seed>:<count>`. Full Match, 24 AI, fast-forward.
   EVERY sim asserts:
   - terminates within time limit + grace (no stalls);
   - **fairness**: every NPC kill had LOS-or-prior-sighting at fire time;
     no damage through non-penetrable walls;
   - no bunching: mean nearest-teammate distance > 48 px while moving;
   - metrics logged (cover %, flanks, check-six, killzone reactions,
     bandages, win rates) → `reports/sim/*.json`.
   Balance gate: faction win rates 45–55% over 200 seeds/map/mode; weapon
   TTK within design targets ±15% (design §6).
4. **Screenshots** (display :0 required): `godot --path . --
   --shot=<scene>:<frames>:<out.png>` → SHOT_OK. In-game F12. Fixtures:
   `tools/shot_*.tscn` (rig states, tiles, HUD mock, menus). UI changes =
   before/after screenshots, inspect visually. Headless CANNOT screenshot.
5. **Full gate**: `tools/verify.sh` — unit + 3 quick sims + UI screenshots;
   nonzero exit on any failure. Run before every commit.

## Workflow per change
- Pure-model change → unit test red→green → module tests.
- Gameplay-affecting → seeded sim, compare metrics vs baseline in reports/sim/
  (fairness invariants MUST hold; balance shifts need justification).
- UI/aesthetic → screenshot fixture + visual inspection.
- AI → sims + F3 overlay observation (see kangur-ai skill).
- New content → content-specific sims (kangur-content skill).

## Reporting
- Never dump raw test logs into chat; summarize pass/fail counts + failures.
- Sim metrics: quote the specific numbers that changed (win rate, cover %,
  TTK) with seed counts.
- Screenshots: save under reports/screenshots/ (gitignored), reference paths.
- Flaky sim? Fix the seed/determinism bug — sims must be reproducible.

## Pitfalls
- Headless: audio no-ops, no viewport texture — code must tolerate both;
  never gate logic on rendering/audio success.
- Physics queries only in _physics_process; sims fast-forward via manual
  tick loops, not Engine.time_scale (determinism).
- New assets need `--import` pass before headless runs (.import committed).
- If a sim stalls: check rules timeout grace + AI stalemate breaker
  (Suppress/Flank stall timer) — stall is a BUG, not a feature.
