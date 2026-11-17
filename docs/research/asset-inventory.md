# Asset Library Inventory — `/home/mjensen/Obrazy/Assets`

Read-only survey of the external asset library for **Kangur** (topdown 2D tactical
shooter, Godot 4.7.2, EUPL-1.2, near-future corporate mercenaries in Europe).

- **Surveyed**: 2026-11-17 · **Total**: **67 pack directories + 12 loose files**
  (79 top-level entries), ~21,852 files, **5.4 GB**
- **Method**: `find`/`du` counts, PIL for image dimensions, `ffprobe` for audio
  durations, license/readme text read verbatim. Nothing copied or modified.
- **Design context used**: `docs/design/game-design.md` (32 px = 1 m, 32×32 tiles,
  layered topdown soldier sprites, holographic cyan/amber HUD, 12-weapon roster
  adder/judge/vespa/kedr/kestrel/volk/falx/sokol/lynx/mule/breve/automa).

> **⚠️ Headline license finding**: the two best music packs (**AlkaKrab**
> "30 Sci-fi Space Tracks" and "Sci-Fi Music Pack Vol. 2") explicitly require
> **written permission for use in open-source games**. Kangur is EUPL-1.2, so
> these are **NOT safe to ship** without contacting the licensor. See §Licence risk.

---

## 0. Top-level inventory (all 67 pack directories)

| Pack | Files | Size | Formats | Primary role | Licence |
|---|---:|---:|---|---|---|
| `1-bit_Pixel_Icons` | 2971 | 12M | png | 1-bit icon set (19 categories) | **unknown** |
| `16x16 Weapons RPG Icons` | 5 | 324K | png | 4 weapon sheets (bronze→gold tier) | **unknown** |
| `2-Bit Pack` | 140 | 5.4M | png | **4-colour palettes** (not tiles) | **unknown** |
| `30 Sci-fi Space Tracks` | 181 | 1.8G | wav/ogg/mp3/pdf | 30 sci-fi music tracks + loops | AlkaKrab — **open-source restricted** |
| `Animation Library[Standard]` | 7 | 53M | glb/fbx/png | Quaternius humanoid anim library | CC0 |
| `Board Game Icons - Kenney` | 774 | 3.6M | png/svg | 255 board-game/fantasy icons | CC0 |
| `Clicks` | 102 | 784K | ogg/meta | 51 UI clicks/rollovers/switches | **unknown** |
| `Crosshair Pack - Kenney` | 1212 | 5.2M | png/svg | 200 crosshairs ×6 variants | CC0 |
| `DG Fire Zone Expansion Free Ver` | 2 | 8K | png/txt | 192×128 fire/explosion tile sheet | Custom free — **no commercial edit** |
| `Dungeon tileset` | 4 | 36K | png/gif | 384×192 dungeon tile atlas | **unknown** |
| `FBX_Pistol_Starter` | 37 | 57M | fbx/ma/pdf | MocapOnline pistol mocap (3D) | **unknown** |
| `FOXTEX COMPLETE` | 4662 | 1.4G | png/txt | 4.6k Doom-style brick/concrete textures | **unknown** |
| `Free 3D Modular Game Assets For Prototyping` | 87 | 3.0M | fbx/png | grey-box modular primitives + char | CC0 |
| `Free Hologram Interface Wenrexa` | 53 | 788K | png/url | **Holographic HUD panels/buttons/icons** | **unknown** |
| `Free-Cyberpunk-Resource-Pixel-Art-32x32-Icons` | 45 | 2.7M | png/psd/pdf | 40 cyberpunk 32×32 icons | CraftPix (needs reading) |
| `Free_pixel_food_16x16` | 102 | 472K | png | 100 food icons 16×16 | CC BY 4.0 |
| `Game UI collection FREE version` | 172 | 53M | png (152) / svg/eps/ai | 152 UI bars/borders/buttons/dialogue | **unknown** |
| `Hexany's 1-bit UI Panels` | 30 | 124K | png | 12 1-bit 96×96 panels | CC0 |
| `Input Prompts - Kenney` | 4099 | 19M | png/svg/ttf | Keyboard/mouse/gamepad prompts | CC0 |
| `JDSherbert Free Weapon Sounds` | 50 | 4.1M | wav/ogg/mp3/m4a | 1 weapon (Walther P38) 5 foley types | **unknown** |
| `LPCh_Sol_01` | 2 | 376K | fbx/jpg | **3D low-poly man, Rigify rig** — NOT LPC sprites | **unknown** |
| `Low Poly Furniture` | 112 | 3.4M | fbx/png | 14 categories furniture | **unknown** |
| `Lowpoly_Furniture` | 47 | 3.4M | fbx/unitypackage | 46 furniture meshes | **unknown** |
| `MetallicPanelsAndGrids_01` | 70 | 102M | jpg/png/blend | 9 PBR metal panel/grid sets 4096² | **unknown** |
| `Modular SciFi MegaKit[Standard]` | 1167 | 65M | fbx/obj/gltf/png | 189 modular sci-fi kit pieces | CC0 |
| `MonoPixel Icon Pack ver. 2` | 264 | 1.1M | png/aseprite | 131 monochrome 8×8 UI icons | Custom — credit `o_lobster` |
| `Nature Ambient Pack Vol 1 - mp3` | 27 | 78M | mp3/pdf | 26 nature ambiences | **unknown** |
| `Ombremonde_Pack_Landscape_Illustrations` | 63 | 564M | jpg/png | 32 fantasy landscape paintings 1920² | **unknown** |
| `Pixel UI pack 3` | 9 | 100K | png | 8 pixel UI panels, dark/red | **unknown** |
| `Playing Cards` | 272 | 14M | png/svg | 67-card deck (standard 52 + jokers) | **unknown** |
| `Qoupy's_ROGNs_Free` | 19 | 108K | png | rock-node sprites | **NON-COMMERCIAL ONLY** |
| `Retro Inventory` | 247 | 1.0M | png | pixel health/hearts/inventory/settings | Custom — credit ElvGames |
| `RPGsounds_Kenney` | 103 | 1.1M | ogg | 100 RPG sfx (UI, combat, magic) | CC0 |
| `SCI-FI_UI_SFX_PACK` | 496 | 114M | wav | 393 sci-fi UI sfx (clicks/glitches/tones) | **unknown** |
| `SFX` | 14 | 1.3M | ogg/mp3 | gun foley: reloads, bolts, mags, 3 shots | **unknown** |
| `Sci-Fi Essentials Kit` | 292 | 176M | fbx/obj/gltf/png | 37 sci-fi props + 4 guns + 3 enemies | CC0 |
| `Sci-Fi Music Pack Vol. 2` | 37 | 469M | wav/ogg/mp3 | 6 sci-fi tracks + loops | AlkaKrab — **open-source restricted** |
| `Sci-Fi Ship Voices` | 51 | 23M | wav | 25 female + 25 male ship-AI lines | CC0 |
| `Snake's SECOND Authentic Gun Sounds` | 167 | 25M | wav/mp3 | **real gunshots + full reload foley** | **unknown** |
| `SpawnIconPack` | 157 | 1.9M | png | 153 512×512 crosshairs/cursors/compasses | **unknown** |
| `Super Foley Pack` | 13 | 31M | wav | 12 body/cloth/glass foley | **unknown** |
| `The Male adventurer - Free` | 60 | 408K | png | topdown 8-dir character, dash/death/idle | **unknown** |
| `TopDownFantasy-Forest` | 6 | 88K | png | forest tileset | **unknown** |
| `Top_Down_Adventure_Pack_v.1.0` | 197 | 832K | png/gif | **topdown char + enemies + tileset** | **unknown** (credit o_lobster) |
| `Ultimate Modular Sci-Fi - Feb 2021` | 366 | 54M | fbx/obj/blend | 91 sci-fi modular pieces | CC0 |
| `Universal Animation Library[Standard]` | 9 | 61M | glb/fbx/png | Quaternius universal anims | CC0 |
| `ambient machinery 1` | 12 | 20M | wav | 12 machine/engine loops | **unknown** |
| `ambient machinery 2` | 14 | 18M | wav | 14 machine/fan/motor loops | **unknown** |
| `door_close_-_starninjas` | 4 | 68K | ogg | 4 door close sounds | **unknown** |
| `extreme_splatter` | 2 | 856K | flac | 2 gore crack sounds | **unknown** |
| `feather` | 287 | 1.2M | svg | 287 feather/leaf vector shapes | **unknown** |
| `footsteps` | 129 | 852K | ogg/txt | **10 surface footstep sets** | **mixed CC0 / CC BY 3.0** |
| `grass` | 3 | 3.0M | png | 3 grass sprites | **unknown** |
| `hits` | 37 | 2.1M | flac | 37 impact/hit sounds | **unknown** |
| `inventory_sound_effects` | 6 | 736K | wav | 6 inventory foley | **unknown** |
| `items` | 1244 | 4.9M | png | 1244 16×16 item icons | **unknown** |
| `kenney_casino-audio` | 58 | 1.1M | ogg | 57 casino sfx | CC0 |
| `kenney_voiceoverFighter` | 50 | 1.4M | ogg | 46 fighting-game announcer lines | CC0 |
| `medieval_sfx_textures_1_of_2` | 25 | 124M | wav | bow/crossbow/katana foley | **unknown** |
| `metal_interactions` | 5 | 308K | wav | 5 metal button/swing sounds | **unknown** |
| `multi stylized grass` | 83 | 5.8M | png | grass billboards | CC0 (Nobiax) |
| `robotic` | 10 | 768K | wav/txt | 9 robot steps/voices | **CC BY 3.0** |
| `rpgiab_icon_pack_v1.3` | 804 | 3.4M | png | 400 16×16 RPG icons (+sheets) | **CC BY 4.0** |
| `sci-fi-sfx` | 50 | 2.5M | ogg | 50 sci-fi sfx (beeps/loops/shots) | **unknown** |
| `shots` | 5 | 820K | wav/txt | 3 gunshots (pistol/rifle/shotgun) | **CC BY 3.0** (Michel Baradari) |
| `yewbic-ambiences` | 8 | 55M | wav | 8 ambient beds | **unknown** |

*Note: `kenney_casino-audio`, `kenney_voiceoverFighter`, `shots`, `robotic`,
`rpgiab_icon_pack_v1.3`, `multi stylized grass`, `medieval_sfx_textures_1_of_2`,
`feather`, `items`, `grass`, `extreme_splatter`, `hits` were not in the caller's
known list — they are additional finds.*

---

## 1. AUDIO — Gunshots & weapon foley

### 1.1 `Snake's SECOND Authentic Gun Sounds` ⭐ best gunshot source

- **Path**: `/home/mjensen/Obrazy/Assets/Snake's SECOND Authentic Gun Sounds`
- **167 files · 25 MB · WAV (84) + MP3 (82) + txt**
- **Licence**: `Please ReadMe.txt` is **credit/promo only, no license terms**.
  → **license unknown — verify before shipping** (itch.io page
  `f8studios.itch.io/snakes-authentic-gun-sounds` presumably carries terms).
- **Structure** (3 parallel trees: `Full Sounds` = shot incl. tail/reverb,
  `Isolated` = dry single shot, `& More` = mechanical foley):

**A. Gunshot taxonomy (`Full Sounds/` and `Isolated/` are identical sets):**

| Caliber dir | Files (5 each) | Duration |
|---|---|---|
| `.308 (7.62x51)` | `308 Single`, `Double Tap`, `Burst`, `Slow Burst`, `Spray` | ~2.5–3.0 s |
| `9mm` | `9mm Single`, `Double Tap`, `Burst`, `Slow Burst`, `Spray` | ~2.5–3.0 s |
| `20 Gauge` | `20 Gauge Single`, `Double Tap`, `Burst`, `Slow Burst`, `Spray` | ~2.5–3.0 s |

Each has `WAV/` + `MP3/`. **`Isolated` is what you want for gameplay** (single
report, no burst tail); `Full Sounds` includes the mechanical cycle.

**B. Mechanical foley (`& More/`, WAV+MP3):**

| Subdir | Files | Contents |
|---|---|---|
| `Pistol/` | 11 | `9mm Pistol Reload 1/2`, `Rack Full/Part 1/Part 2`, `Chamber Check Full/Part 1/Part 2`, `Slide Lock`, `Slide Release`, `Dry Fire` |
| `Mag Pack/` | 13 | `9mm/22LR/AR PolyMag/AK PolyMag/Bolt Mag/Mosin PolyMag` each `Pack`+`Unpack`; `Mosin Top Load`, `Single Shotgun Load` |
| `Revolver/44 Magnum/` | 14 | `Open Cylinder`, `Close Cylinder`, `Cock Hammer`, `Decock Hammer`, `Single Load`, `Eject One Casing`, `Eject Empty Full/Part 1`, `Eject Full`, `Eject Floor Impact` ×3 variants |
| `Revolver/32 SW Long/` | 9 | `Open/Close Cylinder`, `Hammer Cock/Decock`, `Rotate Cylinder`, `Single Load`, `Eject One Casing` |
| `Bipod/` | 6 | `Deploy/Raise/Impact` × `One/Two Legs` |

**Mapping to Kangur roster** (design doc §6):

