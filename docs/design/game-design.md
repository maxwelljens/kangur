# Kangur — Game Design Bible

Working title **Kangur**. Singleplayer topdown 2D tactical shooter in Godot 4.7.
Aesthetic reference: CS2D. Depth reference: Door Kickers 2 / Running with Rifles /
Escape from Tarkov's firearm handling. Lethality reference: Hotline Miami.
Setting: near-future Europe (2041), corporate proxy warfare.

This document is the design authority. Implementation lives in `docs/architecture.md`.
Numbers here are starting values; balance is tuned via simulation tests
(`tests/simulation/`) and all live values are data-driven (`res://data/`).

---

## 1. Fantasy & Setting

Two private military corporations fight a shadow war across European
infrastructure — ports, rail terminals, data centers, old-town administrative
quarters — on behalf of rival conglomerates. No nations, no flags: contracts,
liability waivers, and kill bonuses. The tone is dry, professional, slightly
cynical. Radio chatter is corporate ("Contact, grid C-4. Logging engagement."),
never cartoonish.

**Factions** (playable both sides):

| | BASTION | SIROCCO |
|---|---|---|
| Full name | Bastion Security Group | Sirocco Extraction Corps |
| Business | Defensive infrastructure contracts | Offensive extraction & sabotage |
| Palette | Slate blue `#3E5C76` + amber `#F2A541` | Burnt orange `#C4552D` + gunmetal `#4A4E54` |
| Doctrine (AI flavor) | Holds angles, anchors sites, methodical | Flanks, pushes, aggressive rotations |
| Callsign pool | European mix: Vuk, Marta, Dries, Sanne, Jens, Klara, Piotr, Anouk… | Luca, Elena, Rui, Tomas, Ines, Bram, Nadia, Milo… |

"Kangur" is the operation callsign for the campaign — a kangaroo: a herbivore
that boxes. NPCs have persistent callsigns per match, shown in killfeed and
scoreboard. The player is "You" / chosen callsign.

**Visual identity**: near-future holographic HUD (thin cyan/amber lines, subtle
scanlines, bracket corners), grounded industrial maps (concrete, sand, metal
grating, glass), topdown soldiers rendered as layered sprites (legs/torso, head,
arms+weapon) with free rotation toward aim. Muzzle flashes, tracers, brass
casings, blood decals, bullet chips on walls. Night/dusk lighting on some maps
with canvas lights (muzzle flash lights, flares). Not pixel-cute: crisp,
readable, slightly gritty.

## 2. Core Loop

Title → Lobby (mode, map, faction, class, bot count/skill) → Match → Debrief
(stats, timeline, rematch). One match = one life in Elimination; respawns with
tickets in Battle. Matches run 5–12 minutes. Every match must feel different:
NPC personalities, routes, and lingering are re-rolled per match from a seed.

### Moment-to-moment
- Cursor aims; camera leans toward cursor (see §4) so you can see far.
- Vision is a cone blocked by walls. You cannot see behind you. Checking your
  six is a real action.
- Guns are lethal (low TTK) but inaccurate while moving; stopping, focusing
  (RMB), and firing semi/burst is rewarded.
- Hits damage body parts. Legs slow you, arms ruin your aim, bleeding kills you
  slowly if you don't bandage. Fights leave consequences.
- Sound travels and is occluded by walls. You hear fights next door, muffled.
  NPCs hear you too.

## 3. Scale & Movement

- **Scale**: 32 px = 1 m. Tiles 32×32. Character collision radius 10 px.
- **Stances**: STAND (default), CROUCH (toggle, quieter, smaller cone range,
  better accuracy), SPRINT (hold, stamina).
- **Speeds** (px/s): walk 130, sprint 215, crouch 65. Focus (RMB) ×0.5.
  Crippled leg ×0.55 and no sprint. Class multipliers 0.92–1.08.
- **Feel**: Source-engine-style acceleration + friction, not instant velocity.
  Ground accel 1400 px/s², friction coefficient 10/s (exponential decay),
  air control N/A (no jumping). Direction changes carry momentum; counter-
  strafing (tapping opposite direction) stops you fast — a skill expression.
- **Stamina**: 100. Sprint drains 18/s, regen 12/s after 1 s rest. Exhausted at
  0 → forced walk until 30. Sprint widens spread massively and narrows vision
  cone (tunnel vision).
- **Focus (RMB)**: brace weapon — spread ×0.55, recoil ×0.7, move ×0.5, vision
  cone narrows to 70° but range +15%. The tactical "stop and aim" verb.

