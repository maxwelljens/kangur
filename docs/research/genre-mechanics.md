# Genre Mechanics — Research Findings

Research input for **Kangur** (singleplayer topdown 2D tactical shooter, Godot 4.7.2,
CS2D aesthetic, Hotline Miami lethality, Tarkov-ish firearm handling, Door Kickers-ish
tactics). Companion to `docs/design/game-design.md` (design authority) and
`docs/architecture.md` (contracts).

- **Researched**: 2026-11-17
- **Method**: primary sources only where possible — CS2D's own site/reference pages and
  its developer's forum posts, Valve's Source SDK source, CS2 game-file dumps, Riot's
  Valorant wiki, Unreal/Godot official docs, a peer-reviewed reaction-time study, and
  first-party dev blogs. Fandom mirrors were read through the MediaWiki API where the
  HTML is bot-blocked. Numbers marked **(computed)** were produced by simulation in this
  session and are reproducible from the formulas given; they are *derivations*, not
  quotations.
- **Scale used throughout**: 32 px = 1 m (Kangur's design constant, and CS2D's tile size —
  see §1.1).

---

## 1. CS2D as the reference implementation

CS2D is the closest architectural ancestor: freeware, topdown, 32 px tiles, hitscan
bullets, Lua-scripted bots, optional fog of war. Its published numbers are a useful
sanity anchor but are *not* internally consistent (see §1.3.2).

### 1.1 Map scale, screen, camera, HUD

| Fact | Value | Source |
|---|---|---|
| Tile size | 32×32 px | "A tile is a square with a size of 32x32 pixels." — <https://www.cs2d.com/tutorials_mapping.php> |
| Default resolution | 850×480 | "In CS2D 1.0.0.3 the standard game resolution has been changed to 850x480." — <https://cs2d.com/help.php?cat=settings&cmd=mp_hudscale> |
| Visible map area | 26.5 × 15 tiles | "One screen (850x480) can display a map area of 26.5x15 tiles (850/32 x 480/32)!" — <https://cs2d.com/tutorials_mapping.php?part=2> |
| Screen half-extent used by engine code | x = 425+32, y = 240+32 | "bigger than (850/2)+32 on the X-axis or bigger than (480/2)+32 on the y-axis" — <https://cs2d.com/help.php?cat=settings&cmd=sv_offscreendamage> |
| Radar position | top-left | "players will see a radar in the top left corner of their screen" — <https://cs2d.com/help.php?cat=settings&cmd=mp_radar> |
| Aiming | free 360°, mouse direction only | "Your player will always aim to the direction of your mousepointer (a little crosshair). Please note that only the direction matters." — <https://www.cs2d.com/play.php> |

**HUD layout is a bitmask, and the element list is effectively a spec** — health, armor,
time, ammo, money, icons, kill messages:

> "1 - Health / 2 - Armor / 4 - Time / 8 - Ammo / 16 - Money / 32 - Icons (like buyzone,
> rescuezone etc) / 64 - Kill Messages … The default value for this setting is
> 1+2+4+8+16+32+64 = 127"
> — <https://cs2d.com/help.php?cat=settings&cmd=mp_hud>

**Camera-follows-crosshair:** CS2D does *not* implement a lean-toward-cursor camera. The
viewport is centred on the player and only scrolls at the map edge (the "virtual screen of
the player" in `ai_findtarget` is a fixed rectangle around the player, not a cursor
offset). Evidence: `sv_offscreendamage` defines off-screen purely by a fixed
425+32 / 240+32 half-extent around the attacker
(<https://cs2d.com/help.php?cat=settings&cmd=sv_offscreendamage>), and `autoscreen` /
`drawradar` / `mp_hud` contain no camera-offset command at all — there is no camera
convar in the settings list (<https://cs2d.com/help.php?cat=settings>). **Inference:**
cursor-lean is Kangur's own addition (design doc §4), not something to copy from CS2D;
it is a legitimate readability improvement at 32 px/m but must be clamped, because it
effectively extends sight range in the lean direction.

Two CS2D settings worth copying as *options*:

- `relativemovement 0/1` — "The direction of your player (controlled with mouse) affects
  the movement direction if it is relative. In absolute mode the direction does not affect
  the movement." (<https://cs2d.com/help.php?cat=settings&cmd=relativemovement>) —
  absolute (screen-relative WASD) is the CS2D/Hotline Miami default and the right default
  for Kangur; relative movement is a twin-stick/couch option.
- `wiggle 0/1` — the whole-body walk wobble ("Do players 'wiggle' while moving or not?"),
  <https://cs2d.com/help.php?cat=settings&cmd=wiggle>. Cheap, high-value topdown juice.

### 1.2 Movement

CS2D's developer published the exact movement formula. This is the single most useful
primary source in the whole document:

> "speed per frame:
> ( 2.0 base speed
> + weapon speed modifier
> (- 0.5 if player carries flag)
> (+ speedmodvalue/10.0) )
> * 1.2 (this is a constant adjustment value I used for dev)
> (/2.0 if walking)
> = movement speed
> …
> the game runs with 50 fps … this means:
> movement speed * 50 = pixels per second
> example with knife: 2.0 + 0.75 = 2.75; 2.75 * 1.2 = 3.3; 3.3 * 50 = 165 pixels per second"
> — DC (CS2D author), <https://unrealsoftware.de/forum_posts.php?post=214333&goto=214978>

Derived consequences **(computed)**:

| Case | Formula | px/s |
|---|---|---|
| Base, no weapon modifier | 2.0 × 1.2 × 50 | **120** |
| Knife / Wrench (+0.75) | 2.75 × 1.2 × 50 | **165** |
| Pistols (+0.5) | 2.5 × 1.2 × 50 | **150** |
| Most rifles/SMGs (0.0) | 2.0 × 1.2 × 50 | **120** |
| AWP / M249 (−0.5) | 1.5 × 1.2 × 50 | **90** |
| Shift-walk (÷2) | half of the above | 45–82 |
| Flag carrier (−0.5) | −30 px/s | — |

Two structural lessons:

1. **Weapon weight is a direct additive speed modifier, not a multiplier.** Simple,
   readable, and it makes "heavy gun = slow" legible without a stat screen.
2. **"Walk" is a hard ÷2, not an acceleration change** — and it removes footstep audio
   entirely: "You can also hold the shift key down while moving. This makes you slower but
   you also cause no footstep sounds anymore." (<https://www.cs2d.com/play.php>). Silence
   is the *point* of walk, not the speed.

CS2D has no acceleration model to speak of (clientside per-frame integration, no accel
constant exposed); movement is effectively instant-velocity with a per-frame step. That is
exactly the thing Kangur's design doc replaces with Source-style accel/friction — see §2.

### 1.3 Weapons

#### 1.3.1 Published table (verbatim, official site)

Source: <https://cs2d.com/weapons.php>. "Range" is projectile lifetime in px; "Accuracy"
is the dispersion class (V value). Reproduced for the categories the brief asks about:

| Weapon | Cat | Price | Dmg | Ammo (mag\|reserve) | Rate | Range px | Accuracy (V) | Weight (SpdM) |
|---|---|---|---|---|---|---|---|---|
| USP | pistol | 500 | 24 | 12 \| 100 | 166 RPM | 300 | Perfect (0) | +0.5 |
| Glock | pistol | 400 | 21 | 20 \| 120 | 166 RPM | 250 | Perfect (0) | +0.5 |
| Deagle | pistol | 650 | 34 | 7 \| 35 | 100 RPM | 300 | Perfect (0) | +0.5 |
| Five-Seven | pistol | 750 | 21 | 20 \| 100 | 214 RPM | 300 | Perfect (0) | +0.5 |
| MP5 | SMG | 1500 | 13 | 30 \| 120 | 500 RPM | 300 | Average (2) | 0 |
| TMP | SMG | 1250 | 9 | 30 \| 120 | 750 RPM | 100 | Bad (4) | +0.35 |
| P90 | SMG | 2350 | 11 | 50 \| 100 | 750 RPM | 300 | Average (3) | 0 |
| Mac 10 | SMG | 1400 | 9 | 30 \| 90 | 750 RPM | 100 | Bad (4) | +0.35 |
| UMP45 | SMG | 1700 | 15 | 25 \| 90 | 375 RPM | 300 | Average (3) | 0 |
| AK-47 | AR | 2500 | 22 | 30 \| 90 | 500 RPM | 300 | Average (3) | 0 |
| M4A1 | AR | 3100 | 22 | 30 \| 90 | 500 RPM | 300 | Average (2) | 0 |
| Galil | AR | 2000 | 13 | 35 \| 90 | 500 RPM | 300 | Good (1) | 0 |
| Famas | AR | 2250 | 14 | 25 \| 90 | 500 RPM | 300 | Good (1) | 0 |
| SG552 | AR | 3500 | 24 (zoom 35) | 30 \| 90 | 375 RPM | 325 | Perfect (0) | 0 |
| Scout | sniper | 2750 | 45 (z1 50, z2 100) | 10 \| 60 | 75 RPM | 350 | Perfect (0) | +0.1 |
| AWP | sniper | 4750 | 50 (z1 65, z2 150) | 10 \| 30 | 23 RPM | 400 | Perfect (0) | −0.5 |
| G3SG1 | semi-sniper | 5000 | 32 (z1 37, z2 45) | 20 \| 60 | 250 RPM | 350 | Good (1) | −0.3 |
| M249 | LMG | 5750 | 15 | 100 \| 200 | 750 RPM | 300 | Horrible (8) | −0.5 |
| M3 | shotgun | 1700 | 26 × 5 = 130 | 8 \| 32 | 75 RPM | 50 | Horrible (10) | 0 |
| XM1014 | shotgun | 3000 | 22 × 5 = 110 | 7 \| 32 | 125 RPM | 50 | Horrible (10) | 0 |

Note the **weight = shotgun/pistol asymmetry**: pistols are the *fastest* guns in CS2D
(+0.5) while shotguns are neutral — the opposite of Tarkov/CS intuition and a deliberate
readability choice for a 2D game.

#### 1.3.2 The CS2D numbers contradict themselves — do not copy them blindly

The wiki mirror exposes the raw engine fields and their units:

> "**rate** the firerate; the delay between two shots, in [frame]s."
> "**reload**: the time the weapon needs to reload (if the weapon is reloadable), in
> [frame]s."
> "**dispersion**: level of burst of the weapon. 0 means perfect accuracy, meaning the
> bullets fly exacly to the mouse pointer, higher numbers mean lower accuracy."
> "**recoil**: how much the recoil pushes back the player. This is just an animation
> without effects on gameplay."
> — <https://cs2d.fandom.com/wiki/List_of_all_weapons_and_items> (read via
> `api.php?action=parse`; HTML is bot-blocked)

**Conflict found (fact):** the AK-47's published RPM is 500 with "FD: 3", yet the same
page's DPS column says "352 (16 x 22)" — i.e. 16 shots/second, which is ~960 RPM. The
DPS column is internally consistent with FD at CS2D's stated 50 fps (3000/3 = 1000 RPM);
the "RPM" label is exactly half that. Same pattern for MP5 (labelled 500, DPS implies 1000),
Deagle (labelled 100, DPS implies 200), AWP (labelled 23, FD 65 → 46). **Conclusion:** the
site's RPM column and its FD/DPS columns use different tick bases. Reported as a conflict,
not resolved. Recommendation: use CS2/CS2D *category feel* and real-world RPM as the anchor
(§3.6), never CS2D's RPM label as a literal.

Reload is likewise ambiguous — e.g. AK-47 "reload 275 frames". At 50 fps that is 5.5 s
(implausible); at 100 fps it is 2.75 s (plausible). No source states the reload tick base.
**Therefore Kangur reload times are grounded in CS2 values instead** (§3.5).

**Accuracy is a discrete 6-level scale, not degrees.** V = 0/1/2/3/4/8/10 map to
Perfect/Good/Average/Bad/Horrible. CS2D therefore has *no continuous spread model* — the
only recoil is visual:

> "If dynamic recoil is disabled (mp_recoil 0, default), all weapons will just have a random
> precision. Firing long bursts or single shots makes no difference for the precision. With
> dynamic recoil enabled (mp_recoil 1), weapons get less precise when you hold the trigger
> instead of firing single shots. Precision will increase again after a very short cool
> down. The crosshair adjusts automatically depending on the precision."
> — <https://cs2d.com/help.php?cat=settings&cmd=mp_recoil>

That is the single biggest mechanical gap between CS2D and what Kangur wants: CS2D defaults
to *static* dispersion with an optional bloom; Kangur's design doc specifies continuous
bloom + recovery, which is strictly better and should stay.

**Body penetration falloff is a CS2D-specific nicety worth stealing:**

> "Controls how much the force/damage of shots is weakened when they hit a
> player/hostage/NPC or image hitzone. The default value for this setting is 30 (=30%
> damage reduction per hit). … first player will suffer full 100 damage, the second player
> will suffer 30% less … 70 damage, the third … 49"
> — <https://cs2d.com/help.php?cat=settings&cmd=mp_shotweakening>

#### 1.3.3 Bullets are hitscan

> "projectiles are grenades and most stuff launched by weapons which is visible for multiple
> frames. **Regular bullets are NO projectiles though**"
> — <https://cs2d.com/help.php?luacat=all&luacmd=projectile>

CS2D is therefore hitscan with a maximum range in px (`range` field: 300 px = 9.4 m for
most guns, 400 for AWP, 50 for shotguns). Kangur deliberately diverges here (real
projectiles, 4000–9000 px/s — design doc §6), and that divergence is load-bearing for the
"break LOS after the muzzle flash" moment.

#### 1.3.4 No headshots in CS2D

> "there will be no headshots in cs2d." — DC, <https://www.unrealsoftware.de/forum_posts.php?post=62240>

A 2007 thread asking for a "0.75 s aim-hold" headshot mechanic. The reason given is the
missing third dimension: in a pure topdown projection the head sprite and the feet sprite
occupy the same screen pixel. **Design implication for Kangur:** body-part damage in
topdown cannot come from the hit *position* (you cannot aim at a head you cannot see).
Kangur's design doc uses separate per-part HP pools and a part-agnostic hit resolution;
if hit *location* is wanted, it must be modelled as (a) lateral offset from the body
centre-line, or (b) an explicit aim-height/`Part` selector, never as a sprite hitbox. This
is a hard constraint the CS2D author called impossible, and it is worth respecting rather
than fighting.

### 1.4 Fog of war / vision cone

Fog of war is optional and has graded modes:

> "Set the fog of war mode. Fog of war makes the game more realistic by hiding stuff which is
> out of the players view angle and behind walls. … 0 - off … 1 - hide characters only …
> 2 - hide characters and effects … 3 - hide everything … only the map itself and buildings
> will be visible"
> — <https://cs2d.com/help.php?cat=settings&cmd=sv_fow>

Supporting settings: `fowalpha` (0 = invisible, 100 = opaque black) and `fowdetails` (0–1,
"High fog of war details can slow down the game on slow systems") —
<https://cs2d.com/help.php?cat=settings&cmd=fowalpha>.

The visibility test is *position + facing dependent*:

> "Returns if the coordinate defined in pixels at x|y is currently hidden by the fog of war
> (1) or not (0). The visibility is calculated for player with the given ID, **taking its
> current position and rotation into account**. Attention: This check is relatively slow as
> it recalculates the fog of war each time it is called."
> — <https://cs2d.com/help.php?luacat=all&luacmd=fow_in>

**No cone angle is documented anywhere** in CS2D's public reference. Do not invent a
number for CS2D; Kangur's 100° / 520 px (design doc §5) is a design decision, not a port.

One genuinely subtle behaviour to copy: **buildings and smoke always stay visible** because
hiding them breaks the effect —

> "Smoke grenade smoke will always be visible in fog of war because it would otherwise hide
> itself, leading to strange effects. … Buildings will also always be visible in fog of war."
> — <https://cs2d.com/help.php?cat=settings&cmd=sv_fow>

### 1.5 Bot AI

The public bot surface is small and honest about what it models:

> "Sets the skill level of all bots. **This mainly affects reaction times and aiming speed.**
> Also bots with a skill <2 won't buy any armor"
> — `bot_skill` 0–4, <https://cs2d.com/help.php?cat=bots&cmd=bot_skill>

> "Bot with given ID aims at the given position (x|y) on the map (in pixels). **Aiming
> happens smoothly (over multiple frames).** Note: bot_skill has an impact on the rotation
> speed and on how long it takes to aim at the target!"
> — `ai_aim`, <https://cs2d.com/help.php?luacat=all&luacmd=ai_aim>

> "Returns the ID of the closest enemy … Only players which are close enough (**inside the
> virtual screen of the player**) will be returned. When fog of war is enabled players behind
> walls won't be returned. Note: bot_skill has a slight impact on the size of the virtual
> screen of bots. Bots with a high skill will 'see' enemies slightly earlier than bots with a
> low skill."
> — `ai_findtarget`, <https://cs2d.com/help.php?luacat=all&luacmd=ai_findtarget>