| Game weapon | Best source |
|---|---|
| `adder` P-9 pistol | `Isolated/9mm/WAV/9mm Single Isolated.wav` |
| `judge` R-357 revolver | **missing** — no .357; use `44 Magnum` single (heavier) |
| `vespa`/`kedr` SMG | `Isolated/9mm/.../9mm Burst Isolated.wav` (pitch-shift per weapon) |
| `kestrel` 5.56 AR | **missing 5.56** — closest is `.308 Single Isolated` (heavier); 9mm burst for lighter |
| `volk` 7.62 AR | `Isolated/.308 (7.62x51)/WAV/308 Single Isolated.wav` ✔ |
| `falx`/`sokol` BR/DMR | `308 Single Isolated` (different tail/EQ) |
| `lynx` sniper | `308 Single Isolated` + pitch down / layered tail |
| `mule` LMG | `308 Slow Burst Isolated` |
| `breve`/`automa` shotgun | `Isolated/20 Gauge/WAV/20 Gauge Single Isolated.wav` ✔ |
| All reloads | `& More/Mag Pack`, `& More/Pistol`, `& More/Revolver` |

> **Gap**: no 5.56, no .357, no suppressed shots, no distance/reverb variants.

### 1.2 `JDSherbert Free Weapon Sounds`

- **Path**: `/home/mjensen/Obrazy/Assets/JDSherbert Free Weapon Sounds`
- **50 files · 4.1 MB · wav (20) / ogg (10) / mp3 (10) / m4a (10)**
- **Licence**: none present → **license unknown — verify before shipping**
  (likely itch.io CC0/royalty-free; confirm on the JDSherbert page).
- **Contents**: a **single weapon**, `Walther P38`, in 6 mix variants
  (`Mono/` × `Stereo/` × `wav HD`, `wav SD`, `ogg`, `mp3`, `m4a`).
  Per format: `Aim - 1`, `Equip - 1`, `Fire - 1`, `Fire (Dry) - 1`, `Reload - 1`.
- **Use**: the cleanest **single-shot pistol + reload pair** in the library.
  Great for the `adder`, or as a base layer for pitching other calibers.
  Very small palette — not a whole arsenal.

### 1.3 `SFX` (generic gun foley grab-bag)

- **Path**: `/home/mjensen/Obrazy/Assets/SFX`
- **14 files · 1.3 MB · ogg (12) + mp3 (2)**
- **Licence**: none → **license unknown — verify before shipping**
- **Contents** (filename = content, no subdirs):

| File | Note |
|---|---|
| `12ga_dry.ogg` | shotgun dry-fire (11.2 s — long, trim) |
| `12ga_load_chamber.ogg` | shotgun chamber load |
| `22_mag.ogg` | .22 magazine in/out |
| `30-06_accessories.ogg` | bolt-action accessory rattle |
| `30-06_bolt.ogg` | **bolt cycle** — good for `lynx` |
| `30-06_load.ogg` | bolt-action load |
| `45ACP_Loading.ogg` | .45 ACP load |
| `45ACP_slide.ogg` | pistol slide |
| `45_add_rounds.ogg` / `45_unload_rounds.ogg` | partial mag handling |
| `generic_rifle_shot1.ogg` / `generic_rifle_shot2.ogg` | low-fi rifle shots (7.9/12.2 KB) |
| `generic_pistol_shot1.mp3` / `072780_bullet-39718.mp3` | placeholder shots |

- **Use**: excellent **reload/bolt/slide foley layer** to dress up Snake's
  mag sounds per weapon. Shot files are weak — do not use as hero gunshots.

### 1.4 `DG Fire Zone Expansion Free Ver` — NOT audio

- **Path**: `/home/mjensen/Obrazy/Assets/DG Fire Zone Expansion Free Ver`
- **2 files · 8 KB** — one PNG `All Tiles Free Ver..png` (**192×128 RGBA**,
  fire/explosion animation frames) + `FreeLicense.txt`.
- **Licence** (`FreeLicense.txt`, Dungeon Gathering / Jose Javier "SnowHex"):
  - ✅ commercial + non-commercial use allowed
  - ⚠️ **edits only allowed for NON-commercial projects** (term 1b) — this is
    a self-contradiction with 1a; treat carefully
  - ❌ no redistribution/resale/NFT as game assets
  - credit optional
- **Use**: 2D fire/explosion strip for molotov / burning barrels. **Not** a
  gunshot pack. Licence text is ambiguous for commercial modification →
  **verify before shipping** if you recolor it.

### 1.5 `shots` (OpenGameArt, clean CC BY)

- **Path**: `/home/mjensen/Obrazy/Assets/shots` · 5 files · 820 KB · wav
- **Licence**: **CC BY 3.0** — "Sounds (c) by Michel Baradari apollo-music.de",
  hosted on opengameart.org. **Attribution required.**
- Contents: `pistol.wav`, `rifle.wav`, `shotgun.wav`, `cg1.wav`, `info.txt`.
- **Use**: legally-clean placeholder shots with documented provenance; good
  reference timbre.

### 1.6 Other weapon-adjacent audio

| Pack | Contents | Licence |
|---|---|---|
| `medieval_sfx_textures_1_of_2` (25 wav, 124 MB) | bow draw/nock/release, crossbow lever/bolt/shoot, katana sheath/swing — **no firearms** | unknown |
| `hits` (37 flac, 2.1 MB) | `hit01–hit37.mp3.flac` — generic impacts **incl. flesh/bone**; ideal bullet-impact layer | unknown |
| `extreme_splatter` (2 flac, 856 KB) | `crack11`, `crack12` — heavy gore cracks | unknown |
| `robotic` (9 wav) | `robot1/3/4`, `robotstand`, `robotstep1–4`, `robotstomp` | **CC BY 3.0** (Lee Barkovich) |
| `metal_interactions` (5 wav) | `metal_button_press1/2`, `metal_interaction1/2`, `metal_swing1` | unknown |
| `Super Foley Pack` (12 wav, 31 MB) | `body_hit_on_ground`, `chest_hit`, `glass_hit`, `leather_hits`, `leather_rustling`, `shuffling_movement`, `wrist_slaps`, `squishy_sounds`, `fist_hitting_bottle`, `chair_push`, `spittakes`, `heart_to_ground` | unknown |
| `inventory_sound_effects` (6 wav) | `cloth-inventory`, `leather_inventory`, `metal-clash`, `ring_inventory`, `sell:buy_item`, `turn_page` | unknown |

---

## 2. AUDIO — Footsteps

### 2.1 `footsteps` ⭐ (10 surfaces, mixed licences)

- **Path**: `/home/mjensen/Obrazy/Assets/footsteps/footsteps` (note doubled dir;
  `__MACOSX` junk alongside)
- **129 files · 852 KB · ogg (100) + license.txt (10) per surface**
- **Licence: MIXED — read per surface. Attribution required for most.**

| Surface | Files | Licence | Attribution string |
|---|---:|---|---|
| `boots` | 9 | **CC BY 3.0** | `footstep-concrete.wav` by **swuing** (freesound 38873) |
| `tile` | 9 | **CC BY 3.0** | swuing 38873 + `Squeaky footstep.wav` by **ceberation** (235524) |
| `wood` | 9 | **CC BY 3.0** | swuing 38876 |
| `grass` | 9 | **CC BY 3.0** | swuing 38874 |
| `metal` | 8 | **CC BY 3.0** | `fboots on aluminum ladder 01` by **Eelke** (462598) |
| `water` | 5 | **CC BY 3.0** | `Water Footsteps` by **EminYILDIRIM** (608663) + swuing |
| `dog` | 8 | **CC BY 3.0** | `Wolf run.wav` by **sabotovat** (414350) |
| `mech` | 1 | **CC BY 3.0** | `Robotic mechanic step sounds` by **Lee Barkovich** |
| `gravel` | 10 | **CC0** | `Gravel Footsteps` pack by **Ali_6868** |
| `bones` | 10 | **CC0** | `bone shell` by **blukotek** (249319) |

- Naming is `0.ogg` … `N.ogg`; ~0.13 s per step. **No crouch/sprint/jog
  variants** — vary playback rate + volume per stance in code.
- **Perfect fits for Kangur maps**: `boots` (concrete), `tile`, `metal`
  (grating), `gravel`, `wood`. Drop `dog`/`bones`/`water` unless needed.
- **Attribution**: one `docs/credits.md` block listing swuing, ceberation,
  Eelke, EminYILDIRIM, Lee Barkovich, Ali_6868, blukotek, sabotovat.

---

## 3. AUDIO — UI SFX

### 3.1 `SCI-FI_UI_SFX_PACK` ⭐ best holographic-UI audio

- **Path**: `/home/mjensen/Obrazy/Assets/SCI-FI_UI_SFX_PACK/SCI-FI_UI_SFX_PACK`
  (zip wrapper: `SCI-FI_UI_SFX_PACK/` + `__MACOSX/`)
- **496 files · 114 MB · wav (480 + 393 in nested dir) · 16 DS_Store junk**
- **Licence**: **none found → license unknown — verify before shipping**
- **Taxonomy** (dir → count → examples):

| Directory | Files | Examples / use |
|---|---:|---|
| `Clicks/` | 17 | `Click`, `Click_1/2/3`, `Click_Low`, `Click_Mid`, `Click_Mid-High`, `Click_Pitched_Down/Up`, `Click_Scoop_Up`, `Click_Stutter`, `High_Click_1/2`, `Ting_Pitched_Down/Up` → **buttons, hovers** |
| `Click Combos/` | 12 | `Click_Combo`, `_2`, `_2_High/Low`, `_3`, `_3_High`, `_4`, `_4_High`, `_5`, `_5_Pitched_Up/Down` → **confirm/accept actions** |
| `Glitches/` | 31 | `Glitch`, `Glitch_1…Glitch_30` → **hacked terminal, damage to HUD, EMP** |
| `Rings/` | 12 | `Reverse_Ring`, `Reverse_Ring_2_High/Mid/Low/Very_Low`, `Ring_Pitched_Up/Down` → **notification ping, objective update** |
| `Impacts/` | 6 | `Impact_1`, `Impact_1_Low`, `Impact_2`, `_2_Mid`, `_2_Reso`, `_2_Top_End` → **HUD hit feedback** |
| `FX Sounds/` | 3 | `Air_FX`, `_Pitched_Up`, `_Pitched_Down` → **whoosh / panel slide** |
| `Tone1/`, `Tone2/`, `Tone3/` | 7 each | `Basic Tones/Tone1A…D` + `_Double` → **menu ambience stings** |
| `Tone1/Fifth`, `Fourth`, `Major`, `Minor`, `Octave`, `Tritone` | — | musical intervals → **procedural UI melodies** |

- **This is the single best match for the holographic HUD aesthetic.** 393
  playable files after removing junk. Pair with the Wenrexa HUD art.

### 3.2 `Clicks` (Unity export)

- **Path**: `/home/mjensen/Obrazy/Assets/Clicks` · 102 files · 784 KB · ogg
- **Licence**: none (has Unity `.meta` files → ripped from a Unity project)
  → **license unknown — verify before shipping; provenance is weak**
- Contents: `click1–5` (0.09 s), `mouseclick1`, `mouserelease1`,
  `rollover1–6` (0.23 s), `switch1–38`.
- Good basic mouse feedback; `rollover*` are ideal **hover** sounds.
- ⚠️ Unity `.meta` GUIDs suggest this is not an original distribution.

### 3.3 `RPGsounds_Kenney` (CC0, huge variety)

- **Path**: `/home/mjensen/Obrazy/Assets/RPGsounds_Kenney` · 103 files · 1.1 MB · ogg
- **Licence: CC0** — "RPG sounds by Kenney Vleugels (www.kenney.nl) …
  You may use these in personal and commercial projects. Credit nice but not
  mandatory." **Safe to ship.**
- 100 sounds: UI clicks, coin, door, footsteps, combat swishes, magic.
- **Use**: zero-risk UI/menu feedback where the sci-fi pack feels too "soft".

### 3.4 `kenney_casino-audio` (CC0)

- 58 files · 1.1 MB · ogg. **CC0.** Card chips, dice, slots, shuffle.
- **Use**: card/paper handling for the debrief screen, loadout cards, dossier UI.

### 3.5 `sci-fi-sfx` (50 ogg, 2.5 MB)

- **Path**: `/home/mjensen/Obrazy/Assets/sci-fi-sfx` · **licence unknown**
- Contents: `beep_01/02/03`, `retro_beep_01–06`, `explosion_01/02`,
  `retro_explosion`, `retro_laser_01/02`, `rocket_01`, `shoot_01/02`,
  `teleport_01/02`, `terminal_01–09`, `misc_01–12`, `weird_01–05`,
  `loop_ambient_01`, `loop_ambient_weird`, `loop_machine_01/02/03`.
- **Use**: `terminal_*` = perfect **hacking / computer interaction**;
  `loop_machine_*` = server-room ambience; `beep_*` = HUD alerts.
- This is the most *gameplay-useful* small sci-fi set after the UI pack.

---

## 4. AUDIO — Music

### 4.1 `Sci-Fi Music Pack Vol. 2` (AlkaKrab)

- **Path**: `/home/mjensen/Obrazy/Assets/Sci-Fi Music Pack Vol. 2`
- **37 files · 469 MB · wav/ogg/mp3 + PDF**
- **Licence**: `AlkaKrab Music License Info.pdf` — **CRITICAL**:
  - ✅ royalty-free, commercial use, credit appreciated not required
  - ❌ **"No reselling, sublicensing, or redistribution of the track as-is.
    If you want to use these tracks in open-source games, contact me directly
    for a permission."**
  - ❌ no re-mixing/sampling without written permission; edits for timing/EQ OK
  - Licensor retains copyright; non-exclusive
