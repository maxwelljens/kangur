# Audio gap fill — per-file attribution (CC0 1.0, Freesound)

Sourced 2026-11-18 to close the audio gaps tracked in
[`../production-todo.md`](../production-todo.md) §Audio. Every file below was
taken from **Freesound** and every sound page was read: the licence block on all
18 pages reads

> **Creative Commons 0** — *"You can copy, modify, distribute and perform the
> sound, even for commercial purposes, all without the need of asking permission
> to the author."*
> — verbatim from each sound page, linking
> <http://creativecommons.org/publicdomain/zero/1.0/>

**No attribution is required** (CC0 1.0). Freesound's own generated attribution
lines are quoted per file anyway, so `credits.md` and the in-game Credits screen
can list them as a courtesy. **No CC-BY-NC, no "contact me first", no
royalty-free-without-a-licence sources were used.**

## 0. How the files were obtained (reproducible)

Freesound `/download/` redirects to a login wall for anonymous users, so the
**public HQ preview MP3** (`cdn.freesound.org/previews/<id3>/<id>_<userid>-hq.mp3`,
192 kbps) was the transport. Preview URLs are listed per file and are the same
audio content as the original, lossy-compressed. Consequences, stated plainly:

- Weapon one-shots and impacts are low-bitrate compared with the Snake's-pack
  WAVs next to them; fine for SFX at gameplay distance, not master-quality.
- Every file was re-encoded to the container its neighbours already use
  (`pcm_s16le` 44.1 kHz stereo for `weapons/`, Vorbis q6 48 kHz stereo for
  `sfx/impacts/`), and peak-normalised to **−1.5 dBFS** so no new file can
  clip — `docs/production-todo.md` lists >0 dBFS peaks as a live defect, and
  some source previews did clip (e.g. `357Magnum.wav`, `Shotgun Pump.wav`).
- Multi-take recordings were trimmed to a single take with 5 ms in / 40 ms out
  fades (see §5); the source take offsets are recorded there.

Re-running the fetch needs only `curl` + `ffmpeg`; the exact commands are in
§5's "Trim" column and the per-file table.

## 1. Weapon fire — 5.56 / .223 rifle (gap #1)

Replaces the CC-BY `shots/rifle.wav` stopgap as the *primary* 5.56 set.
`rifle.wav` is kept as the last variant in the set so the stopgap sound still
exists if the new files are ever removed.

| Shipped file | Freesound | Author | Source duration / rate | HQ preview | Licence |
|---|---|---|---|---|---|
| `weapons/556/fire/556_m4carbine_single.wav` | `m4carbine_fire` (865985) | **db465** | 0.696 s, 44.1 kHz | `…/865/865985_19132311-hq.mp3` | CC0 1.0 |
| `weapons/556/fire/556_ar15_pistol_single.wav` | `AR15 pistol shot` (427598) | **michorvath** | 0.908 s, 44.1 kHz | `…/427/427598_3094998-hq.mp3` | CC0 1.0 |
| `weapons/556/fire/556_rifle_single_outdoor.wav` | `Rifle gunshot, one shot` (710084) | **felix.blume** | 4.264 s, 48 kHz | `…/710/710084_1661766-hq.mp3` | CC0 1.0 |
| `weapons/556/fire/rifle.wav` *(pre-existing, unchanged)* | `chaingun-pistol-rifle-shotgun-shots` | Michel Baradari | — | OpenGameArt | **CC BY 3.0** (credits §1) |

Freesound attribution lines (courtesy, not required):

```
m4carbine_fire by db465 -- https://freesound.org/s/865985/ -- License: Creative Commons 0
AR15 pistol shot by michorvath -- https://freesound.org/s/427598/ -- License: Creative Commons 0
Rifle gunshot, one shot by felix.blume -- https://freesound.org/s/710084/ -- License: Creative Commons 0
```

