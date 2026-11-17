# Shippable Music & Ambience for Kangur — Verified CC0 / CC BY Sources

**Question.** Which music (6–10 tracks across 7 slots) and ambience beds can Kangur
ship in a public EUPL-1.2 repository, with licenses that permit open-source
redistribution — and what are the exact download URLs and attribution strings?

**Answer in one line.** **Incompetech (Kevin MacLeod, CC BY 4.0) is intact and is the
best single-artist source** for the whole music set; its license has *not* changed.
For zero-attribution ambience and cold drones, **OpenGameArt CC0** (notably
Tsorthan Grove) fills the gaps. **Freesound downloads require a free account**, so
plan a logged-in step; **Free Music Archive is no longer a CC-first catalog** and
carries license traps; **itch.io "CC0" tags are unreliable**.

- **Researched**: 2026-11-17 · **Method**: catalog JSON from incompetech.com,
  per-track HTTP HEAD checks, license text read on each source page, `ffprobe` for durations.
- **Constraint honoured**: no audio downloaded into the repo. Only headers/streams probed.
- **Scope**: music beds + ambience loops. Gunshots/foley/UI live in
  `docs/research/asset-inventory.md` and are out of scope here.

---

## 0. Verdict summary (read this if nothing else)

| Slot | Track | Source | License | Loop? |
|---|---|---|---|---|
| 1 Title/menu | **Static Motion** | Incompetech | CC BY 4.0 | seamless-ish (drone) |
| 2 Lobby/deploy | **Industrial Cinematic** | Incompetech | CC BY 4.0 | no (fade in/out) |
| 3 Match calm | **Controlled Chaos – no percussion** | Incompetech | CC BY 4.0 | drone bed |
| 4 Match engaged | **Controlled Chaos** | Incompetech | CC BY 4.0 | same bed + percussion |
| 5 Clutch | **Oppressive Gloom** | Incompetech | CC BY 4.0 | near-loop (trim tail) |
| 6 Debrief win | **Peaceful Desolation** | Incompetech | CC BY 4.0 | no, 1:31 sting |
| 7 Debrief loss | **Lost Time** | Incompetech | CC BY 4.0 | no, 3:47 |
| Ambience | 4 Freesound CC0 beds + 2 OGA CC0 beds | mixed | CC0 | yes |

**The headline win:** `Controlled Chaos` and `Controlled Chaos - no percussion` are the
**same composition with and without percussion**, both CC BY 4.0, same length (~5:51).
That is a ready-made two-layer adaptive system for slots 3→4 — exactly the
"calm → engaged" design promised in `docs/design/game-design.md` §12, with no
custom mixing required and a guaranteed-consistent mix.

---

## 1. Incompetech / Kevin MacLeod — **license unchanged, still CC BY 4.0**

The brief asked me to check for a 2025/2026 licensing pivot. **There was none.**

Evidence (all fetched 2026-11-17):

- License chooser still offers exactly two paths — a paid Standard License and a free
  CC license: *"Standard License … For projects where attribution is not wanted or is
  impossible"* / *"Creative Commons — Free … No charge. Requires that you credit the
  music."* — <https://incompetech.com/music/royalty-free/licenses/>
- The generated credit block on that same page emits:
  `"Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / http://creativecommons.org/licenses/by/4.0/"`
- FAQ confirms version and the game-specific placement rule: *"Video Games — Most
  commonly, credits are placed on a 'Credits' screen found in the settings menu."*
  — <https://incompetech.com/music/royalty-free/faq.html>
- Site footer reads **"© 1997–2026 Incompetech Inc."**, so the site is current, not stale.
- The full-collection page still states *"Creative Commons: By Attribution 4.0 — this
  is the license that covers the music."* — <https://incompetech.com/music/royalty-free/Downloads/allthemusic.html>

**Caveat that matters for the repo:** the *recordings* are copyrighted; only the
license is free. FAQ: *"Is this music Copyright Free? No. All of this music is
copyrighted."* So CC BY attribution is mandatory, not optional. That is compatible
with EUPL-1.2 (the license attaches to audio assets, not to the source code license),
but the credits must actually ship.

### 1.1 Direct download URL pattern (verified)

```
https://incompetech.com/music/royalty-free/mp3-royaltyfree/<URL-encoded filename>.mp3
```

Filenames come from the catalog JSON at
<https://incompetech.com/music/royalty-free/pieces.json> — **the `filename` field is
not always the title.** `Satiate - only percussion` downloads as `Satiate Percussion.mp3`.
Use the filenames in the table below verbatim.

All 25 candidate URLs returned **HTTP 200** with plausible `Content-Length`; durations
confirmed via `ffprobe`. MP3s are 256–320 kbps.

