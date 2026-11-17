# Music & Ambience Attribution — shipping text

**Purpose.** Exact credit strings for every audio file downloaded into
`assets/audio/music/` and `assets/audio/ambience/`. Feeds `docs/credits.md` and the
in-game Credits screen (which must be reachable from Settings and **must name each
title** — Incompetech FAQ: *"It is important that you replace the word Title with the
Actual Title of the piece that you are using!"*).

- **Downloaded**: 2026-11-17 · **Verified**: HTTP 200, nonzero size, `ffprobe` duration
- **Plan / source research**: `docs/research/music-sources.md`
- **Total shipped**: 99.1 MB (music 50.3 MB + ambience 48.8 MB)

---

## 1. Music — Kevin MacLeod, CC BY 4.0 (attribution **mandatory**)

The recordings are copyrighted; only the license is free. FAQ: *"Is this music
Copyright Free? No. All of this music is copyrighted."* Each title below must be
credited individually. Do **not** collapse to "Music by Kevin MacLeod".

Copy verbatim, one block per title:

```
"<Actual Title>" Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / http://creativecommons.org/licenses/by/4.0/
```

### Titles used (7 unique, 8 files)

| # | Actual Title (must match exactly) | Slot | File | Duration |
|---|---|---|---|---|
| 1 | `Static Motion` | Title / menu | `music/title_theme.ogg` | 188.79 s |
| 2 | `Industrial Cinematic` | Lobby / deploy | `music/lobby_deploy.ogg` | 244.43 s |
| 3 | `Controlled Chaos - no percussion` | Match calm | `music/match_calm.ogg`, `music/match_calm_noperc.ogg` | 350.77 s |
| 4 | `Controlled Chaos` | Match engaged | `music/match_engaged.ogg` | 352.26 s |
| 5 | `Oppressive Gloom` | Clutch | `music/clutch.ogg` | 199.39 s |
| 6 | `Peaceful Desolation` | Debrief win | `music/debrief_win.ogg` | 91.17 s |
| 7 | `Lost Time` | Debrief loss | `music/debrief_loss.ogg` | 227.40 s |

`match_calm.ogg` and `match_calm_noperc.ogg` are byte-identical (one source file,
kept under both slot names). Credit `Controlled Chaos - no percussion` **once**.

### Ready-to-paste block

```
"Static Motion" Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / http://creativecommons.org/licenses/by/4.0/

"Industrial Cinematic" Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / http://creativecommons.org/licenses/by/4.0/

"Controlled Chaos - no percussion" Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / http://creativecommons.org/licenses/by/4.0/

"Controlled Chaos" Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / http://creativecommons.org/licenses/by/4.0/

"Oppressive Gloom" Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / http://creativecommons.org/licenses/by/4.0/

"Peaceful Desolation" Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / http://creativecommons.org/licenses/by/4.0/

"Lost Time" Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / http://creativecommons.org/licenses/by/4.0/
```

### Statement of changes — CC BY 4.0 requires this

CC BY 4.0 obliges you to indicate if changes were made. Ship this line next to the
music credits:

> Music files were converted to Ogg Vorbis and edited for looping; no musical content
> was altered.

---

## 2. CC0 alternates — Tsorthan Grove, OpenGameArt (no attribution required)

Page notice, verbatim: *"CC0 / Public Domain. No Rights Reserved. Free to use, no
attribution required."* Credited here as courtesy. Format: **author + title + CC0 /
Public Domain**.

| Title | Author | Source | File | Duration |
|---|---|---|---|---|
| Dark Ambient Drone | Tsorthan Grove | opengameart.org/content/dark-ambient-drone | `music/cc0_alternates/dark_ambient_drone.ogg` | 307.20 s |
| Rebel Base | Tsorthan Grove | opengameart.org/content/background-drones-vol-1 | `music/cc0_alternates/rebel_base.ogg` | 153.60 s |
| Light Through a Pale Window | Tsorthan Grove | opengameart.org/content/background-drones-vol-1 | `music/cc0_alternates/light_through_a_pale_window.ogg` | 153.60 s |
| Temple of the Digital Monk | Tsorthan Grove | opengameart.org/content/background-drones-vol-1 | `music/cc0_alternates/temple_of_the_digital_monk.ogg` | 153.60 s |
| When the Shadows Gather | Tsorthan Grove | opengameart.org/content/when-the-shadows-gather | `music/cc0_alternates/when_the_shadows_gather.ogg` | 153.60 s |
| L.A. War Zone | Tsorthan Grove | opengameart.org/content/la-war-zone | `music/cc0_alternates/la_war_zone.ogg` | 139.63 s |
| Streets After Midnight | Tsorthan Grove | opengameart.org/content/streets-after-midnight | `music/cc0_alternates/streets_after_midnight.ogg` | 76.80 s |

Ready-to-paste:

```
"Dark Ambient Drone" by Tsorthan Grove — CC0 / Public Domain (opengameart.org/content/dark-ambient-drone)
"Rebel Base" by Tsorthan Grove — CC0 / Public Domain (opengameart.org/content/background-drones-vol-1)
"Light Through a Pale Window" by Tsorthan Grove — CC0 / Public Domain (opengameart.org/content/background-drones-vol-1)
"Temple of the Digital Monk" by Tsorthan Grove — CC0 / Public Domain (opengameart.org/content/background-drones-vol-1)
"When the Shadows Gather" by Tsorthan Grove — CC0 / Public Domain (opengameart.org/content/when-the-shadows-gather)
"L.A. War Zone" by Tsorthan Grove — CC0 / Public Domain (opengameart.org/content/la-war-zone)
"Streets After Midnight" by Tsorthan Grove — CC0 / Public Domain (opengameart.org/content/streets-after-midnight)
```

---

## 3. Ambience — Freesound, CC0 (no attribution required)

License block on each sound page: *"Creative Commons 0 — You can copy, modify,
distribute and perform the sound, even for commercial purposes, all without the need
of asking permission to the author."* Format: **author + sound ID + CC0**.

| File | Title | Author | ID | Duration |
|---|---|---|---|---|
| `ambience/wind.mp3` | AMBUndr_Subterranean Howling Wind Loop | KolbyRFX | 852822 | 219.16 s |
| `ambience/industrial_hum.mp3` | hums industrial tonal machines creak resonate large room | kyles | 453446 | 242.99 s |
| `ambience/harbor_gulls.mp3` | Seagulls in a quiet street, 6AM, Harbour City | etienne.leplumey | 450529 | 255.47 s |
| `ambience/city_murmur.mp3` | Urban commercial pedestrian street ambience | lastraindrop | 716384 | 1075.75 s |
| `ambience/distant_traffic.mp3` | People walking and cars driving over metal bridge part 2 | Tom_Kaszuba | 670759 | 468.43 s |

Ready-to-paste:

```
"AMBUndr_Subterranean Howling Wind Loop" by KolbyRFX (freesound.org/s/852822/) — CC0
"hums industrial tonal machines creak resonate large room" by kyles (freesound.org/s/453446/) — CC0
"Seagulls in a quiet street, 6AM, Harbour City" by etienne.leplumey (freesound.org/s/450529/) — CC0
"Urban commercial pedestrian street ambience" by lastraindrop (freesound.org/s/716384/) — CC0
"People walking and cars driving over metal bridge part 2" by Tom_Kaszuba (freesound.org/s/670759/) — CC0
```

**Caveat.** These are the publicly fetchable HQ MP3 previews (192 kbps), not the
originals — originals need a logged-in Freesound account. Adequate for ambience
beds, but expect to trim/crossfade loop points; only `wind` and `industrial_hum` are
purpose-built loops. `city_murmur` is 18 minutes and will need a cut-down.

---

## 4. Also required in the Credits screen

- The Incompetech seven, by actual title, as above.
- The changes line from §1.
- A link to this file in the repo (optional but cheap).

CDN / licensing contacts are not required by either license. Nothing here is
NonCommercial, NoDerivatives, or "contact me first" — no FMA or itch.io content was
used.