Rejected during curation (don't re-investigate): `Colt M4A1 SOCOM` (737569) and
`Ar15-Real Recording` (432366) are **bursts** (15–34 report transients), not
single shots — a per-shot engine cannot slice them without artefacts;
`AR15 rifle shot from 50 yards away` (427597) is a single shot but 50-yard
distant, wrong perspective for a first-person crack.

## 2. Weapon fire — .357 Magnum revolver (gap #2)

The Judge had foley only. Now it has a real magnum report.

| Shipped file | Freesound | Author | Source duration / rate | HQ preview | Licence |
|---|---|---|---|---|---|
| `weapons/357/fire/357_magnum_single.wav` | `357 Magnum Revolver Gunshot` (683186) | **Shark_Anthony** | 0.902 s, 44.1 kHz | `…/683/683186_3692246-hq.mp3` | CC0 1.0 |
| `weapons/357/fire/357_magnum_single_tail.wav` | `357 Magnum Revolver Gunshot with Tail` (683175) | **Shark_Anthony** | 2.783 s, 44.1 kHz | `…/683/683175_3692246-hq.mp3` | CC0 1.0 |
| `weapons/357/fire/357_magnum_snub_single.wav` | `snub_nose_357_magnum_noisegate-17.80.wav` (645316) | **DarkShroom** | 0.325 s, 44.1 kHz | `…/645/645316_3139426-hq.mp3` | CC0 1.0 |

```
357 Magnum Revolver Gunshot by Shark_Anthony -- https://freesound.org/s/683186/ -- License: Creative Commons 0
357 Magnum Revolver Gunshot with Tail by Shark_Anthony -- https://freesound.org/s/683175/ -- License: Creative Commons 0
snub_nose_357_magnum_noisegate-17.80.wav by DarkShroom -- https://freesound.org/s/645316/ -- License: Creative Commons 0
```

The "with tail" variant carries the outdoor slap-back; the snub-nose is the dry
short-barrel crack. Together they cover near/indoor and distant/outdoor cases.
`357Mag.wav` (49512, Jon285, CC0) is a 6-shot range string — rejected because
the shots are 1.5 s apart in one file; `357 Magnum with 9mm mix EXT.wav`
(232868) rejected: mixed calibres in one recording.

## 3. Suppressed gunshots (gap #3)

No weapon uses these yet (no suppressed weapon in `data/weapons/`); curated so a
`suppressed` sound set can be authored without a sourcing wave. **Not wired into
any `.tres`** — `data/sounds/` has no suppressed set by design.

| Shipped file | Freesound | Author | Source duration / rate | HQ preview | Licence |
|---|---|---|---|---|---|
| `weapons/suppressed/fire/suppressed_1911.wav` | `Springfield Armory 1911 Operator (Suppressed)` (827945) | **areniporgen** | 0.635 s, 48 kHz | `…/827/827945_15072041-hq.mp3` | CC0 1.0 |
| `weapons/suppressed/fire/suppressed_silencer.wav` | `Gun Silencer.mp3` (618994) | **mrrap4food** | 0.432 s, 44.1 kHz | `…/618/618994_781461-hq.mp3` | CC0 1.0 |
| `weapons/suppressed/fire/suppressed_shot_quiet.wav` | `Silenced shot.wav` (100465) | **hoot_avi** | 0.873 s, 32 kHz | `…/100/100465_1176149-hq.mp3` | CC0 1.0 |

```
Springfield Armory 1911 Operator (Suppressed) by areniporgen -- https://freesound.org/s/827945/ -- License: Creative Commons 0
Gun Silencer.mp3 by mrrap4food -- https://freesound.org/s/618994/ -- License: Creative Commons 0
Silenced shot.wav by hoot_avi -- https://freesound.org/s/100465/ -- License: Creative Commons 0
```

`Silenced SMG Three-Shot Burst` (740120), `Silenced Submachine gun` (257364),
`SIG Sauer P226 (Suppressed)` (828790) and `Assault rifle suppressor gunshot`
(539141) are bursts or too loud/unsuppressed-sounding to read as suppressed —
one report each was preferred. `suppressed_shot_quiet.wav` came in 13 dB below
the others and was normalised +11.5 dB; it is the quietest, most "airgun" take.

## 4. Bullet impacts (gap #5, #6)

| Shipped file | Freesound | Author | Source duration / rate | HQ preview | Licence |
|---|---|---|---|---|---|
| `sfx/impacts/concrete/concrete_chip_1.ogg` | `Concrete Hit` (321477) | **dslrguide** | 0.966 s, 48 kHz | `…/321/321477_5485024-hq.mp3` | CC0 1.0 |
| `sfx/impacts/concrete/concrete_chip_2.ogg` | `Concrete Hit 2` (321478) | **dslrguide** | 0.841 s, 48 kHz | `…/321/321478_5485024-hq.mp3` | CC0 1.0 |
| `sfx/impacts/concrete/concrete_ricochet_1.ogg` | `Ricochet 4.wav` (394187) | **saturdaysoundguy** | 2.114 s, 48 kHz | `…/394/394187_7280678-hq.mp3` | CC0 1.0 |
| `sfx/impacts/glass/glass_shatter_1.ogg` | `Hard Glass Break 3` (861044) | **ElevatorFan2020** | 0.823 s, 44.1 kHz | `…/861/861044_14269391-hq.mp3` | CC0 1.0 |
| `sfx/impacts/glass/glass_shatter_2.ogg` | `Breaking Glass 2` (560767) | **Bricklover** | 0.641 s, 44.1 kHz | `…/560/560767_8919922-hq.mp3` | CC0 1.0 |
| `sfx/impacts/glass/glass_shatter_3.ogg` | `Breaking-Glass.wav` (267889) | **wjl** | 0.864 s, 44.1 kHz | `…/267/267889_5025429-hq.mp3` | CC0 1.0 |

```
Concrete Hit by dslrguide -- https://freesound.org/s/321477/ -- License: Creative Commons 0
Concrete Hit 2 by dslrguide -- https://freesound.org/s/321478/ -- License: Creative Commons 0
Ricochet 4.wav by saturdaysoundguy -- https://freesound.org/s/394187/ -- License: Creative Commons 0
Hard Glass Break 3 by ElevatorFan2020 -- https://freesound.org/s/861044/ -- License: Creative Commons 0
Breaking Glass 2 by Bricklover -- https://freesound.org/s/560767/ -- License: Creative Commons 0
Breaking-Glass.wav by wjl -- https://freesound.org/s/267889/ -- License: Creative Commons 0
```

The two dslrguide files are the impact half of a "hit a concrete wall" recording
pair — dry, close, short. The ricochet is a single descending whine, trimmed to
0.90 s (the 2.11 s original's tail is a second, unrelated bounce). Glass:
`shatter_1` = hard flat pane, `shatter_2` = small/high, `shatter_3` = dense
fragments; three variants keep repeated shots from machine-gunning.

Rejected: everything under "glass break" that is a **footstep-on-glass** or
**dumpster** recording (404923, 321143), and `Glass Breaking` (465946) because
its onset is 0.5 s into the file behind room tone.

## 5. Weapon action cycling (gap #4)

| Shipped file | Freesound | Author | Trim (start / len, 44.1 kHz stereo) | Licence |
|---|---|---|---|---|
| `weapons/20ga/action/pump_cycle_1.wav` | `Shotgun Pump.wav` (673320) | **Dentrabert** | 0.40 s / 0.60 s | CC0 1.0 |
| `weapons/20ga/action/pump_cycle_2.wav` | `Shotgun Pump.wav` (673320) | **Dentrabert** | 2.92 s / 0.54 s | CC0 1.0 |
| `weapons/308/action/bolt_cycle_1.wav` | `Mosin Nagant Bolt (fast).wav` (267895) | **rammbostein** | 1.10 s / 1.45 s | CC0 1.0 |
| `weapons/308/action/bolt_cycle_2.wav` | `Mosin Nagant Bolt.wav` (263459) | **rammbostein** | 1.20 s / 1.05 s | CC0 1.0 |

```
Shotgun Pump.wav by Dentrabert -- https://freesound.org/s/673320/ -- License: Creative Commons 0
Mosin Nagant Bolt (fast).wav by rammbostein -- https://freesound.org/s/267895/ -- License: Creative Commons 0
Mosin Nagant Bolt.wav by rammbostein -- https://freesound.org/s/263459/ -- License: Creative Commons 0
```

**Why trimmed:** each source is a *session* of several takes with silent gaps
(673320: clack groups at 0.43–0.94 s and 2.96–3.38 s; 267895: 1.15–2.39 s;
263459: 1.28–2.16 s and 2.60–3.44 s). The engine plays one `cycle` stream per
shot, so each shipped file is exactly **one** pump/bolt cycle, taken from a
different group so the two `cycle` variants are not the same take. Each trim was
checked to contain the full cycle — 267895 needed 1.45 s, not 1.05 s, or the
bolt-down/lock clack at ~1.2–1.35 s would have been cut off.

**Caveat:** the Mosin originals are **16 kHz** (telephone-grade top end). The
bolt clack survives that — it is all low-mid metal — but it will not match the
44.1 kHz Snake's-pack body foley in a spectrum analyser. Acceptable: a bolt
cycle is quiet foley, not a foreground gunshot. Upgrade path: a 44.1/48 kHz
bolt-action recording if one turns up CC0.

## 6. Sound-set wiring (`data/sounds/*.tres`)

Schema: [`src/core/data/sound_set_def.gd`](../../src/core/data/sound_set_def.gd)
— `actions: Dictionary[StringName, Array]`, `impacts: Dictionary[int, Array]`.
Surface indices from `Enums.Surface`: **0 CONCRETE, 2 METAL, 4 WOOD, 5 GLASS**.

| Set | Change |
|---|---|
| `556.tres` | `fire` = 3 new 5.56 one-shots + `rifle.wav` last (stopgap retained as fallback); `impacts[0]` = concrete chip 1/2 + ricochet; **`impacts[5]` = glass shatter 1/2 (new surface)** |
| `357.tres` | `fire` = 3 new .357 shots (was the borrowed `308 Single Isolated`); `impacts[0]` concrete; `impacts[5]` glass |
| `308_bolt.tres` | `cycle` = 2 real bolt cycles (was a borrowed `44 Magnum Cock Hammer`); `impacts[0]`, `impacts[5]` |
| `20ga.tres` | **`cycle` added** (did not exist) = 2 pump cycles; `impacts[0]`, `impacts[5]` |
| `308.tres`, `9mm.tres`, `lmg.tres` | `impacts[0]` concrete + `impacts[5]` glass only; fire/reload untouched |
| *(none)* | no `suppressed` set authored — no weapon uses one (see §3) |

All pre-existing valid mappings were kept verbatim: 9mm/308/20ga fires, the
Judge cylinder foley, the LMG bipod, every reload/shared set, the metal impact
stand-ins.

**One pre-existing bug fixed in passing.** Every set had `0: [wood_chip_1]` and
`4: [wood_chip_1]` sharing one `ext_resource` id — concrete impacts were a wood
chop. With real concrete samples available that split had to happen anyway, so
surface 4 now has its own `wood_chip_1` `ext_resource` and surface 0 has the
concrete family. Verified after the edit: no set has a `surface4` stream whose
filename does not start with `wood` (temporary probe, since deleted).

## 7. Verification performed

- `tools/godot.sh --headless --path . --import` → clean, all 19 new audio files
  imported (`.import` files generated).
- `tools/godot.sh --headless --path . tools/probe_content.tscn` →
  `CONTENT_PROBE_OK {… "sounds":7 …}`.
- Throwaway stream probe (deleted after the run): every stream in every
  `data/sounds/*.tres` resolves to an existing file with nonzero length, **and
  every impact surface points at a sample named for that surface** (concrete/
  metal/wood/glass) — **120 streams, 7 sets, 0 failures**.
- `tools/audio_asset_check.gd` → `missing: none`; `tools/audio_routing_report.gd`
  now resolves `gunshot:kestrel` to `556_m4carbine_single.wav`.
- Peak levels: every new file at −1.5 dBFS (no clipping added); each file
  `ffprobe`-validated for codec/duration.
- Total new audio: **2.54 MB** across 20 files (19 new + `rifle.wav` retained).

## 8. Still missing / honestly unresolved

**Read this first — two audio paths exist, and only one is data.** `AudioDirector`
`_stream_for()` resolves `&"gunshot:<weapon_id>"` by scanning a **folder**
(`WEAPON_SETS` in `src/audio/audio_director.gd:46`) and has no `impact` kind at
all. Nothing in `src/` reads `SoundSetDef.actions` / `.impacts` — the only reader
is `tools/probe_content.gd` (resolves the id). So a `.tres` edit is a **content
contract**, not an audible change, unless the folder it points at is what
`AudioDirector` scans. Consequences per gap:

| Gap | Data (`.tres`) | Audible in game now? |
|---|---|---|
| 5.56 dedicated set | **Filled** (3 one-shots) | **Yes** — `kestrel` → `WEAPON_SETS[556]` → the `556/fire` folder, which now holds the 3 new shots (+ `rifle.wav`, still 1-in-4). |
| .357 Judge shot | **Filled** (3 shots) | **No.** `WEAPON_SETS[&"judge"] = &"308"`. Needs a one-line `src/audio` change (`judge → &"357"`); the folder now exists and is populated, so that line is the whole fix. Out of scope for this wave (no `src/` edits). |
| Suppressed | **Files curated, not wired** | No — no suppressed weapon exists. |
| Concrete chip | **Filled** (2 chips + 1 ricochet) | **No** — no impact kind in `AudioDirector`. |
| Glass shatter | **Filled** (3 variants), mapped to `impacts[5]` | **No** — same reason. |
| 20ga pump / .308 bolt | **Filled** (2 each) | **No** — nothing emits `&"cycle"`; `SoundSetDef.actions[&"cycle"]` is read by nobody. |
| `rifle.wav` + `metal_clang_3` clipping | unchanged | still >0 dBFS; the AudioDirector limiter task in production-todo stands. |

The impact/cycle/357 hooks are each a small `src/audio` (or `src/entities`) task:
add an `&"impact:<surface>"` kind fed from `EventBus.bullet_impact`, emit
`&"gunshot:<weapon_id>:cycle"` on the action cycle, and remap `judge`. All three
are one-sitting jobs once someone owns `src/`, and the content they need now
exists — which is what this wave was for.