## 4. Camera & Crosshair

- Camera target = player + clamp((cursor − player) × 0.35, 220 px). Smooth
  lerp 8/s. Zoom default 1.6 (settings 1.0–2.5).
- Crosshair = cursor, dynamic: four brackets expanding with current weapon
  bloom (live accuracy feedback), contract when focused/stationary.
- Recoil kicks crosshair + camera slightly; hits/explosions shake screen
  (toggle in settings).
- Cursor is captured to window in match; released in menus.

## 5. Vision & Fog

- Player cone: 100° forward, range 520 px standing / 420 crouch, plus 70 px
  360° peripheral awareness. Walls fully block. Glass blocks sound partially,
  vision not at all. Smoke blocks vision (both sides).
- **On-screen rendering**: enemies render only while inside your cone with LOS
  (or peripheral radius). Once spotted, a fading "ghost" marker remains at
  last-seen position for 3 s (your own memory, not omniscience). Corpses and
  blood remain visible once discovered.
- **Team sharing**: any teammate's cone sighting is radioed in (0.4–1.5 s delay,
  position noise). Shared contacts appear on the **minimap** only, fading over
  6–12 s. You never see enemies on-screen through teammates' eyes.
- **Minimap**: map outline, objectives + status, teammates (live), shared enemy
  contacts (fading), your cone, danger hints (skull marks where teammates died
  recently, if your team witnessed it). Rotates? No — fixed north-up, player
  arrow rotates.
- **LOW_COVER** (crates, cars, sandbags): blocks movement + bullets (wood
  penetrable), NOT sound. Vision: crouched characters behind it are hidden
  from everyone; crouched observers can't see over it; standing observers see
  over. Stance tactics — crouch to vanish, stand to shoot over. NPCs reason
  about stance-dependent cover quality.
- **GLASS**: blocks movement, partial sound (1-wall), NOT vision; penetrable
  ×0.8, shatters after 2 hits (opens sightline + sound spike).
- NPCs use the exact same cone/LOS/hearing rules. No wallhacks, ever.
  Enforcement is tested (see architecture §Testing).

## 6. Firearms & Ballistics

**Model**: real projectiles, not hitscan, not slow arcade pellets. Bullet
speeds 4000–9000 px/s (deliberately ~3× compressed from real m/s for
readability at 32 px/m; tunable per weapon). Swept raycast per physics tick;
visible tracer line; travel time matters at long range; you can break LOS
after seeing a muzzle flash and live.

**Spread** (degrees, half-angle):
`spread = (base + bloom) × move_mult(speed) × stance_mult × focus_mult × arm_mult`
- `move_mult`: 1.0 at rest → ~3.5 at sprint (curve: 1 + 2.5·(v/vmax)^1.5).
- `bloom`: += per-shot bloom, decays exponentially (recovery rate per weapon).
  First shot from rest is near-pinpoint; sustained auto fire climbs hard.
- Stance: crouch ×0.75. Focus ×0.55. Crippled arm ×1.6.

**Recoil**: per-shot camera/crosshair kick + aim-direction push (vertical-ish
in topdown = along aim axis + random lateral). Recovery pulls back toward
pre-fire aim over ~0.4 s. Heavy weapons (LMG, 7.62) kick noticeably; the
crosshair physically walks during sprays.

**Fire modes**: AUTO / BURST (2–3 round, enforced pause) / SEMI / BOLT / PUMP.
Switchable (X) where the weapon supports it. Semi-auto rewards click discipline
(RPM cap = weapon cycle rate, no macro benefit).

**Damage & penetration**: base damage per weapon; body-part multipliers
(head ×3.5, torso ×1.0, arms ×0.75, legs ×0.8). Falloff linear from
`falloff_start` to `falloff_end` px down to `min_mult`. Penetration: bullets
can pass thin walls/wood/glass with damage ×0.55 and deflection up to 4°;
concrete/stone stops everything except sniper (×0.35 through thin concrete).
Armor (class): vest absorbs 40% torso damage, helmet 50% head, each with
durability that degrades per hit.

**Draft weapon roster** (fictional names; stats grounded in research doc
`docs/research/genre-mechanics.md`, finalized in `res://data/weapons/`):

