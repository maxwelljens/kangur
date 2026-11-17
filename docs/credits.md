# Credits & Asset Attribution — Kangur

Kangur game code and original content: **Licensed under the EUPL-1.2** —
see [`LICENSE`](../LICENSE). Copyright © the Kangur contributors.

Third-party assets are listed below with their own licences, which govern those
files (not the EUPL). Everything shipped under `assets/` was verified against a
licence file in the source pack **or** the original distribution page; the
verification evidence is recorded per pack. Packs we could not verify are **not
shipped** — see [Rejected / unshipped sources](#rejected--unshipped-sources).

This file feeds the in-game Credits screen (`src/ui/menus/credits`).

---

## 1. Audio — weapons (gunshots & mechanical foley)

### Snake's SECOND Authentic Gun Sounds — **public domain (author-dedicated)**

- Author: **SnakeF8** (https://f8studios.itch.io)
- Source: <https://f8studios.itch.io/snakes-second-authentic-gun-sounds-pack>
- Licence basis: the pack's `Please ReadMe.txt` only credits the author, but the
  distribution page states *"All sounds can be used commercially, and credit is
  not needed (I would appreciate it a lot though!)"* and the author confirms in
  the page comments: *"It's public domain!"* … *"Go right ahead use it in any
  way you see fit I do not mind :D"* (asked and confirmed whether CC0 wording
  applies; author agreed).
- Attribution required: **no** (courtesy credit given above).
- **64 files copied**, original filenames kept, into
  `assets/audio/weapons/{9mm,308,20ga,357,shared}/{fire,action,reload}/`.

| Game weapon (design §6) | Source dir | Sound set |
|---|---|---|
| `adder` P-9 (9mm pistol) | `weapons/9mm/` | `9mm Single`, `Single Isolated`, `Double Tap Isolated`, `Burst Isolated`, `Slow Burst Isolated`, `Spray Isolated` + `Action/` slide lock/release, rack full & halves, chamber check, dry fire + `Reload/` 2 full reloads, mag pack, mag unpack |
| `vespa` / `kedr` (9mm SMG) | `weapons/9mm/fire` | `Burst Isolated` / `Slow Burst Isolated` (pitch variants at runtime) |
| `volk` / `falx` / `sokol` / `lynx` / `mule` (.308 / 7.62×51) | `weapons/308/fire` | `308 Single`, `Single Isolated`, `Double Tap Isolated`, `Burst Isolated`, `Slow Burst Isolated`, `Spray Isolated` |
| `breve` / `automa` (20 gauge) | `weapons/20ga/` | 6 shot variants + `Reload/Single Shotgun Load.wav` |
| `judge` R-357 revolver | `weapons/357/` | **no .357 shot exists** — `action/` and `reload/` only: real .44 Magnum cylinder open/close, cock/decock hammer, eject one casing/full/empty, floor impact, single load + .32 S&W Long cylinder rotate/cock/load |
| `mule` LMG bipod | `weapons/shared/action` | `Bipod Deploy/Raise/Impact` × one/both legs |
| All mag-fed weapons | `weapons/shared/reload` | `AR PolyMag`, `AK PolyMag`, `Bolt Mag` pack/unpack, `Mosin Top Load`, `Modded Mosin PolyMag Pack`, `22LR` pack/unpack |

### `shots` — **CC BY 3.0**

- Author: **Michel Baradari** (apollo-music.de), submitted by qubodup
- Source: <https://opengameart.org/content/chaingun-pistol-rifle-shotgun-shots>
- Licence text verbatim (pack `info.txt`): *"Sounds (c) by Michel Baradari
  apollo-music.de / Licensed under CC BY 3.0
  http://creativecommons.org/licenses/by/3.0/ / Hosted on opengameart.org"*
- **Attribution required.**
- Copied: `rifle.wav` → `assets/audio/weapons/556/fire/rifle.wav`.
  Used as the **5.56 stopgap** for `kestrel`; a purpose-recorded 5.56 set is a
  known content gap.

---

## 2. Audio — footsteps

Pack: `footsteps` (`footsteps/footsteps/<surface>/`, `0.ogg`…`8.ogg`, ~0.13 s each).
Per-surface `license.txt` copied alongside as `assets/audio/footsteps/<surface>/license.txt`.

| Game surface | Source surface | Files | Licence | Attribution (required) |
|---|---|---:|---|---|
| `concrete` | `boots` | 6 | **CC BY 3.0** | `footstep-concrete.wav` by **swuing** — <http://www.freesound.org/people/swuing/sounds/38873/> |
| `sand` | `gravel` | 6 | **CC0 1.0** | Pack "Gravel Footsteps" by **Ali_6868** — <https://freesound.org/people/Ali_6868/packs/21608/> |
| `metal` | `metal` | 6 | **CC BY 3.0** | `fboots on aluminum ladder 01` by **Eelke** — <https://freesound.org/people/Eelke/sounds/462598/> |
| `grass` | `grass` | 6 | **CC BY 3.0** | `footstep-grass.wav` by **swuing** — <https://freesound.org/people/swuing/sounds/38874/> |
| `wood` | `wood` | 6 | **CC BY 3.0** | `footstep-wood.wav` by **swuing** — <https://freesound.org/people/swuing/sounds/38876/> |
| `water` | `water` | 5 | **CC BY 3.0** | `Water Footsteps` by **EminYILDIRIM** (<https://freesound.org/people/EminYILDIRIM/sounds/608663/>) + `footstep-concrete.wav` by **swuing** |

**Substitutions** (design §12 asks for concrete/sand/metal/grass/wood/water):

- `sand` ← `gravel` (no sand set exists in the library; gravel is the closest
  loose-granular surface).
- The pack's `tile` surface (CC BY 3.0, swuing + ceberation) was **not copied** —
  no `tile` surface in the design's surface list; map tile floors to `concrete`.
- Dropped as off-theme: `dog` (wolf run), `bones` (CC0), `mech` (CC BY 3.0,
  Lee Barkovich) — available in the library if a robot/ruin map needs them.

---

## 3. Audio — UI

### `sci-fi-sfx` — **CC0 1.0**

- Author: **rubberduck**, OpenGameArt
- Source: <https://opengameart.org/content/50-cc0-sci-fi-sfx> (CC0; the library
  copy is the unmodified 50-file distribution)
- Attribution required: no.
- 37 files copied total (33 into `assets/audio/ui/` + 4 loops into
  `assets/audio/ambience/loops/`, see §5), renamed semantically. Original→new:

| Original | Shipped as |
|---|---|
| `retro_beep_02.ogg` | `ui/click.ogg` |
| `terminal_01.ogg` | `ui/click_soft.ogg` |
| `beep_03.ogg` | `ui/hover.ogg` |
| `retro_beep_03.ogg` | `ui/hover_alt.ogg` |
| `misc_01.ogg` | `ui/confirm.ogg` |
| `misc_11.ogg` | `ui/confirm_alt.ogg` |
| `retro_beep_01.ogg` | `ui/back.ogg` |
| `retro_beep_05.ogg` | `ui/back_alt.ogg` |
| `misc_03.ogg` | `ui/error.ogg` |
| `weird_04.ogg` | `ui/error_alt.ogg` |
| `retro_beep_06.ogg` | `ui/notify.ogg` |
| `teleport_01.ogg` | `ui/start.ogg` |
| `teleport_02.ogg` | `ui/deploy.ogg` |
| `misc_09.ogg` | `ui/objective_capture.ogg` |
| `terminal_09.ogg` | `ui/objective_capture_alt.ogg` |
| `beep_01.ogg` | `ui/ticket_warning.ogg` |
| `weird_05.ogg` | `ui/ticket_warning_alt.ogg` |
| `misc_08.ogg` | `ui/hud_hit.ogg` |
| `misc_07.ogg` | `ui/hud_hit_alt.ogg` |
| `misc_10.ogg` | `ui/match_end_victory.ogg` |
| `misc_04.ogg` | `ui/match_end_defeat.ogg` |
| `weird_01/02/03.ogg` | `ui/glitch_1/2/3.ogg` |
| `misc_12.ogg` | `ui/glitch_4.ogg` |
| `terminal_01…08.ogg` | `ui/terminal/terminal_01…08.ogg` (unchanged names) |

### `kenney_casino-audio` — **CC0 1.0**

- Author: **Kenney Vleugels** (kenney.nl), licence `License.txt` in pack.
- 5 files → `assets/audio/ui/cards/` for debrief / loadout dossiers:
  `card-shuffle`, `card-place-1`, `card-slide-1`, `cards-pack-open-1`, `card-fan-1`.

---

## 4. Audio — voice

### Sci-Fi Ship Voices — **CC0 1.0**

- Author: **Lentikula** — <https://lentikula.itch.io> (paypal/paytreon links in
  the pack readme). Recorded by the author, no AI used.