- **Kangur is EUPL-1.2 (open source) → requires written permission.**
  Mark **license unknown — verify before shipping** (contact
  `alkakrab04@gmail.com`), or use a different music source.

**Tracks** (each with `Tracks/{wav,ogg,mp3}` and `Loops/{wav,ogg,mp3}`):

| # | Title | Duration | Loop |
|---|---|---|---|
| 1 | Astro Reverie | 133 s | 128 s |
| 2 | Galactic Odyssey | 141 s | 137 s |
| 3 | Lunar Serenity | 116 s | 112 s |
| 4 | Celestial Echoes | 122 s | 118 s |
| 5 | Stellar Drift | 120 s | 115 s |
| 6 | Orbital Echoes | 132 s | 128 s |

- **Mood**: ambient/cinematic space — pads, slow arpeggios, wide reverb.
  Suitable for menus, debrief, slow infiltration; **too ethereal** for combat
  and not "corporate-thriller Europe".

### 4.2 `30 Sci-fi Space Tracks` (AlkaKrab) ⭐ best music volume

- **Path**: `/home/mjensen/Obrazy/Assets/30 Sci-fi Space Tracks` · **181 files · 1.8 GB**
- **Licence: same AlkaKrab PDF → open-source restricted (see above).**
- **Structure**: `Tracks/{wav,ogg,mp3}` (30 each) + `Loops/{wav,ogg,mp3}` (30 each)
  + `License Info.pdf`. Tracks ~121–142 s, loops ~112–137 s.
- **Mood per title** — best mission-fit picks for Kangur:
  - `22. Abandoned Mining Zone`, `1. Abandoned Outpost` — derelict industrial
  - `26. Lights of the Megacity` — **urban night, best menu/title theme**
  - `20. Scanning the Unknown`, `28. Orbital Scan` — **surveillance / HUD tension**
  - `24. Power Down Sequence`, `15. Collapse of the Core` — **alarm / fail state**
  - `7. Awakening the Relic`, `2. Entering the Void` — slow infiltration
  - `13. Echoes from the Station`, `11. Awakening Station` — interior ambience
  - `21. Breach of the Voidline`, `19. Breach the Horizon` — **assault/breach**
  - `30. Stellar Rift`, `27. After the Starfall` — debrief / aftermath
  - `4. Lost Signal`, `6. Signal from Beyond`, `25. Signals Across` — **radio/comms**
- 90 unique audio files (30 × 3 formats × 2 sets). Use `ogg` in-game
  (≈3 MB each vs 3.5 MB wav; all 30 tracks ≈ 90 MB as ogg).

> **Music gap**: nothing here reads as *corporate mercenary Europe* (no
  industrial, no drum-and-bass tension, no military percussion). This is
  space-ambient. Consider a second source for combat music.

---

## 5. AUDIO — Ambience

### 5.1 `ambient machinery 1` / `ambient machinery 2` ⭐ industrial beds

- **Paths**: `/home/mjensen/Obrazy/Assets/ambient machinery 1` (12 wav, 20 MB)
  · `ambient machinery 2` (14 wav, 18 MB)
- **Licence: none → license unknown — verify before shipping**
- **`ambient machinery 1`**: `ambient_machine1`, `ambient_machine2`,
  `Electric noise`, `Engine noise`, `engine noise 2`, `aircompressor`,
  `clothesdryer`, `dryer`, `dryer1`, `dryer2`, `fan_1`, `debris_1`.
- **`ambient machinery 2`**: `fan_noise`, `fan_reso_1/2/3`, `motor_1`, `motor_2`,
  `loudmotor3`, `radiator_1`, `helicopter_2`, `subwayTrain_B-line` ⭐,
  `sprinkler_1`, `hair-dryer`, `vinly_flex_1`, `wind_up_long_1`.
- **Use**: `subwayTrain_B-line` (3 s loop) for metro maps; `motor_*`/`fan_*`
  for server rooms/garages; `helicopter_2` for extraction; `radiator_1` for
  old-town interiors. **Directly on-theme for industrial Europe.**

### 5.2 `yewbic-ambiences` (8 wav, 55 MB)

- **Path**: `/home/mjensen/Obrazy/Assets/yewbic-ambiences`
- **Licence**: none in dir, but Freesound IDs in filenames
  (`31904__yewbic__ambience01.wav` …) → Freesound terms apply; likely CC0/CC BY.
  **license unknown — verify before shipping** (look up the 8 Freesound IDs).
- `ambience01–06` + `ambience07_Internal`, `ambience08_Internal`
  (the `_Internal` ones are interior room tones — **ideal for building
  interiors**). Long files (4–9.6 MB), loopable beds.

### 5.3 `Nature Ambient Pack Vol 1 - mp3` (27 mp3, 78 MB)

- **Path**: `/home/mjensen/Obrazy/Assets/Nature Ambient Pack Vol 1 - mp3`
- **Licence: none → license unknown — verify before shipping**
- 26 ambiences in 4 categories (with `Assets List.pdf`):
  - `Forest Enviroments/`: Day, Night, Enchanted, Autumn, Rainforest Canopy,
    Spooky, Clearing, Pine
  - `Water Enviroments/`: Ocean Waves, Mountain Stream, Peaceful Lake,
    Waterfall, Swamp, Underground River
  - `Weather/`: Light Rain, Heavy Thunderstorm, Fog, Morning Mist, Desert Wind,
    Mountain Peak, Summer Evening, Winter Wind
  - `Fire & Elemental/`: Campfire Crackling, Dying Embers, Large Bonfire,
    Torch Flame
- **Use for Kangur**: `Weather/Light Rain` + `Heavy Thunderstorm` for outdoor
  maps; `Fire & Elemental` for burning wrecks; **not** the forest beds.
  Rain-on-concrete is exactly the mood for a European port at night.

### 5.4 Sci-fi small ambience

- `sci-fi-sfx`: `loop_ambient_01`, `loop_ambient_weird`, `loop_machine_01/02/03`
  (licence unknown).

---

## 6. AUDIO — Voice

### 6.1 `Sci-Fi Ship Voices` ⭐ radio chatter

- **Path**: `/home/mjensen/Obrazy/Assets/Sci-Fi Ship Voices`
- **51 files · 23 MB · wav (Female/ 25, Male/ 25) + Readme.txt**
- **Licence: CC0** — "The person who associated a work with this deed has
  dedicated the work to the public domain … You can copy, modify, distribute
  and perform the work, even for commercial purposes, all without asking
  permission." Recorded by **Lentikula**, no AI. **Safe to ship.**
- **Full line list** (identical set Male/Female):

| Category | Lines |
|---|---|
| Access/security | `Access Granted`, `Access Denied`, `Unknown Request`, `Processing`, `Affirmative` |
| Boot/system | `Boot Sequence Initiated`, `Boot Sequence Complete`, `System Online`, `System Offline`, `Critical System Failure` |
| Navigation | `Coordinates Confirmed`, `Destination Reached`, `Engines Disengaged`, `Engines Full Capacity` / `Engines At Full Capacity` |
| Threat | `Hostiles Detected`, `Intruder Alert`, `Proximity Alert`, `Anomaly Detected`, `Warning Hull Integrity`, `Warning Low Oxygen` |
| Combat systems | `Weapon Systems Armed`, `Weapon Systems Disarmed`, `Shields Activated`, `Shields Deactivated` |
| Social | `Welcome Commander` |

- **Use in Kangur**: map these onto HUD/radio events —
  `Hostiles Detected` → contact callout; `Access Granted/Denied` → door/keycard;
  `Weapon Systems Armed` → loadout ready; `System Online/Offline` → objective
  capture/loss; `Coordinates Confirmed` → move order ack; `Warning Hull
  Integrity` → armor/health critical; `Welcome Commander` → mission start.
  **Tone is calm ship-AI, not squad chatter** — you'd process with radio EQ +
  light distortion and treat as "OVERWATCH" AI, not teammates. For human
  squad barks, `kenney_voiceoverFighter` (CC0, 46 fighting-game announcer
  lines: `fight`, `ko`, `combo`, `flawless_victory`, `kill_him/her`) is the
  only other voice source and is **tonally wrong** (arcade announcer).

> **Voice gap**: no human squad radio chatter ("Reloading", "Contact left",
> "Moving up", "Man down"). This must be recorded/TTS'd or licensed separately.
---

## 7. 2D ART — Character sprites (topdown)

### 7.1 `LPCh_Sol_01` — ⚠️ NOT a sprite pack

- **Path**: `/home/mjensen/Obrazy/Assets/LPCh_Sol_01` · **2 files · 376 KB**
- Contents: `Char_Man_02v1.fbx` (348 KB) + `Color_B_Gradient.jpg` (736×566 palette)
- **Verified by importing in Blender 4.x/5.x**:

| Property | Value |
|---|---|
| Type | **3D mesh + armature** (Blender-exported FBX) |
| Mesh | `Cube.038` — 3,859 verts / 4,518 polys, single material |
| Rig | `metarig` — **Rigify humanoid, 64 bones** (spine.001–006, upper_arm/forearm/hand L/R, full 5-finger chains, thigh/shin/foot/toe) |
| Dimensions | **1.88 m tall**, 1.15 m wide, 0.45 m deep |
| Animations | **none** (0 actions) |
| Texture | `Color_B_Gradient.jpg` — 736×566 gradient palette atlas |
| Provenance | `D:\3D\Characters\Char_Man_02`, "Blender (stable FBX IO) 4.0.0" |

- **Verdict**: this is a low-poly **3D** character for 3D rendering, *not*
  "LPC soldier sprites". There are **no topdown body/arms/head layers, no walk
  cycles, no 4/8-direction frames**. Not usable as a 2D topdown sprite without
  a full 3D→2D bake pipeline (render 8 directions × N frames → atlas).
- **Licence**: none → **license unknown — verify before shipping**
- **Possible use**: reference proportions for drawing Kangur's own topdown
  soldier, or if you pivot to 2.5D pre-rendered sprites, this is a rig you
  could animate and bake (Rigify rig is clean and 64-bone complete).

### 7.2 `Top_Down_Adventure_Pack_v.1.0` ⭐ only real topdown character set

- **Path**: `/home/mjensen/Obrazy/Assets/Top_Down_Adventure_Pack_v.1.0`
- **197 files · 832 KB · png + gif** (each anim has `.gif` preview and
  `_strip_N.png` horizontal strip)
- **Licence**: `README.txt` = "Credits go to: **o_lobster**,
  https://o-lobster.itch.io/" — **no licence terms** →
  **license unknown — verify before shipping**
- **Structure**: `Char_Sprites/` (65), `Enemies_Sprites/` (86),
  `Hud_Ui/` (4), `Props_Items_(animated)/` (21), `Tiles_(animated)/` (18),
  `Dungeon_Tileset.png`, `Overworld_Tileset.png`

**Character (`Char_Sprites/`) — 4-direction, 16×16-ish base, strip format:**

| Animation | Strip size | Frames |
|---|---|---|
| `char_idle_{down,up}` | 96×16 | 6 |
| `char_idle_{left,right}` | 96×32 | 6 |
| `char_run_{down,up}` | 96×16 | 6 |
| `char_run_{left,right}` | 96×32 | 6 |
| `char_attack_{down,up}` | 288×32 | 6 (wide reach) |
| `char_attack_{left,right}` | 192×48 | 6 |
| `char_death_all_dir` | — | 10 |
| `char_falling_all_dir` | — | — |
| `char_hit_{down,up,left,right}` | — | — |
| `char_climbing_{up,down}` | — | 6 (+ before/after 3) |
| `char_pushing_{dir}` | — | — |
| `char_shielded_hit_{dir}` + `char_shielded_static_{dir}` | — | — |
| `char_spritesheet.png` | **415×368** | master sheet |

- **Style**: pixel-art adventurer, bare-handed / sword-swing attacks.
  **4 directions only, no separate arms+gun layer, no aim rotation.**
- **Use**: placeholder player/NPC body for a vertical slice; the `attack_*`
  frames can stand in for a melee/breach animation. Cannot deliver Kangur's
  "free rotation toward aim with arms+weapon layer" (design §1).
- **HUD**: `health_bar_hud.png` (64×16), `health_hud.png` (56×16),
  `item_box_hud.png` (16×16), `select_icon_ui.png` (16×16) — tiny pixel HUD.
- **Tiles**: `Dungeon_Tileset.png` **192×208**, `Overworld_Tileset.png`
  **288×208**, plus animated tiles (water, doors, iron gate, spikes trap,
  breakable rock) as strips.
- **Enemies** (6): Bomberplant, Phantom, Pinkbat, Pinkslime, Spider, Spinner —
  fantasy monsters, not soldiers.
- **Licence risk**: same author as `MonoPixel` (o_lobster) whose other pack
  says "personal and commercial use, no resale of icons alone, credit
  o_lobster" — plausible but **must confirm on itch.io**.

### 7.3 `The Male adventurer - Free`

- **Path**: `/home/mjensen/Obrazy/Assets/The Male adventurer - Free`
- **60 files · 408 KB · png**
- **Licence**: none → **license unknown — verify before shipping**
- **Structure**: `Idle/`, `Walk/`, `Dash/` (+`Dust/`), `Death/`,
  `Death Shadow/`, `Jump - NEW/` (`Normal/`, `Dust/`), `Shadow.png`,
  `Dash_Shadow.png`, `frame dimensions.png` (1344×769 reference)
- **Format**: two layouts per anim —
  - **all-directions grid**: `idle.png` **384×384** (8×8 grid of 48×48 frames)
  - **single-direction strip**: `idle_down.png` **384×64** (8 frames of 48×48)
  - Directions: `down`, `up`, `left_down`, `left_up`, `right_down`, `right_up`
    → **6 directions** (no pure left/right)