### 1.2 The recommended set (single artist, consistent mastering)

| # | Title | Cat. length | Measured | BPM | Feel (verbatim) | Instruments | Filename |
|---|---|---|---|---|---|---|---|
| 1 | Static Motion | 3:09 | 188.8 s | — | Dark, Eerie, Mysterious, Suspenseful, Unnerving | Synths | `Static Motion.mp3` |
| 2 | Industrial Cinematic | 4:04 | 244.4 s | 110 | Driving, Suspenseful | — | `Industrial Cinematic.mp3` |
| 3 | Controlled Chaos – no percussion | 5:51 | — | — | Dark, Mysterious, Mystical, Suspenseful, Unnerving | Synths | `Controlled Chaos - no percussion.mp3` |
| 4 | Controlled Chaos | 5:52 | 352.3 s | 80 | Dark, Eerie, Intense, Mysterious, Suspenseful, Unnerving | Synths, Percussion | `Controlled Chaos.mp3` |
| 5 | Oppressive Gloom | 3:19 | 199.4 s | 58 | Dark, Eerie, Epic, Mysterious, Somber, Suspenseful | — | `Oppressive Gloom.mp3` |
| 6 | Peaceful Desolation | 1:31 | 91.2 s | 54 | Calming, Relaxed, Somber, Uplifting | Brass, Timpani, Glockenspiel, Flute, Clarinet, Oboe, Strings | `Peaceful Desolation.mp3` |
| 7 | Lost Time | 3:47 | 227.4 s | 55 | Somber, Dark | — | `Lost Time.mp3` |

Author's own descriptions, which are the closest thing to a mood spec:

- **Static Motion** — *"Sharp subtle percussive clicks accompany with otherworldly drone."*
  → cold, spacious, a pulse you can barely hear. Title-screen fit.
- **Industrial Cinematic** — *"Industrial-sounding music."* 110 BPM, driving/suspenseful.
  → deploy/lobby build.
- **Controlled Chaos (no percussion)** — *"Dark background drone made with the new
  SkannerXT synth."*
- **Controlled Chaos** — *"Weird synth drone with a soundtrack-style percussion backing driver."*
- **Oppressive Gloom** — *"Moody moody dark score. Almost a death march. **Loops pretty
  darned well - but you need to trim the end.**"* → the author himself flags it as a loop.
- **Peaceful Desolation** — *"Low-key mood establisher … Starts dark, ends open and airy."*
  → win debrief that resolves without triumphalism.
- **Lost Time** — *"Dark and moving … not get in the way of those final bits of dialog."*
  → loss debrief, hollow and brief (use the first ~60–90 s, not the whole 3:47).

All descriptions and metadata above are from the `pieces.json` catalog served by
<https://incompetech.com/music/royalty-free/pieces.json> (fetched 2026-11-17), which is
the same data that renders each track page.

### 1.3 Verified download URLs (all HTTP 200)

```
https://incompetech.com/music/royalty-free/mp3-royaltyfree/Static%20Motion.mp3
https://incompetech.com/music/royalty-free/mp3-royaltyfree/Industrial%20Cinematic.mp3
https://incompetech.com/music/royalty-free/mp3-royaltyfree/Controlled%20Chaos%20-%20no%20percussion.mp3
https://incompetech.com/music/royalty-free/mp3-royaltyfree/Controlled%20Chaos.mp3
https://incompetech.com/music/royalty-free/mp3-royaltyfree/Oppressive%20Gloom.mp3
https://incompetech.com/music/royalty-free/mp3-royaltyfree/Peaceful%20Desolation.mp3
https://incompetech.com/music/royalty-free/mp3-royaltyfree/Lost%20Time.mp3
```

Per-track page for citation, e.g.
<https://incompetech.com/music/royalty-free/music.html> (catalog UI; search the title).

### 1.4 Attribution string — **exact**