| id | Name | Cat | Modes | RPM | Mag | Dmg | Bullet px/s | Notes |
|---|---|---|---|---|---|---|---|---|
| adder | P-9 "Adder" | pistol | SEMI | 420 | 17 | 24 | 4600 | universal sidearm |
| judge | R-357 "Judge" | pistol | SEMI | 150 | 6 | 55 | 5200 | breacher sidearm, big kick |
| vespa | SMG "Vespa" | smg | AUTO/SEMI | 800 | 32 | 20 | 4400 | recon, low bloom |
| kedr | SMG "Kedr" | smg | AUTO | 1000 | 20 | 18 | 4200 | shreds up close, sprays wide |
| kestrel | AR "Kestrel" | ar | AUTO/BURST/SEMI | 650 | 30 | 30 | 6200 | assault, 5.56, balanced |
| volk | AR "Volk" | ar | AUTO/SEMI | 600 | 30 | 34 | 6000 | 7.62, heavier recoil |
| falx | BR "Falx" | br | SEMI/BURST | 300 | 20 | 46 | 7000 | 2-tap torso, marksman-ish |
| sokol | DMR "Sokol" | dmr | SEMI | 260 | 15 | 55 | 7600 | high pen, focus bonus |
| lynx | SR "Lynx" | sniper | BOLT | 45 | 5 | 110 | 9000 | torso one-shot, huge audio signature |
| mule | LMG "Mule" | lmg | AUTO | 700 | 100 | 28 | 6000 | support, suppression, heavy bloom |
| breve | SG "Breve" | shotgun | PUMP | 70 | 6 | 12×8 | 4000 | pump, tight choke when focused |
| automa | SG "Automa" | shotgun | SEMI | 240 | 8 | 10×6 | 3900 | faster, wider |

Equipment: **frag** (fuse 2.2 s, bounce physics, lethal radius 90 px, part-aware
damage), **flash** (LOS-gated blind 1.5–3 s + ringing, NPCs affected too),
**smoke** (vision-blocking cloud 12 s, AI respects it). Throw arc = topdown
lob with shadow, G to throw, cookable frag (hold).

**TTK targets** (stationary, unarmored torso): rifle 3 hits ≈ 0.28–0.4 s,
pistol 4–5 ≈ 0.6 s, sniper 1, shotgun ≤1 at close. High lethality is the point;
positioning beats reflexes.

## 7. Health, Wounds, Bandaging

Body parts with separate HP: **head 30, torso 70, arm L/R 18 each,
leg L/R 22 each**. Death: head ≤ 0, torso ≤ 0, or bleed-out (total blood loss).

- **Bleeding**: limb wound below 50% part HP → bleed 1.5 HP/s (from torso pool);
  torso wound below 35% → 2.5 HP/s. Stacked wounds stack bleed. HUD shows
  droplet icons per bleeding part.
- **Bandage** (B, hold 2.8 s channel, interrupted by damage/sprint): stops one
  wound (worst first), heals that part +25. Limited count per class (2–4).
  Cannot fire while bandaging; can walk slowly.
- **Recovery**: torso regens +2 HP/s after 7 s without damage, up to 70% of max.
  Limbs do NOT regen — a crippled leg stays crippled until bandaged. Head hits
  that don't kill cause brief aim blur + shake.
- **Cripple thresholds** (<30% part HP): leg → speed ×0.55, no sprint;
  arm → spread ×1.6, reload ×1.3. HUD body diagram colors: green/amber/red/black.
- Armor durability visible as small shield pips.

## 8. Classes & Loadouts

Universal: sidearm slot, primary slot, equipment slot ×2, bandages.
Class = speed/armor multipliers + allowed primary categories + kit + one perk.

| Class | Primary options | Armor | Bandages | Equip | Perk |
|---|---|---|---|---|---|
| Vanguard (Assault) | AR, BR | vest 60 | 3 | frag, flash | balanced: reload ×0.9 |
| Pathfinder (Recon) | SMG, DMR | vest 30 | 2 | smoke, flash | speed ×1.08; spots persist +4 s on minimap |
| Bulwark (Support) | LMG, AR | vest 90 + helmet | 4 | frag, smoke | suppression: enemies under your fire get +1.5° aim error |
| Ram (Breacher) | shotgun, SMG | vest 110 + helmet | 2 | flash, flash | speed ×0.95; pump/shotgun cycle ×0.8; breach doors fast |
| Longshot (Marksman) | DMR, sniper, BR | vest 40 | 2 | smoke, frag | focus spread ×0.4 instead of ×0.55 |

