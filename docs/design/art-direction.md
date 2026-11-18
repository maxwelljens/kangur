# Kangur — Art Direction

**Identity**: clean vector operators + holographic HUD + gritty industrial
maps. Near-future PMC Europe. Readability first: silhouettes, faction color,
stance state. The CS2D resemblance lives in camera, pacing, cone fog, and
layout — the art is original, cohesive, and license-clean (the asset library
has NO usable topdown soldier sprites; music packs are license-blocked for
open source; see `docs/research/asset-inventory.md`).

Everything gameplay-visual is **procedural/original** (code-drawn or generated
atlases). Curated CC0/CC-BY audio only. Menu key art + emblems generated.
Designers tune palettes/params in data, never need to draw to add content.

## 1. Characters — procedural vector rig (`entities/rig.gd`, Node2D `_draw`)

Single canvas item per character, drawn in local space, rotated to aim.
Parts (draw order): blob shadow → legs → torso → head → arms → weapon →
status overlays. All shapes Polygon2D-style paths via `draw_colored_polygon`
/ `draw_line` / `draw_circle` (anti-aliased: `draw_set_transform` + MSAA 2D
project setting if needed; test via screenshot).

- **Legs**: two capsules, swing phase from velocity (walk cycle), tucked when
  crouched, splayed on death.
- **Torso**: rounded rect ~18×14 px, armor plate lines, faction accent stripe,
  class silhouette cue (backpack: support ammo box / recon antenna / breacher
  shield plate / marksman ghillie strands / assault chest rig).
- **Head**: helmet circle r≈6 with visor arc (faction-tinted glint), rotates
  with aim; crouch → whole rig scale 0.82 + head lowered.
- **Arms**: two capsules shoulder→grip; both hands on weapon when firing/
  focused; one arm drops for reload (mag hand), moves to torso for bandage
  (white wrap flash), pistol one-handed when sidearm.
- **Weapon**: procedural silhouette from `WeaponDef` visual params
  (body_len, barrel_len, width, mag_offset/len, stock, scope, color).
  Gunmetal + faction accent dot. Muzzle at barrel tip (gameplay muzzle pos
  comes from the same params — visuals and ballistics agree).
- **States**: idle breathe bob · walk swing+bob · sprint lean · crouch tuck ·
  focus brace · recoil kick (weapon+arms push back along aim, spring recover) ·
  reload mag anim · bandage channel · hit flinch (offset + red flash 80 ms) ·
  death collapse (rotate ~90°, splay, blood pool grows) · flashblind (white
  overlay + stagger) · bleed droplet particles when wounded.
- **Size**: footprint ~26 px, collision r=10. At the default zoom 1.8 ≈ 47 px on
  screen (was 1.6 ≈ 42 px; see Settings → Camera zoom, 1.0–2.4).
- **Faction palettes** (colorblind-safe blue vs orange):
  BASTION slate `#3E5C76` + amber `#F2A541`; SIROCCO burnt `#C4552D` +
  gunmetal `#4A4E54`. Visor glint: BASTION cyan, SIROCCO red-orange.
- **Rig hook**: optional texture overlay per part (`Texture2D` fields) so
  future hand-drawn art can replace vectors without code changes.

## 2. Effects & decals (all procedural)

- **Muzzle flash**: 4-point star polygon + transient PointLight2D (0.06 s,
  energy 1.2, warm). Shotgun: wider fan. No external light masks needed.
- **Tracers**: thin bright line (WeaponDef.tracer_color), length ~ speed×0.016,
  fade 60 ms. Pellets thinner/dimmer. Sniper: brighter + faint crack line.
- **Brass**: tiny rects ejected perpendicular to aim, arc + spin, fade 1.2 s,
  cap 120 FIFO. Shotgun shells red.
- **Blood**: dark red `#7A1F1F` splat polygons + directional spray on hit;
  pools grow under corpses; cap 250 FIFO. Gore off → gray spark decals only.