- Licence text verbatim (`Readme.txt`): *"License CC0: The person who associated
  a work with this deed has dedicated the work to the public domain by waiving
  all of his or her rights to the work worldwide under copyright law … You can
  copy, modify, distribute and perform the work, even for commercial purposes,
  all without asking permission."*
- Attribution required: no (courtesy credit given).
- **50 files** (25 male + 25 female) into `assets/audio/voice/<category>/`,
  original filenames kept. Runtime treatment: bandpass + light distortion as the
  OVERWATCH AI radio voice (design §12, art-direction §5).

| Category | Lines |
|---|---|
| `voice/contact/` | Hostiles Detected, Intruder Alert, Proximity Alert, Anomaly Detected |
| `voice/warning/` | Warning Hull Integrity, Warning Low Oxygen, Critical System Failure |
| `voice/denied/` | Access Denied, Unknown Request |
| `voice/affirmative/` | Affirmative, Access Granted, Coordinates Confirmed, Processing, Weapon Systems Armed, Shields Activated |
| `voice/status/` | System Online/Offline, Boot Sequence Initiated/Complete, Engines Disengaged, Engines At Full Capacity, Weapon Systems Disarmed, Shields Deactivated, Destination Reached, Welcome Commander |

> Filename quirks preserved from the pack: the female variants of *Boot Sequence
> Complete* and *Engines At Full Capacity* are truncated (`Boot Sequence
> Comple`, `Engines Full Capacity`). Also note the male set names the line
> `Engines At Full Capacity` where the female set says `Engines Full Capacity`.

