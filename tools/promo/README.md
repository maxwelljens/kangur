# Promo capture harness

Records real gameplay to PNG frame sequences for the promo cut. No mocked
visuals: every segment boots a production `Match` (real ballistics, `BodyModel`,
AI, HUD, fog) and choreographs the player body through the same `Intent`
pipeline a human fills.

```bash
tools/promo/capture.sh                    # all segments + README stills
tools/promo/capture.sh --seg=combat       # one segment
tools/promo/capture.sh --stills-only      # README stills only
tools/promo/capture.sh --footage DIR      # output root
```

Output: `$FOOTAGE/<seg>/f%04d.png` (0-based, contiguous, 1920×1080, 30 fps) plus
`$FOOTAGE/manifest.json`. Default root `/tmp/opencode/kangur_promo/footage`.
Stills land in `docs/media/*.png`.

## Movie Maker mode (Godot 4.7.2) — measured behaviour

- `--write-movie <base>.png` writes `<base><8 digits>.png`, starting at
  `00000000`. Its extension is `.png`; the frame counter is not configurable, so
  capture.sh renames into the `f%04d.png` contract and deletes the raw frames.
- **`--resolution` does not reach movie mode.** The recording size comes from
  the project's `window_width_override` / `window_height_override` (1280×720),
  so 1920×1080 is forced with a transient root `override.cfg` that capture.sh
  writes and removes on exit (`trap`). Scene screenshots (`Dev --shot`) obey the
  same override, which is how the 1600×900 stills are pinned.
- `window/stretch/aspect` must be pinned to `="keep"` in that override. Under
  niri the WM resizes the window after boot; with the project's `expand` aspect
  the HUD then lays out off-screen and the capture shows a HUD-less frame.
- Movie mode runs unlocked (faster than realtime) and delivers a fixed dt, so
  choreography is indexed by physics tick, never by wall clock.
- `--quit-after N` counts rendered frames. At 30 fps and the project's 60 Hz
  physics that is **2 physics ticks per frame**, so a 360-frame clip is 720
  ticks.
- `--time-scale 0.5` halves the dt handed to `_physics_process` *and* keeps the
  physics tick rate, so 120 recorded frames = 240 ticks = 2 s of simulated time.
  That is what `combat_slow` uses for a smooth half-speed take.
- Never pass `--shot` together with `--write-movie`: the Dev harness quits the
  run after its frame count and the movie is truncated.
- A GDScript parse error still records N valid PNGs of the boot screen and exits
  0, so capture.sh greps each log for `SCRIPT ERROR` / `Failed to load script`
  and fails the segment instead of shipping empty footage.

## Segments

| seg | frames | staging |
|---|---|---|
| `title` | 90 | `title_screen.tscn` directly |
| `lobby` | 120 | `lobby_screen.tscn` directly |
| `deploy` | 360 | Elimination, compound, 5v5, seed 101, player body on the real AI |
| `combat` | 360 | dustworks lane; sprint → brace → bursts → reload → re-engage |
| `combat_slow` | 120 | same duel at `--time-scale 0.5`; a lane enemy is killed |
| `wounds` | 360 | leg hit from behind, limp to cover, 2.8 s bandage channel |
| `smoke` | 240 | smoke into the lane, squad advance, frag onto the enemy line |
| `ai` | 300 | `shot_ai.tscn` 4v4 arena with the F3 overlay |
| `battle` | 450 | Battle, terminal, 6v6, seed 505; warm-up trimmed to 150 frames |
| `debrief` | 210 | short match → `force_finish` → real debrief (120 trimmed) |

Segment lengths, beats and trim counts live in `promo_shot.gd` (`TRIM_FRAMES`
prints a `PROMO_TRIM <n>` line that capture.sh reads), so there is one place to
retune a take.

## Fixture

`promo_shot.tscn` takes `--seg=<name>` and `--still=<seg>`. Staging uses only
documented seams:

- **Player body:** `AIController` manual drivers (`set_aim_target`,
  `set_move_target`, `set_sprint`, `set_stance`, `set_focus`, `set_fire`) — the
  same `Intent` fields a human fills, so movement, spread, recoil and reload are
  shared code.
- **Enemies:** real `Character`s with their real weapons, aimed by the same
  manual surface. A staged enemy clears `arsenal.current().equip_timer` so its
  burst starts on the beat instead of waiting out the draw animation.
- **Grenades:** `Arsenal.throw_equipment` → `EventBus.equipment_thrown` →
  `EquipmentSystem`, i.e. the production throw path. The grenade body, fuse,
  blast, smoke growth, fog punch-out and killfeed are untouched gameplay.
- **Wounds:** the shot is aimed 20 px behind the player's hips in his own facing
  frame, because `BodyModel.part_at_offset` puts the legs in the body's rear
  half (`forward < -8`). Measured: 16 px is torso, 20 px is a leg, 32 px clips an
  arm. The wound, bleed-out, ×0.55 limp and bandage channel are all real.
- **Camera:** the staged segments null out `CameraRig.player`/`target` and park
  the rig, because the default rig lerps toward the OS cursor and a capture has
  no cursor. Recoil kick and blast shake still come from the real rig.

Staging coordinates are real map geometry, probed against the live
`World`/`TileMapLayer` (`cover_points`, `is_wall`, `is_low_cover`) rather than
guessed.

## Adding a segment

1. Add an entry to `TRIM_FRAMES` (0 unless it needs a warm-up trim).
2. Add a `match` arm in `_spec()` for map/mode/bots/seed/class.
3. Add a `_stage_*` and a `_<seg>_tick` if it needs a beat, then wire both in
   `_stage()` / `_physics_process`.
4. Add the `movie` line in `capture.sh` with its frame count.