Lobby lets you pick class + primary within class + sidearm + equipment.
Bots pick loadouts weighted by personality (campers favor DMR/LMG, flankers
SMG/shotgun).

## 9. NPCs — The Beam

NPCs must feel like human players: own routes, own tempo, broad cooperation.
Never conga lines, never identical matches, never cheap omniscience.

**Pillars**
1. **Fair sensors only**: cone vision + occluded hearing + delayed noisy team
   radio. Same rules as player. Reaction delays, aim turn-rate limits, aim
   error that converges over time, burst discipline. An NPC that hasn't seen
   you cannot shoot you.
2. **Personality per match**: each NPC rolls traits — aggression, caution,
   discipline (burst length/cover adherence), aim skill, reaction, campiness,
   curiosity, independence. Traits weight a **utility AI** scorer; hysteresis
   prevents jitter. Two NPCs with the same intel choose differently.
3. **Human tempo**: sporadic linger (stop 0.5–2 s at corners), peek-and-retract,
   check-six pauses (rotate cone backward 0.6–1.2 s every 8–20 s while holding),
   route jitter (choose among near-equal paths), occasional overpeek mistakes.
4. **Squad without hivemind**: per-team coordinator assigns loose roles
   (point / flank / support / anchor) per objective phase; individuals deviate
   by independence trait. Spacing enforced (personal goal offsets + RVO
   avoidance): no bunching.
5. **Danger memory**: teammate deaths build a decaying **danger map**. Kill
   zones (2+ deaths in 6 s within 150 px) trigger: avoid reroute, hold longer
   angles, pre-aim common off-angles cautiously, smoke if available, call it
   on radio ("Lost two at mid — holding."). NPCs facing impossible odds
   (3+ visible enemies, or HP critical vs healthy enemy) immediately break to
   cover; unlikely odds (outnumbered 2:1) → cautious peeking / retreat to team.
6. **Cover is real**: maps carry authored cover points (position, lean
   direction, quality, lane coverage). Utility scores cover by: protection
   from threat direction, lane coverage toward objective/likely enemy, distance
   to teammates (spacing), danger map penalty. NPCs lean/peek from cover, shift
   between covers under pressure, and camp with check-six when personality says so.
7. **Combat behavior**: engage at weapon-effective range; suppress (fire at
   last-seen/cover edges) when no LOS but recent contact; flank when stalled
   >6 s or personality aggressive; disengage to bandage/reload behind cover;
   investigate sounds (occluded loudness threshold); react to flash/smoke/frag
   like players (turn away from flashbangs they see coming — sometimes).
8. **Objective drive**: TDM → hunt via intel + patrol hotspots; Battle →
   phase-based push/hold with role assignments, attackers commit in waves
   (not all 12 at once), defenders anchor + rotate.

**Difficulty presets** scale reaction/error/aggression, NOT sensors:
Recruit (reaction 320–450 ms, error 4–7°), Operator (240–360, 2.5–5°),
Veteran (180–280, 1.5–3.5°), Elite (140–220, 1–2.5°, better burst discipline).
Player always faces the same physics.

**Radio chatter** (text + optional voice barks): contact calls, kill calls,
"reloading", "bandaging", "lost him", killzone warnings. Subtle, faction-flavored,
rate-limited. Shown as small radio lines near minimap + killfeed.

## 10. Game Modes

### Elimination (TDM, no respawns)
- Up to 12v12. One life each. Time limit 8 min (lobby-adjustable 4–12).
- Surviving team wins. Timeout: more survivors wins; tie → higher summed HP;
  tie → draw.
- Maps: **Dustworks** (de_dust2-inspired test map: mid, long, tunnels, two
  bombsite-shaped arenas), **Compound** (industrial estate, symmetrical lanes).
- Pacing: early probing, mid-map attrition, late 1vX clutch tension. Spectate
  own team after death (free-follow camera + minimap), skip to debrief option.

### Battle (objective chain, tickets)
- Attackers: limited tickets (default 36 for 12v12, scales with bot count).
  Defenders: infinite respawns (8 s wave timer).
- Chain of 3 objectives (capture zones, hold-to-capture 20 s, contested pauses,
  defenders can recapture at 2× speed before it locks). Capturing grants +8
  tickets and unlocks next objective. Attackers respawn 6 s waves while tickets
  remain; each attacker death costs 1 ticket.
- Attackers win: final objective locked. Defenders win: tickets 0 AND all
  attackers dead (grace: last life plays out).