---

## 5. Audio — ambience

### Nature Ambient Pack Vol 1 — **CC BY 4.0**

- Author: **JC Sounds** — <https://jcsounds.itch.io/natureambientsfxvol1>
- Source (licence statement): OpenGameArt listing
  <https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1> —
  *"License(s): CC-BY 4.0. Copyright/Attribution Notice: CC BY 4.0 - Credit:
  JC Sounds"*, confirmed by the author in the itch.io comments.
- **Attribution required: "Sounds by JC Sounds (jcsounds.itch.io)"**.
- 5 files copied (mp3 originals, not re-encoded):
  `Weather/Light Rain`, `Weather/Heavy Thunderstorm`, `Weather/Winter Wind`,
  `Weather/Desert Wind` → `assets/audio/ambience/weather/`;
  `Fire & Elemental/Large Bonfire` → `assets/audio/ambience/fire/`.

### yewbic ambience 01–06 — **CC0 1.0**

- Author: **yewbic**, Freesound. The library copy carries Freesound IDs in the
  filenames; each ID was checked on Freesound and is CC0:
  `31904, 33703, 33796, 36043, 58897, 66015` →
  `https://freesound.org/people/yewbic/sounds/<id>/` (all "Creative Commons 0").
- 6 files → `assets/audio/ambience/hum/` (original filenames kept).
- IDs `66057` / `66058` (`ambience07_Internal`, `ambience08_Internal`) now
  return *"Deleted sound"* on Freesound → **not copied** (licence unverifiable).
- These are dark atmospheric drones, not literal room tone; use as map beds.

### Industrial loops — **CC0 1.0** (`sci-fi-sfx`, see §3)

`loop_machine_01/02/03.ogg`, `loop_ambient_01.ogg` → `assets/audio/ambience/loops/`.
Substitute for the (unverified) `ambient machinery 1/2` industrial beds.

---

## 6. Audio — impacts & body foley

All **CC0 1.0**.

| Files | Source | Notes |
|---|---|---|
| `sfx/impacts/metal/metal_ping_1/2.ogg`, `metal_clang_1/2/3.ogg` | `RPGsounds_Kenney` — **Kenney Vleugels** (kenney.nl), `license.txt`: *"RPG sounds by Kenney Vleugels … License (CC0)"* | Stand-ins for bullet-on-metal; Kenney's metal bowls/click are the only verified metallic impacts available |
| `sfx/impacts/flesh/flesh_slash_1/2.ogg` | same pack (`knifeSlice`, `knifeSlice2`) | Stand-ins for bullet-on-flesh |
| `sfx/impacts/wood/wood_chip_1.ogg` | same pack (`chop`) | Stand-in for bullet-on-wood |
| `sfx/body/body_fall_1.ogg`, `cloth_rustle_1/2.ogg` | same pack (`dropLeather`, `cloth1`, `cloth2`) | Body fall / gear rustle |
| `sfx/casing/casing_floor_1.wav` | Snake's SECOND (`44 Magnum Eject Floor Impact`) | Brass-on-floor |