Three transferable facts:

1. **Perception is a rectangle plus LOS, not a cone** — CS2D bots see 360° within their
   virtual screen, gated only by walls. This is why CS2D bots feel omniscient from behind
   and is precisely the failure mode Kangur's fairness rule (cone + hearing + radio) exists
   to avoid.
2. **Skill is applied as timing, not as information** — reaction time, rotation speed, and
   a small (~skill-proportional) sight-range bonus. That is the correct lever; the sight
   bonus should be dropped or capped for Kangur.
3. **Movement primitives are deliberately dumb** — `ai_move` "does not do any pathfinding
   and the bot will just stop if it hits any obstacle" (<https://cs2d.com/help.php?luacat=all&luacmd=ai_move>),
   while `ai_goto` does pathfinding. Bots are assembled from Lua rather than an engine AI,
   so CS2D is an existence proof that "simple primitives + a good script" reads as
   competent, and no argument at all for sophisticated AI in the engine layer.

### 1.6 Hit zones are rectangles and never rotate

> "The hit zone is always rectangular without rotation. Image rotation does NOT affect the
> hit zone in any way. … A minimum width/height of 10 pixels is recommended!"
> — <https://cs2d.com/help.php?luacat=all&luacmd=imagehitzone>

With bodies drawn as free-rotating layered sprites (§4), this is direct evidence that
coupling hit geometry to the *sprite* is a mistake: CS2D keeps hitboxes axis-aligned and
separate from art. Kangur should do the same (single capsule/circle per character on the
CHARACTER physics layer, part resolution in `BodyModel`, not in `Area2D` shapes).

---

## 2. Source engine movement, and how to adapt it to 8-direction topdown

### 2.1 The actual algorithm

Valve's `CGameMovement::Accelerate` (verbatim, abridged):

```cpp
currentspeed = mv->m_vecVelocity.Dot(wishdir);
addspeed = wishspeed - currentspeed;
if (addspeed <= 0) return;
accelspeed = accel * gpGlobals->frametime * wishspeed * player->m_surfaceFriction;
if (accelspeed > addspeed) accelspeed = addspeed;
for (i=0; i<3; i++) mv->m_vecVelocity[i] += accelspeed * wishdir[i];
```
— <https://raw.githubusercontent.com/ValveSoftware/source-sdk-2013/master/src/game/shared/gamemovement.cpp>

Friction, same file:

```cpp
speed = VectorLength(mv->m_vecVelocity);
if (speed < 0.1f) return;
if (player->GetGroundEntity() != NULL) {
    friction = sv_friction.GetFloat() * player->m_surfaceFriction;
    control = (speed < sv_stopspeed.GetFloat()) ? sv_stopspeed.GetFloat() : speed;
    drop += control * friction * gpGlobals->frametime;
}
newspeed = speed - drop;
if (newspeed < 0) newspeed = 0;
newspeed /= speed;
VectorScale(mv->m_vecVelocity, newspeed, mv->m_vecVelocity);
```

Consequences that matter for feel:

- **Acceleration is proportional to `wishspeed`, not constant.** Low-speed movement
  accelerates gently; sprint accelerates hard. The `addspeed` cap is what makes the ramp
  asymptotic instead of overshooting.
- **`control = max(speed, sv_stopspeed)` creates a constant deceleration floor.** Without
  it, exponential friction has an infinite tail and the character never quite stops;
  `sv_stopspeed` makes the last ~100 u/s of decel linear, so stopping is crisp.
- **Order matters: friction *then* acceleration**, every tick. Reversing the order changes
  the terminal speed.

Default cvars (Source SDK `movevars_shared.cpp`): `sv_accelerate 10`, `sv_friction 4`,
`sv_stopspeed 100`, `sv_maxspeed 320`, `sv_airaccelerate 10`, `sv_stepsize 18`,
`sv_maxvelocity 3500` — <https://raw.githubusercontent.com/ValveSoftware/source-sdk-2013/master/src/game/shared/movevars_shared.cpp>

