# Kangur — Production TODO / Known Gaps

Tracking deferred work and known imperfections across waves. Core gameplay spine
takes priority; these are polish-wave (W5) items unless noted. Check items off as
resolved; keep this current for orchestration continuity.

## Audio (polish wave — source CC0 replacements, e.g. Freesound CC0 HQ previews)
- [ ] 5.56 gunshot (Kestrel/Volk/Mule) — currently CC-BY `shots/rifle.wav` placeholder.
- [ ] .357 Judge gunshot — foley only (.44/.32 cylinder sounds exist, no shot).
- [ ] Suppressed weapon sounds — none in library.
- [ ] 20ga pump/shell-eject + .308 bolt cycling — live in Snake's pack ONE (absent).
      Candidate fills if provenance established: `SFX/30-06_bolt.ogg`, `12ga_load_chamber.ogg`.
- [ ] Bullet impacts: concrete chip, glass shatter — empty dirs (metal/flesh/wood are stand-ins).
- [ ] Ambience: harbor/gulls (Terminal), city murmur (Oldtown) — absent.
      Candidate: `ambient machinery 2/subwayTrain_B-line.wav` (verify license first).
- [ ] **Clipping**: `shots/rifle.wav`, Kenney `metal_clang_3` peak >0 dBFS (+2.3 dB).
      → AudioDirector: add AudioEffectLimiter on SFX bus, OR renormalize files. (Do in audio wave.)
- [ ] UI stingers (`match_end_*`, `objective_capture*`) picked by spectral analysis,
      not authored — re-pick after listening in-game.
- [ ] Music mood fit unverified by listening (tags only) — audition once downloaded.
- [ ] Human squad barks — ship-AI voices only (expected); text radio is canonical.

## Engine / addons
- [ ] at-icons dock bug #28 (blank on 4.7.2) — verify in a real editor session;
      keep plugin disabled in headless CI regardless.
- [ ] gdUnit4 pinned to master HEAD (7.0.0, no git tag) — hash in addons/gdUnit4/KANGUR_PIN.md;
      watch for a stable tagged release, re-pin then.
- [ ] NavigationServer2D classes are Experimental — watch Godot 4.8+ for API changes.
- [ ] Physics interpolation + multi-layer rig untested (godot-tech Appendix B) — verify no jitter.
- [ ] Dev harness fixes (rsplit(":",true,2) for --shot, headless frame_post_draw guard)
      — coordinator applies after core agent lands (follow-up mechanism failed).

## Content / balance
- [ ] Map art-polish pass: blockouts are structurally correct but visually flat
      (uniform gray wall mass, simple speckle floors). Add surface variation,
      decals, props (containers/cars/furniture), dusk lighting + occluders,
      detail tiles. Verified readable via reports/screenshots/dustworks.png.
- [ ] Weapon sound-set .tres instances (filename→weapon mapping in docs/credits.md §1).
- [ ] Radio line .tres instances from docs/design/radio-lines.md.
- [ ] Balance suite: 200-seed winrates per map/mode (Battle now winnable both maps;
      needs full calibration). BLOCKED on sim throughput (~real-time pace; bullet
      sweeps read physics space, 1 tick/frame). Fast gate uses 100s matches instead.
- [ ] Elimination still mostly timeouts (survivors avoid re-meeting) — add late-game
      hunt pressure / shorter default clock; dustworks cover 27.3% (<30% gate).
- [ ] check_six metric reads 0 in short sims (behavior exists; verify sampling/trigger).
- [x] Terminal + Oldtown (Battle maps) + Range built (193 probe checks, specs exact).
- [ ] Range training controller: spawn target dummies (static + rail-moving), weapon
      racks (switch any weapon), infinite-ammo toggle, live spread/recoil readout,
      TTK dummy with body-part display, bandage dummy. Markers exist (markers.json).
- [ ] Fold markers.json into BlockoutDef.markers field (world schema was frozen during
      battle-maps wave; markers currently a sidecar workaround).

## Deferred scope (design §14 — revisit after core excellence)
- Campaign story missions between matches (lore currently in briefings/debriefs).
- Vehicles, destructible walls (penetration only for now), controller support,
  multiplayer/networking, mod.io/Steam integration.

## Resolved
- [x] Movement/headshot/TTK design arithmetic (genre research fixes applied).
- [x] Music licensing (Incompetech CC BY 4.0 verified + downloaded).
- [x] Concurrent-godot cache races (tools/godot.sh flock wrapper).
- [x] vision-cone frozen FOV / apex / mask (patched, probe-green).
- [x] Playtest: WASD dropped by install() multi-binding bug; crosshair stuck center
      (CAPTURED->CONFINED_HIDDEN + widgets track cursor).
- [x] Playtest: AI passive/inaccurate (stale aim pos -> perception.live_pos tracking);
      AI shooting corpses (death invalidates memory/visible contacts + releases aim).
- [x] Battle capture structurally impossible -> superiority-based capture model;
      both Terminal+Oldtown attacker-winnable (verified sims, fairness 0).
- [x] Bleed-out deaths attributed to "environment" -> last damager tracked.
- [x] Silent guns -> shot_fired wired to SoundSetDef resolution; all 12 weapons audible.
- [x] Audio gaps filled (CC0 5.56/.357/suppressed/impacts/cycling).
- [x] Cook timing, weapon silhouettes, range camera/fog, zoom 1.8, credits tables.
- [x] Fast per-commit gate (100s sim matches); full gate GREEN (582 tests + sims + flow).