`sfx/impacts/concrete/` and `sfx/impacts/glass/` are **empty** (`.gitkeep`) —
no licence-verified concrete chip or glass break exists in the library.

---

## 7. Audio — music

`assets/audio/music/` is **empty** (`.gitkeep`). Both music packs in the library
(AlkaKrab: *30 Sci-fi Space Tracks*, *Sci-Fi Music Pack Vol. 2*) require written
permission for open-source use and are **blocked**. CC0/CC-BY replacements are
being sourced separately.

---

## 8. Fonts — SIL Open Font License 1.1

Both faces ship as unmodified TTFs in `assets/ui/fonts/`, each with the upstream
`OFL.txt` copied alongside. OFL permits bundling in a game, including a
commercially distributed one, provided the licence text ships and the fonts are
not sold on their own.

| File | Family | Author | Licence |
|---|---|---|---|
| `ChakraPetch-{Regular,Medium,SemiBold,Bold}.ttf` | **Chakra Petch** | Copyright 2018 The Chakra Petch Project Authors (<https://github.com/m4rc1e/Chakra-Petch>) | OFL 1.1 (`OFL-ChakraPetch.txt`) |
| `ShareTechMono-Regular.ttf` | **Share Tech Mono** | Copyright 2012 Carrois Type Design, Ralph du Carrois | OFL 1.1 (`OFL-ShareTechMono.txt`) |

Sources: `google/fonts` → `ofl/chakrapetch/*` and `ofl/sharetechmono/*` (raw
GitHub TTFs). Usage: Chakra Petch = display/UI text; Share Tech Mono = all
numerals (HUD ammo, timers, killfeed) so the columns stay tabular.

## 9. Engine & tools

- **Godot Engine 4.7.2** — MIT (godotengine.org)
- **gdUnit4** — MIT © 2023 Mike Schulze (vendored in `addons/gdUnit4/`)
- **@icons** — MIT © 2026–present Valentin Fossati (Voxybuns) & contributors
- **Vision Cone 2D** — Apache-2.0 © sirdorius

## 10. Rejected / unshipped sources

Kept out of `assets/` deliberately. Do not add these without a new licence check.

| Pack | Why |
|---|---|
| `JDSherbert Free Weapon Sounds` (Walther P38) | Author's own licence (itch.io Terms & Conditions): *"You can't include these assets in another asset pack, template, **public/open source repository** or tool where others can grab them directly."* Kangur ships in a public EUPL repo → **blocked**. Credit condition also applies. |
| `SCI-FI_UI_SFX_PACK` (Hove Audio) | Distribution page grants only *"feel free to use it in whatever project you like"* / *"my sounds are royalty free"*. Not a CC licence, and "royalty free" does not clearly permit redistribution in a public source repo → **unverified, skipped**. UI SFX came from CC0 `sci-fi-sfx` instead. |
| `Clicks` | No licence file; Unity `.meta` GUIDs indicate ripped project content → provenance risk. |
| `ambient machinery 1/2` | No licence file, no source page found → unverified. |
| `hits`, `extreme_splatter`, `Super Foley Pack`, `metal_interactions`, `inventory_sound_effects`, `door_close_-_starninjas` | No licence file, no source page → unverified. |
| `SFX` | No licence file → unverified (its bolt/pump foley would be useful once cleared). |
| `yewbic ambience07/08` | Freesound entries deleted → licence unverifiable. |
| AlkaKrab music packs | Open-source use needs written permission (author's licence PDF). **Never ship.** |
| `Qoupy's_ROGNs_Free` | Non-commercial only. |

---

## Unverified-but-known attribution strings (for later re-checks)

- `footsteps/tile` — `footstep-concrete.wav` by swuing + `Squeaky footstep.wav`
  by **ceberation** (<https://freesound.org/people/ceberation/sounds/235524/>), CC BY 3.0.
- `footsteps/mech` — *Robotic mechanic step sounds* by **Lee Barkovich**,
  <http://www.archive.org/details/Berklee44Barkovich>, CC BY 3.0.
- `footsteps/bones` — *bone shell* by **blukotek**, CC0.
- `footsteps/dog` — *Wolf run.wav* by **sabotovat**, CC BY 3.0.