Per-track, one block per file (this is the format the site's own generator emits):

```
"Static Motion" Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
https://creativecommons.org/licenses/by/4.0/
```

For `docs/credits.md`, one row per track is enough; in-game Credits screen should list
all seven with the block above. **Do not** collapse to "Music by Kevin MacLeod" —
the FAQ requires the *actual title*: *"It is important that you replace the word Title
with the Actual Title of the piece that you are using!"*

### 1.5 Bonus: `Satiate` is a genuine stem family

Not in the recommended seven, but the single best *adaptive* asset found anywhere,
because it ships as three separately-licensed renders of one composition:

| Title | Filename | Measured | Instruments |
|---|---|---|---|
| Satiate | `Satiate.mp3` | 192.1 s | Strings, Percussion |
| Satiate - only percussion | `Satiate Percussion.mp3` | 192.6 s | Percussion |
| Satiate - only strings | `Satiate Strings.mp3` | 192.1 s | Strings |

Author: *"It is also available with just the percussion, and just the strings… both of
which are quite different from the combined."* All three verified HTTP 200.

**Opinion:** if you want a *third* intensity tier beyond the Controlled Chaos pair,
`Satiate` strings-only (calm) → percussion-only (clutch) is a legitimate drop-in. It is
more dissonant and restless than Controlled Chaos; audition before committing.

### 1.6 Other verified Incompetech candidates (alternatives / swaps)

All HTTP 200, durations measured:

| Title | Length | Feel | Why you might pick it |
|---|---|---|---|
| The Complex | 4:28 | Action, Aggressive, Dark, Driving, Epic, Intense, Mysterious | *"Mechanistic, electronic and organic."* Best "corporate war machine" cue; too big for a calm layer. |
| Cephalopod | 4:08 | Aggressive, Dark | *"Semi-industrial electronic with live percussion bits."* Literal label match for industrial. |
| Mary Celeste | 2:42 | Dark, Mysterious, Intense | Thin → muddy → faster clear section; good lobby escalation. |
| Anxiety | 1:51 | Dark, Intense, Suspenseful | *"Background horror music. Electronic."* Short, loop-friendly clutch sting. |
| Simplex | 3:03 | Dark, Suspenseful, Unnerving | *"Thin, dark, moody piece that accelerates to the end."* |
| Vanes | 1:46 | Somber, Unnerving | *"Disturbingly sweet … one last despair-filled refrain."* Strong loss-debrief alternate. |
| Thunder Dreams | 3:50 | Dark, Mysterious, Suspenseful, Unnerving | *"Probably useful after a loss. Beautiful, horrible."* |
| Bump in the Night | 1:52 | Dark, Intense, Unnerving | Percussion-only; **author warns "Very bass heavy"** — check your mix bus. |
| Deep Haze | 2:02 | Action, Driving, Grooving | *"More hollow than dark"* — a lighter engaged layer. |
| Past the Edge | 1:18 | Dark, Eerie, Mysterious, Somber | 44 BPM, very sparse — extreme clutch. |
| Medusa / Steel and Seething | 1:19 / 0:49 | Dark, Intense, Suspenseful, Unnerving | Short percussion+synth stings for round-start / last-kill. |
| Division | 1:06 | Dark, Driving, Intense | 80 BPM loopable theme sting. |
| Urban Gauntlet | 3:29 | Epic, Intense | Percussion-driven tension; **leaks "epic"** — use sparingly. |

### 1.7 Stems / uncompressed audio

Individual track pages offer **MP3 only** — I probed
`/wav-royaltyfree/Industrial%20Cinematic.wav` and got **HTTP 404**. Stems and
alternate takes exist only in the paid **"All the Music"** bundle: *"5 giant zip files
… Over 200 individual tracks with stems, alternate takes, etc."* — **$38 USD**,
<https://incompetech.com/music/royalty-free/Downloads/allthemusic.html>.

**Opinion:** not needed. The Controlled Chaos pair already gives two layers; buying the
bundle for stems in 2026 is hard to justify for a 7-slot soundtrack.

---

## 2. OpenGameArt.org — CC0 drones and loops

OGA is reachable but **403s a plain fetcher**; a browser User-Agent returns 200. Note
this for the curation agent: `curl -A "Mozilla/5.0 …"` works, default UA does not.
Search filter used: Art Type = Music, License = CC0
(`field_art_type_tid[]=12&field_art_licenses_tid[]=4`).

### 2.1 Tsorthan Grove — the coherent CC0 alternative

One artist, one aesthetic (dark ambient / drone / dystopian), all CC0, most ship with
**pre-looped versions**. This is the fallback if Incompetech's CC BY attribution is
ever a problem, or the source for extra cold drones.

Attribution notice quoted verbatim from every one of his pages:
*"CC0 / Public Domain. No Rights Reserved. Free to use, no attribution required."*

| Track | Page | Direct file | Measured | Notes |
|---|---|---|---|---|
| Dark Ambient Drone (loop) | <https://opengameart.org/content/dark-ambient-drone> | `https://opengameart.org/sites/default/files/dark_ambient_drone_loop.flac` | 307.2 s | Tags: Ambient, drone, dark, loop. 32 MB FLAC. |
| Rebel Base (loop) | <https://opengameart.org/content/background-drones-vol-1> | `https://opengameart.org/sites/default/files/rebel_base_loop.flac` | 153.6 s | From "Background Drones Vol 1" (3 drones + 3 loops). |
| Light Through a Pale Window (loop) | same pack | `https://opengameart.org/sites/default/files/light_through_a_pale_window_loop.flac` | 153.6 s | Brighter/hopeful — good win-debrief bed. |
| Temple of the Digital Monk (loop) | same pack | `https://opengameart.org/sites/default/files/temple_of_the_digital_monk_loop.flac` | 153.6 s | "Digital monk" = machine + ritual. Strong title alternate. |
| When the Shadows Gather | <https://opengameart.org/content/when-the-shadows-gather> | `https://opengameart.org/sites/default/files/when_the_shadows_gather_0.ogg` | 153.6 s | Tags include **dystopian, pulsing, drone, loop**. OGG 2.6 MB — the smallest good file found. |
| L.A. War Zone (loop) | <https://opengameart.org/content/la-war-zone> | `https://opengameart.org/sites/default/files/l.a_war_zone_loop.flac` | 139.6 s | *"It loops seamlessly for longer scenes."* Cyberpunk streets. |
| Streets After Midnight | <https://opengameart.org/content/streets-after-midnight> | `https://opengameart.org/sites/default/files/streets_after_midnight.flac` | 76.8 s | *"It loops seamlessly."* Neon back alleys — Oldtown/urban map bed. |

All URLs verified HTTP 200. **License field on each page reads `CC0`**, and each carries
the CC0 notice above. CC0 needs no attribution — but crediting is still polite and
costs nothing; the repo already has `docs/credits.md`.

### 2.2 Other CC0 beds worth knowing

| Track | Author | Page | Direct file | Measured | License |
|---|---|---|---|---|---|
| Factory ambiance | yd | <https://opengameart.org/content/factory-ambiance> | `https://opengameart.org/sites/default/files/Factory.ogg` | 123.0 s | CC0 |
| EmptyCity | yd | <https://opengameart.org/content/emptycity-background-music> | `https://opengameart.org/sites/default/files/EmptyCity.ogg` | 100.0 s | CC0 |
| Insistent | yd | <https://opengameart.org/content/insistent-background-loop> | `https://opengameart.org/sites/default/files/Insistent.ogg` | 128.7 s | CC0 |
| Bleak Terminal | Ruskerdax | <https://opengameart.org/content/bleak-terminal> | `https://opengameart.org/sites/default/files/ruskerdax_-_bleak_terminal_theme.mp3` | 112.2 s | CC0 |

- **Factory ambiance** tags: *ambience, atmospheric, industrial, factory, hollow, ruin*.
  The most literal "industrial Europe" bed on OGA. 123 s, loops (it is an ambience piece).
- **EmptyCity** tags: *urban, empty, spy, security, infiltration, sneaking, dark*.
  Strong Oldtown night bed.
- **Bleak Terminal** — author: *"The theme for my sci-fi/horror fiction setting, Bleak
  Terminal"*; tags *industrial, horror, sci-fi*. Longest usable *music* cue among CC0 picks.
- **Insistent** tags: *dark, loop, paranoia, danger, underground*.

### 2.3 OGA — checked and rejected

- **Iron wasteland** (Alexandr Zhelanov) — *perfect* mood (*"small looped post
  apocalyptic suspense ambient theme"*, tags include tactical, pulse, thriller) but
  **CC-BY 4.0, not CC0**. Still allowed by the brief; listed in §5 as a fallback.
  <https://opengameart.org/content/iron-wasteland>
- **RUOK Apocalyptic Loops** — CC-BY 4.0, 10 loops, Track I is *"Industrial type beat,
  droning ambience"*. Usable but inconsistent mastering across tracks; A–J vary wildly.
  <https://opengameart.org/content/ruok-apocalyptic-loopstracks>
- **T & T Free Cyberpunk Pack 2** (Alexander Ehlers) — **CC0**, 10 OGG tracks with BPM
  in filename (`new_factory_129bpm.ogg`, `system_overload_154bpm.ogg`). Tagged
  industrial/cyberpunk. Rejected as primary: it reads as *upbeat electronic*
  ("CC0 - Upbeat / Electronic Music" collection), not cold menace. Note the file is
  `new_factory_129bpm_0.ogg` on the server, not `_129bpm.ogg`.
  <https://opengameart.org/content/t-t-free-cyberpunk-pack-2>
- **Kenney.nl** — the only music pack is **Music Jingles** (85 files, CC0,
  <https://kenney.nl/assets/music-jingles>), released 2014. Jingles only — no loops,
  no dark ambient. **Kenney has no usable music for Kangur.** Do not spend time there.

---

## 3. Freesound.org — CC0 ambience (with a login caveat)

**Constraint discovered:** `https://freesound.org/people/<user>/sounds/<id>/download/`
**redirects to the login page** (`/home/login/?next=…`) for anonymous users. A free
account is required to fetch originals. The **HQ MP3 previews on `cdn.freesound.org`
are publicly fetchable and HTTP 200** — those are 192 kbps MP3s, adequate for ambience
beds, and a legitimate fallback if the curation agent cannot log in.

Every sound below has its license block read on the sound page: *"Creative Commons 0 —
You can copy, modify, distribute and perform the sound, even for commercial purposes,
all without the need of asking permission to the author."*

| Need | Sound | ID | Duration | License | Page | Direct HQ preview (verified 200) |
|---|---|---|---|---|---|---|
| Wind loop (underground/howling) | AMBUndr_Subterranean Howling Wind Loop | 852822 | 3:39.2 | CC0 | <https://freesound.org/s/852822/> | `https://cdn.freesound.org/previews/852/852822_18763192-hq.mp3` |
| Industrial hum / machine room | hums industrial tonal machines creak resonate large room | 453446 | 4:03.0 | CC0 | <https://freesound.org/s/453446/> | `https://cdn.freesound.org/previews/453/453446_612689-hq.mp3` |
| Harbour gulls | Seagulls in a quiet street, 6AM, Harbour City | 450529 | 4:15.5 | CC0 | <https://freesound.org/s/450529/> | `https://cdn.freesound.org/previews/450/450529_997174-hq.mp3` |
| Harbour ambience (alt) | Genaral Habour Ambience | 561815 | 3:00.0 | CC0 | <https://freesound.org/s/561815/> | `https://cdn.freesound.org/previews/561/561815_2247456-hq.mp3` |
| City murmur | Urban commercial pedestrian street ambience | 716384 | 17:55.8 | CC0 | <https://freesound.org/s/716384/> | `https://cdn.freesound.org/previews/716/716384_12768873-hq.mp3` |
| Distant traffic (bridge/cars) | People walking and cars driving over metal bridge part 2 | 670759 | 7:48.4 | CC0 | <https://freesound.org/s/670759/> | `https://cdn.freesound.org/previews/670/670759_11673893-hq.mp3` |
| Fluorescent hum (interior) | Fluorescent Light Hum | 383657 | 0:19.1 | CC0 | <https://freesound.org/s/383657/> | `https://cdn.freesound.org/previews/383/383657_7146007-hq.mp3` |
| Distant sirens | 200927 Sirens, distant fire trucks mostly, noisy 7am | 568971 | 2:08.0 | CC0 | <https://freesound.org/s/568971/> | `https://cdn.freesound.org/previews/568/568971_97550-hq.mp3` |

These map exactly onto the ambience list in `docs/design/game-design.md` §12:
*"per-map ambience (wind, distant industrial hum, gulls at Terminal, city murmur at
Oldtown)"* — wind (852822), industrial hum (453446 / 383657), gulls (450529 / 561815),
city murmur (716384), plus distant traffic (670759) and sirens (568971) for scale.

**Caveat on 716384 / 670759 / 568971:** these are *field recordings*, so they contain
real-world detail (people, birds, specific engines) and their loop points are not
guaranteed. Kangur needs seamless beds — plan to trim and crossfade in-engine (Godot
`AudioStreamOggVorbis` + loop points, or pre-process to seamless). The two purpose-built
loops (852822, 453446) will loop better than the long ambiences.

**Attribution:** not required (CC0). If crediting anyway:
`"<sound title>" by <author>, freesound.org/s/<id>/ — CC0 1.0`.

---

## 4. Sources checked and **rejected** (with reasons — do not re-investigate)

### 4.1 Free Music Archive — no longer a CC-first catalog
FMA is now operated by **Tribe of Noise** and its homepage leads with *"Royalty free
music. Safe to use in all kinds of media … Search PRO"* — a paid library upsell.
<https://freemusicarchive.org/> The legacy CC search still exists
(<https://freemusicarchive.org/search?quicksearch=dark+ambient> → 32 tracks) but:

- **License traps are common.** `Dark Ambient | Deep` by Alex-Productions shows an
  **NC** license: *"Attribution-NonCommercial 4.0 International License"* — banned by
  the brief. <https://freemusicarchive.org/music/alex-productions/single/dark-ambient-deep/>
- **Worse: a CC BY badge with a hidden "contact me" condition.** Soularflair's
  `Black Sun Sentinel` is badged *"licensed under a Attribution 4.0 International
  License"*, but the description says *"a condition of this is that you let me know –
  please contact me … so I can see the result"*. That is a contact-first term wearing a
  CC BY badge — the exact failure mode the brief says to avoid.
  <https://freemusicarchive.org/music/Soularflair/cc-by-free-to-use-for-anything-1/black-sun-sentinel-dark-soundtrack-ambient-drums/>

**Verdict:** avoid FMA entirely. Any FMA candidate needs its *description* read, not
just its badge — the badge is not the whole license.

### 4.2 itch.io — "CC0" tag is unreliable
`tag-cc0` is creator-applied and frequently wrong. Concrete example:
**Dystopian Ambient Pack** (ImperialDawnAudio) is tagged **CC0** and
"Royalty Free", 10 dark-ambient tracks with **loop + one-shot versions** — sounds
ideal — but its actual **Asset license field reads "Creative Commons
Attribution_NoDerivatives v4.0 International"** (CC BY-ND), which forbids the edits a
game needs. <https://imperial-dawn-audio.itch.io/dystopian-ambient-pack> It is also
flagged *AI Assisted*.

Same author's **Lurking Layers** is a genuinely interesting adaptive pack (3 tracks ×
≥5 layers each: Ambient/Mysterious/Intrigue/Danger/Melodic, same BPM, all with loops),
but **no license is stated on the page at all** — only tags. Unusable without asking.
<https://imperial-dawn-audio.itch.io/lurking-layers>

**Verdict:** itch.io requires opening each page and reading the *Asset license* row
(not the tag). Nothing on itch met the bar without a manual license confirmation.

### 4.3 Pixabay — not CC, and unsuitable for a repo
Pixabay's Content License is its own bespoke license, **not CC0/CC BY**. It forbids
*"sell or distribute Content … on a Standalone basis"* and its terms are not
GPL/EUPL-compatible-friendly for a source repo that redistributes assets. Not usable
under this brief's rule. <https://pixabay.com/service/license-summary/>

### 4.4 Kenney.nl
Only `Music Jingles` (CC0, 2014) — jingles, not beds. Covered in §2.3.

---

## 5. Fallbacks (if a primary link dies or attribution becomes a problem)

| Slot | Primary | Fallback A (also CC BY 4.0) | Fallback B (CC0, no attribution) |
|---|---|---|---|
| 1 Title | Static Motion | Temple of the Digital Monk (loop, 153.6 s) | Dark Ambient Drone (loop, 307 s) |
| 2 Lobby | Industrial Cinematic | Mary Celeste | Factory ambiance (123 s) |
| 3 Calm | Controlled Chaos – no percussion | Dark Ambient Drone (loop) | Light Through a Pale Window (loop) |
| 4 Engaged | Controlled Chaos | Cephalopod / The Complex | Rebel Base (loop) |
| 5 Clutch | Oppressive Gloom | Anxiety (1:51) / Past the Edge (1:18) | When the Shadows Gather (153.6 s) |
| 6 Win | Peaceful Desolation | Light Through a Pale Window | Temple of the Digital Monk |
| 7 Loss | Lost Time | Vanes / Thunder Dreams | Bleak Terminal (112 s) |
| Map: industrial | Factory ambiance | Iron wasteland (CC BY 4.0) | Rebel Base |
| Map: urban night | EmptyCity | Streets After Midnight | L.A. War Zone (loop) |

Also acceptable and mood-verified: **Iron wasteland** (Alexandr Zhelanov, CC BY 4.0,
72 s loop, *"small looped post apocalyptic suspense ambient theme"*, tags include
tactical/tactics/pulse/thriller) —
<https://opengameart.org/content/iron-wasteland>,
`https://opengameart.org/sites/default/files/Iron%20wasteland.ogg` (HTTP 200, 72.0 s).

---

## 6. Recommended download plan (ordered, copy-pasteable)

Slot order. The curation agent should fetch into
`assets/audio/music/` and `assets/audio/ambience/` per `docs/architecture.md` §1,
and convert MP3/FLAC → OGG Vorbis for size.

| # | Slot | File to save as | URL | License | Attribution required |
|---|---|---|---|---|---|
| 1 | Title | `music/title_static_motion.mp3` | `https://incompetech.com/music/royalty-free/mp3-royaltyfree/Static%20Motion.mp3` | CC BY 4.0 | yes |
| 2 | Lobby/deploy | `music/lobby_industrial_cinematic.mp3` | `https://incompetech.com/music/royalty-free/mp3-royaltyfree/Industrial%20Cinematic.mp3` | CC BY 4.0 | yes |
| 3 | Match calm | `music/match_calm_controlled_chaos_noperc.mp3` | `https://incompetech.com/music/royalty-free/mp3-royaltyfree/Controlled%20Chaos%20-%20no%20percussion.mp3` | CC BY 4.0 | yes |
| 4 | Match engaged | `music/match_engaged_controlled_chaos.mp3` | `https://incompetech.com/music/royalty-free/mp3-royaltyfree/Controlled%20Chaos.mp3` | CC BY 4.0 | yes |
| 5 | Clutch | `music/clutch_oppressive_gloom.mp3` | `https://incompetech.com/music/royalty-free/mp3-royaltyfree/Oppressive%20Gloom.mp3` | CC BY 4.0 | yes |
| 6 | Debrief win | `music/win_peaceful_desolation.mp3` | `https://incompetech.com/music/royalty-free/mp3-royaltyfree/Peaceful%20Desolation.mp3` | CC BY 4.0 | yes |
| 7 | Debrief loss | `music/loss_lost_time.mp3` | `https://incompetech.com/music/royalty-free/mp3-royaltyfree/Lost%20Time.mp3` | CC BY 4.0 | yes |
| 8 | Ambience: wind | `ambience/amb_wind_loop.mp3` | `https://cdn.freesound.org/previews/852/852822_18763192-hq.mp3` | CC0 | no |
| 9 | Ambience: industrial hum | `ambience/amb_industrial_hum.mp3` | `https://cdn.freesound.org/previews/453/453446_612689-hq.mp3` | CC0 | no |
| 10 | Ambience: gulls | `ambience/amb_gulls_harbour.mp3` | `https://cdn.freesound.org/previews/450/450529_997174-hq.mp3` | CC0 | no |
| 11 | Ambience: city murmur | `ambience/amb_city_murmur.mp3` | `https://cdn.freesound.org/previews/716/716384_12768873-hq.mp3` | CC0 | no |
| 12 | Ambience: distant traffic | `ambience/amb_distant_traffic.mp3` | `https://cdn.freesound.org/previews/670/670759_11673893-hq.mp3` | CC0 | no |
| 13 | Ambience: fluorescent hum | `ambience/amb_fluorescent_hum.mp3` | `https://cdn.freesound.org/previews/383/383657_7146007-hq.mp3` | CC0 | no |
| 14 | Ambience: distant sirens | `ambience/amb_distant_sirens.mp3` | `https://cdn.freesound.org/previews/568/568971_97550-hq.mp3` | CC0 | no |
| 15 | Ambience: machine room (OGA alt) | `ambience/amb_factory.ogg` | `https://opengameart.org/sites/default/files/Factory.ogg` | CC0 | no |

For Freesound originals (higher quality than the previews), log in and use
`https://freesound.org/s/<id>/download/` — IDs 852822, 453446, 450529, 716384,
670759, 383657, 568971. **The preview URLs above are the no-login path and were
verified 200.**

**Download size sanity check:** 7 Incompetech MP3s ≈ 2.0+2.4+3.5+3.6+2.5+0.9+1.8 MB ≈
**17 MB**; Freesound previews ≈ 5–8 MB each, ~40 MB; total well under 60 MB before
OGG conversion (which should halve it).

---

## 7. Exact attribution blocks for `docs/credits.md` + in-game Credits

Insert verbatim. Per the FAQ, put the credits on a Credits screen reachable from
Settings, and list each title.

```markdown
### Music

"Static Motion" Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
https://creativecommons.org/licenses/by/4.0/

"Industrial Cinematic" Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
https://creativecommons.org/licenses/by/4.0/

"Controlled Chaos - no percussion" Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
https://creativecommons.org/licenses/by/4.0/

"Controlled Chaos" Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
https://creativecommons.org/licenses/by/4.0/

"Oppressive Gloom" Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
https://creativecommons.org/licenses/by/4.0/

"Peaceful Desolation" Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
https://creativecommons.org/licenses/by/4.0/

"Lost Time" Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
https://creativecommons.org/licenses/by/4.0/

### Ambience

Freesound CC0 recordings by KolbyRFX, kyles, etienne.leplumey, lastraindrop,
Tom_Kaszuba, deleted_user_7146007 and TRP. Released under CC0 1.0 (no attribution
required; credited as courtesy):
- "AMBUndr_Subterranean Howling Wind Loop" — freesound.org/s/852822/
- "hums industrial tonal machines creak resonate large room" — freesound.org/s/453446/
- "Seagulls in a quiet street, 6AM, Harbour City" — freesound.org/s/450529/
- "Urban commercial pedestrian street ambience" — freesound.org/s/716384/
- "People walking and cars driving over metal bridge part 2" — freesound.org/s/670759/
- "Fluorescent Light Hum" — freesound.org/s/383657/
- "200927 Sirens, distant fire trucks mostly, noisy 7am" — freesound.org/s/568971/

"Factory ambiance" by yd — CC0 — opengameart.org/content/factory-ambiance
```

Note the FAQ's exact casing: **"By Attribution 4.0"** (the site's generator says
`By Attribution 4.0`; the `License` suffix appears in the on-page block). Either is
acceptable; be consistent.

**CC BY 4.0 also requires indicating changes.** We will convert MP3→OGG, trim, and set
loop points. Add one line to credits: *"Music files were converted to Ogg Vorbis and
edited for looping; no musical content was altered."* That satisfies
*"indicate if changes were made"* —
<https://creativecommons.org/licenses/by/4.0/> ("Attribution — You must give
appropriate credit … and indicate if changes were made").

---

## 8. Open questions / things a curator should still confirm

1. **Godot loop points.** MP3 has no loop metadata; `AudioStreamMP3` supports
   `loop` + `loop_offset` in Godot 4. Safer: convert to OGG and set loop points, or
   build the loop in-engine. For `Oppressive Gloom` the author explicitly says *"trim
   the end"* — the tail is a decay, so an in-engine loop will click unless trimmed.
2. **Controlled Chaos layer alignment.** Catalogue lengths are 5:52 (with percussion,
   measured 352.26 s) and 5:51 (no percussion, **not** measured — only HEAD-checked).
   They should be sample-aligned as one composition, **but verify by ear before relying
   on a gapless crossfade**: start both at 0 and check for phase/comb artefacts.
3. **Adaptive implementation.** `Controlled Chaos`/`- no percussion` share a tempo
   (80 BPM) and composition, which is what makes them mixable. If a third tier is
   wanted, `Satiate`'s stem family is 192 s — a different tempo, so it cannot
   crossfade with Controlled Chaos.
4. **Not auditioned.** I verified licenses, URLs, durations and the author's own
   descriptions — **I did not listen to any track.** Mood fit is inferred from the
   catalogue's `feel` tags and descriptions, which are the author's words. A curator
   must audition before committing; specifically check that `Industrial Cinematic` is
   not too "epic" and that `Peaceful Desolation`'s brass/timpani isn't too orchestral
   for the "not orchestral epic" constraint.
5. **`Lost Time` is 3:47** — too long for a "brief" debrief. Plan to use the first
   minute and fade.
6. **Cover-art / preview images on OGA are NOT CC0.** OGA's FAQ notes preview images
   may be separately licensed (a comment thread on L.A. War Zone discusses exactly
   this). Only download the audio files listed here.
7. **EUPL-1.2 interaction.** CC BY 4.0 audio is a separate work aggregated with the
   code; it does not relicense the code. But the repo must carry the attribution in
   `docs/credits.md`. Confirm with whoever owns licensing that this aggregation is
   acceptable — **opinion: it is standard practice and fine**, but the credits file
   must exist before the first commit that adds audio.

---

## 9. Source index (all fetched 2026-11-17)

| Source | URL | Verdict |
|---|---|---|
| Incompetech licenses | <https://incompetech.com/music/royalty-free/licenses/> | CC BY 4.0 intact |
| Incompetech FAQ | <https://incompetech.com/music/royalty-free/faq.html> | attribution wording + game placement |
| Incompetech catalog JSON | <https://incompetech.com/music/royalty-free/pieces.json> | metadata/durations/feel |
| Incompetech all-music bundle | <https://incompetech.com/music/royalty-free/Downloads/allthemusic.html> | $38, stems only here |
| CC BY 4.0 deed | <https://creativecommons.org/licenses/by/4.0/> | terms quoted |
| OGA Tsorthan Grove | <https://opengameart.org/content/background-drones-vol-1> etc. | CC0, loops |
| OGA search (CC0 music) | <https://opengameart.org/art-search-advanced?field_art_type_tid%5B%5D=12&field_art_licenses_tid%5B%5D=4> | needs browser UA |
| Freesound | <https://freesound.org/s/852822/> etc. | CC0; download needs login |
| Kenney music | <https://kenney.nl/assets/music-jingles> | jingles only — rejected |
| Free Music Archive | <https://freemusicarchive.org/> | Tribe of Noise; traps — rejected |
| itch.io CC0+music | <https://itch.io/game-assets/tag-cc0/tag-music> | tag unreliable — rejected |
| Pixabay license | <https://pixabay.com/service/license-summary/> | not CC — rejected |

**Local context used:** `docs/research/asset-inventory.md` §4 (AlkaKrab blocked),
`docs/design/game-design.md` §12 (adaptive calm→engaged→clutch, per-map ambience),
`docs/architecture.md` §1 (`assets/audio/{music,ambience}/`).