- Time limit 15 min; timeout = defenders win.
- Maps: **Terminal** (port logistics: A gatehouse → B warehouse → C control
  tower), **Oldtown** (European streets: A plaza → B church → C administration).

### Training Range (bonus)
- Solo sandbox: static + moving targets, weapon racks (switch any weapon),
  infinite ammo toggle, recoil/spread readout, TTK dummies with body-part
  display. Teaches focus/burst/bandage. Always accessible from title.

## 11. HUD & Menus (holographic near-future)

**Match HUD**
- Bottom-left: body diagram (6 parts, color states, bleed droplets), HP number,
  bandage count + channel bar, armor pips.
- Bottom-right: weapon silhouette icon, name, fire mode, mag / reserve (tabular
  numerals), equipment icons + counts.
- Top-center: mode strip — Elimination: timer + alive counts per faction;
  Battle: objective chain A→B→C with progress + ticket bars.
- Top-left: minimap (180–240 px, holographic frame, cone, contacts, objectives).
- Top-right: killfeed (callsign + weapon icon + callsign, faction colors),
  radio chatter lines beneath.
- Center: dynamic crosshair, hitmarkers (white hit / red kill), damage direction
  arcs, low-HP vignette + heartbeat audio, bleed warning.
- Tab: scoreboard (callsign, class, K/D, damage, status alive/dead, tickets).
- Esc: pause (resume, settings, surrender/quit to lobby).
- Death: brief killcam card (who, weapon, distance, your wound map), then
  spectate teammates (Elimination) or respawn countdown (Battle).

**Menus**: Title (animated map-diorama background, emblem, Deploy / Training /
Settings / Credits / Quit) → Lobby (left: mode+map cards with minimap preview &
briefing; right: faction toggle, class cards, loadout pickers, bot count sliders
per team, difficulty, time/ticket rules; bottom: DEPLOY) → Loading (briefing +
tips) → Match → Debrief (result banner, timeline of kills/objectives, personal
stats, team table, Rematch / Lobby / Title). Settings tabs: Video, Audio,
Controls (rebinds), Gameplay (crosshair style/color, HUD scale, camera lean,
shake, gore, difficulty default). Credits: assets attributions (required by
several packs), EUPL notice, tools.

**Accessibility**: HUD scale 0.8–1.4, colorblind-safe faction palettes
(blue/orange default already), crosshair presets, subtitle-style radio text,
screen-shake toggle, hold-vs-toggle for crouch/focus/sprint.

## 12. Audio Design

- Spatial 2D with **occlusion**: raycast listener→source counts walls; buses
  Open / Light (1 wall) / Heavy (2) / Muffled (3+) apply lowpass + attenuation.
  Gunshots through two walls are dull thumps you can still locate.
- Loudness → max audible distance: gunshot 1600 px, sprint footstep 420,
  walk 260, crouch 120, reload 200, bandage rustle 140, explosion 2000,
  body fall 180. Surfaces from tile custom data: concrete, sand, metal, grass,
  wood, water (footstep sets per surface).
- Guns: layered fire sound (close crack + mechanical action + distant tail),
  per-weapon sets from researched asset packs. Bolt/pump action sounds on cycle.
  Dry-fire click. Reload foley (mag out/in, bolt).
- Impacts: surface-specific (concrete chip, metal ping, glass shatter, flesh).
- Atmosphere: per-map ambience (wind, distant industrial hum, gulls at Terminal,
  city murmur at Oldtown), low music tension layer that rises on contact
  (adaptive: calm → engaged → clutch), faction-styled menu music.
- Voice: optional radio bark sets (Sci-Fi Ship Voices pack pitched/processed if
  license allows), otherwise text-only radio.
- Mix: master / sfx / music / voice buses, settings sliders, occlusion toggle.

## 13. Content & Moddability (designer promises)

Everything content-like is data: weapons, classes, equipment, factions, maps,
difficulty presets, radio lines. Adding a weapon = one `.tres` + sprites +
sounds, zero code. Adding a map = copy template scene, paint tiles, place
markers, one `.tres`. See `docs/adding-content.md` and the `kangur-content`
skill. UI theme centralized in one theme resource + palette constants.

## 14. Out of Scope (for now)

Multiplayer/networking, campaign story missions between matches (lore lives in
briefings/debriefs), vehicles, destructible walls (penetration only), controller
support (keyboard+mouse first), mod.io/Steam integration. Revisit after core
excellence.