- **Style**: clean pixel adventurer with separate shadow sprite. **6-dir
  movement set** — closer to Kangur's needs than the 4-dir pack above, but
  again **no arms+weapon overlay, no aim-independent torso**.
- **Use**: best *free* body base for prototyping a topdown character rig;
  `Dash/` gives a sprint-ish anim.

### 7.4 Character verdict for Kangur

**No pack in the library provides the design-mandated layered topdown soldier
(legs/torso + head + arms&weapon, free rotation).** Both sprite packs are
4–6-direction pixel fantasy adventurers with baked-in arms. Options:

1. **Draw from scratch** (recommended): 32 px/m → ~24 px wide soldier.
   Layered atlas: `legs` (8 dir or rotating), `torso` (8 dir), `head`
   (8 dir + 4 expressions), `arms_weapon` (rotating around shoulder pivot).
   Matches CS2D readability and the "crisp, slightly gritty" brief.
2. **Pre-render** from a 3D rig: `LPCh_Sol_01`'s 64-bone Rigify rig could be
   animated and baked to 32-direction sprites, but it's an untextured
   gradient-mapped low-poly body and has zero animations.
3. **Prototype** with `The Male adventurer - Free` (6-dir) and swap later.

---

## 8. 2D ART — Tilesets & textures

### 8.1 `2-Bit Pack` — ⚠️ 4-colour **palettes**, not tilesets

- **Path**: `/home/mjensen/Obrazy/Assets/2-Bit Pack`
- **140 files · 5.4 MB · png** · **Licence: none → verify before shipping**
- **Structure**: 28 palette directories (exact names): `2bit Demichrome`,
  `2bit Sunrise`, `Ayy4`, `Blushroom`, `Borealis`, `Cherrymelon`, `Deadbeat`,
  `didi4`, `Dreamfull Space`, `Dusty4`, `Hollow`, `Honey Milk`, `Ice Cream`,
  `Kanagawa`, `LavaGB`, `LostGB`, `Moon Crystal`, `Moonlight`, `Mushbloom`,
  `Nostalgia`, `Paper4`, `Pen'n'Paper`, `Pocket Gray`, `Pocket Green`,
  `Red Poster`, `Sanguine`, `Soggy Newspaper`, `Sunset Lantern`
- Each palette dir contains: `<name>_a.png` + `<name>_b.png` (**768×464**
  sheets, verified **exactly 4 unique RGBA colours**), mirrored `_r` variants,
  and `<name>-32x.png` (**128×32** swatch strip)
- **Verdict**: these are **Lospec-style 4-colour palette references** (e.g.
  Demichrome = `#A0A08B #E9EFEC #555568 #211E20`). **Zero tileable tilesets.**
  Correction to the caller's assumption — do **not** plan a map tileset from this.
- **Useful as**: a strict colour-discipline reference if you go 1-bit/4-colour
  for a stylised mode, or for a "security camera / degraded feed" post effect.

### 8.2 `Dungeon tileset`

