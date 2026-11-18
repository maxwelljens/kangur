# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-18

First public release: a playable end-to-end vertical slice. Attached binaries
cover Linux x86_64 and Windows x86_64; both are single self-contained
executables with the game data embedded.

### Added

- Full contract flow: title → operations desk → match → debrief, with a
  holographic HUD, pause and settings screens.
- Three modes: Elimination, Battle (A→B→C objective chain with a ticket clock),
  and Training Range.
- Five maps: Dustworks, Compound, Terminal, Oldtown and Range.
- Twelve weapons with swept-raycast projectiles, penetration, damage falloff,
  spread bloom, recoil and committed reloads.
- Body-part wounds: bleeding, crippled limbs, and a 2.8-second bandage channel.
- Frag, flash and smoke grenades that interact with the vision simulation
  itself, including cookable fuses and bounces.
- Cone fog-of-war, occluded hearing, and delayed, noisy team radio.
- NPC AI: 17 behaviors, utility scoring, per-match rolled personalities, squad
  point/flank/support/anchor roles, danger maps, memory and radio. Fairness
  invariants (zero wallhacks, no bunching, clean termination) are asserted by
  headless battle simulations.
- Data-driven content: 40 `.tres` resources for weapons, classes, factions,
  maps, difficulty presets, radio lines and palettes.
- Spatial audio with occlusion and an adaptive soundtrack.
- 583 unit tests, a seeded headless battle-simulation harness (`--sim=...`),
  and the `tools/verify.sh` verification gate.
- Procedural gameplay trailer pipeline (`tools/promo/`).
- Release tooling: `export_presets.cfg` and `tools/build_release.sh` build the
  Linux and Windows binaries, install and verify the matching export templates,
  package the archives and emit SHA256 checksums.

### Notes

- Balance tuning is ongoing: Battle capture timing and Elimination
  decisiveness are still being adjusted. See `docs/production-todo.md`.
- macOS and Web builds are not shipped in this release.
- Requires a working desktop session for rendering and audio; the game also
  runs headless for simulations. Godot 4.7.2 (standard build, not .NET).

[Unreleased]: https://github.com/maxwelljens/kangur/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/maxwelljens/kangur/releases/tag/v0.1.0
