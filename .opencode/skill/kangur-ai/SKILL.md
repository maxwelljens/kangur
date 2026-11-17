---
name: kangur-ai
description: Work on Kangur NPC behavior — perception, memory, utility AI, behaviors, personalities, squad coordination, danger maps, fairness. Use when adding/tuning NPC behaviors, debugging bot stupidity or wallhacks, or changing AI decision logic.
---

# Kangur AI Development

**NPCs are the product.** Design pillars: `docs/design/game-design.md` §9.
Architecture: `docs/architecture.md` §4 (AI runtime, Intent, pure models).
Read both before touching `src/ai/`.

## The fairness seam (NEVER violate)
- NPCs perceive ONLY: own vision cone + LOS (stance-aware low-cover rules),
  occluded hearing (`sound_emitted` → loudness at NPC pos), and team radio
  (`TeamIntel`: delayed 0.4–1.5 s + position noise). NEVER read enemy node
  positions directly in AI code.
- NPC aim goes through the same `Aim` turn-rate/error pipeline and the same
  `WeaponModel` spread/recoil as the player. No snap-aim, no perfect tracking.
- Every NPC shot must be justified: LOS at fire time OR a prior sighting
  (suppressing last-seen/cover edges is legal; blind fresh kills are not).
  Sim tests assert this (`tests/simulation/` fairness probes). If you add a
  behavior that fires, it must pass the provenance check.
- Difficulty scales reaction/error/aggression — NOT sensor range or accuracy
  of information.

## Pipeline (per NPC)
`Perception` (cone rays + hearing) → `MemoryModel` (contacts decay 6–12 s,
heard sounds) → `Blackboard` (self, personality, memory, TeamIntel ref,
danger map ref, role, current action) → `UtilityAI.choose()` (5–10 Hz,
staggered; scores + hysteresis) → behavior `tick()` fills `Intent` every
physics tick (continuous aim tracking). `SquadCoordinator` (per team) assigns
loose roles (point/flank/support/anchor) per phase; individuals deviate via
`independence` trait. Spacing: personal goal offsets ±40 px + RVO avoidance.

## Behaviors (src/ai/behaviors/)
Advance, Engage, Suppress, TakeCover, Peek, Flank, HoldAngle, CheckSix,
Investigate, Retreat, Regroup, Bandage, Reload, AvoidDanger, UseEquipment,
CaptureObjective, DefendObjective. Each: `score(bb) -> float` +
`enter/tick/exit`. To add one: new file, register in the behavior list,
write a unit test for scoring sanity + a sim metric proving it triggers.

## Personality (rolled per match, seeded)
Traits 0..1: aggression, caution, discipline, aim_skill, reaction, campiness,
curiosity, independence. Weight utility scores; two NPCs with identical intel
must choose differently. Never hardcode a trait response — weight it.

## Human tempo (the anti-robot rules)
- Linger 0.5–2 s at corners; peek-and-retract; check-six every 8–20 s while
  holding (rotate cone backward 0.6–1.2 s).
- Route jitter among near-equal paths; occasional overpeek mistakes.
- Killzone reaction: 2+ teammate deaths in 6 s within 150 px → danger map
  spike → reroute/hold/smoke/radio warning. Test this explicitly in sims.
- Impossible odds (3+ visible enemies or critical HP vs healthy) → immediate
  cover break. Unlikely odds (2:1) → cautious peek/retreat to team.
- No conga lines: spacing metric (mean nearest-teammate dist > 48 px while
  moving) is asserted in sims.

## Tuning workflow
1. Change weights/ranges in data (`data/difficulty/`, personality ranges in
   `src/ai/personality.gd` consts) — not magic numbers in behaviors.
2. Run seeded battle sims (`--sim=<map>:<mode>:<seed>:<count>`), compare
   metrics JSON vs baseline: cover usage ≥30% engaged time, flank frequency,
   check-six frequency, killzone reactions, bunching, win rates 45–55%.
3. Watch a match with F3 debug overlay (AI state, cones, nav, danger map).
4. Screenshot nothing — AI is verified by sims + overlays, not stills.

## Where it lives (implemented)
- Pure models: `memory_model`, `personality`, `blackboard`, `utility_ai`,
  `danger_map`, `team_intel` (all RefCounted). Node shells: `ai_controller`
  (the brain; `src/entities/ai_controller.gd` is now a thin alias of it) and
  `squad_coordinator` (one per team, self-creating: `SquadCoordinator.for_team`).
- Behaviors: `src/ai/behaviors/*.gd`, all extending `behavior.gd`.
- Headless probes: `tools/godot.sh --headless --path . tools/shot_ai.tscn --
  --ai-selftest` (wiring) and `--ai-sim=<seconds>` (action histogram, kills,
  radio lines, fairness denials). Overlay screenshot: `--shot=res://tools/
  shot_ai.tscn:600:reports/screenshots/ai_overlay.png` (needs DISPLAY).
- Tests: `tests/unit/ai/` — fairness suite is `test_fairness.gd`.
- Tuning knobs are consts at the top of each behavior and blackboard (linger,
  check-six window, spacing, hysteresis, dwell budget). Difficulty only shifts
  aggression/discipline and Aim (never sensors).

## Common failure modes
- Bots bunch → check personal offsets + avoidance enabled + role spacing.
- Bots stalemate → check Suppress/Flank scores rise with stall timer (>6 s).
- Bots feel psychic → audit for direct enemy-position reads; run fairness sim.
- Bots jitter → hysteresis too low; raise action-switch penalty.
- Identical matches → seed not propagated; check per-match RNG derivation.