Counter-Strike overrides them for a heavier feel: `sv_accelerate 5.5`, `sv_friction 5.2`,
`sv_stopspeed 80` — see the CS:GO movement-value changelog (old 5.6/4.8/75 → current
5.5/5.2/80), <http://hltv.org/blog/8736-csgo-03102014-update-movement-analysis>, corroborated
by <https://totalcsgo.com/commands/svaccelerate> and
<https://forums.alliedmods.net/showthread.php?t=300527>. Crouch is a `0.34` multiplier on
forward/side move ("This method scales the player's FSU by approximately 0.34 when ducking",
<https://github.com/followingthefasciaplane/crouching-airaccel-patch>); Shift-walk is `0.52`
(`cl_movespeedkey` default, <https://csdownload.net/how-to-fix-movement-speed-bugs-in-counter-strike-1-6>).

### 2.2 Adapting to topdown: what changes and what does not

- **Air acceleration is irrelevant** — Kangur has no jump (design doc §3). Drop
  `sv_airaccelerate` entirely; it is a strafe-jumping exploit vector, not a feel feature.
- **`wishdir` is the input stick direction, not view forward.** In FPS, W means "toward
  where I look"; in topdown absolute movement, W means "up on screen" independent of aim.
  Keep `wishspeed = |move| * stance_speed` and `wishdir = move.normalized()`.
- **Speed cropping by stance/weapon** replaces CS's `HandleDuckingSpeedCrop`: scale the
  *target speed* (and hence both `wishspeed` and the accel term), not the resulting
  velocity. Scaling velocity directly makes heavy weapons feel like moving through mud
  after the fact.
- **Diagonal normalisation** must be explicit: `move.normalized()` before use, else 8-way
  diagonal input is √2 faster — the classic topdown bug. Source gets this for free from
  unit `wishdir` + `addspeed` cap; a naive `velocity += input * accel` does not.

### 2.3 Derived constants for Kangur

The design doc currently specifies "Ground accel 1400 px/s², friction coefficient 10/s
(exponential decay)". **That pair is inconsistent (computed):** with pure exponential
friction `v -= F·v·dt` and constant acceleration `A`, the terminal speed is `A/F` =
1400/10 = **140 px/s** — below the 215 px/s sprint target. Sprint only reaches 215 because
the speed clamp forces it, and the resulting ramp is wrong (it arrives at the clamp rather
than easing into it). Adopting Source's proportional form fixes this for free, because
`A·Vmax` scales with the target speed.

Recommended (all **(computed)** from the Source formulas above, 240 Hz integration,
`stopspeed` floor included):

| Stance | `max_speed` px/s | `accel` (1/s) | `friction` (1/s) | `stopspeed` px/s | t→50% | t→90% | stop time | stop distance |
|---|---|---|---|---|---|---|---|---|
| CROUCH | 65 | 10 | 9 | 60 | 0.28 s | 0.51 s | 0.11 s | 0.12 m |
| WALK / default | 130 | 10 | 9 | 60 | 0.08 s | 0.20 s | 0.19 s | 0.33 m |
| SPRINT | 215 | 10 | 9 | 60 | 0.07 s | 0.19 s | 0.25 s | 0.62 m |
| FOCUS (×0.5 of stance) | 65 | 10 | 9 | 60 | 0.28 s | 0.51 s | 0.11 s | 0.12 m |
| Leg-crippled (×0.55) | 72 | 10 | 9 | 60 | 0.19 s | 0.35 s | 0.13 s | 0.14 m |

(Crouch is deliberately the *slowest* to reach speed as well as the slowest top speed — that
is what makes crouch-walking feel heavy rather than just slow. Note that crouch's low
`max_speed` is only ~1.1× `stopspeed`, so the constant-deceleration floor dominates its
whole motion; if that feels mushy, lower `stopspeed` to 30 for crouch only.)

- `accel = 10 /s` is deliberately ~1.8× CS:GO's 5.5 and matches the SDK default 10. At
  walk speed that is `10 × 130 = 1300 px/s²` at zero speed — within 7% of the design doc's
  1400 px/s², so the doc's *intent* is preserved; only the expression changes.
- `friction = 9 /s` (vs CS:GO 5.2) keeps the ~0.3 m stopping distance that makes
  counter-strafing a real skill without letting players slide.
- `stopspeed = 60 px/s` (vs CS:GO 80 u/s) because the whole speed scale is compressed:
  60 px/s = 1.9 m/s, which is roughly a walking pace, so the "crisp final stop" happens at
  a sensible human scale.
- Report these as **`MovementModel` config fields**, not constants: the architecture
  already injects walk/sprint/crouch speeds, accel, friction, and stamina rates
  (`docs/architecture.md` §4).

Sanity check against a real feel (`computed`): 180° reversal (full sprint one way, stick
fully the other way) crosses zero velocity in ~0.07 s, having travelled ~0.35 m forward from
the moment of input reversal — fast enough to feel responsive, long enough that you cannot
instantly jitter-peek.

---

## 3. Realistic-ish firearm handling

### 3.1 Two published models worth studying

**Valorant** publishes the whole spread budget in degrees, which is the closest thing to a
specification that exists for a modern tactical shooter:

| Vandal (rifle) | 1st shot spread | Max spread | Crouched | Walking | Running | Airborne |
|---|---|---|---|---|---|---|
| Standing | 0.25° | 1.00° | — | — | — | — |
| Crouched | 0.21° | 0.85° | +0.8° | — | — | — |
| Movement penalty | — | — | — | +3° | +6° | +10° |
| ADS (alt fire) | 0.157° | 1.02° | — | — | — | — |

Fire rate 9.75 rds/s (585 RPM), run speed 5.4 m/s, mag 25, reload 2.5 s, headshot ×4, leg
×0.85, crouch spread ×0.85. — <https://wiki.playvalorant.com/en-us/Vandal>

**Interpretation (opinion, but arithmetic):** a 6° running penalty is 24× the 0.25° first-shot
value. At 10 m the cone radius is 10 m · tan(3°) ≈ 52 cm (computed) — i.e. running fire is
*unusable* beyond a few metres, by design. That is the cleanest possible way to encode
"stop to shoot" and it needs no separate accuracy stat.

Valorant also names the recovery mechanic explicitly:

> "Inaccuracy is accrued any time the weapon is re-fired prior to a complete duration of a
> weapon's respective Gun Recovery Time." / "Tap Efficiency determines the rate that
> inaccuracy is accrued when re-firing … The higher the Tap Efficiency, the lower the rate of
> inaccuracy accrual"
> — Riot patch 0.50, <https://playvalorant.com/en-us/news/game-updates/valorant-patch-notes-0-50>
> (rifle Gun Recovery Time 0.375 s after a bugfix, per
> <https://wiki.playvalorant.com/en-us/Vandal>)

**CS2** does not publish degrees, but the raw weapon attributes are readable in game files
and confirm the same shape — the AK-47 (from an `items_game`-derived dump):

| Attribute | Value |
|---|---|
| damage | 36 |
| cycletime | 0.1 s (600 RPM) |
| spread | 0.6 |
| inaccuracy stand / crouch | 6.41 / 4.81 |
| inaccuracy fire (per shot bloom) | 7.8 |
| inaccuracy move | 175.06 |
| recovery time stand / final | 0.368 s / 0.506 s |
| recoil magnitude / angle variance | 30 / 70 |
| max player speed | 215 |
| armor ratio / penetration | 1.55 / 2 |
| headshot multiplier | 4 |
| range / range modifier | 8192 / 0.98 |

— <https://raw.githubusercontent.com/Citrinate/CS2Interface/main/CS2Interface/IPC/Documentation/Items/InspectItem.md>
(values are CS2 `attributes` for `item_class: weapon_ak47`; the doc is a tool-integration
reference that echoes the game's item schema). Note `max player speed 215` — Kangur's sprint
215 px/s is a coincidental but pleasing match to CS's rifle run speed in units, though the
scales differ.

**The ratios are the interesting part (computed):** `inaccuracy_move / inaccuracy_stand` =
175.06/6.41 ≈ **27×**; `inaccuracy_fire / inaccuracy_stand` ≈ **1.2×** per shot. So in CS2,
*movement* dominates inaccuracy and per-shot bloom is a slow accumulation — the opposite of
how most arcade shooters tune it.

### 3.2 Why semi/burst beats full-auto at range (the actual mechanism)

Not "recoil is strong". The mechanism is that **error accumulates faster than it recovers,
and the accumulation is per-shot while the recovery is per-second**:

- bloom grows by a fixed increment on every shot (`inaccuracy fire`, CS2 7.8 units), so at
  RPM `r` the growth rate is `7.8·r/60` units/s — 600 RPM grows 78 units/s;
- recovery is a time constant (`recovery time stand` 0.368 s), so decay is roughly
  `error/τ` per second with τ ≈ 0.37 s;
- therefore there is a **sustainable fire rate** at which growth = decay. Above it, the cone
  diverges; below it, every shot lands at first-shot accuracy. Firing in bursts keeps you
  under that rate for the first N shots, which is why 2–3 round bursts are the correct
  answer at range and full-auto is only correct inside the range where the cone's radius is
  smaller than the target.

**(computed) target size vs cone radius** — this is the table to balance against, because it
is what the player actually experiences. Cone radius (px) at range for a half-angle:

| half-angle | 5 m | 10 m | 20 m | 40 m |
|---|---|---|---|---|
| 0.25° | 0.7 | 1.4 | 2.8 | 5.6 |
| 0.5° | 1.4 | 2.8 | 5.6 | 11.2 |
| 1.0° | 2.8 | 5.6 | 11.2 | 22.3 |
| 2.0° | 5.6 | 11.2 | 22.3 | 44.7 |
| 3.0° | 8.4 | 16.8 | 33.5 | 67.1 |
| 6.0° | 16.8 | 33.6 | 67.3 | 134.5 |

A character is ~10 px radius (design doc §3), so a 20 px-wide torso. At 1° half-angle the
cone is smaller than the torso out to ~35 m; at 3° only to ~12 m; at 6° only to ~6 m. This
gives a principled way to pick base spreads: **set base spread so a weapon is torso-accurate
at its intended effective range**, and let bloom/movement decide what happens beyond it.

### 3.3 Suppression, stamina, and the no-reticle school

Insurgency: Sandstorm is the best-documented "realism-lite" model; the developers describe
suppression as a *player-side* sway/vision penalty rather than an accuracy nerf:

> "One of our features focused on immersion is what we call Suppression. When under fire, your
> weapon sway increases, and your vision is obscured."
> "Insurgency: Sandstorm uses a stamina system, where the lower your stamina is, the more
> weapon sway you'll have. … With a lot of weight, sprinting will be very costly."
> "Time to kill … is very low – one or two shots is usually all it takes. The run-and-gun
> playstyle … will mostly get you killed"
> — New World Interactive dev blog via Xbox Wire,
> <https://news.xbox.com/en-us/2021/09/13/creating-immersion-and-intensity-in-insurgency-sandstorm/>

Also from that post, and directly relevant to Kangur's HUD and audio design: no kill feed or
kill confirmation, no reticle without an optic, no ammo counter unless you check, and
"you'll also be able to tell their location, if they're outside or inside, what kind of room
they're in (big, small, metal, concrete, etc), and even which direction they're facing" from
gunfire alone.

### 3.4 Real muzzle velocities (Tarkov, for ballistics plausibility)

Tarkov models velocity per *ammunition*, not per weapon, and its data is public. Ranges
extracted from `tarkov.help`'s ammo JSON **(fact, as published)**:

| Calibre | min → max m/s | Example rounds |
|---|---|---|
| 9×19 | 560 | PBP gzh |
| 9×39 | 305 | SP-6 (subsonic) |
| .45 ACP | 274–340 | RIP / FMJ |
| 12/70 | 320–510 | Flechette / buckshot |
| 5.45×39 | 880–915 | BT gs / 7N40 |
| 5.56×45 | 940–1013 | M856A1 / SSA AP |
| 7.62×39 | 730–875 | BP gzh / MAI AP |
| 7.62×51 | 838 | M61 / M80 |
| .338 LM | 849 | AP |
| 12.7×108 | 818 | B-32 |

— <https://tarkov.help/en/ammo> (JSON payload; per-round pages e.g.
<https://tarkov.help/en/ammo/detail/Caliber556x45NATO/556x45mm-m995>)

Cross-check against a general cartridge table (ft/s → m/s, **(computed)** conversion):
9×19 1155 ft/s ≈ **352 m/s**; 5.56×45 3130 ≈ **954**; 5.45×39 2810 ≈ **856**; 7.62×39 2360
≈ **719**; 7.62×51 3165 ≈ **965**; 7.62×54R 2894 ≈ **882**; .338 LM 2900 ≈ **884**
— <https://en.wikipedia.org/wiki/Table_of_handgun_and_rifle_cartridges>

**Two sources, same order of magnitude, different values** (Tarkov is consistently 5–8%
higher because it models muzzle velocity at the barrel, the table reports "highest found for
the cartridge"). Use the class ranges, not the point values.

**Kangur's 3× compression** (design doc §6: 4000–9000 px/s at 32 px/m) maps real m/s to a
readable screen speed. Check (computed): 954 m/s × 32 px/m = 30,528 px/s; ÷ 9000 ≈ **3.4×**.
A 9 mm at 352 m/s × 32 = 11,264 px/s; ÷ 4600 ≈ **2.4×**. So the compression factor is not
constant across the roster — pistols are compressed ~2.4×, rifles ~3.4×. That is fine (and
arguably desirable: it keeps pistol/sniper travel-time *differentiation* visible), but the
doc should say "≈2.5–3.5× variable compression", not "~3×", so nobody "fixes" it later.

Travel time at 20 m (640 px, computed): 9000 px/s → 71 ms; 4600 px/s → 139 ms. Both are
below human reaction time (§5.1), so at normal engagement ranges Kangur is effectively
hitscan for fairness purposes, and the projectile model only pays off at long lanes. Worth
knowing before balancing around it.

### 3.5 Reload and cycle times (CS2, for the roster)

CS2's AK-47 cycletime is 0.1 s → 600 RPM (same source as §3.1). Public CS2 references give
the rest of the family: Deagle 267 RPM / 2.2 s reload, UMP-45 667 RPM / 3.43 s
(<https://blitz.gg/cs2/database/weapons/weapon_ump45/overview>,
<https://blitz.gg/cs2/database/weapons/weapon_deagle/overview>). Where CS2 disagrees with
CS2D, prefer CS2 — CS2D's reload unit is undocumented (§1.3.2).

### 3.6 A concrete spread/recoil model for Kangur

Keep the design doc's multiplicative structure (it is correct and already in
`WeaponDef`), and fix four things:

1. **Split "spread" from "recoil".** Spread = random cone (what determines hit probability).
   Recoil = directional kick (what the player must compensate). CS2D conflates them (its
   "recoil" is animation only); Valorant separates them; Kangur's doc already separates them
   — keep that and never let one be derived from the other.
2. **Make the movement multiplier a table, not a curve.** Valorant's +0.8/+3/+6/+10 is
   linear in stance and trivially tunable. Kangur's `1 + 2.5·(v/vmax)^1.5` is fine but hides
   the numbers; the design doc's own `move_mult` reaches 3.5 at sprint, which at a 1° base
   is 3.5° — comparable to Valorant's walking penalty, i.e. probably too forgiving. Suggest
   `move_mult` at sprint ≈ 6× (matching Valorant's run penalty relative to walk).
3. **First-shot accuracy must be a real promise.** Set `bloom = 0` on the first shot after
   ≥ `reset_time` of not firing, and make `reset_time` per class (0.25 s SMG → 0.55 s
   marksman). This is what makes tapping a skill instead of a dice roll.
4. **Recovery is exponential toward zero bloom with a floor**, `bloom *= exp(-dt/τ)`, with
   `τ = reset_time / 3` (so ~95% recovery at `reset_time`). Exponential avoids the
   "recovered exactly at t=τ" cliff that linear decay produces.

Formulas (to live in `Ballistics` as static functions):

```
# per shot
bloom_after = min(bloom_max, bloom_before + bloom_per_shot)
# per tick, when not firing  (exponential decay, tau = reset_time / 3)
bloom = bloom * exp(-dt / tau)                       # ~95% gone after `reset_time`
# effective cone half-angle, degrees
spread_deg = (base_deg + bloom)
           * move_mult(speed_ratio)
           * (0.75 if crouch else 1.0)
           * (focus_mult if focus else 1.0)          # 0.55 default, 0.4 marksman perk
           * (1.6 if arm_crippled else 1.0)
# movement multiplier: linear in speed, table-driven
#   r = |velocity| / sprint_speed  (0 at rest, 1 at full sprint)
move_mult(r) = 1.0 + (run_mult - 1.0) * clamp(r, 0.0, 1.0)   # run_mult 4.0–8.0 by class
```

Suggested class values (opinion, anchored to §3.1 ratios — movement error ~27× standing
error in CS2, run penalty ~24× in Valorant, so a large multiplier is *authentic*, not
extreme):

| Class | `base_deg` | `bloom_per_shot` | `bloom_max` | `reset_time` | `run_mult` | rpm anchor |
|---|---|---|---|---|---|---|
| Pistol | 0.7 | 0.55 | 3.5 | 0.30 s | 4.0 | 150–420 |
| SMG | 0.9 | 0.35 | 4.5 | 0.28 s | 5.0 | 750–1000 |
| Assault rifle | 0.5 | 0.40 | 5.0 | 0.40 s | 6.0 | 600–650 |
| Battle rifle / DMR | 0.35 | 0.60 | 6.0 | 0.50 s | 7.0 | 260–300 |
| Sniper | 0.15 | 1.50 | 8.0 | 0.60 s | 8.0 | 45–75 |
| LMG | 0.8 | 0.30 | 7.0 | 0.55 s | 6.5 | 700–750 |
| Shotgun (per pellet) | 4.0 (spread) | 0.0 | 6.0 | 0.35 s | 5.0 | 70–240 |

Note the shotgun is inverted: its "spread" *is* the pellet cone, so `base_deg` is large and
bloom is small — buck has no meaningful per-shot bloom, only a pump-cycle penalty.

---

## 4. Topdown character rendering

### 4.1 How the references actually do it

**Hotline Miami / HM2 — layered sprite sheets with shared legs.** The community's definitive
spriting breakdown documents the exact decomposition: legs are a *separate, shared* asset
category, and the same leg sheet is reused across many characters —

> "Leg Sprites: Who Gets What? … If you change these leg sprites, other characters and NPCs
> will be changed as well."
> — <https://steamcommunity.com/sharedfiles/filedetails/?id=1404594863>

with per-faction leg sheets (Mobster, Gangster, Soldier, Colombian, Guard, Prisoner, Pardo,
Beard) and separately-sheeted bodies/heads; "severed white heads are shared for the Mafia,
Gang, and Guard factions". Aim is fully free, not 8-directional: "There are separate actions
for movement and Jacket can also aim in any direction"
(<https://www.mobygames.com/game/hotline-miami>). This is *free rotation of a topdown-drawn
sprite* — the sprite is drawn looking "up" and rotated by `aim_angle`; because the view is
directly overhead, rotation never reveals a "wrong" side, which is why HM can get away with
one sprite set instead of 8 directions.

**CS2D — 32×32 sprites, engine-rotated.** CS2D's own Lua `image()` API exposes per-image
rotation modes that only make sense if the engine rotates attached sprites:

> "x=1 - rotate image with player / x=2 - rotate and wiggle image with player / x=3 - rotate
> and wiggle image with player and move correctly with recoil"
> — <https://cs2d.com/help.php?luacat=all&luacmd=image>

So CS2D = free rotation + "wiggle" (the walk cycle is largely a positional/rotational
wobble of a mostly-static body, which is why `wiggle 0/1` exists as a *setting*).

**Running with Rifles — voxel point-cloud soldiers, not sprites at all:**

> "The soldiers are 3D models basically, but made of 3D points rather than the usual polygons,
> and the 3D points are rendered as tiny 2D rectangles in the …"
> — RWR developer, <http://runningwithrifles.com/phpBB3/viewtopic.php?f=4&t=314>
> (also mirrored at `…?f=4&t=301`)

RWR is the existence proof that at this camera angle, **silhouette + colour blocking beats
detail**: soldiers are a few hundred coloured rectangles and read perfectly at gameplay zoom.
It also implies RWR's animations are skeletal (points moving) rather than frame-based.

**Synthesis:** three valid architectures —
(a) one sprite set, free-rotated (HM, CS2D),
(b) 8 directions × N frames (classic pixel-art),
(c) 3D/voxel rendered to 2D (RWR).
(a) is cheapest and gives perfect aiming fidelity; its cost is that the *art* must be drawn
straight-overhead with no perspective, and that per-limb animation cannot be baked into the
body frame (you need separate arm sprites or none).

### 4.2 Recommended Godot sprite-layer architecture

Kangur's design doc already specifies "layered sprites (legs/torso, head, arms+weapon) with
free rotation toward aim". Concretely:

```
Character (CharacterBody2D, y_sort_enabled on parent)
└── Rig (Node2D)                        # rotates? NO — see below
    ├── Shadow        (Sprite2D or MeshInstance/canvas)   z=-1
    ├── Legs          (AnimatedSprite2D)                  # 8-dir OR 1-dir + flip
    ├── Torso         (Sprite2D)                          # 1 sprite, rotated by aim
    ├── Head          (Sprite2D)                          # rotated by aim (+ small lag)
    ├── Arms          (Sprite2D, weapon drawn in)         # rotated by aim
    ├── Muzzle        (Marker2D)                          # muzzle flash/brass origin
    └── Overlay       (Sprite2D: hit flash, shield pips)
```

Critical rules:

1. **Do not rotate the `Rig` node.** Rotate only the *aim-facing* layers (torso, head, arms).
   If you rotate the whole rig, the legs rotate too and the walk cycle always points where
   you shoot — the "tank" look. HM/CS2D decouple them; Kangur must too.
2. **Legs are pick-one-of-8 by *movement*, not aim.** Use `round(move_angle / 45°)` to pick a
   direction row, only when `move.length() > 0.1`; keep the last row when idle. This gives
   directional readability with 1/8 the art of free rotation, and reuses HM's shared-leg
   trick: **one leg sheet per body type, many characters**.
3. **Head/arms get `rotation = aim_angle`** with a small per-layer slew limit (e.g. head
   15°/frame, arms 35°/frame) so a fast flick reads as a body turn rather than a teleport.
   For the player, no limit; for NPCs, this *is* the turn-rate fairness limit (§5.4).
4. **Weapon is part of the arms sprite** (one sheet per weapon class per arm pose), not a
   separate node. A separate weapon node needs its own pivot offset per weapon and will
   drift. If you want attachments, swap the arms sheet, not a child sprite.
5. **`y_sort_enabled` on the map's entity layer, `z_index` reserved for effects.** Godot's
   rule: "Nodes sort relative to each other only if they are on the same `z_index`"
   (<https://docs.godotengine.org/en/stable/classes/class_canvasitem.html>). So put all
   characters at `z_index 0` with y-sort, and use +1/-1 only for decals/projectiles that must
   be flat.
6. **Animation:** `AnimatedSprite2D` for legs (frame lists, `SpriteFrames`), because the
   speed needs to scale with velocity (`speed_scale = |velocity| / reference_speed`) — that
   single property is why frame-based walk cycles are cheap. Use `AnimationPlayer` only if
   you need to animate non-frame properties. Godot documents both approaches and notes
   `AnimatedSprite2D` is the simpler path
   (<https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html>).
7. **Rotation of pixel art:** rotating a 32 px sprite bilinearly blurs it; rotating with
   nearest-neighbour makes it crawl. Kangur's design doc says "Not pixel-cute: crisp,
   readable, slightly gritty" — so draw at 2× the final display size and let the camera zoom
   (1.6 default) bring it down, which gives the rotation enough pixels to survive. Set
   `texture_filter = TEXTURE_FILTER_LINEAR` on character sprites and
   `TEXTURE_FILTER_NEAREST` on tiles, per `CanvasItem.texture_filter`
   (<https://docs.godotengine.org/en/stable/classes/class_canvasitem.html>).
8. **Hit flash / damage feedback:** use `modulate` or a shader on the whole rig (one draw
   call) rather than per-layer tints.
9. **Muzzle point:** `Marker2D` child of Arms at the barrel tip. Because Arms is rotated by
   aim, the muzzle position is correct for free — no per-weapon muzzle offset maths.
10. **Hitboxes stay axis-aligned** (§1.6). One `CollisionShape2D` (circle r≈10) on the body;
    never rotate collision shapes with aim.

Art budget implication: 1 leg sheet per body type (8 rows × 6 frames), 1 torso + 1 head +
N arm sheets (one per weapon class, 1 pose each, since the arm sprite only needs the
"holding this weapon" pose and rotates rigidly). That is dramatically cheaper than 8 × 6
full-body sets and is exactly the HM2 decomposition.

---

## 5. Tactical NPC AI

### 5.1 How fast humans actually are

The best-calibrated public dataset is Woods et al. 2015, *Factors influencing the latency of
simple reaction time* (Front Hum Neurosci 9:131), n=1469:

> "Mean SRT latencies were short (231, 213 ms when corrected for hardware delays) and
> increased significantly with age (0.55 ms/year)"
> "Stimulus detection time (SDT) … averaged 131 ms"
> "Intraindividual SRT SDs (mean 40.0 ms)"
> — <https://pmc.ncbi.nlm.nih.gov/articles/PMC4374455>

**This is the number to calibrate against (fact):** a simple visual reaction to a *known*
stimulus at a *known* location is ~200–230 ms, with ~40 ms trial-to-trial noise, of which
~131 ms is pure sensory detection and the rest is motor output. A *choice* reaction (is that
a friend? which of 3 doors?) is much slower — the same literature's choice-RT figures run
300–450 ms. So:

- **150 ms is superhuman** and should be reserved for Elite/aimbot-adjacent difficulty;
- **200–350 ms is the human band** for "saw a target, decided to shoot";
- **adding 100–200 ms for "noticed something moved"** (pre-attentive detection) is not a
  fudge, it is the SDT plus an attention-switch cost.

### 5.2 How shipped games encode it

**CS:GO's `botprofile.db` is effectively a published personality schema** — it ships with
the game and is widely mirrored. Defaults and difficulty tiers:

| Template | Skill | ReactionTime | AimFocusInitial (deg) | AimFocusDecay | AimFocusOffsetScale | AimFocusInterval |
|---|---|---|---|---|---|---|
| Default | 50 | **0.3 s** | 20 | 0.7 | 0.30 | 0.8 s |
| Fair | 25 | 0.50 s | 12 | 0.5 | 0.35 | 0.60 s |
| Normal | 50 | 0.45 s | 10 | 0.4 | 0.25 | 0.50 s |
| Tough | 60 | 0.40 s | 10 | 0.4 | 0.20 | 0.40 s |
| Hard | 75 | 0.35 s | 5 | 0.3 | 0.17 | 0.30 s |
| VeryHard | 80 | 0.30 s | 1 | 0.1 | 0.05 | 0.05 s |
| Expert | 90 | 0.20 s | 0.1 | 0.05 | 0.03 | 0.03 s |
| Elite | 100 | 0.15 s | 0.01 | 0.01 | 0.01 | 0.01 s |
| ProP | 100 | 0.15 s | ~0 | ~0 | ~0 | ~0 |

— <https://gist.github.com/ianlucas/76cdfb9d662761cfe251f19fcaf6869c> (mirror of the shipped
file; the header credits "Michael S. Booth, Turtle Rock Studios"). Comment strings in the file
define the semantics: `AimFocusInitial` = "initial focus spread in degrees (from desired
center)", `AimFocusOffsetScale` = "controls accuracy when tracking to target (0 == perfect,
should always be < 1)", `AimfocusInterval` = "how often focus is adjusted (smaller intervals
means better movement tracking)".

**This is the single most useful schema in the whole research set**, because it models aim
as *error that decays*, not as a hit probability: the bot has an angular error that shrinks
over time toward the target, with a lower bound set by `AimFocusOffsetScale`. That produces
"bot tracks you, then tightens" — the human-feeling behaviour — and it is trivially
implementable in the `Aim` component.

Also note CS:GO models bot *neck* as a spring-damper with explicit constants
(`LookAngleMaxAccelNormal 5500`, `LookAngleStiffnessNormal 1150`, `LookAngleDampingNormal
110`, and separate `…Attacking` values with damping 50). Two takeaways: turn rate should be
a *physical* limit (accel + damping), and it should be *different* when attacking vs idle.

**Unreal's AI Perception** provides the vocabulary for the sensor model:

> "**Sight Radius** — The max distance over which this sense can start perceiving."
> "**Lose Sight Radius** — The max distance in which a seen target is no longer perceived."
> "**Peripheral Vision Half Angle Degrees** — How far to the side the AI can see in degrees.
> The value represents the angle measured to the forward vector, not the whole range."
> "**Max Age** — Determines the duration in which the stimuli generated by this sense become
> forgotten (0 means never forgotten)."
> — <https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-perception-in-unreal-engine>

Three design lessons: (a) **hysteresis via distinct gain/lose radii** (gain 520, lose 620 —
otherwise AI flickers in and out at the cone edge); (b) **perception memory has an explicit
max age**, separate from the visual; (c) **near-clipping / backward offset** creates a small
360° "something is right behind me" awareness ring, which is how you avoid AI that cannot
notice a knife in its back — Kangur's design doc already has this as the 70 px peripheral ring.

### 5.3 Plan-based behaviour without a planner

F.E.A.R.'s GOAP talk is the canonical argument that behaviour should be *generated*, not
scripted:

> "The FSM for characters in F.E.A.R. has only three states, and we use A* to plan sequences of
> actions as well as to plan paths. … a planning system gives A.I. the knowledge they need to be
> able to make their own decisions about when to transition from one state to another."
> — Jeff Orkin, GDC 2006, "Three States and a Plan: The A.I. of F.E.A.R.",
> <https://web.archive.org/web/20140613121607/http://alumni.media.mit.edu/~jorkin/gdc2006_orkin_jeff_fear.pdf>

Kangur does not need A* over action preconditions; a utility scorer with hysteresis gets 90%
of the perceived intelligence (design doc §9 already specifies this). But F.E.A.R.'s real
lesson is the **decoupling**: actions declare their own preconditions/effects, so adding a
behaviour does not require touching a state machine. Kangur's `Behaviour.score(bb)` /
`enter/tick/exit` interface is the same idea in a lighter form — worth keeping strictly, i.e.
adding `UseEquipment` must never require editing `Engage`.

### 5.4 Squad tactics shipped in comparable games

**Door Kickers 2** (the closest tactical reference) leans on three systems the design doc
should mirror: suppressive fire as a first-class tool ("Light Machine Guns for suppressive
fire"), destructible/breachable geometry, and pause-at-will planning
(<https://inthekillhouse.com/doorkickers2/>). Its patch notes over years show what actually
needed fixing in a topdown tactical AI, which is a useful risk list:

- "AI now correctly engages center of visible mass when engaging partially-covered enemies"
  (<http://inthekillhouse.com/door-kickers-alpha-5-is-out>)
- "Major improvement to enemy AI. They will seek cover. They will move around. Even we can't
  predict what their doing." (<http://inthekillhouse.com/door-kickers-alpha-7>)
- "Friendly AI: troopers will now investigate the direction they are attack from." +
  "new patrol/investigation strategies" (<http://inthekillhouse.com/door-kickers-alpha-4>)
- "Lockpicking. Beware – can be heard by enemies at short range."
  (<https://inthekillhouse.com/door-kickers-alpha-6>)

Read together: **partial cover, cover-seeking, investigating the *direction* of incoming
fire, and audible actions** are the four things that took a shipped tactical AI multiple
iterations. All four are in Kangur's design doc §9 already; the research supports the
priority order (cover seeking and fire-direction investigation first).

**Running with Rifles** shows the cheap end of the spectrum: bots with large sight ranges
and no cone. Its config exposes `max_sight_range_with_muzzle 40`, `leader_sight_range 35`,
`team_member_sight_range 30` (world units), i.e. vision is *range-based and radio-extended*
rather than cone-based. Players complain precisely about the fairness consequence — one
thread asks to "simply get the shot bot to just turn around and scan for the shooter, rather
than give the bot 360 degrees FoV"
(<http://runningwithrifles.com/phpBB3/viewtopic.php?t=1612&p=18779>, unverified full text —
search snippet only; treat as weak evidence). Also relevant: RWR's own wiki notes that
sprinting away reduces your forward view "by around 80%"
(<https://runningwithrifles.fandom.com/wiki/Line_of_Sight,_Vision>, bot-blocked; snippet
only). That supports Kangur's "sprint narrows the cone" rule.

### 5.5 Fairness rules for Kangur (recommendation)

The architecture already mandates "No wallhacks, ever" (`docs/architecture.md` §4). Research
suggests the following *additional* invariants, each of which is testable in a headless sim:

1. **Two radii, hard hysteresis.** Gain 520 px / lose 640 px. Never re-gain a contact from
   memory — re-acquisition requires a fresh cone test.
2. **Radio is a queue, not a broadcast.** `TeamIntel` entries carry `(pos, t_seen, confidence,
   observer)`; consumers must apply `delay ∈ [0.4, 1.5] s` and position noise. A bot may
   never act on a contact whose `t_seen + delay > now`. This is the only defence against
   "squad hivemind", which is the most common complaint about tactical-game bots.
3. **Hearing requires a loudness budget and occlusion.** `sound_emitted` already carries
   `loudness`; the hear test must be `loudness_after_walls > threshold(distance)`, and the
   *direction* should be quantised to ±15–25° (humans localise poorly, especially indoors).
4. **Turn rate is the fairness valve, not reaction time.** Cap angular velocity (e.g.
   180–540 °/s by difficulty) and angular acceleration (CS:GO's spring constants are a good
   template). A bot with a 150 ms reaction and unlimited turn rate still feels like an aimbot;
   a bot with 280 ms and a 300 °/s cap feels like a person.
5. **Aim error decays, it does not vanish.** Model `aim_error_deg(t) = max(floor, initial *
   exp(-t/τ))` with `floor` set by skill. Never let a bot's error reach exactly zero.
6. **Burst discipline as a rule, not a preference.** Fire in bursts whose length is a
   function of range and weapon (2–3 at range, 5–8 close) with an enforced inter-burst pause
   (0.25–0.6 s). This is what makes bot gunfire sound human, and it falls out of the §3.2
   spread model for free if the bot is given the *same* `WeaponModel`.
7. **Cover as an authored-resource query, never as raycast magic.** Kangur's `CoverPoint`
   markers with `lean_dir`, `quality`, `lanes` are the right call; a bot choosing cover must
   not learn whether the *player* can see that point.
8. **Danger memory decays and is team-scoped.** Deaths within 150 px / 6 s raise a local
   danger value that decays over 20–30 s; it must be built only from *witnessed or radioed*
   deaths, never from the global kill log.

### 5.6 Personality parameter ranges (recommendation, informed by §5.2)

Ranges chosen so that Recruit ≈ CS:GO Normal/Hard and Elite ≈ CS:GO Expert, with turn-rate
caps added (which CS:GO does not expose per-difficulty):

| Trait | Recruit | Operator | Veteran | Elite |
|---|---|---|---|---|
| reaction (ms) | 320–450 | 240–360 | 180–280 | 140–220 |
| detection delay before reaction starts (ms) | 250–450 | 180–320 | 120–240 | 80–160 |
| turn rate cap (°/s) | 160–240 | 220–320 | 300–420 | 380–540 |
| aim error initial (°) | 6–9 | 4–6 | 2.5–4 | 1–2.5 |
| aim error floor (°) | 2.0–3.0 | 1.2–2.0 | 0.6–1.2 | 0.3–0.6 |
| aim convergence τ (s) | 0.9–1.4 | 0.7–1.0 | 0.5–0.8 | 0.35–0.6 |
| burst length (rounds) | 2–4 | 3–5 | 3–7 | 4–9 |
| inter-burst pause (s) | 0.5–0.9 | 0.4–0.7 | 0.3–0.55 | 0.22–0.4 |
| aggression (0–1) | 0.15–0.45 | 0.3–0.6 | 0.4–0.75 | 0.5–0.9 |
| caution (0–1) | 0.6–0.9 | 0.45–0.75 | 0.3–0.6 | 0.2–0.5 |
| discipline (cover adherence) | 0.2–0.45 | 0.35–0.6 | 0.5–0.75 | 0.65–0.9 |
| campiness | 0.1–0.5 | 0.1–0.45 | 0.05–0.4 | 0.05–0.3 |

Cross-check vs published bot data: CS:GO's shipped `ReactionTime` ranges 0.15–0.50 s across
all nine tiers, and Kangur's 140–450 ms matches that band almost exactly — so these are not
invented. The *detection delay* (a second delay before the reaction clock starts) is
Kangur-specific and is what stops bots insta-snapping to a player who peeks for 80 ms.

---

## 6. Audio occlusion in 2D

### 6.1 The mechanism, and what Godot gives you

Godot's 2D positional audio is a distance-attenuated `AudioStreamPlayer2D` with an
attenuation exponent, a `max_distance`, and an `area_mask` that redirects sound into a bus:

> "Plays audio that is attenuated with distance to the listener. … By default, audio is heard
> from the screen center."
> "**attenuation** — The volume is attenuated over distance with this as an exponent."
> "**max_distance** — Maximum distance from which audio is still hearable."
> "**area_mask** — Determines which Area2D layers affect the sound for reverb and audio bus
> effects. … An example of how you might use this is making a 'water' area so that sounds
> played in the water are redirected through an audio bus…"
> — <https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer2d.html>

And the muffling primitive is a bus effect:

> "A 'low-pass' filter attenuates frequencies higher than AudioEffectFilter.cutoff_hz and
> allows lower frequencies to pass unchanged. **This filter can be used to muffle sounds.**"
> — <https://docs.godotengine.org/en/stable/classes/class_audioeffectlowpassfilter.html>

Buses are routed right-to-left and effects are applied in order; Godot auto-disables silent
buses (so a per-occlusion bus is cheap when unused) —
<https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html>. Note the dB scale:
"Every 6 dB below the 0 dB limit, sound energy is halved … sound is considered no longer
audible between -60 dB and -80 dB" (same page) — so a "one wall" penalty of −6 dB is a
*halving*, which is a much bigger perceptual change than −6 suggests if you are used to
linear gain.

### 6.2 The standard implementation pattern (secondary source, but concrete)

A widely-copied implementation note describes the canonical approach: raycast listener→source
on a dedicated occlusion layer at 10–30 Hz (not per frame), cache, then apply
`AudioEffectLowPassFilter` cutoff mapped from an occlusion factor plus a volume reduction:

> "Implementation performs periodic raycasts (10-30Hz, not per-frame), caches results with
> timeout, applies AudioEffectLowPassFilter with cutoff frequency based on occlusion, and
> adjusts volume."
> "**LPF cutoff range:** 300Hz (full occlude) to 20kHz (clear); **Volume reduction:** -10 to
> -20dB at full occlusion; **Occlusion factors:** Wood 0.6, Concrete 0.85, Metal 0.95"
> — <https://github.com/raduacg/game-mechanics-optimizations/blob/main/112_audio_occlusion.md>

Treat the specific constants as one developer's defaults, not gospel (this is a community
document, not an engine vendor). The *pattern* — sparse raycasts, cached factor, LPF + gain,
smoothed transitions — is corroborated by every game-audio discussion of the topic and is
what Kangur's `OcclusionMath` should implement. Note that the same document explicitly says
"When NOT to Use: **2D games** — no 3D spatial audio to occlude", which is wrong for Kangur
(Kangur's occluders are walls between rooms, which is exactly the case where occlusion
matters) — an example of why to trust the mechanism and not the blanket advice.

### 6.3 Recommended model for Kangur

The design doc already specifies four buses (Open / Light / Heavy / Muffled by wall count).
Make the mapping explicit and data-driven, one row per wall count:

| walls crossed | bus | `cutoff_hz` | `volume_db` | audible gunshot range |
|---|---|---|---|---|
| 0 | Open | 20000 | 0 | 1600 px |
| 1 | Light | 3500 | −3 | ~1100 px |
| 2 | Heavy | 1400 | −8 | ~700 px |
| 3+ | Muffled | 600 | −14 | ~400 px |

Rationale: the cutoff halving per wall roughly tracks real transmission loss through stud
walls (highs die fast, lows persist) and keeps the *character* of a gunshot recognisable at
2 walls, which is the gameplay-critical case ("I heard a fight next door"). **Opinion:** do
not go below ~500 Hz for gunshots or they stop reading as guns; below that they read as
thumps and players lose the ability to identify weapon class, which Insurgency treats as a
core skill (§3.3).

Implementation constraints from Godot's API:

- **Pool buses, don't create one per sound.** `AudioStreamPlayer2D.bus` takes a name; a small
  fixed set of occlusion buses (one per wall count per category) avoids bus churn.
  `max_polyphony` on the player caps simultaneous instances of the same sound
  (<https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer2d.html>).
- **Raycast on the SOUND_MASK layer only, at 10–20 Hz**, from `AudioListener2D` (or the
  camera) to the source, cached per source with a ~100 ms TTL. Kangur's architecture already
  has `Layers.SOUND_MASK` (§2 of architecture.md).
- **Smooth the transition** (`lerp` cutoff/volume over ~150 ms); a hard switch between buses
  clicks.
- **Headless must no-op** — `AudioDirector` already guards on
  `DisplayServer.get_name() == "headless"` (architecture §3). Occlusion maths can still run
  (it is used by AI hearing), it just must not touch buses.

### 6.4 Footstep surface variety

Kangur already has `Enums.Surface` (CONCRETE, SAND, METAL, GRASS, WOOD, GLASS, WATER) and
tile custom data. Two Godot-specific cheap wins:

- **`AudioStreamRandomizer`** for per-surface footstep sets: it randomly picks a stream *and*
  applies pitch variation — `random_pitch` default 1.1, "Pitch will be randomly chosen within
  a range of `1.0 / random_pitch` and `random_pitch`"
  (<https://docs.godotengine.org/en/stable/classes/class_audiostreamrandomizer.html>).
  Without pitch variation, 4 samples repeat audibly within ~10 steps.
- **Couple step rate to distance travelled, not time.** Accumulate
  `step_accum += |velocity| * dt` and fire a step every `stride_px` (≈ 24–32 px for a walk,
  ≈ 40–48 for a sprint at 32 px/m). This makes the "sneak = no sound" rule (CS2D §1.2) and
  the "sprint = loud" rule fall out automatically, and it is the one place where the
  sprite/animation stride and the audio can be kept in sync.

### 6.5 Gunshot distance model

A gunshot is not one sound. Kangur's design doc already specifies "layered fire sound (close
crack + mechanical action + distant tail)". Model it as three emitters with different
`max_distance` and different occlusion behaviour:

| layer | max_distance | occluded? | purpose |
|---|---|---|---|
| mechanical (action, brass) | ~200 px | yes, strongly | tells you *someone* is reloading/cycling nearby |
| crack (supersonic) | ~900 px | yes | localises the shooter |
| tail / reverb | ~1600 px | partially (walls add, don't remove) | tells you a fight is happening, direction only |

This is the mechanism behind Insurgency's "you can determine… if they're outside or inside,
what kind of room they're in" (§3.3): the *tail* differs by room, and only the tail survives
distance. **Opinion:** it is also the cheapest possible "living world" feature — one extra
emitter per shot at 1600 px range makes every firefight audible across the map.

---

## 7. Kangur recommendations

Concrete, drop-in values. Everything here is either quoted above or **(computed)** from the
quoted formulas; anything marked *opinion* is a judgement call for playtesting.

### 7.1 Movement constants (`MovementModel` config)

```gdscript
# 32 px = 1 m. Source-style: friction first, then accelerate, per tick.
# accel is a RATE (1/s): accelspeed = accel * max_speed * dt  -- do NOT use px/s^2.
const ACCEL := 10.0          # 1/s  (CS:GO 5.5, SDK default 10)
const FRICTION := 9.0        # 1/s  (CS:GO 5.2)
const STOPSPEED := 60.0      # px/s (CS:GO 80 u/s; 60 px/s ~= 1.9 m/s)

const SPEED_CROUCH := 65.0   # px/s
const SPEED_WALK := 130.0    # px/s   (CS2D base = 120; +8% for readability)
const SPEED_SPRINT := 215.0  # px/s
const FOCUS_MULT := 0.5
const CRIPPLE_MULT := 0.55
const WEAPON_SPEED_STEP := 60.0  # px/s per CS2D weight unit, measured:
                                 # (2.0+w)*1.2*50 gives 120 + 60*w for every w in the table
```

Derived feel **(computed)**: 90% of walk speed in 0.20 s; stop from walk in 0.19 s / 0.33 m;
90% of sprint in 0.19 s; 180° reversal from sprint crosses zero in ~0.07 s. Keep the doc's
stamina numbers (sprint −18/s, regen +12/s after 1 s) but express sprint drain per *metre
travelled* as well, so a stationary "sprint" key hold cannot drain stamina.

**Fix required in the design doc:** replace "Ground accel 1400 px/s², friction coefficient
10/s (exponential decay)" — those two numbers give a terminal speed of 140 px/s (§2.3) and
cannot reach 215 px/s sprint without clamping. Use the rate-based pair above.

**Weapon weight, CS2D-style (recommended):** additive px/s penalty from `WeaponDef.weight`,
using CS2D's *measured* slope of **60 px/s per weight unit** (verified: CS2D's
`(2.0 + w) × 1.2 × 50` yields exactly `120 + 60·w` for every weight in its table — knife
+0.75 → +45, pistol +0.5 → +30, AWP −0.5 → −30). Kangur's speeds are 1.08× CS2D's, so map
`weight` to ±0.5 and scale by 60. That gives pistol +30 px/s, LMG −30 px/s — legible, and one
constant instead of a multiplier curve. This is more legible than a multiplier and matches
CS2D's published scheme (§1.2).

### 7.2 Draft weapon table (14 weapons)

12 from the design doc roster plus two additions (**wasp**, **ibex**) that fill real gaps
(5.7 PDW class, semi-auto sniper). RPM/damage/reload anchored to CS2/CS2D categories (§1.3,
§3.5); `bullet px/s` keeps the doc's compression (§3.4); spread columns are the §3.6 class
values. "TTK torso" is **(computed)** against design-doc torso HP 70.

| id | Name | Cat | Modes | RPM | Mag | Dmg | Pellets | Bullet px/s | base° | bloom/shot | max° | reset s | run× | Reload s | TTK torso |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `adder` | P-9 "Adder" | pistol | SEMI | 420 | 17 | 24 | 1 | 4600 | 0.7 | 0.55 | 3.5 | 0.30 | 4.0 | 1.9 | 3 hits / 0.29 s |
| `judge` | R-357 "Judge" | pistol | SEMI | 150 | 6 | 55 | 1 | 5200 | 0.6 | 0.90 | 4.5 | 0.42 | 4.5 | 2.4 | 2 hits / 0.40 s |
| `vespa` | SMG "Vespa" | smg | AUTO/SEMI | 800 | 32 | 20 | 1 | 4400 | 0.9 | 0.35 | 4.5 | 0.28 | 5.0 | 2.2 | 4 hits / 0.23 s |
| `kedr` | SMG "Kedr" | smg | AUTO | 1000 | 20 | 18 | 1 | 4200 | 1.1 | 0.30 | 5.5 | 0.26 | 5.5 | 2.0 | 4 hits / 0.18 s |
| `wasp` ★ | PDW "Wasp" 5.7 | smg | AUTO/SEMI | 900 | 30 | 17 | 1 | 5000 | 0.8 | 0.30 | 4.0 | 0.26 | 4.5 | 2.3 | 5 hits / 0.27 s |
| `kestrel` | AR "Kestrel" | ar | AUTO/BURST/SEMI | 650 | 30 | 30 | 1 | 6200 | 0.5 | 0.40 | 5.0 | 0.40 | 6.0 | 2.5 | 3 hits / 0.18 s |
| `volk` | AR "Volk" 7.62 | ar | AUTO/SEMI | 600 | 30 | 34 | 1 | 6000 | 0.55 | 0.50 | 5.5 | 0.44 | 6.5 | 2.7 | 3 hits / 0.20 s |
| `falx` | BR "Falx" | br | SEMI/BURST | 300 | 20 | 46 | 1 | 7000 | 0.35 | 0.60 | 6.0 | 0.50 | 7.0 | 2.6 | 2 hits / 0.20 s |
| `sokol` | DMR "Sokol" | dmr | SEMI | 260 | 15 | 55 | 1 | 7600 | 0.30 | 0.65 | 6.0 | 0.52 | 7.0 | 2.8 | 2 hits / 0.23 s |
| `ibex` ★ | SR "Ibex" (semi) | dmr | SEMI | 120 | 10 | 85 | 1 | 8200 | 0.20 | 1.10 | 7.0 | 0.58 | 8.0 | 3.1 | 1 hit / — |
| `lynx` | SR "Lynx" (bolt) | sniper | BOLT | 45 | 5 | 110 | 1 | 9000 | 0.15 | 1.50 | 8.0 | 0.60 | 8.0 | 3.4 | 1 hit / — |
| `mule` | LMG "Mule" | lmg | AUTO | 700 | 100 | 28 | 1 | 6000 | 0.8 | 0.30 | 7.0 | 0.55 | 6.5 | 5.2 | 3 hits / 0.17 s |
| `breve` | SG "Breve" (pump) | shotgun | PUMP | 70 | 6 | 12 | 8 | 4000 | 4.0 | 0.0 | 6.0 | 0.35 | 5.0 | 4.2 | 1–2 volleys |
| `automa` | SG "Automa" (semi) | shotgun | SEMI | 240 | 8 | 10 | 6 | 3900 | 4.5 | 0.0 | 6.5 | 0.32 | 5.0 | 3.6 | 1–2 volleys |

Notes:

- **RPM is the authoritative fire-rate field**, not CS2D's labelled RPM (§1.3.2).
  `kestrel` 650 RPM matches the design doc; `volk` 600 matches CS2's 600.
- **`judge` is 2-hit at 150 RPM** — a 0.40 s TTK with a big cone is the intended
  high-skill/high-payoff sidearm.
- **`wasp`** exists because the roster had a 750–1000 RPM hole between `vespa`/`kedr` and
  nothing: a low-recoil, low-damage 5.7 PDW gives Recon a second archetype. **`ibex`** exists
  because `sokol` (DMR) and `lynx` (bolt) left no semi-auto sniper, which is the most-used
  sniper archetype in both CS and Tarkov.
- Shotgun damage is per pellet; 8 pellets × 12 = 96 max, which one-volleys an unarmored torso
  at contact and needs 2 volleys past ~8 m once falloff applies. Falloff for shotguns should
  be steep: `falloff_start` 96 px, `falloff_end` 320 px, `min_mult` 0.25.
- Keep the design doc's body multipliers (head ×3.5, torso ×1.0, arms ×0.75, legs ×0.8), but
  be aware of an arithmetic consequence: with head = 30 HP and ×3.5, any hit of ≥ 8.6 base
  damage kills, so **every weapon in the table one-shots the head** — including the 17-damage
  `wasp` (17 × 3.5 = 59.5). So in the current design a headshot is not a marksmanship reward,
  it is simply "you hit the head box, they die", and the ×3.5 is decorative. Three options:
  (a) raise head HP to ~55–70 so only rifles/DMR/sniper one-shot; (b) drop the multiplier to
  ~1.5 and keep head HP 30, making headshots a 2-hit for pistols and 1-hit for rifles;
  (c) keep it as-is and accept "any head hit kills". **Flag for design** — this is the single
  biggest unresolved lethality decision in the roster, and option (a) preserves both the
  Hotline Miami feel and a reason to aim.
- **Conflict with the design doc's stated TTK band (flag for design).** Design §6 targets
  "rifle 3 hits ≈ 0.28–0.4 s". A 3-hit kill at 650 RPM is 2 × 0.092 = **0.185 s**, not
  0.28 s — the arithmetic cannot satisfy both constraints at that RPM. The TTK column above
  keeps the *hit count* (3) and lets TTK fall where the RPM puts it, because RPM in the
  600–700 band is well-anchored (CS2's AK is 600, CS2D's AK is published at 500–1000) and a
  rifle that needs 0.3 s for 3 hits would imply ~400 RPM, which is LMG/marksman territory.
  Either accept rifle TTK ≈ 0.18–0.20 s (Hotline Miami-appropriate, and consistent with
  Insurgency's "one or two shots"), or lower rifle damage to ~24 so it needs 3 hits at a
  slower RPM — but then `kestrel` and `vespa` converge. **Opinion:** accept the faster TTK and
  fix the design doc's band rather than the RPM; the band looks like it was written for a
  500 RPM rifle and never re-derived.

### 7.3 Spread / recoil formulas (final)

```
# Ballistics.spread_deg(w, state) -> float
cone = (w.base_deg + state.bloom_deg) *
       move_mult(state.speed_ratio) *
       stance_mult(state) *
       (w.focus_mult if state.focus else 1.0) *
       (1.6 if state.arm_crippled else 1.0)

move_mult(r) = 1.0 + (w.run_mult - 1.0) * clamp(r, 0.0, 1.0)   # r = |vel| / sprint_speed
stance_mult  = 0.75 (crouch) | 1.0 (stand)

# Ballistics.bloom_tick(w, state, dt)
if state.firing:  state.bloom = min(w.bloom_max, state.bloom + w.bloom_per_shot)
else:             state.bloom *= exp(-dt / w.tau)     # tau = w.reset_time / 3.0
if state.bloom < 0.02: state.bloom = 0.0              # snap: exponential never reaches 0

# Ballistics.first_shot_is_true(w, state)
#   true when state.bloom == 0.0 and state.speed_ratio < 0.10 and not state.arm_crippled

# Ballistics.apply_recoil(w, state) -> Vector2 kick_px
kick = w.recoil_kick * (0.55 if state.focus else 1.0) * (0.85 if state.crouch else 1.0)
# direction: mostly backward along aim + lateral jitter
angle = aim_angle + PI + randf_range(-0.35, 0.35)   # ±0.35 rad lateral spread
# recovery: w.recoil_recovery (1/s) exponential return toward pre-fire aim
```

Recoil recovery: critically-damped spring toward zero, κ ≈ 12/s, ζ ≈ 0.9 (reuse Source's
`PUNCH_DAMPING 9.0` / `PUNCH_SPRING_CONSTANT 65.0` as a starting point — those are the
constants in `gamemovement.cpp` for view punch, and they are tuned). Camera kick = 0.25 ×
crosshair kick.

Sanity targets (`computed`, from §3.2): with `kestrel` base 0.5° the cone at 20 m is 11 px
(≈ torso width) — torso-accurate at full rifle range from standstill. Crouched it is 0.375°
→ 4 px at 20 m. At sprint (`run_mult` 6) it is 3° → **34 px at 20 m**, i.e. wider than a
torso, which is the point.

**Shotgun caveat:** the movement multiplier must *not* be applied to a shotgun's pellet cone
at full strength — `breve` at `base_deg` 4.0 with `run_mult` 5 becomes a 20° cone (233 px
radius at 20 m), which is a cartoon. Gate it: `spread_deg = (base + bloom) * (1 + 0.15 *
(run_mult - 1) * r)` for shotguns, or simply cap the final cone at 12° for all weapons. Cap
is simpler and also protects against a crippled-arm + sprint + focus-stacking edge case.

**Mapping to the real `WeaponDef` schema** (`src/core/data/weapon_def.gd`) — the table above
uses research field names; author the `.tres` with these:

| Research field here | `WeaponDef` field | Conversion |
|---|---|---|
| `base_deg` | `spread_base` | 1:1 (degrees, half-angle) |
| `bloom_per_shot` | `bloom_per_shot` | 1:1 |
| `max°` | `bloom_max` | 1:1 — **absolute** cap, i.e. `bloom_max - spread_base` is the usable bloom budget |
| `reset s` | `bloom_recovery` | `bloom_recovery = bloom_max / reset_time` (deg/s, linear drain) or keep the schema's linear rate and accept a ~3× longer full reset than the exponential model |
| `run×` | `move_penalty_scale` | 1:1 if `Ballistics.move_mult` is `1 + (scale-1)·r` |
| `RPM`, `mag`, `reload s` | `rpm`, `mag_size`, `reload_time` | 1:1 |
| — | `reserve_mags` | set 4–6 (CS2 AK: 90 reserve / 30 mag = 3 mags; Kangur's longer matches justify 5) |
| — | `weight` | kg-ish; drives `move_speed_mult` (see §7.1 additive-weight note) |
| — | `recoil_kick`, `recoil_recovery` | 0.8–2.2° kick, 3.0–5.0 /s recovery |

**Conflict to resolve when authoring:** the schema's `bloom_recovery` is a *linear rate*
(deg/s) while §3.6 recommends exponential decay with `tau = reset_time/3`. Linear is simpler
but produces a hard "fully recovered" instant and no recovery at all while bloom is 0. Either
is fine — pick one in `Ballistics` and document it; do not let two weapons be tuned against
different models. **Opinion:** exponential, because it makes tap-firing feel analogue
(every extra 50 ms of patience helps) instead of binary.

### 7.4 AI parameter ranges

Use §5.6's table verbatim as `DifficultyDef` content. Add these hard invariants to the sim
harness (each is a one-line assertion):

1. `assert contact.t_seen + radio_delay <= now` before any behaviour consumes it.
2. `assert bot.aim_error_deg >= difficulty.aim_error_floor` every tick.
3. `assert |bot.angular_velocity| <= difficulty.turn_rate_max`.
4. `assert not bot.can_see(enemy)` for any enemy not in `bot.memory` (no direct reads).
5. Radio delay sampled per message from a seeded RNG, **not** per bot per frame (otherwise
   it averages out and the delay disappears).

### 7.5 Character sprite-layer plan

```
Character (CharacterBody2D, y_sort_enabled = true, z_index = 0)
├── Body      CollisionShape2D(circle, r = 10)          # never rotates
└── Rig       Node2D                                     # never rotates
    ├── Shadow      Sprite2D                z = -1, no rotation
    ├── Legs        AnimatedSprite2D        8 rows × 6 frames; row = move dir; speed_scale
    ├── Torso       Sprite2D                rotation = aim
    ├── Head        Sprite2D                rotation = aim (slew-limited for NPCs)
    ├── Arms        Sprite2D                rotation = aim; weapon painted in
    │   └── Muzzle  Marker2D                barrel tip, inherits aim rotation
    └── Overlay     Sprite2D                hit flash, armor pips
```

- **Leg sheet is shared per body type** (HM2 pattern, §4.1): one 8×6 sheet reused by every
  character of that build. Torso/head/arm sheets are per character/faction.
- **Arm sheets are per *weapon class*** (pistol / SMG / rifle / shotgun / LMG / sniper /
  melee), one pose each. Rotation is rigid, so one pose suffices.
- **8-dir legs, free-rotate upper body.** This is the hybrid that gives HM's aiming fidelity
  with pixel-art leg readability, and it is exactly what CS2D's `image()` rotation modes
  enable (§4.1).
- Draw at 2× display size, `TEXTURE_FILTER_LINEAR` on characters, `NEAREST` on tiles (§4.2
  point 7).
- NPC turn-rate limits live on the Head/Arms rotation, **not** on the legs — so a bot can
  strafe while its aim catches up, which is the human tell.

### 7.6 Audio pipeline summary

Four occlusion buses by wall count (Open/Light/Heavy/Muffled at 20 kHz/3.5 kHz/1.4 kHz/600 Hz,
0/−3/−8/−14 dB), sparse 15 Hz raycasts on `SOUND_MASK`, 150 ms smoothing, per-surface
`AudioStreamRandomizer` footstep sets with `random_pitch ≈ 1.12`, distance-accumulated step
trigger, and three gunshot layers (mechanical 200 px / crack 900 px / tail 1600 px). Full
table in §6.3–6.5.

### 7.7 How to verify these numbers landed (per `kangur-verify`)

Everything in §7 is data, so it is verifiable without a screenshot:

| Recommendation | Test that proves it |
|---|---|
| Movement constants | `MovementModel` unit test: from rest, assert `t90` within ±20 ms of §2.3's table; assert `A/F > max_speed` (the bug in §2.3 would fail this immediately) |
| Weapon table | TTK sim table: torso HP 70, assert hits & TTK within ±15% of §7.2's `TTK torso` column (the design doc's stated gate) |
| Spread/recoil | Unit test on `Ballistics`: first shot after `reset_time` is exactly `base_deg`; 10 s of held fire at `rpm` saturates at `bloom_max`; cone monotonic in `speed_ratio` |
| AI ranges | Fairness sim: assert the five invariants in §7.4 every tick; win rates 45–55% over 200 seeds |
| Sprite layers | Screenshot fixture (`tools/shot_rig.tscn`): 8 leg directions × 8 aim angles, inspect that legs do not rotate with aim |
| Audio occlusion | Unit test `OcclusionMath.wall_count → {bus, volume_db, cutoff}` against §6.3's table; manual listen for bus clicks |

**Opinion:** the movement test is the highest-value one in the list. The `A/F` assertion is a
one-liner that permanently prevents the class of bug found in §2.3 (a terminal speed below
the design's own top speed), and it costs nothing to keep.

---

## 8. Conflicts found, and open questions

1. **CS2D's published RPM vs its own FD/DPS columns disagree by exactly 2×** (§1.3.2).
   Unresolved — CS2D's site does not state a tick base. Do not use CS2D fire rates as
   ground truth.
2. **CS2D reload is quoted "in frames" with no tick base**; 275 frames for an AK is 2.75 s at
   100 fps or 5.5 s at 50 fps. Unresolved. Kangur uses CS2 reload times.
3. **The design doc's movement constants are internally inconsistent** (§2.3): accel
   1400 px/s² with exponential friction 10/s has a 140 px/s terminal speed, below the 215 px/s
   sprint. Fixed by the rate-based form in §7.1.
4. **Real muzzle velocity: Tarkov vs cartridge tables differ by 5–8%** for the same
   cartridge (§3.4). Both are plausible; use class ranges.
5. **Kangur's "~3× compression" is actually 2.4–3.4× depending on class** (§3.4). Cosmetic,
   but the doc should not claim a single factor.
6. **Head damage is trivially lethal for every weapon** given head HP 30 and the ×3.5
   multiplier (§7.2). Needs a design decision: raise head HP, lower the multiplier, or accept
   that headshots are automatic.
7. **The design doc's rifle TTK band (0.28–0.4 s for 3 hits) is arithmetically incompatible
   with 600–650 RPM** — it implies ~400 RPM (§7.2). Resolve by keeping RPM and widening the
   band, or by re-deriving the band from the hit count.
8. **CS2D has no headshots at all** (author, §1.3.4), which means there is no lineage for
   Kangur's per-part damage — it is a new mechanic and needs its own playtest loop.
9. **No source gives a CS2D vision-cone angle.** Any "CS2D is 90°" claim found in the wild is
   invented; Kangur's 100°/520 px is a design choice.

## 9. Known imperfections

- **Single-sourced:** the `AudioStreamRandomizer` pitch semantics and `Camera2D` drag-margin
  semantics come only from Godot's class reference (authoritative, but one source). The
  occlusion *numbers* (300 Hz, −10..−20 dB) come from one community document and are labelled
  as such in §6.2.
- **Weak evidence:** the two Running with Rifles forum threads cited in §5.4 return HTTP 404
  to direct fetch; only search snippets were available. The RWR sight-range config values are
  from a snippet of a forum post quoting the game's XML, not from the shipped file.
- **Not verified against a running game:** none of the CS2D numbers were reproduced in-game;
  they are as-published. The `botprofile.db` mirror could differ from the currently shipped
  file in a patch.
- **Skipped deliberately** (out of scope for the six topics, or low value): sound-engine
  internals (Wwise/Steam Audio) beyond the LPF pattern; networking/lag compensation; Steam
  Audio's real geometric occlusion (Kangur is 2D and GL Compatibility, so it is not
  available); CS2's actual recoil *pattern* tables (they are per-weapon arrays not published
  as data); AI cover-selection algorithms beyond the Door Kickers patch-note evidence.
- **All "computed" numbers assume 60 Hz physics and 32 px/m**; at a different tick rate the
  ramp times shift by <5%.
- The `min_mult`/falloff and shotgun pellet values in §7.2 are *opinion* extrapolated from
  CS2D's 50–400 px range fields, not measured.