- **Path**: `/home/mjensen/Obrazy/Assets/Dungeon tileset` · **4 files · 36 KB**
- `Dungeon tileset.png` — **384×192 RGBA**, 389 unique colours (NOT 1-bit;
  it's a small hand-drawn dungeon atlas)
- `01.gif` (64×128), `02.gif` (6.2 KB), `03.gif` (3.4 KB) — animated previews
- **Licence: none → license unknown — verify before shipping**
- **Use**: 32×32-ish dungeon walls/floors. **Fantasy stone**, not urban/sci-fi.
  Could serve a "cellar/underground bunker" map with heavy retinting.

### 8.3 `FOXTEX COMPLETE` ⭐ huge realistic texture library

- **Path**: `/home/mjensen/Obrazy/Assets/FOXTEX COMPLETE`
- **4,662 files · 1.4 GB · png (4,607) + Doom TEXTURES scripts**
- **Licence**: `ReadME.txt` is **GZDoom usage instructions only — no licence
  grant**. → **license unknown — verify before shipping** (this is a
  Doom texture compilation; provenance of individual textures is murky).
- **Structure**: `Textures/`, `Brightmaps/` (`Doors`, `Lava`, `Lights`),
  `Patches/` (`Bricks`, `Concrete`), `Gzdoom scripts/` (`ANIMDEFS`, `GLDEFS`,
  `TEXTURES.*` per volume)

**Texture taxonomy** (4,564 png under `Textures/`):

| Dir | PNGs | Contents |
|---|---:|---|
| `VOL1/` | 1,920 | `Bricks/`, `Concrete/`, `Marble/`, `Stone/` |
| `VOL2/` | 1,483 | `F1/`, `F2/`, `F3/` |
| `VOL3/` | 630 | `F1/`, `F3/` |
| `VOL4/` | 214 | `F1/`, `F2/` |
| `Old Bricks/` | 247 | `Old F3/` |
| `MISC/` | 70 | tech panels: `MCCT*`, `MCFG*`, `MCPF*`, `MCSF*` |

- **Dimensions**: mix of **512×512 (331)**, **256×256 (244)**, plus strips
(64×256, 128×512, 256×512). Perfect for **32 px/m topdown** — a 512² texture
tiles a 16 m × 16 m area at 1:1, or ~4 m at 2× zoom.
- **Use for Kangur**: `VOL1/Concrete` and `VOL1/Stone` for European
  pavements/walls; `MISC/MC*` for **sci-fi tech panels** (server rooms, lifts);
  `Brightmaps/*` are emission masks → reuse as **glow maps for signage**.
- **This is the best source of grounded urban/industrial ground textures.**
  Licence is the blocker, not content.

### 8.4 `MetallicPanelsAndGrids_01` ⭐ PBR metal for sci-fi interiors

- **Path**: `/home/mjensen/Obrazy/Assets/MetallicPanelsAndGrids_01`
- **70 files · 102 MB · jpg + `.blend`**
- **Licence: none → license unknown — verify before shipping**
- **9 material sets**, each with 8 maps
  (`basecolor`, `normal`, `normalogl`, `roughness`, `metallic`, `height`,
  `ambientocclusion`, `Opacity`) at **4096×4096 JPEG**:

| Set | Look |
|---|---|
| `BronzeGrid_01` … `_04` | bronze metal grid/mesh panels |
| `BronzeTiles_01`, `_02` | bronze tile plates |
| `BronzeWall_01` | bronze wall panel |
| `GoldFlowerPattern_01` | ornate gold pattern (corporate lobby / vault) |
| `MetalTiles_01` | plain metal tiles |

- `Materials_MetallicPanelsAndGrids_01.blend` (2.7 MB) has all 9 materials
  pre-wired + 9 preview spheres. **Verified loadable in Blender.**
- **Use**: 4K is overkill at 32 px/m → downscale to 512². Great for
  **lift interiors, vault doors, server racks, corporate atria**. The gold
  pattern suits a "corporate HQ" map; bronze grids suit utility corridors.
- **9-slice/tiling**: these are **tiling** PBR sets (not 9-slice UI).

### 8.5 `Sci-Fi Essentials Kit` (Quaternius, CC0) — 3D, but has 2D-ish value

- **Path**: `/home/mjensen/Obrazy/Assets/Sci-Fi Essentials Kit`
- **292 files · 176 MB** · fbx 74 / png 68 / obj 37 / mtl 37 / gltf 37
- **Licence: CC0 1.0** (Quaternius) — **safe to ship, no attribution required.**
- **37 models** (`FBX/`): `Enemy_EyeDrone`, `Enemy_QuadShell`,
  `Enemy_Trilobite`, `Gun_Pistol`, `Gun_Revolver`, `Gun_Rifle`,
  `Gun_SMG_Ammo`, `Gun_Sniper`, `Gun_Sniper_Ammo`, `Prop_Ammo`,
  `Prop_Ammo_Closed`, `Prop_Ammo_Small`, `Prop_Barrel1`,
  `Prop_Barrel2_Closed/Open`, `Prop_Chair`, `Prop_Chest`, `Prop_Crate`,
  `Prop_Crate_Large`, `Prop_Crate_Tarp`, `Prop_Crate_Tarp_Large`,
  `Prop_Desk_L/Medium/Small`, `Prop_Grenade`, `Prop_HealthPack`,
  `Prop_HealthPack_Tube`, `Prop_KeyCard`, `Prop_Locker`, `Prop_Mine`,
  `Prop_Mug`, `Prop_SatelliteDish`, `Prop_Shelves_ThinShort/ThinTall/
  WideShort/WideTall`, `Prop_Syringe`
- **Textures** (36 png, PBR sets): `T_Guns_Batch1/2_{BaseColor,Normal,ORM,
  Emissive}`, `T_Enemies_*`, `T_Props_Batch1/2_*`, `T_Props_Small_*`
- **Use**: 3D props for a **pre-rendered sprite pipeline** (crates, lockers,
  ammo, health packs, keycards, grenades, mines → bake to topdown icons).
  Also a **ready-made sci-fi colour key** for your 2D art.
  `Gun_*` models are ideal reference for drawing weapon icons.

### 8.6 `Modular SciFi MegaKit[Standard]` (Quaternius, CC0)

- **Path**: `/home/mjensen/Obrazy/Assets/Modular SciFi MegaKit[Standard]`
- **1,167 files · 65 MB** · fbx 378 (189 ×2 Unity variants) / obj 191 /
  gltf 191 / png 24
- **Licence: CC0 1.0** — safe to ship.
- **Categories** (`FBX/`): `Aliens` (3), `Columns` (8), `Decals` (29),
  `Platforms` (37), `Props` (28), `Walls` (84)
- Notable: `Wall_*` 84 modular wall pieces with corners/bands, `Door_Simple`,
  `Door_DarkMetal`, `Door_Frame_*`, `Platform_Ramp/Stairs/Rails`,
  `Prop_Computer`, `Prop_AccessPoint`, `Prop_Light_*`, `Prop_Vent_*`,
  `Decal_Line_Straight/Bend/90` (floor marking decals ⭐ for tactical maps),
  `Decal_Sign`, `Decal_Logo`, `Decal_X/V/Z`
- **Textures**: `T_Decals.png` (2000²), `T_PaddedWall_BaseColor/Normal` (2048²)
- **Use**: **best CC0 source for a sci-fi facility map** — corridors, catwalks,
  doors, decals. For a topdown 2D game you'd render these top-down once and
  bake to tiles, or use them if you ever go 2.5D.

### 8.7 `Ultimate Modular Sci-Fi - Feb 2021` (Quaternius, CC0)

- **Path**: `/home/mjensen/Obrazy/Assets/Ultimate Modular Sci-Fi - Feb 2021`
- **366 files · 54 MB** · fbx 91 / obj 91 / blend 91
- **Licence: CC0 1.0** — safe to ship.
- Contents: `Column_1/2/3/Slim`, plus 87 more modular pieces (walls, floors,
  props). Older/simpler than the MegaKit. **Redundant** if you use MegaKit.

### 8.8 `TopDownFantasy-Forest`

- **Path**: `/home/mjensen/Obrazy/Assets/TopDownFantasy-Forest` · 6 files · 88 KB
- `Tiles/Tileset.png`, `Tiles/Tileset1xPadding.png`, `Decorations/
  Decorations.png`, `Mockup1/2/3.png`
- **Licence: none → license unknown — verify before shipping**
- Fantasy forest only — **not relevant** to urban/sci-fi Kangur maps.

### 8.9 Other environment art

| Pack | Contents | Licence |
|---|---|---|
| `Low Poly Furniture` (112 fbx, 3.4 MB) | `Bathroom/Beds/Carpets/Chairs/Doors/Drawers/Electronics/Kitchen/Lights/Miscellaneous/Shelves/Sofas/Tables/Windows` — **office/apartment furnishing** | unknown |
| `Lowpoly_Furniture` (47 fbx) | 46 furniture meshes + `.unitypackage` (duplicate of above subset) | unknown |
| `Free 3D Modular Game Assets For Prototyping` (87 fbx) | `Character/Character.fbx` + `Pieces/` grey-box primitives (arrow, box, coin, cone, cube variants) + `texture.png` | **CC0** |
| `grass` (3 png, 3 MB) | grass sprites | unknown |
| `multi stylized grass` (83 png, 5.8 MB) | grass billboards | **CC0** (Nobiax) |
| `feather` (287 svg) | feather/leaf vector shapes — decorative only | unknown |
| `Ombremonde_Pack_Landscape_Illustrations` (63 files, 564 MB) | 32 fantasy landscape paintings, 1920×1080 jpg + 12–24 MB png (`Fond_Foret`, `Fond_champ`, `Fond_grotte`, `Fond_village`) | unknown |
| `Playing Cards` (272 png/svg) | 67-card standard deck, `PNG-cards-1.3/` + `SVG-cards-1.3/` | unknown |
| `items` (1,244 png) | `item1.png`…`item1244.png`, **all 16×16** — vast generic item icon sheet | unknown |
| `Free_pixel_food_16x16` (102 png) | 100 food icons 16×16 + display sheet | **CC BY 4.0** |

- `Ombremonde` is **fantasy illustration**, not usable for a near-future
  European shooter. `Playing Cards` is useful only as a diegetic prop
  (briefing dossier / poker in a safehouse).

---

## 9. 2D ART — HUD / UI packs

### 9.1 `Free Hologram Interface Wenrexa` ⭐⭐ the HUD aesthetic match

- **Path**: `/home/mjensen/Obrazy/Assets/Free Hologram Interface Wenrexa`
- **53 files · 788 KB · png (48) + url/readme**
- **Licence**: `Readme.txt` is **ASCII-art promo only, no licence grant** →
  **license unknown — verify before shipping** (Wenrexa itch.io page needed;
  the `.url` files point to paid bundles "Wenrexa Bundle 1/2 +20,000 assets").
- **Style**: **dark teal/near-black glass panels with cyan `#7BEBD4` line work** —
  verified dominant colour `rgb(123,235,212)` across all 35 icons; card
  backgrounds are `rgb(5,19,21)` (near-black teal). **This is exactly Kangur's
  holographic HUD direction** (design §1: "thin cyan/amber lines, subtle
  scanlines, bracket corners"). Tintable to `#3E5C76`/`#F2A541` per faction.

**Complete inventory:**

| Group | Files | Dimensions | Contents |
|---|---|---|---|
| `Button 1/` | 4 | **114×38** | `Button Normal`, `Hover`, `Active`, `Disable` — **a full 4-state button set, 9-slice ready** |
| `Card X1/` | 5 | 405×847, 396×847; panels 113×65 | `Card X1`, `Card X2`, `Panel Empty`, `Panel Empty Green`, `Panel Red` — tall vertical character/loadout card |
| `Card X2/` | 2 | 405×378, 397×378 | `Card X2`, `Card X3` — wide card (weapon slot?) |
| `Card X3/` | 2 | 695×377, 695×399 | `Card X5`, `Card X6` — **large panel/dialog frame** |
| `Icons/` | 35 | 15×29 … 35×24 (mostly ~24–32 px) | unlabeled `01.png`–`35.png`, all cyan line icons: brackets, arrows, chevrons, sliders, bars, targets, gauges |

- **9-slice suitability**: the **Button 1** set is the only explicitly
  4-state, small, frame-like asset → **best 9-slice candidate**.
  Cards are fixed-size layouts (has baked-in corners/ornament) → use as
  fixed panels or rebuild corners manually.
- **Minimap frame**: **none**. No circular/radar frame in the pack.
- **Gap**: no bars/progress fills, no sliders, no checkboxes, no scrollbars,
  no ammo counter, no body-damage diagram. Pair with another pack.

### 9.2 `Game UI collection FREE version` (SunGraphica)

- **Path**: `/home/mjensen/Obrazy/Assets/Game UI collection FREE version`
- **172 files · 53 MB · png (152) + svg/eps/ai**
- **Licence**: `Sungraphica + info .txt` = **marketing/links only, no licence
  terms** → **license unknown — verify before shipping**
  (gamedevmarket.net/member/sgasset).
- **Style**: **flat vector, dark translucent panels with glowing colour
  accents** — 5 colour ramps: `Blue`, `Green`, `Purple`, `White`, `Yellow`.
  Rounded rectangles, soft glow, mobile-game sci-fi. **Very 9-slice friendly.**

**Structure** (`PNG/`):

| Group | PNGs | Colour dirs | Sizes | Contents |
|---|---:|---|---|---|
| `Bars/` | 77 | Blue, Green, Purple, White, Yellow | 1276×106, 1370×158, 421×47, … | **progress/health/XP bars** — multi-segment + fill states, at 0.5×/1×/2× |
| `Borders/` | 20 | Blue, Green, Purple, White, Yellow | up to **3540×1476**, 1042×1859 | **full-screen ornate frames / panel borders** for menus |
| `button/` | 25 | Blue, Green, Purple, White, Yellow | 365×364, 400×399/400 | **round + rounded-square buttons**, 1×/2× |
| `Button with border/` | 10 | Blue, Green, Purple, White, Yellow | 1070×338, 960×338 | **wide CTA buttons** (Start / Deploy / Abort) |
| `Dialogue/` | 5 | Blue, Green, Yellow, 1x | **2783×1114** | **large dialogue/ briefing panel** |
| `Icons/` | 15 | — | 225×415 … 591×580 | large decorative vector icons (trophies, chests, shields, stars) |

- **9-slice**: **excellent** — buttons and bars are clean rounded rects with
  uniform edges. Dialogue panel and borders are also sliceable if you rebuild
  the ornate corners as separate pieces.
- **Minimap frame**: **none explicitly**, but `Borders/` full-frame pieces
  can be cropped into a rectangular minimap frame.
- **Colour mismatch**: the palettes are saturated mobile-game blue/green/
  purple/yellow — **needs recolouring** to Kangur's slate/amber. Source
  `.svg`/`.ai`/`.eps` files make recolouring easy (that's the pack's strength).
- **Best use**: menu/dialogue/loadout screens and progress bars; skip the
  buttons if Wenrexa's suit better.

### 9.3 `Pixel UI pack 3`

- **Path**: `/home/mjensen/Obrazy/Assets/Pixel UI pack 3` · **9 files · 100 KB**
- **Licence: none → license unknown — verify before shipping**
- 8 numbered panels + `All.png` (912×304 contact sheet):
  `00` 320×160, `01` 272×144, `02` 256×160, `03` 240×144, `04` 336×240,
  `05` 384×32 (bar/ribbon, dark + red accent `#CE1400`), `06` 256×240,
  `07` 144×288 (vertical panel)
- **Style**: **dark greyscale pixel panels** (`#000`, `#1B1B1B`, `#3D3D3D`,
  `#5D5D5D`) with occasional red. Chunky 1–2 px borders, hard corners.
- **9-slice**: **good** for the rectangular panels (uniform pixel borders).
- **Use**: inventory/loadout/debrief windows in a **pixel-art** HUD variant,
  or as the "low-tech terminal" UI (contrast against holographic HUD).
  Too dark/greyscale for the primary HUD, but a strong secondary language.

### 9.4 `Hexany's 1-bit UI Panels` (CC0)

- **Path**: `/home/mjensen/Obrazy/Assets/Hexany's 1-bit UI Panels`
- **30 files · 124 KB · png**
- **Licence: CC0** (`LICENSE.txt`: "waived all copyright … CC0 1.0") —
  **safe to ship.**
- `Panels/` — 12 themed panels + `Transparent/` variants, **96×96**, verified
  **2 colours only** (black `#000` + cream `#FFF1E8`):
  `assembly`, `bone_breakers`, `northern_wastes`, `polis_sanctuary`, `simple`,
  `simple2`, `spacing_guild`, `spikecore`, `star_fleet`, `thorny_growth`,
  `weathered_temple`, `ziggurat`
- `panels_1.png` (3.5 KB), `panels_2.png` (882 B) — contact sheets
- **INFO.txt**: "9 pixel art 1-bit panels at 96×96 resolution. Should be good
  for portraits, button borders and UI stuff in general." (the pack now ships
  **12** named panels; the readme still says 9)
- **Use**: **portraits** (96×96 = perfect operator portrait size) and
  **button borders**. Pure 1-bit → recolour both indices to
  `#0B1416`/`#7BEBD4` and it becomes an in-world terminal frame.
  Not a full HUD kit.

### 9.5 `Retro Inventory` (ElvGames)

- **Path**: `/home/mjensen/Obrazy/Assets/Retro Inventory`
- **247 files · 1.0 MB · png** in `Original/` (82), `Scaled 2x/`, `Scaled 3x/`
- **Licence** (`Read Me.txt`): ✅ "You are free to use, personal or commercial
  projects. You can edit/modify to fit your game. **Credits to ElvGames.**
  You cannot: Sell this asset pack, not even modified. Claim this asset is yours."
  → **Commercial OK, attribution required, no resale. Safe to ship with credit.**
- **Contents** (82 originals):

| Group | Files | Sizes | Contents |
|---|---:|---|---|
| `Health_01`–`Health_05` | 28 | **64×16** (horizontal) / **16×64** (vertical) | 5 bar frame styles, each with 3–6 `_BarNN` fill stages |
| `Heart_*` / `Hearts_*` | 31 | 16×16 | `Heart_Red/Blue/Orange/Yellow` + `_Clear` variants, `Hearts_Red/Blue/Yellow` rows |
| `Inventory_*` | 16 | 48×48 slots, 64×64, 64×16 | `Inventory`, `Inventory_9Slices`, `Inventory_Slot_1`…`_10`, `Inventory_Example_01…04` |
| `Settings_*` | 7 | 96×96, 64×16 | `Settings`, `Settings_Bar01–03`, `Settings_Cross01–03` (checkboxes/toggles) |

- **9-slice**: **explicitly yes** — `Inventory_9Slices.png` is provided.
- **Style**: chunky pixel-art, black outline, flat fills. Reads as
  "retro survival inventory". **Tonal mismatch** with holographic HUD, but
  the **9-slice inventory + slot grid is directly reusable** if you restyle
  colours (it's a frame + fill, fully recolourable).
- **Best use**: loadout/inventory grid prototype; body-part health readout
  (5 styles to choose from). The health bar frame + `_BarNN` stages map
  directly onto the design's torso/limb HP display.

### 9.6 `SpawnIconPack` — crosshairs + cursors + compasses

- **Path**: `/home/mjensen/Obrazy/Assets/SpawnIconPack`
- **157 files · 1.9 MB · png** — **all 512×512** (153 files; 2 tiny 1×1/2×2
  alpha placeholders)
- **Licence: none → license unknown — verify before shipping**
  (pack name suggests a spawning/asset-store origin).
- **Contents** (flat dir, no subdirs):

| Family | Count | Variants |
|---|---:|---|
| `Crosshair*` (incl. `Hollow*`, `Square*`, `Fat*`, `Bullseye`, `CircledDot`, half-moons, `Diagonal_Scanline_Square`) | **62** | `Crosshair1`–`28`; `18_Narrow`/`18_Wide`; `27_Horizontal`/`27_Vertical`; `28_Alpha`/`Alpha2`…`Alpha5`; `HollowCrosshair1`–`13` + `HollowCrosshairFill`; `SquareCrosshair`, `2`, `3`; `FatCrosshair`; `Bullseye`; `CircledDotCrosshair`; `CrosshairLowHalfMoon`, `UpHalfMoon`, `LowHalfMoon2` |
| `Bubble*` | 4 | `BubbleCrosshair1`, `Hollow`, `Solid`, `BubbleSun` |
| `Cursor1*`/`Cursor2*` | 22 | fill/outline/nick variants, top/bottom alpha |
| `Compass*` | 12 | `Compass`, `2`–`11`, `6_Closed/Open` |
| `CameraView1`–`8` | 8 | camera/surveillance-view frames |
| Shapes/UI | ~40 | `Circle`, `RingXTabs`, `RoundedSquare_10/45/90/150pxRadius`, `DoubleHollowSquare1-3`, `HollowDiamond`, `HollowSquare`, `Maximize`, `Minimize`, `Plus`, `Subtract`, `ThreeDotsVertical`, `CheckMark`, `Triangle45`, `ThickArrow`, `MidArrow`, `SmallArrow`, `Move*`, `WhitePixel(s)`, `AlphaPixel(s)` |

- **Use in Kangur**:
  - **`Crosshair18_Narrow` / `18_Wide` / `18`** — a 3-state dynamic-spread set
    → maps directly to design §4 "four brackets expanding with bloom".
    Recolour + split into 4 corners for true dynamic bloom, or swap whole images.
  - `Crosshair28_Alpha`–`Alpha5` — concentric-ring style, good for shotgun/SMG.
  - `Compass*` — **minimap compass rose** (design §5 minimap is fixed north-up).
  - `CameraView1–8` — diegetic **CCTV/security-camera** overlays.
  - `RoundedSquare_{10,45,90,150}pxRadius` — **ready-made 9-slice corner
    radii** at 512², perfect for HUD panel frames.
  - `AlphaPixel`/`WhitePixel` — usable as 1×1 9-slice fill textures.
- **Caution**: 512×512 for a 64×64 crosshair is wasteful; downscale on import.

### 9.7 `Crosshair Pack - Kenney` (CC0) ⭐ safest crosshairs

- **Path**: `/home/mjensen/Obrazy/Assets/Crosshair Pack - Kenney`
- **1,212 files · 5.2 MB · png + svg + tilesheet**
- **Licence: CC0** — "You may use these assets in personal and commercial
  projects. Credit would be nice but is not mandatory." **Safe to ship.**
- **Structure**: `PNG/{Black, Black Retina, Outline, Outline Retina, White,
  White Retina}/` — **200 crosshairs each** = 1,200 files, plus
  `PNG/crosshairs_tilesheet_{black,white}[@2].png` and `Vector/` SVGs
- **Dimensions** (`Size.txt`): normal **64×64**, retina **128×128**,
  outline **72×72**, outline retina **144×144**; tilesheet 20×10 tiles of 64²
  with 5 px margin.
- **Use**: **production-safe crosshair set** — 200 shapes, 2 colours, 2 DPRs,
  vector source for recolouring. **Prefer this over SpawnIconPack** for
  shipping (licence is certain). Combine: pick shape from Kenney, glow/scanline
  treatment from Wenrexa palette.

### 9.8 Icon sets for weapons / classes / objectives

| Pack | Count | Size | Style | Licence |
|---|---:|---|---|---|
| `1-bit_Pixel_Icons` | 2,971 (1,476 `Sprites/` + 1,476 `Sprites_Cropped/` + 19 sheets) | 16×16 / 12×12, 19 category sheets at **128×128** | **1-bit black/white**, huge vocabulary: `Icons_Warfare`, `Icons_RPG`, `Icons_Map_Markers`, `Icons_Software`, `Icons_Tools_Crafting`, `Icons_Weather`, `Icons_Arrows`, `Icons_Media`, `Icons_Travel`, `Icons_Alchemy`, `Icons_Boardgames`, `Icons_Controller`, `Icons_Cosmetics`, `Icons_Emoji`, `Icons_Food`, `Icons_Hats`, `Icons_Misc`, `Icons_Platforms`, `Icons_Sports` | **unknown** |
| `MonoPixel Icon Pack ver. 2` | 264 (131 png: 70 standard + 59 monochrome + 2 sheets; 128 `.aseprite`), **8×8** | 1.1 MB | monochrome UI glyphs (`icon_gear`, `icon_map`, `icon_locked`, `icon_medal`, `icon_save`, `icon_music`, `icon_fullscreen`…) + `Icon Sheet/` sheets & `.aseprite` sources | custom: **credit `o_lobster`**, no resale of icons alone |
| `16x16 Weapons RPG Icons` | 5 | 16×16 sprites in 384×320 sheets | 4 tiers `bronze/iron/steel/gold-weapons.png` + preview | **unknown** |
| `Free-Cyberpunk-Resource-Pixel-Art-32x32-Icons` | 45 | **32×32** (41 icons `Icon14_01`–`_41`) + PSD | cyberpunk neon icons | CraftPix — `License.txt` only a **URL** → **verify** |
| `rpgiab_icon_pack_v1.3` | 804 | **16×16** (400 icons) + 32×32 + sheets | colourful RPG application icons | **CC BY 4.0** — attribution required |
| `items` | 1,244 | **16×16** | generic item icons, numbered | **unknown** |
| `Board Game Icons - Kenney` | 774 | **64×64** / 128×128 + SVG | 255 icons: dice, pawns, flags, shields, timers, `direction_n/e/s/w`, `hourglass`, `lock_closed/open`, `target`-ish, `resource_*`, `structure_*` | **CC0** |
| `Free_pixel_food_16x16` | 102 | 16×16 | food/drink | **CC BY 4.0** |

- **Best for Kangur weapon/class icons**: `1-bit_Pixel_Icons` has the right
  vocabulary (`RPG_Item_Weapon_Pistol_Gun_Ranged.png`,
  `Warfare_Ammo_Bullet_Assault_Rifle.png`, `Warfare_Ammo_Bullet_Pistol.png`,
  `Map_Markers_Scanner_Sweep_Radar_Detection.png`,
  `RPG_Creature_Archetypes_Robot_Mechanical.png`) and is **1-bit → trivially
  recolourable to cyan/amber**. Licence is the only blocker.
- **Safest fallback**: `Board Game Icons - Kenney` (CC0) for objectives/timers/
  directions, plus hand-drawn weapon silhouettes.
- **`MonoPixel` 8×8** is ideal for **tiny HUD glyphs** (settings, map, lock,
  gear) if you accept the credit requirement.

### 9.9 Input prompts

- **Path**: `/home/mjensen/Obrazy/Assets/Input Prompts - Kenney` · **4,099 files · 19 MB**
- **Licence: CC0** (v1.4) — safe to ship.
- `Keyboard & Mouse/Default/` — 243 PNGs, **64×64**: `keyboard*`, per-key
  `keyboard_0`…, `mouse_*`, with `_outline` variants.
- Also `Generic/`, `Flairs/`, `Nintendo *`, `PlayStation Series`, `Xbox Series`,
  `Steam Deck/Controller`, `Touch/`, `Gamecube`, `Wii/WiiU`, `Switch`, `Playdate`
  — each with `Default`/`Double`/`Fonts`/`Vector`.
- **Use**: control hints in menus/tutorial — `WASD`, `RMB` focus, `B` bandage,
  `X` fire-mode, `G` grenade. Also has **prompt fonts** (`ttf`/`otf`, 14 each).

### 9.10 Fonts found

- `Free-Cyberpunk-Resource-Pixel-Art-32x32-Icons/Font.txt` → "Future Millennium"
  (dafont.com) — **not bundled**, link only.
- `Input Prompts - Kenney/*/Fonts/` — 14 ttf + 14 otf (Kenney's own, CC0).
- **No monospace/technical UI font in the library** — for the corporate
  holographic HUD you'll want a condensed technical sans (e.g. bundled font
  or an OFL face) — **gap**.

---

## 10. Music / ambience / voice summary table

| Pack | Tracks | Length | Mood | Licence |
|---|---:|---|---|---|
| `Sci-Fi Music Pack Vol. 2` | 6 (+6 loops) | 116–141 s | ambient space pads, slow arps | AlkaKrab — **open-source restricted** |
| `30 Sci-fi Space Tracks` | 30 (+30 loops) | 121–142 s | space ambient → tension, per-title | AlkaKrab — **open-source restricted** |
| `Nature Ambient Pack Vol 1` | 26 beds | long | rain, storm, forest, fire | unknown |
| `ambient machinery 1/2` | 26 | 0.2–3 s loops | engines, fans, motors, subway, heli | unknown |
| `yewbic-ambiences` | 8 | long | 6 exterior + 2 interior room tones | unknown (Freesound IDs) |
| `sci-fi-sfx` | 5 loops | short | machine/ambient loops | unknown |
| `Sci-Fi Ship Voices` | 50 lines | 1–3 s | calm ship-AI, M/F | **CC0** |
| `kenney_voiceoverFighter` | 46 lines | 1–2 s | arcade announcer | **CC0** |

---

## 11. Loose files at library root (not in a pack folder)

These 13 files sit directly in `/home/mjensen/Obrazy/Assets` and are easy to
miss. **All have no accompanying licence file** (the whole root has none) →
**license unknown — verify before shipping** for every item here.

| File | Size | Dimensions / length | Notes |
|---|---:|---|---|
| `tileset-red-factory.png` ⭐ | 14.7 KB | **256×142 RGBA**, 6 colours | **1-bit urban/industrial tileset** — palette `#412213` (dark brown), `#B2434D` (rust red), `#452C46` (plum), white. **The single most on-theme map tileset in the library**: factory/warehouse floors, walls, machinery. Recolour 3 indices → cyan/amber Kangur palette. |
| `Tilemap Dungeon original size.png` | 36.5 KB | **480×320 RGBA**, 24 colours | dungeon tilemap, small palette — usable for bunker/cellar |
| `items_sheet.png` | 108 KB | **576×560 P** | item icon sheet (36×35 grid of 16×16) |
| `desert.png` | 58.7 KB | **208×384 RGBA**, 64 colours | desert/sand tileset — arid map variant |
| `1bit-sci-fi-asset-pack-by-kmitrich.png` | 5.2 KB | **320×128 P**, 2 colours (pure 1-bit) | **sci-fi 1-bit tileset/props** — corridors, panels |
| `1bit_sciencefiction_pyairvander.png` | 5.2 KB | **320×192 P**, 2 colours | sci-fi 1-bit set (second author) |
| `1BitMoonAssetPack.png` | 7.6 KB | **320×128 RGBA**, 2 colours | 1-bit moon-base tiles/props |
| `Flash.jpg`, `FlashCone.jpg` | 34.9 / 499 KB | **1024×1024**, greyscale (`L`) | **flash/light cone masks** — perfect for Kangur's muzzle-flash light + flashbang LoS cone (design §6, §8). Multiply/overlay as light masks. |
| `monster_scream.ogg` | 232 KB | 12.2 s, 154 kbps | distant scream/howl — atmosphere |
| `equipmentclicks.wav` | 488 KB | 5.7 s, 705 kbps | **gear/equipment handling clicks** — great for loadout screen |
| `mdget.svg` | 16 KB | A4 vector (210×297 mm) | Inkscape document, appears to be a **Kangur logo draft** (`inkscape:export-filename="logo.png"`) — author's own WIP, not a third-party asset |
| `low-poly-astronaut/` | 2 files | fbx + png | `source/astronaut.fbx` + `textures/LOW_POLY_ASTRONAUGHT_lambert1_BaseColor.png` — a **3D astronaut** (2 files, 3.1 MB) — could serve a hazmat/EVA character reference |

**Recommendation**: `tileset-red-factory.png`, `Flash.jpg`, `FlashCone.jpg` and
the three 1-bit sci-fi sheets are immediately useful. `mdget.svg` looks like
*our own* logo source — verify authorship before treating it as third-party.

---

## 12. Recommended shortlist per category

Exact paths, ready to copy into `assets/` once licence is confirmed.

### Gunshots
| Need | Path |
|---|---|
| 9mm single (pistol/SMG) | `/home/mjensen/Obrazy/Assets/Snake's SECOND Authentic Gun Sounds/Isolated/9mm/WAV/9mm Single Isolated.wav` |
| 9mm burst (SMG) | `/home/mjensen/Obrazy/Assets/Snake's SECOND Authentic Gun Sounds/Isolated/9mm/WAV/9mm Burst Isolated.wav` |
| 7.62 / .308 single (AR/DMR/sniper) | `/home/mjensen/Obrazy/Assets/Snake's SECOND Authentic Gun Sounds/Isolated/.308 (7.62x51)/WAV/308 Single Isolated.wav` |
| .308 burst (LMG) | `/home/mjensen/Obrazy/Assets/Snake's SECOND Authentic Gun Sounds/Isolated/.308 (7.62x51)/WAV/308 Slow Burst Isolated.wav` |
| 20 gauge single (pump shotgun) | `/home/mjensen/Obrazy/Assets/Snake's SECOND Authentic Gun Sounds/Isolated/20 Gauge/WAV/20 Gauge Single Isolated.wav` |
| Revolver (Judge) | `/home/mjensen/Obrazy/Assets/Snake's SECOND Authentic Gun Sounds/Full Sounds/...` (no revolver shot — **use `44 Magnum` mechanical foley + `308 Single` pitched down**) |
| Clean pistol pair (fallback / layer) | `/home/mjensen/Obrazy/Assets/JDSherbert Free Weapon Sounds/Mono/wav (HD)/JDSherbert - Firearm FX - Weapon SFX Pack - Walther P38 - Fire - 1.wav` |
| CC-BY placeholder shots | `/home/mjensen/Obrazy/Assets/shots/{pistol,rifle,shotgun}.wav` |
| Muzzle light mask | `/home/mjensen/Obrazy/Assets/FlashCone.jpg` |

### Reloads / weapon foley
| Need | Path |
|---|---|
| Pistol reload (full) | `.../Snake's SECOND Authentic Gun Sounds/& More/Pistol/WAV/9mm Pistol Reload 1.wav` |
| Pistol slide lock/release | `.../& More/Pistol/WAV/9mm Pistol Slide Lock.wav`, `9mm Pistol Slide Release.wav` |
| Chamber check / rack | `.../& More/Pistol/WAV/9mm Pistol Rack Full.wav`, `9mm Pistol Chamber Check Full.wav` |
| Dry fire | `.../& More/Pistol/WAV/9mm Pistol Dry Fire.wav` |
| Mag in / mag out (per platform) | `.../& More/Mag Pack/WAV/{9mm,22LR,AR PolyMag,AK PolyMag,Bolt Mag} Magazine Pack/Unpack.wav` |
| Shotgun single-shell load | `.../& More/Mag Pack/WAV/Single Shotgun Load.wav` |
| Bolt-action cycle (Lynx) | `/home/mjensen/Obrazy/Assets/SFX/30-06_bolt.ogg` + `30-06_load.ogg` |
| Shotgun chamber | `/home/mjensen/Obrazy/Assets/SFX/12ga_load_chamber.ogg`, `12ga_dry.ogg` |
| Revolver cylinder | `.../& More/Revolver/44 Magnum/WAV/44 Magnum Open Cylinder.wav` (+ Open/Close/Cock/Decock) |
| Bipod deploy (Mule) | `.../& More/Bipod/WAV/Bipod Deploy Both Legs.wav` |
| Equip/unequip | `.../JDSherbert Free Weapon Sounds/Mono/wav (HD)/...Walther P38 - Equip - 1.wav` |
| Gear handling | `/home/mjensen/Obrazy/Assets/equipmentclicks.wav` |

### Footsteps
`/home/mjensen/Obrazy/Assets/footsteps/footsteps/{boots,tile,metal,gravel,wood,grass}/0.ogg` …
(9–10 per surface). **Attribution required (CC BY 3.0) except `gravel`/`bones` (CC0).**

### UI SFX
| Need | Path |
|---|---|
| Button click | `/home/mjensen/Obrazy/Assets/SCI-FI_UI_SFX_PACK/SCI-FI_UI_SFX_PACK/Clicks/Click_Mid.wav` |
| Hover | `.../Clicks/Click_Pitched_Up.wav` or `/home/mjensen/Obrazy/Assets/Clicks/rollover1.ogg` |
| Confirm / accept | `.../Click Combos/Click_Combo_3.wav` |
| Back / cancel | `.../Clicks/Click_Low.wav` |
| Notification ping | `.../Rings/Reverse_Ring_2_Mid.wav` |
| Objective update | `.../Rings/Ring_Pitched_Up.wav` |
| HUD hit feedback | `.../Impacts/Impact_2_Mid.wav` |
| Glitch / hack | `.../Glitches/Glitch_1.wav` … `Glitch_30.wav` |
| Terminal beep | `/home/mjensen/Obrazy/Assets/sci-fi-sfx/terminal_01.ogg` … `terminal_09.ogg` |
| CC0 safe clicks | `/home/mjensen/Obrazy/Assets/RPGsounds_Kenney/` (100 ogg) |
| Card/paper (debrief) | `/home/mjensen/Obrazy/Assets/kenney_casino-audio/Audio/` |

### Music
⚠️ Both good packs are **open-source-restricted (AlkaKrab)**. If cleared:
- Menu/title: `/home/mjensen/Obrazy/Assets/30 Sci-fi Space Tracks/Tracks/ogg/26. Lights of the Megacity.ogg`
- Infiltration: `.../24. Power Down Sequence.ogg`, `.../2. Entering the Void.ogg`
- Assault: `.../21. Breach of the Voidline.ogg`, `.../19. Breach the Horizon.ogg`
- Debrief: `.../27. After the Starfall.ogg`, `.../30. Stellar Rift.ogg`
- Loops for gameplay: `/home/mjensen/Obrazy/Assets/30 Sci-fi Space Tracks/Loops/ogg/<n>. <name> (Loop).ogg`
- Alternative (also AlkaKrab): `/home/mjensen/Obrazy/Assets/Sci-Fi Music Pack Vol. 2/Loops/ogg/1 - Astro Reverie (Loop).ogg`

### Ambience
- Interior room tone: `/home/mjensen/Obrazy/Assets/yewbic-ambiences/66057__yewbic__ambience07_Internal.wav`, `.../66058__yewbic__ambience08_Internal.wav`
- Metro map: `/home/mjensen/Obrazy/Assets/ambient machinery 2/subwayTrain_B-line.wav`
- Server room: `/home/mjensen/Obrazy/Assets/ambient machinery 2/fan_reso_1.wav`, `.../ambient machinery 1/ambient_machine1.wav`
- Garage/plant: `/home/mjensen/Obrazy/Assets/ambient machinery 1/Engine noise.wav`, `.../ambient machinery 2/motor_1.wav`
- Extraction: `/home/mjensen/Obrazy/Assets/ambient machinery 2/helicopter_2.wav`
- Rain on concrete: `/home/mjensen/Obrazy/Assets/Nature Ambient Pack Vol 1 - mp3/Weather/AMB_Nature Pack Vol 1_Weather_Light Rain.mp3`
- Rain + thunder: `.../Weather/AMB_Nature Pack Vol 1_Weather_Heavy Thunderstorm.mp3`
- Fire/wreck: `.../Fire & Elemental/AMB_Nature Pack Vol 1_ Fire & Elemental_Large Bonfire.mp3`

### HUD art
| Need | Path |
|---|---|
| Button (4-state) | `/home/mjensen/Obrazy/Assets/Free Hologram Interface Wenrexa/Button 1/Button {Normal,Hover,Active,Disable}.png` |
| Panels (small) | `.../Card X1/Panel Empty.png`, `Panel Empty Green.png`, `Panel Red.png` (113×65) |
| Cards (vertical) | `.../Card X1/Card X1.png` (405×847), `Card X2.png` (396×847) |
| Cards (wide) | `.../Card X2/Card X2.png`, `Card X3.png` (405×378) |
| Large panel/dialog | `.../Card X3/Card X5.png`, `Card X6.png` (695×377/399) |
| Cyan line icons (35) | `.../Icons/01.png` … `35.png` |
| Menu frames | `/home/mjensen/Obrazy/Assets/Game UI collection FREE version/PNG/Borders/{Blue,Green,Purple,White,Yellow}/Group 4 copy.png` |
| Dialogue panel | `.../PNG/Dialogue/1x/Asset 3.png` (2783×1114) |
| Progress/health bars | `.../PNG/Bars/{Blue,Green,Purple,White,Yellow}/` |
| CTA buttons | `.../PNG/Button with border/<colour>/1x/Asset 7.png` (1070×338) |
| Portraits 96×96 | `/home/mjensen/Obrazy/Assets/Hexany's 1-bit UI Panels/Panels/Transparent/{simple,star_fleet,assembly,…}.png` |
| Inventory grid 9-slice | `/home/mjensen/Obrazy/Assets/Retro Inventory/Original/Inventory_9Slices.png` |
| Slots | `.../Retro Inventory/Original/Inventory_Slot_1.png` … `_10.png` |
| Health bar frames | `.../Retro Inventory/Original/Health_01.png` (64×16) + `Health_01_Bar01–03.png` |
| Body-part readout | `.../Retro Inventory/Original/Health_04_Heart_Red.png` + `_Clear` variants |
| 9-slice corner radii | `/home/mjensen/Obrazy/Assets/SpawnIconPack/RoundedSquare_{10,45,90,150}pxRadius.png` |
| CCTV overlay | `/home/mjensen/Obrazy/Assets/SpawnIconPack/CameraView1.png` … `8.png` |
| Terminal frame (1-bit) | `/home/mjensen/Obrazy/Assets/Hexany's 1-bit UI Panels/Panels/Transparent/simple.png` |
| Flashbang cone | `/home/mjensen/Obrazy/Assets/FlashCone.jpg` |

### Crosshairs
| Need | Path |
|---|---|
| Safe production set (200 shapes ×2 colour) | `/home/mjensen/Obrazy/Assets/Crosshair Pack - Kenney/PNG/White/crosshair001.png` … `crosshair200.png` |
| Vector source | `/home/mjensen/Obrazy/Assets/Crosshair Pack - Kenney/Vector/` |
| Dynamic-spread 3-state | `/home/mjensen/Obrazy/Assets/SpawnIconPack/Crosshair18.png` (+ `_Narrow`, `_Wide`) |
| Concentric ring (Alpha) | `.../SpawnIconPack/Crosshair28_Alpha.png` … `Alpha5.png` |
| Hollow bracket style | `.../SpawnIconPack/HollowCrosshair1.png` … `13.png` |
| Compass rose (minimap) | `.../SpawnIconPack/Compass.png` … `Compass11.png` |

### Icons
| Need | Path |
|---|---|
| Weapons / ammo / classes (1-bit) | `/home/mjensen/Obrazy/Assets/1-bit_Pixel_Icons/Sprites/` — 22 `RPG_Item_Weapon_*.png`, 6 `Warfare_Ammo_Bullet_*.png` (`Assault_Rifle`, `Pistol`, `Shotgun_Shells`, `Sniper_Rifle`, `Revolver_Six_Shooter_Bullets_Barrel`, `Rocket_Missile_RPG`) |
| Category sheets | `/home/mjensen/Obrazy/Assets/1-bit_Pixel_Icons/Icons_{Warfare,RPG,Map_Markers,Software,Tools_Crafting}.png` (128×128) |
| Objectives / timers / directions (CC0) | `/home/mjensen/Obrazy/Assets/Board Game Icons - Kenney/PNG/Default (64px)/{timer_*,flag_*,direction_*,lock_*,hourglass*}.png` |
| Colourful RPG icons (CC BY 4.0) | `/home/mjensen/Obrazy/Assets/rpgiab_icon_pack_v1.3/16x16/` |
| Tiny 8×8 HUD glyphs | `/home/mjensen/Obrazy/Assets/MonoPixel Icon Pack ver. 2/Icons/Standard Version/icon_*.png` |
| Weapon tier sheets | `/home/mjensen/Obrazy/Assets/16x16 Weapons RPG Icons/{bronze,iron,steel,gold}-weapons.png` |
| Cyberpunk 32×32 | `/home/mjensen/Obrazy/Assets/Free-Cyberpunk-Resource-Pixel-Art-32x32-Icons/1 Icons/Icon14_01.png` … `_41.png` |
| Input prompts | `/home/mjensen/Obrazy/Assets/Input Prompts - Kenney/Keyboard & Mouse/Default/` |

### Character sprites
| Need | Path |
|---|---|
| Prototype 6-dir body (idle/walk/dash/death) | `/home/mjensen/Obrazy/Assets/The Male adventurer - Free/Idle/idle_down.png`, `Walk/walk_down.png`, `Dash/Dash.png`, `Death/death_normal.png` |
| Prototype 4-dir body + anims | `/home/mjensen/Obrazy/Assets/Top_Down_Adventure_Pack_v.1.0/Char_Sprites/char_{idle,run,attack,death,hit}_*` |
| Reference proportions / 3D bake source | `/home/mjensen/Obrazy/Assets/LPCh_Sol_01/Char_Man_02v1.fbx` (1.88 m, 64-bone Rigify) |
| Hazmat/EVA reference | `/home/mjensen/Obrazy/Assets/low-poly-astronaut/source/astronaut.fbx` |

### Map tiles / textures
| Need | Path |
|---|---|
| **Urban/industrial 1-bit tileset** | `/home/mjensen/Obrazy/Assets/tileset-red-factory.png` (256×142) |
| Sci-fi 1-bit sets | `.../1bit-sci-fi-asset-pack-by-kmitrich.png` (320×128), `.../1bit_sciencefiction_pyairvander.png` (320×192), `.../1BitMoonAssetPack.png` (320×128) |
| Dungeon/cellar | `.../Tilemap Dungeon original size.png` (480×320), `/home/mjensen/Obrazy/Assets/Dungeon tileset/Dungeon tileset.png` (384×192) |
| Concrete / stone / brick ground | `/home/mjensen/Obrazy/Assets/FOXTEX COMPLETE/Textures/VOL1/{Concrete,Stone,Bricks}/` (512², 256²) |
| Tech wall panels | `/home/mjensen/Obrazy/Assets/FOXTEX COMPLETE/Textures/MISC/MCFG1.png` (+ `_1`…`_5` variants) |
| PBR metal panels 4K | `/home/mjensen/Obrazy/Assets/MetallicPanelsAndGrids_01/JPEG/{MetalTiles_01,BronzeGrid_01..04,BronzeWall_01,GoldFlowerPattern_01}/*_basecolor.jpg` |
| Modular facility (3D→bake) | `/home/mjensen/Obrazy/Assets/Modular SciFi MegaKit[Standard]/FBX/` (CC0) |
| Props for icon bake | `/home/mjensen/Obrazy/Assets/Sci-Fi Essentials Kit/FBX/Prop_*.fbx` (CC0) |
| Floor decals (arrows/lines/zones) | `/home/mjensen/Obrazy/Assets/Modular SciFi MegaKit[Standard]/FBX/Decals/Decal_Line_*.fbx` |
| Sand/desert variant | `/home/mjensen/Obrazy/Assets/desert.png` (208×384) |
| Fire/explosion strip | `/home/mjensen/Obrazy/Assets/DG Fire Zone Expansion Free Ver/All Tiles Free Ver..png` (192×128) |

---

## 13. Gaps — what's missing for a topdown tactical shooter

### Blocking gaps (must create)

1. **Layered topdown soldier sprites (the #1 gap).**
   Design §1 requires "legs/torso, head, arms+weapon" with free rotation toward
   aim. **No pack provides this.** Library has only 4-dir/6-dir fantasy
   adventurers with baked-in arms. → **Draw from scratch** (recommended) at
   32 px/m: ~24 px silhouette, 8-dir torso/head/legs + rotating arm+weapon
   layer. Needed per faction (BASTION slate/amber, SIROCCO orange/gunmetal)
   × 5 classes × stance variants (stand/crouch/sprint) × wound states.
   This is the single largest art task in the project.

2. **Human squad radio chatter.**
   Only `Sci-Fi Ship Voices` (CC0, calm ship AI) and `kenney_voiceoverFighter`
   (arcade announcer). **No "Contact!", "Reloading!", "Moving up", "Man down",
   "Grenade out"** lines. Either record, commission, or use TTS with heavy
   radio processing. Design §1 demands dry corporate radio — none exists here.

3. **Combat music.**
   Both music packs are ambient space; **nothing with tension, percussion, or
   industrial drive** for firefights. Plus the AlkaKrab open-source restriction
   means even the ambient tracks need permission.

4. **Body-part damage diagram / HUD anatomy.**
   Design §7 requires head/torso/arms/legs HP visualisation. `Retro Inventory`
   has generic hearts/bars but **no anatomical body diagram**. Must draw.

5. **Minimap frame + objective markers.**
   No dedicated circular/radar minimap frame anywhere (`SpawnIconPack` has
   compass roses; `Game UI` has generic borders). Objective icons exist in
   `1-bit_Pixel_Icons/Icons_Map_Markers.png` and `Board Game Icons` flags but
   the frame must be composed.

6. **5.56 / intermediate-caliber gunshots.**
   Snake's has only 9mm, .308, 20ga. **No 5.56 (Kestrel), no .357 (Judge),
   no suppressed variants.** Pitch-shifting .308/9mm is the stopgap.

### Serious gaps (should create/license)

7. **Weapon sprites in topdown view** — every gun (12 weapons × held + icon +
   world pickup). No pack has topdown-held weapon art.
8. **Muzzle flash sprites** — no flash sprite sheets (only `Flash.jpg` light
   masks). Need 2–3 frame directional flashes.
9. **Tracer + impact FX** — no tracer/ricochet/spark sprites; `hits/` gives
   audio only.
10. **Blood decals / corpses** — `extreme_splatter` is audio. No decal art.
11. **Brass casing / shell ejection sprites.**
12. **Vehicles** (extraction van, APC, helicopter) — none in library.
13. **Doors/windows/breach props in 2D topdown** — `Modular SciFi MegaKit` has
    3D doors only.
14. **Technical/condensed UI font** for the holographic HUD (only Kenney's
    prompt fonts and a link to a dafont face).
15. **Player/NPC portraits** (96×96) — `Hexany` gives 12 *frames*, no faces.
16. **Objective/contract briefing art** (corporate dossiers, floor plans).
17. **Footstep variants per stance** — only single-speed sets; needs pitch/
    volume variation in code.
18. **Weapon-specific reload timings/lengths** — Snake's reloads are for
    9mm pistol / AR mag / revolver only; shotgun and LMG need assembly from parts.

### Gaps that are actually fine
- Ground textures: `FOXTEX` + `MetallicPanels` + `tileset-red-factory` cover
  concrete/stone/brick/metal well.
- UI panels/buttons: `Wenrexa` + `Game UI collection` + `Pixel UI 3` cover it.
- Icons: `1-bit_Pixel_Icons` + `Board Game Icons` + `rpgiab` cover it.
- Ambience: `ambient machinery 1/2` + `yewbic` + `Nature Ambient` cover it.
- Crosshairs: Kenney's 200 is more than enough.

---

## 14. Licence risk table

**Legend**: ✅ safe to ship · ⚠️ safe *with conditions* (attribution /
written permission) · ❌ not usable · ❓ unknown (must verify)

| Pack | Licence | Commercial | Open-source (EUPL) OK? | Ship? | Attribution file? |
|---|---|---|---|---|---|
| `Animation Library[Standard]` | CC0 1.0 | ✅ | ✅ | ✅ **safe** | not required |
| `Universal Animation Library[Standard]` | CC0 1.0 | ✅ | ✅ | ✅ **safe** | not required |
| `Modular SciFi MegaKit[Standard]` | CC0 1.0 | ✅ | ✅ | ✅ **safe** | not required (courtesy: Quaternius) |
| `Sci-Fi Essentials Kit` | CC0 1.0 | ✅ | ✅ | ✅ **safe** | not required (courtesy: Quaternius) |
| `Ultimate Modular Sci-Fi - Feb 2021` | CC0 1.0 | ✅ | ✅ | ✅ **safe** | not required |
| `Free 3D Modular Game Assets For Prototyping` | CC0 1.0 | ✅ | ✅ | ✅ **safe** | not required |
| `Board Game Icons - Kenney` | CC0 | ✅ | ✅ | ✅ **safe** | not required |
| `Crosshair Pack - Kenney` | CC0 | ✅ | ✅ | ✅ **safe** | not required |
| `Input Prompts - Kenney` | CC0 | ✅ | ✅ | ✅ **safe** | not required |
| `RPGsounds_Kenney` | CC0 | ✅ | ✅ | ✅ **safe** | not required |
| `kenney_casino-audio` | CC0 | ✅ | ✅ | ✅ **safe** | not required |
| `kenney_voiceoverFighter` | CC0 | ✅ | ✅ | ✅ **safe** | not required |
| `Hexany's 1-bit UI Panels` | CC0 | ✅ | ✅ | ✅ **safe** | not required |
| `Sci-Fi Ship Voices` | CC0 | ✅ | ✅ | ✅ **safe** | not required (courtesy: Lentikula) |
| `multi stylized grass` | CC0 (Nobiax) | ✅ | ✅ | ✅ **safe** | not required |
| `Qoupy's_ROGNs_Free` | **Non-commercial only** | ❌ | ❌ | ❌ **do not use** | n/a |
| `30 Sci-fi Space Tracks` | AlkaKrab custom | ✅ | ❌ **needs written permission for open-source** | ❌ **not until cleared** | yes, plus permission email |
| `Sci-Fi Music Pack Vol. 2` | AlkaKrab custom | ✅ | ❌ **needs written permission** | ❌ **not until cleared** | yes, plus permission email |
| `DG Fire Zone Expansion Free Ver` | Custom free | ⚠️ yes, but **edits only for non-commercial** | ❌ if edited | ⚠️ **unmodified only, or verify** | optional (SnowHex) |
| `Retro Inventory` | Custom (ElvGames) | ✅ | ✅ (but "no resale") | ⚠️ **safe with credit** | **required** (ElvGames) |
| `MonoPixel Icon Pack ver. 2` | Custom (o_lobster) | ✅ | ✅ | ⚠️ **safe with credit** | **required** (o_lobster) |
| `Top_Down_Adventure_Pack_v.1.0` | None (credit o_lobster) | ❓ | ❓ | ⚠️ **verify** | yes if used |
| `rpgiab_icon_pack_v1.3` | **CC BY 4.0** | ✅ | ✅ | ⚠️ **safe with attribution** | **required** (Justin Arnold) |
| `Free_pixel_food_16x16` | **CC BY 4.0** | ✅ | ✅ | ⚠️ safe with attribution | **required** |
| `shots` | **CC BY 3.0** | ✅ | ✅ | ⚠️ safe with attribution | **required** (Michel Baradari) |
| `robotic` | **CC BY 3.0** | ✅ | ✅ | ⚠️ safe with attribution | **required** (Lee Barkovich) |
| `footsteps` (boots, tile, wood, grass, metal, water, dog, mech) | **CC BY 3.0** | ✅ | ✅ | ⚠️ **safe with attribution** | **required** (8 authors, see §2.1) |
| `footsteps` (gravel, bones) | CC0 | ✅ | ✅ | ✅ **safe** | not required |
| `Free-Cyberpunk-Resource-Pixel-Art-32x32-Icons` | CraftPix freebie (per their file-licenses page: use in unlimited commercial projects, no source-file redistribution, **no AI training**) | ✅ | ✅ | ⚠️ **safe** (don't ship PSD; note no-AI clause) | not required |
| `Free Hologram Interface Wenrexa` | ❓ none in pack | ❓ | ❓ | ❓ **verify** | likely required |
| `Game UI collection FREE version` | ❓ marketing txt only | ❓ | ❓ | ❓ **verify** | likely required |
| `Snake's SECOND Authentic Gun Sounds` | ❓ readme is promo only | ❓ | ❓ | ❓ **verify** (itch.io page) | likely required |
| `JDSherbert Free Weapon Sounds` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `SCI-FI_UI_SFX_PACK` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `SFX` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `Clicks` | ❓ none (Unity `.meta` GUIDs) | ❓ | ❓ | ❓ **verify + provenance risk** | likely required |
| `SpawnIconPack` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `Pixel UI pack 3` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `1-bit_Pixel_Icons` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `16x16 Weapons RPG Icons` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `2-Bit Pack` | ❓ none | ❓ | ❓ | ❓ **verify** (palettes — likely fine) | likely required |
| `Dungeon tileset` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `FOXTEX COMPLETE` | ❓ GZDoom readme only | ❓ | ❓ | ❓ **verify — high provenance risk** (Doom compilation) | required |
| `MetallicPanelsAndGrids_01` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `Nature Ambient Pack Vol 1` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `ambient machinery 1` / `2` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `yewbic-ambiences` | ❓ Freesound IDs in names | ❓ | ❓ | ❓ **verify the 8 IDs** | likely required |
| `sci-fi-sfx` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `hits` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `extreme_splatter` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `Super Foley Pack` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `inventory_sound_effects` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `metal_interactions` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `door_close_-_starninjas` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `medieval_sfx_textures_1_of_2` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `items` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `Feather` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `grass` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `Ombremonde_Pack_Landscape_Illustrations` | ❓ none | ❓ | ❓ | ❓ **verify** (not needed anyway) | likely required |
| `Playing Cards` | ❓ none (looks like the public-domain SVG-cards set) | ❓ | ❓ | ❓ **verify** | likely required |
| `LPCh_Sol_01` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `Low Poly Furniture` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `Lowpoly_Furniture` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `FBX_Pistol_Starter` | ❓ none (MocapOnline) | ❓ | ❓ | ❓ **verify — mocap licensing is strict** | required |
| `TopDownFantasy-Forest` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| `low-poly-astronaut` | ❓ none | ❓ | ❓ | ❓ **verify** | likely required |
| Loose root files (13) | ❓ none | ❓ | ❓ | ❓ **verify** except `mdget.svg` (likely ours) | likely required |

### Summary counts
Counting the 67 pack directories + 12 loose root files (79 entries):

| Class | Count | Notes |
|---|---:|---|
| ✅ **Safe, no conditions** (CC0) | **15 packs** | verified by grep for "CC0"/"public domain dedication": `Animation Library`, `Board Game Icons`, `Crosshair Pack`, `Free 3D Modular…`, `Hexany's 1-bit UI Panels`, `Input Prompts`, `kenney_casino-audio`, `kenney_voiceoverFighter`, `Modular SciFi MegaKit`, `multi stylized grass`, `RPGsounds_Kenney`, `Sci-Fi Essentials Kit`, `Sci-Fi Ship Voices`, `Ultimate Modular Sci-Fi`, `Universal Animation Library` |
| ⚠️ **Safe with attribution** | **5 packs** + 2 partial | `rpgiab_icon_pack_v1.3` (CC BY 4.0), `Free_pixel_food_16x16` (CC BY 4.0), `shots` (CC BY 3.0), `robotic` (CC BY 3.0), `Retro Inventory` (ElvGames credit) · partial: `MonoPixel` (o_lobster credit), `footsteps` (**8 of 10 surfaces** CC BY 3.0, 2 CC0) |
| ❌ **Do not use / blocked** | **3 packs** | `Qoupy's_ROGNs_Free` (non-commercial only); `30 Sci-fi Space Tracks` + `Sci-Fi Music Pack Vol. 2` (AlkaKrab, open-source needs written permission) |
| ⚠️ **Restricted** | **1 pack** | `DG Fire Zone Expansion Free Ver` — commercial use OK but *editing* only for non-commercial projects |
| ❓ **Unknown — verify** | **~55 entries** | Exact measurement: **33 packs contain no text/PDF document of any kind** (`1-bit_Pixel_Icons`, `16x16 Weapons RPG Icons`, `2-Bit Pack`, `Clicks`, `Dungeon tileset`, `JDSherbert Free Weapon Sounds`, `LPCh_Sol_01`, `Low Poly Furniture`, `Lowpoly_Furniture`, `MetallicPanelsAndGrids_01`, `Ombremonde…`, `Pixel UI pack 3`, `Playing Cards`, `SCI-FI_UI_SFX_PACK`, `SFX`, `SpawnIconPack`, `Super Foley Pack`, `The Male adventurer`, `TopDownFantasy-Forest`, `ambient machinery 1/2`, `door_close_-_starninjas`, `extreme_splatter`, `feather`, `grass`, `hits`, `inventory_sound_effects`, `items`, `low-poly-astronaut`, `medieval_sfx_textures_1_of_2`, `metal_interactions`, `sci-fi-sfx`, `yewbic-ambiences`). A further ~12 have a readme that grants nothing (promo/instructions only). Plus 11 third-party loose root files. ← the real risk |

The ❓ bucket is large because this library was assembled by downloading, not
by tracking licences. **Assume nothing ships until verified.**

### Action items before copying anything into `assets/`
1. **Music**: email `alkakrab04@gmail.com` for open-source permission, or drop
   both AlkaKrab packs and find CC0/CC-BY combat music.
2. **Verify the ❓ packs you actually want** — priority order:
   `Snake's SECOND Authentic Gun Sounds`, `Free Hologram Interface Wenrexa`,
   `SCI-FI_UI_SFX_PACK`, `JDSherbert Free Weapon Sounds`, `Game UI collection`,
   `SpawnIconPack`, `1-bit_Pixel_Icons`, `MetallicPanelsAndGrids_01`,
   `FOXTEX COMPLETE`, `SFX`, `Clicks`, `Pixel UI pack 3`, `items`.
   Each is an itch.io / asset-store page → screenshot the licence into
   `docs/research/licenses/<pack>.md`.
3. **Create `docs/credits.md`** immediately with the ⚠️ attributions already
   known (Kenney optional; ElvGames, o_lobster, Justin Arnold, Michel Baradari,
   Lee Barkovich, the 8 Freesound footstep authors, CraftPix optional,
   Lentikula/Quaternius optional).
4. **Never ship source files** (PSD/AI/EPS/SVG/`.aseprite`/`.blend`) for
   CraftPix or `Retro Inventory` — licence forbids redistributing source.
5. **FOXTEX**: treat as high risk. Its textures are a Doom-community
   compilation; individual authorship is untraceable. Use only if you can
   identify each texture's origin, or replace with CC0 textures.
6. **`Clicks`**: Unity `.meta` GUIDs indicate ripped project content.
   Replace with `SCI-FI_UI_SFX_PACK` (once verified) or `RPGsounds_Kenney` (CC0).
7. **`Qoupy's_ROGNs_Free`**: non-commercial only → leave out entirely.

---

## 15. Quick reference: project fit scorecard

| Category | Coverage from library | Verdict |
|---|---|---|
| Gunshots | 9mm/.308/20ga only, no 5.56/.357/suppressed | **60%** — pitch-shift + layer |
| Reload foley | Excellent (pistol/AR/revolver/shotgun/bipod) | **90%** |
| Footsteps | 10 surfaces, single-speed | **75%** |
| UI SFX | SCI-FI_UI_SFX_PACK is ideal but unverified | **85%** (licence aside) |
| Music | Ambient space only; open-source restricted | **25%** |
| Ambience | Strong industrial/urban/weather | **85%** |
| HUD art | Wenrexa matches aesthetic; no minimap frame, no body diagram, no bars | **60%** |
| Crosshairs | 200 CC0 + dynamic-spread variants | **95%** |
| Icons | Huge 1-bit vocabulary; licence unverified | **85%** |
| Character sprites | **No layered topdown soldier** | **10%** (must draw) |
| Map tiles/textures | `tileset-red-factory` + FOXTEX + MetallicPanels | **80%** |
| Voice | Ship AI only, no squad chatter | **30%** |
| Fonts | Kenney prompt fonts only | **20%** |
