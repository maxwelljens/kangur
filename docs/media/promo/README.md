# Promo video

`promo.ts` builds the Kangur trailer: `docs/media/promo.mp4` (95 s, 1920×1080,
30 fps, H.264 + AAC) and `docs/media/promo.gif` (12 s highlight, 800×450).

It is one self-contained Deno script. Every frame is a pure function of time —
`renderFrame(t)` returns an SVG string — rasterised 8 at a time with
`rsvg-convert`, encoded with ffmpeg, and scored with the game's own soundtrack.
No Node, no npm, no React/Remotion, no baked-in video editor.

Gameplay footage is **not** faked: `--placeholders` exists only so the pipeline
can be tested before capture lands, and the real render feeds in frames recorded
from actual matches in-engine.

## Dependencies

- `deno` (2.x) — runs the script.
- `rsvg-convert` (librsvg) — SVG → PNG.
- `ffmpeg` with `libx264`, `aac`, `palettegen`/`paletteuse`.
- Fonts: Chakra Petch + Share Tech Mono. The script points fontconfig at the
  project's own `assets/ui/fonts/`, so no system install is required; it falls
  back to DejaVu Sans / DejaVu Sans Mono if a face is missing.

## Regenerate

```sh
# 1. Capture footage from real matches (pipeline detail in tools/promo/).
tools/promo/capture.sh

# 2. Compose, encode, mux.
deno run -A docs/media/promo/promo.ts
```

Pipeline smoke test, with no footage on disk:

```sh
deno run -A docs/media/promo/promo.ts --placeholders \
  --width 960 \
  --out /tmp/opencode/kangur_promo/test.mp4 \
  --gif-out /tmp/opencode/kangur_promo/test.gif
```

`--placeholders` writes synthetic frames into the footage directory (dark panel
+ segment name + a fake HUD layout + a moving block) and a matching
`manifest.json`. It **never overwrites a segment that already has `f0000.png`**,
so it is safe to run while capture is in progress and safe to run again after.
Delete the footage directory to force regeneration.

## Flags

| Flag | Default | Meaning |
| --- | --- | --- |
| `--out PATH` | `docs/media/promo.mp4` | Video output. |
| `--gif-out PATH` | `docs/media/promo.gif` | GIF output. |
| `--footage DIR` | `/tmp/opencode/kangur_promo/footage` | Frame sequences + `manifest.json`. |
| `--width N` | `1920` | Output width; height is 16:9. Every layout value scales from it. |
| `--fps N` | `30` | Video frame rate. |
| `--gif-window A:B` | `28:40` | Screen seconds for the GIF (capped at 12 s). |
| `--at T` | — | Render one frame at `t` seconds to `frames/at-<t>.png` and stop. |
| `--keep-frames` | off | Keep intermediate SVG/PNG in `frames/` (gitignored). |
| `--placeholders` | off | Generate missing footage synthetically. |

## Footage contract

```
<footage>/<segment>/f%04d.png   1920×1080, 0-based, contiguous
<footage>/manifest.json         {"segments":{"<name>":{"frames":N,"fps":30,"time_scale":x}}}
<footage>/map_<id>.png          1600×900 montage stills (optional)
```

Segments and default frame counts (used when `manifest.json` is absent):
`title` 90 · `lobby` 120 · `deploy` 360 · `combat` 360 · `combat_slow` 120 ·
`wounds` 360 · `smoke` 240 · `ai` 300 · `battle` 300 · `debrief` 90.

`combat_slow` is recorded at `time_scale 0.5`, so its 120 frames already play at
half speed across the 4 s slot — the compositor maps time 1:1 with no speed
maths. Map stills fall back to `maps/<id>/minimap.png`, letterboxed rather than
stretched (those are 320×256).

## EDL

Screen seconds, 0.4 s crossfades between adjacent scenes.

| Time | Scene | Notes |
| --- | --- | --- |
| 0–4 | `card_intro` | Procedural: wordmark, faction emblems, grid + scanlines, staggered lines. |
| 4–7 | `title` | Footage. |
| 7–11 | `lobby` | Footage; callout 7.5–10.5. |
| 11–23 | `deploy` | Footage; callouts 11.5–20.5. |
| 23–35 | `combat` | Footage; callouts 23.5–32.5. |
| 35–39 | `combat_slow` | Half-speed; `0.5× SPEED` tag + projectile note. |
| 39–51 | `wounds` | Footage; callouts 39.5–48.5. |
| 51–59 | `smoke` | Footage; callouts 51.5–58.5. |
| 59–69 | `ai` | Footage; `LIVE AI TELEMETRY — F3 OVERLAY` tag, callouts 59.5–68.5. |
| 69–79 | `battle` | Footage; callouts 69.5–78. |
| 79–85 | `maps` | 5 stills × 1.2 s, Ken Burns 1.0→1.06, name + mode labels. |
| 85–88 | `debrief` | Footage; callout 85.5–87.8. |
| 88–95 | `card_outro` | Procedure: wordmark, feature line, tagline, footer, emblems. |

Music (the game's soundtrack, 1 s crossfades, −15 dBFS-ish bed at volume 0.85,
0.5 s fade in / 2 s fade out): `title_theme` 0–8, `lobby_deploy` 8–12,
`match_calm` 12–24, `match_engaged` 24–51, `clutch` 51–79, `debrief_win` 79–95.

## Implementation notes

- **librsvg image resolution.** `rsvg-convert` only loads `<image>` files that
  live inside the SVG's own directory tree; absolute hrefs elsewhere and
  symlinked directories silently render nothing. The script therefore keeps a
  per-run `<frames>/img/` directory and links each asset in beside the frame
  SVGs, always referenced relatively.
- **Concurrency.** Frames render 8 at a time, so every frame writes its own
  asset names (`f<n>_<segment>.png`); nothing shared is mutated during a batch.
- **Self-check.** Before rendering, `selfCheck()` asserts every card line and
  callout fits the frame at the chosen `--width`, that callouts sit inside the
  runtime, and that the EDL has no gaps. It fails loudly instead of shipping
  clipped text.
- **Overlay placement.** Callouts sit bottom-centre (the HUD owns bottom-left
  vitals and bottom-right weapon); the speed/AI tags sit bottom-right just above
  the weapon block, clear of the top-left minimap and top-right killfeed.
- **Two-pass encode.** Frames → silent H.264 (`crf 21`, `preset slow`,
  `yuv420p`, BT.709, `+faststart`), then the six-block audio mix is muxed over a
  stream copy — so the video is encoded exactly once.
- **GIF.** Cut from the finished MP4, `fps=12.5`, scaled to 800 px wide, one
  `palettegen=stats_mode=diff:max_colors=128` / `paletteuse=dither=bayer:
  bayer_scale=4:diff_mode=rectangle` pass, `-loop 0`.