- **Bullet chips**: gray sparks + permanent small chip marks on walls (cap 300).
  Glass shatter: cyan shard burst + crack decal, then open.
- **Explosions**: frag = flash circle + smoke puffs + shockwave ring + shake;
  flash = white screen overlay (LOS-gated) + ringing; smoke = growing
  gray cloud polygon (vision blocker, 12 s, soft edges via shader or layered
  translucent circles).
- **Hitmarkers**: white X (hit) / red X (kill) at crosshair, 120 ms.
- **Damage direction**: red arc at screen edge toward damage source, 0.6 s.

## 3. Maps — procedural tile atlases (`tools/gen_tiles.gd`)

32×32 tiles generated via Image API into atlases (committed PNGs + .import),
palettes in `data/palettes/` (designer-editable Resources). Surfaces:
- concrete: gray speckle + panel seams · sand: ochre grain + wind ripples ·
  metal: plate + rivets (+ grating variant) · grass: green noise + blades ·
  wood: planks · water: blue tint + animated shader shimmer.
Walls: 16-variant bitmask autotile per material (concrete block, brick,
container side). **Low cover** tiles (crate wood-X, sandbag, car top) drawn
with top-face highlight so "shoot over / hide behind" reads instantly.
**Glass**: cyan translucent + frame, crack overlay stage.
Props as tiles/vector: containers (corrugation lines, muted colors), cars
(roof + windshield), fountain (circle + water), church (roof + cross),
desks, pillars. Minimap bake uses same palette (walls dark, floors tinted,
low cover mid-tone).
Dusk maps: CanvasModulate `#2A3040` + PointLight2D lamps/flare + LightOccluder2D
on walls (2D shadows; verify Compatibility renderer via screenshot).

## 4. HUD & menus — holographic, code-built theme

- Palette: holo cyan `#7BEBD4` (matches Wenrexa pack if used as accent),
  amber `#F2A541` alerts, faction colors, near-black panels `#0B0E14` @ 85%.
- Widgets: thin 1 px lines, bracket corners, subtle scanline shader, tabular
  numerals. Built from StyleBoxFlat/StyleBoxLine + custom `_draw` widgets
  (body diagram, minimap frame, ticket bars, objective chain). One theme
  resource + `ui/theme.gd` palette consts — restyle the game in one place.
- Wenrexa hologram textures: optional accents ONLY if license verified CC0/
  equivalent (inventory §license); code theme is the source of truth.
- Fonts (OFL, fetched in UI wave): **Chakra Petch** (display/UI) +
  **Share Tech Mono** (numerals/killfeed). Google Fonts GitHub raw TTFs.
- Crosshair: 4 brackets expanding with live bloom + center dot; presets
  (brackets/cross/dot), color setting; hitmarker overlay.
- Menus: **procedural vector title diorama** (parallax dusk European port:
  gradient sky, crane/container silhouettes, control tower, wet-concrete
  reflection, holo grid + scanlines, faction emblems) — cohesive with the
  in-game vector art. Image generation is unavailable in this environment;
  emblems are hand-authored SVG (`assets/ui/art/*.svg`, original, EUPL).
  Lobby map cards: baked minimap + briefing text.
- Motion: 120–180 ms eases, staggered list entrances, hover glow, button
  press depth. Respect `make-interfaces-feel-better` principles.

## 5. Audio art (curated, see credits)

Gunshots layered (close crack + mech action + distant tail), per-surface
footsteps, occlusion buses (design §12), adaptive tension music (CC0/CC-BY
sources per `docs/research/music-sources.md`), CC0 ship-voice barks processed
as radio (bandpass + slight pitch per faction). Mix: master/sfx/music/voice.

## 6. Verification

Every visual system ships with a screenshot fixture (`tools/shot_*.tscn`):
rig states sheet, tile atlas sheet, HUD mock, menu screens. `tools/verify.sh`
captures them; regressions are visible diffs. Art params live in data/consts —
no hardcoded colors in draw code (palette refs only).
