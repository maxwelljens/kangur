// SPDX-License-Identifier: EUPL-1.2
//
// Kangur promo compositor.
//
// Renders a 95-second trailer as a pure function of time: SVG frames (Deno),
// rasterised 8-way in parallel with rsvg-convert, assembled with ffmpeg and
// scored with the game's own soundtrack. Gameplay footage is captured in-engine
// (tools/promo/capture.sh) as PNG sequences; title/outro cards are procedural.
//
// Usage:
//   deno run -A docs/media/promo/promo.ts [--placeholders] [--out PATH]
//       [--gif-out PATH] [--footage DIR] [--fps 30] [--width 1920]
//       [--at T] [--keep-frames] [--gif-window START:END]
//
// Requires: deno, rsvg-convert (librsvg), ffmpeg (libx264 + palettegen),
// Chakra Petch + Share Tech Mono in the project's assets/ui/fonts (falls back
// to DejaVu Sans / DejaVu Sans Mono).

// ---------------------------------------------------------------------------
// CLI args
// ---------------------------------------------------------------------------

function arg(name: string, fallback: string): string {
  const i = Deno.args.indexOf(`--${name}`);
  return i >= 0 && Deno.args[i + 1] ? Deno.args[i + 1] : fallback;
}
const flag = (name: string) => Deno.args.includes(`--${name}`);

const WIDTH = Number(arg("width", "1920"));
const HEIGHT = Math.round(WIDTH * (9 / 16));
const FPS = Number(arg("fps", "30"));
const S = WIDTH / 1920; // layout scale: everything is authored at 1080p
const OUT = arg("out", "docs/media/promo.mp4");
const GIF_OUT = arg("gif-out", "docs/media/promo.gif");
const GIF_WINDOW = arg("gif-window", "28:40"); // combat burst + slow-mo kill
const FOOTAGE = arg("footage", "/tmp/opencode/kangur_promo/footage").replace(/\/$/, "");
const AT = arg("at", "");
const KEEP_FRAMES = flag("keep-frames");
const PLACEHOLDERS = flag("placeholders");

const ROOT = new URL("../../../", import.meta.url).pathname; // repo root
const PROMO = `${ROOT}docs/media/promo`;
const DURATION = 95; // seconds, see EDL below

// ---------------------------------------------------------------------------
// Theme — src/ui/theme.gd (single palette source in the game)
// ---------------------------------------------------------------------------

const C = {
  bg: "#0B0E14",
  holo: "#7BEBD4",
  amber: "#F2A541",
  text: "#DCE7E4",
  dim: "#7E8F92",
  muted: "#4C5A5E",
  danger: "#E0524A",
  ok: "#6FD08C",
  bastion: "#3E5C76",
  sirocco: "#C4552D",
  line: "#7bebd43d", // holo @ 24%
  scan: "#7bebd40d", // holo @ 5%
};

const FONT_UI = "Chakra Petch, DejaVu Sans, sans-serif";
const FONT_MONO = "Share Tech Mono, DejaVu Sans Mono, monospace";

// Text advance at 1000px, from the project's own TTFs (ASCII 32..126). Used to
// size callout panels and to assert that nothing overflows the frame.
const ADV_BOLD = [272, 274, 460, 717, 637, 875, 662, 256, 348, 348, 349, 564, 238, 432, 238, 522, 652, 382, 574, 603, 579, 606, 622, 522, 638, 627, 232, 232, 614, 564, 614, 562, 835, 646, 670, 655, 688, 606, 576, 676, 698, 276, 580, 651, 561, 801, 697, 700, 646, 700, 675, 637, 584, 700, 650, 879, 652, 634, 592, 344, 537, 344, 657, 482, 240, 575, 600, 558, 602, 583, 400, 602, 594, 272, 287, 567, 262, 861, 592, 592, 602, 595, 409, 536, 414, 591, 510, 729, 528, 593, 498, 377, 264, 377, 586];
const ADV_MONO = 540;

function textWidth(s: string, size: number, mono = false, spacing = 0): number {
  let u = 0;
  for (const ch of s) {
    const c = ch.codePointAt(0)!;
    u += mono ? ADV_MONO : (c >= 32 && c <= 126 ? ADV_BOLD[c - 32] : 555);
  }
  return (u * size) / 1000 + spacing * Math.max(0, [...s].length - 1);
}

// ---------------------------------------------------------------------------
// SVG helpers
// ---------------------------------------------------------------------------

const esc = (s: string) =>
  s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");

interface TextOpts {
  fill?: string;
  size?: number;
  bold?: boolean;
  opacity?: number;
  anchor?: "start" | "middle" | "end";
  spacing?: number;
  mono?: boolean;
}

function text(x: number, y: number, s: string, o: TextOpts = {}): string {
  if (s === "") return "";
  const attrs = [
    `x="${x.toFixed(1)}"`,
    `y="${y.toFixed(1)}"`,
    `font-family="${o.mono ? FONT_MONO : FONT_UI}"`,
    `font-size="${(o.size ?? 20).toFixed(1)}"`,
    `fill="${o.fill ?? C.text}"`,
    o.bold ? 'font-weight="bold"' : "",
    o.opacity !== undefined ? `opacity="${o.opacity.toFixed(3)}"` : "",
    o.anchor ? `text-anchor="${o.anchor}"` : "",
    o.spacing ? `letter-spacing="${o.spacing.toFixed(1)}"` : "",
  ].filter(Boolean).join(" ");
  return `<text ${attrs}>${esc(s)}</text>`;
}

function rect(
  x: number, y: number, w: number, h: number,
  fill: string, opacity = 1, stroke?: string, strokeWidth = 1,
): string {
  if (w <= 0 || h <= 0) return "";
  return `<rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${w.toFixed(1)}" height="${h.toFixed(1)}" fill="${fill}"${
    opacity < 1 ? ` opacity="${opacity.toFixed(3)}"` : ""
  }${stroke ? ` stroke="${stroke}" stroke-width="${strokeWidth}"` : ""}/>`;
}

function line(x1: number, y1: number, x2: number, y2: number, stroke: string, opacity = 1, width = 1): string {
  return `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" stroke="${stroke}" stroke-width="${width}"${
    opacity < 1 ? ` opacity="${opacity.toFixed(3)}"` : ""
  }/>`;
}

function group(body: string, opacity = 1, transform = ""): string {
  if (opacity <= 0.001 || body === "") return "";
  const attrs = [
    opacity < 1 ? `opacity="${opacity.toFixed(3)}"` : "",
    transform ? `transform="${transform}"` : "",
  ].filter(Boolean).join(" ");
  return `<g ${attrs}>${body}</g>`;
}

/** Image at an explicit box. `href` is relative to the frame SVG (asset farm). */
function image(
  href: string, x: number, y: number, w: number, h: number, opacity = 1, slice = true,
): string {
  if (opacity <= 0.001 || w <= 0 || h <= 0) return "";
  return `<image href="${href}" x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${w.toFixed(1)}" height="${h.toFixed(1)}"${
    slice ? ' preserveAspectRatio="xMidYMid slice"' : ""
  }${opacity < 1 ? ` opacity="${opacity.toFixed(3)}"` : ""}/>`;
}

/** Full-frame footage, optionally zoomed (Ken Burns) around a focus point. */
function plate(href: string, opacity = 1, zoom = 1, focusX = 0.5, focusY = 0.5): string {
  const w = WIDTH * zoom, h = HEIGHT * zoom;
  return image(href, -(w - WIDTH) * focusX, -(h - HEIGHT) * focusY, w, h, opacity);
}

function svgFrame(body: string): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">
<defs>
  <linearGradient id="cardBg" x1="0" y1="0" x2="0.35" y2="1">
    <stop offset="0" stop-color="#101822"/>
    <stop offset="0.55" stop-color="#0B0E14"/>
    <stop offset="1" stop-color="#06080C"/>
  </linearGradient>
  <radialGradient id="vignette" cx="0.5" cy="0.46" r="0.78">
    <stop offset="0.5" stop-color="#000000" stop-opacity="0"/>
    <stop offset="1" stop-color="#000000" stop-opacity="0.55"/>
  </radialGradient>
  <pattern id="scan" width="4" height="4" patternUnits="userSpaceOnUse">
    <rect width="4" height="1.2" fill="${C.scan}"/>
  </pattern>
</defs>
${body}
</svg>`;
}

// ---------------------------------------------------------------------------
// Easing / timing
// ---------------------------------------------------------------------------

const clamp01 = (t: number) => Math.max(0, Math.min(1, t));
const span = (t: number, a: number, b: number) => clamp01((t - a) / (b - a));
const easeOut = (t: number) => 1 - Math.pow(1 - t, 3);
const easeInOut = (t: number) => t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

// ---------------------------------------------------------------------------
// EDL — screen seconds. Crossfade 0.4s centred on each cut.
// ---------------------------------------------------------------------------

type Kind = "card" | "footage" | "maps";
interface Scene { id: string; kind: Kind; start: number; end: number; segment?: string }

const SCENES: Scene[] = [
  { id: "intro", kind: "card", start: 0, end: 4 },
  { id: "title", kind: "footage", start: 4, end: 7, segment: "title" },
  { id: "lobby", kind: "footage", start: 7, end: 11, segment: "lobby" },
  { id: "deploy", kind: "footage", start: 11, end: 23, segment: "deploy" },
  { id: "combat", kind: "footage", start: 23, end: 35, segment: "combat" },
  { id: "combat_slow", kind: "footage", start: 35, end: 39, segment: "combat_slow" },
  { id: "wounds", kind: "footage", start: 39, end: 51, segment: "wounds" },
  { id: "smoke", kind: "footage", start: 51, end: 59, segment: "smoke" },
  { id: "ai", kind: "footage", start: 59, end: 69, segment: "ai" },
  { id: "battle", kind: "footage", start: 69, end: 79, segment: "battle" },
  { id: "maps", kind: "maps", start: 79, end: 85 },
  { id: "debrief", kind: "footage", start: 85, end: 88, segment: "debrief" },
  { id: "outro", kind: "card", start: 88, end: 95 },
];
const XFADE = 0.4;

const DEFAULTS: Record<string, number> = {
  title: 90, lobby: 120, deploy: 360, combat: 360, combat_slow: 120,
  wounds: 360, smoke: 240, ai: 300, battle: 300, debrief: 90,
};

interface Callout { start: number; end: number; header: string; sub: string }

const CALLOUTS: Callout[] = [
  { start: 7.5, end: 10.5, header: "ASSEMBLE YOUR CONTRACT", sub: "5 classes · 12 weapons · 4 bot skills · up to 12v12" },
  { start: 11.5, end: 15.5, header: "YOU SEE WHAT YOUR OPERATOR SEES", sub: "Cone vision · walls block sight" },
  { start: 16.5, end: 20.5, header: "SOUND BLEEDS THROUGH CONCRETE", sub: "Occluded hearing · delayed, noisy team radio" },
  { start: 23.5, end: 27.5, header: "STOP. BRACE. BURST.", sub: "Bloom · recoil · stance-aware spread" },
  { start: 28.5, end: 32.5, header: "REAL PROJECTILES", sub: "Penetration · falloff · swept raycasts" },
  { start: 39.5, end: 43.5, header: "WOUNDS THAT MATTER", sub: "Legs slow you · arms ruin your aim" },
  { start: 44.5, end: 48.5, header: "BLEEDING KILLS", sub: "Bandage before you fade" },
  { start: 51.5, end: 55, header: "SMOKE KILLS VISION", sub: "Fog punched out · advance blind" },
  { start: 55.5, end: 58.5, header: "FRAGS KILL COVER", sub: "Cookable fuses · flash LOS-gated" },
  { start: 59.5, end: 63.5, header: "THEY PLAY LIKE PEOPLE", sub: "17 behaviors · personalities · squad roles" },
  { start: 64, end: 68.5, header: "EVERY SHOT JUSTIFIED", sub: "Danger maps · killzones · zero wallhacks, asserted by sim" },
  { start: 69.5, end: 73.5, header: "BATTLE: TAKE THE PORT", sub: "A→B→C objective chain · attacker tickets" },
  { start: 74, end: 78, header: "CAPTURE UNDER FIRE", sub: "Superiority capture · recapture ×2" },
  { start: 85.5, end: 87.8, header: "EVERY MATCH SEEDED", sub: "Every contract different" },
];

// Music: the game's own soundtrack, blocks with 1s crossfades.
const MUSIC: { track: string; start: number; end: number }[] = [
  { track: "title_theme.ogg", start: 0, end: 8 },
  { track: "lobby_deploy.ogg", start: 8, end: 12 },
  { track: "match_calm.ogg", start: 12, end: 24 },
  { track: "match_engaged.ogg", start: 24, end: 51 },
  { track: "clutch.ogg", start: 51, end: 79 },
  { track: "debrief_win.ogg", start: 79, end: DURATION },
];

// Map montage: 5 stills × 1.2s.
const MAPS = [
  { id: "dustworks", name: "DUSTWORKS", mode: "ELIMINATION" },
  { id: "compound", name: "COMPOUND", mode: "ELIMINATION" },
  { id: "terminal", name: "TERMINAL", mode: "BATTLE" },
  { id: "oldtown", name: "OLDTOWN", mode: "BATTLE" },
  { id: "range", name: "RANGE", mode: "TRAINING" },
];
const MAP_STILL = 1.2;
/** Map ids whose still is the low-res minimap fallback (320×256, 4:3). */
const MAP_MINIMAP = new Set<string>();

// ---------------------------------------------------------------------------
// Footage manifest + asset farm
//
// librsvg only loads <image> files that live inside the SVG's own directory
// tree (absolute paths elsewhere silently render blank). Every raster/vector we
// composite is therefore linked (or copied) into <frameDir>/img/ and referenced
// by a relative href.
// ---------------------------------------------------------------------------

let SEGMENTS: Record<string, number> = { ...DEFAULTS };

async function readManifest(): Promise<void> {
  try {
    const m = JSON.parse(await Deno.readTextFile(`${FOOTAGE}/manifest.json`));
    for (const [k, v] of Object.entries(m.segments ?? {})) {
      const frames = Number((v as { frames?: number }).frames);
      if (Number.isFinite(frames) && frames > 0) SEGMENTS[k] = frames;
    }
  } catch {
    // No manifest yet: use the agreed frame counts.
  }
}

/** Assets are linked/copied once into <dir>/img/ so hrefs stay relative. */
async function prepareAssets(dir: string): Promise<void> {
  await Deno.mkdir(`${dir}/img`, { recursive: true });
  await asset(dir, "emblem_bastion.svg", `${ROOT}assets/ui/art/bastion_emblem.svg`);
  await asset(dir, "emblem_sirocco.svg", `${ROOT}assets/ui/art/sirocco_emblem.svg`);
  for (const m of MAPS) {
    const still = `${FOOTAGE}/map_${m.id}.png`;
    const got = await asset(dir, `map_${m.id}.png`, still);
    if (got) continue;
    MAP_MINIMAP.add(m.id); // 320×256 fallback — letterboxed, not stretched
    await asset(dir, `map_${m.id}.png`, `${ROOT}maps/${m.id}/minimap.png`);
  }
}

const ASSETS = new Map<string, Promise<string>>();

/**
 * Make `src` available to the frame SVG as img/<name>. Returns the href, or ""
 * if the source is missing. Cached per path: batches render 8 frames at once
 * and must not race on the same destination.
 */
function asset(dir: string, name: string, src: string): Promise<string> {
  const dst = `${dir}/img/${name}`;
  const key = `${dir}|${name}|${src}`;
  let p = ASSETS.get(key);
  if (!p) {
    p = (async () => {
      if (!(await exists(src))) return "";
      try {
        await Deno.link(src, dst); // free within one filesystem
      } catch {
        try {
          await Deno.copyFile(src, dst);
        } catch {
          return "";
        }
      }
      return `img/${name}`;
    })();
    ASSETS.set(key, p);
  }
  return p;
}

/** Footage frame index for a scene-local time. */
function framePath(segment: string, idx: number): string {
  return `${FOOTAGE}/${segment}/f${String(idx).padStart(4, "0")}.png`;
}

/**
 * Map scene-local time onto the segment's frames, 1:1. `combat_slow` needs no
 * time_scale math here: it was captured at time_scale 0.5, so its 120 frames
 * (4s of source) stretched over the 4s slot already play at smooth half speed.
 */
function segFrame(segment: string, local: number, length: number): number {
  const n = SEGMENTS[segment] ?? DEFAULTS[segment] ?? 1;
  return Math.max(0, Math.min(n - 1, Math.round((local / length) * (n - 1))));
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

function backdrop(): string {
  const grid: string[] = [];
  const step = 96 * S;
  for (let x = 0; x <= WIDTH; x += step) grid.push(line(x, 0, x, HEIGHT, C.line, 0.30));
  for (let y = 0; y <= HEIGHT; y += step) grid.push(line(0, y, WIDTH, y, C.line, 0.22));
  return [
    rect(0, 0, WIDTH, HEIGHT, "url(#cardBg)"),
    grid.join(""),
    rect(0, 0, WIDTH, HEIGHT, "url(#scan)", 0.5),
  ].join("");
}

function emblemLeft(x: number, y: number, size: number, opacity: number): string {
  return image("img/emblem_bastion.svg", x, y, size, size, opacity, false);
}

function emblemRight(x: number, y: number, size: number, opacity: number): string {
  return image("img/emblem_sirocco.svg", x, y, size, size, opacity, false);
}

/** Staggered line: fades in from `from`, slight rise. */
function rise(t: number, from: number, body: (op: number, dy: number) => string): string {
  if (t < from) return "";
  const e = easeOut(span(t, from, from + 0.55));
  return body(e, (1 - e) * 14 * S);
}

function cardIntro(t: number): string {
  const cx = WIDTH / 2, cy = HEIGHT / 2;
  const word = 110 * S, spacing = 12 * S;
  const emSize = 132 * S, emY = cy - emSize * 0.62;
  const wordW = textWidth("KANGUR", word, false, spacing);

  return [
    backdrop(),
    emblemLeft(cx - wordW / 2 - emSize - 70 * S, emY, emSize, easeOut(span(t, 0.75, 1.3)) * 0.95),
    emblemRight(cx + wordW / 2 + 70 * S, emY, emSize, easeOut(span(t, 0.9, 1.45)) * 0.95),
    rise(t, 0.15, (op, dy) =>
      group(
        [
          text(cx, cy + 2 + dy, "KANGUR", {
            fill: C.holo, size: word, bold: true, anchor: "middle", spacing,
          }),
          line(cx - wordW / 2, cy + 34 * S, cx + wordW / 2, cy + 34 * S, C.holo, 0.35),
        ].join(""),
        op,
      )),
    rise(t, 0.6, (op, dy) =>
      text(cx, cy + 82 * S + dy, "NEAR-FUTURE EUROPE · CORPORATE PROXY WARS", {
        fill: C.amber, size: 22 * S, mono: true, anchor: "middle", spacing: 3.2 * S, opacity: op,
      })),
    rise(t, 0.95, (op, dy) =>
      text(cx, cy + 132 * S + dy, "A tactical shooter where the enemy plays like people.", {
        fill: C.text, size: 26 * S, anchor: "middle", opacity: op * 0.94,
      })),
    rect(0, 0, WIDTH, HEIGHT, "url(#vignette)"),
  ].join("");
}

function cardOutro(t: number): string {
  const cx = WIDTH / 2, cy = HEIGHT / 2;
  const word = 84 * S, spacing = 10 * S;
  const emSize = 104 * S, emY = cy - 210 * S;
  const wordW = textWidth("KANGUR", word, false, spacing);

  return [
    backdrop(),
    emblemLeft(cx - wordW / 2 - emSize - 64 * S, emY, emSize, easeOut(span(t, 0.1, 0.6)) * 0.9),
    emblemRight(cx + wordW / 2 + 64 * S, emY, emSize, easeOut(span(t, 0.25, 0.75)) * 0.9),
    rise(t, 0.05, (op, dy) =>
      text(cx, cy - 96 * S + dy, "KANGUR", {
        fill: C.holo, size: word, bold: true, anchor: "middle", spacing, opacity: op,
      })),
    rise(t, 0.45, (op, dy) =>
      text(cx, cy + 4 * S + dy, "12 WEAPONS · 5 CLASSES · 5 MAPS · 3 MODES · UP TO 12v12", {
        fill: C.amber, size: 24 * S, mono: true, anchor: "middle", spacing: 1.6 * S, opacity: op,
      })),
    rise(t, 0.75, (op, dy) =>
      text(cx, cy + 78 * S + dy, "Fair fights. Unfair odds.", {
        fill: C.text, size: 46 * S, bold: true, anchor: "middle", spacing: 1.2 * S, opacity: op,
      })),
    rise(t, 1.05, (op) =>
      text(cx, HEIGHT - 88 * S, "Playable vertical slice · Godot 4.7 · EUPL-1.2 · github.com/maxwelljens/kangur", {
        fill: C.dim, size: 17 * S, mono: true, anchor: "middle", spacing: 0.6 * S, opacity: op * 0.9,
      })),
    rect(0, 0, WIDTH, HEIGHT, "url(#vignette)"),
  ].join("");
}

// ---------------------------------------------------------------------------
// Footage scenes
// ---------------------------------------------------------------------------

function mapsScene(local: number): string {
  const i = Math.max(0, Math.min(MAPS.length - 1, Math.floor(local / MAP_STILL)));
  const p = clamp01((local - i * MAP_STILL) / MAP_STILL);
  const m = MAPS[i];
  const zoom = lerp(1.0, 1.06, easeInOut(p));
  const lowRes = MAP_MINIMAP.has(m.id); // 320×256 minimap: letterbox, never stretch

  // Name + mode sit bottom-left per the EDL; the small header stays top-left.
  const nameY = HEIGHT - 132 * S;
  const metaY = HEIGHT - 84 * S;
  const headerW = textWidth("FIVE CONTRACTS", 18 * S, true, 2 * S);
  const canvas = lowRes
    ? image(`img/map_${m.id}.png`, (WIDTH - HEIGHT * (320 / 256)) / 2, 0, HEIGHT * (320 / 256), HEIGHT, 1, false)
    : plate(`img/map_${m.id}.png`, 1, zoom);
  return [
    rect(0, 0, WIDTH, HEIGHT, "#07090C"),
    canvas,
    rect(0, HEIGHT - 220 * S, WIDTH, 220 * S, C.bg, 0.6),
    text(64 * S, 76 * S, "FIVE CONTRACTS", { fill: C.holo, size: 18 * S, mono: true, spacing: 2 * S, opacity: 0.9 }),
    line(64 * S, 88 * S, 64 * S + headerW, 88 * S, C.holo, 0.5),
    text(64 * S, nameY, m.name, { fill: C.text, size: 54 * S, bold: true, spacing: 4 * S }),
    text(64 * S, metaY, `${String(i + 1).padStart(2, "0")} / ${String(MAPS.length).padStart(2, "0")}`, {
      fill: C.dim, size: 16 * S, mono: true, spacing: 1.5 * S,
    }),
    rect(196 * S, metaY - 20 * S, 2 * S, 22 * S, C.amber),
    text(222 * S, metaY, m.mode, { fill: C.amber, size: 18 * S, mono: true, spacing: 1.6 * S }),
    rect(0, 0, WIDTH, HEIGHT, "url(#vignette)", 0.7),
  ].join("");
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

/** Small corner tag. Anchored just above the weapon block (bottom-right): the
 * HUD owns the top-right corner (killfeed + radio, hud.gd _build_feed). */
function cornerTag(label: string, sub: string, opacity = 1, color = C.amber): string {
  const size = 17 * S, subSize = 14 * S;
  const pad = 12 * S;
  const w = Math.max(textWidth(label, size, true, 1.6 * S), sub ? textWidth(sub, subSize, true, 0.8 * S) : 0) + pad * 2;
  const h = (sub ? 58 : 36) * S;
  // Sits clear of the weapon block (356×150 at a 22px margin, hud.gd): its top
  // edge is ≈ HEIGHT-196 at 1080p, so end the tag above that.
  const x = WIDTH - 30 * S - w, y = HEIGHT - 220 * S - h;
  return group(
    [
      rect(x, y, w, h, C.bg, 0.66),
      line(x, y + h, x + w, y + h, color, 0.55),
      line(x + w, y, x + w, y + h, color, 0.55),
      text(x + pad, y + 24 * S, label, { fill: color, size, mono: true, spacing: 1.6 * S }),
      sub ? text(x + pad, y + 45 * S, sub, { fill: C.text, size: subSize, mono: true, opacity: 0.8, spacing: 0.8 * S }) : "",
    ].join(""),
    opacity,
  );
}

function callout(e: Callout, t: number): string {
  const inP = easeOut(span(t, e.start, e.start + 0.25));
  const outP = 1 - span(t, e.end - 0.25, e.end);
  const op = inP * outP;
  if (op <= 0.001) return "";

  const headerSize = 34 * S, subSize = 20 * S;
  const hw = textWidth(e.header, headerSize, false), sw = textWidth(e.sub, subSize, true);
  const padX = 26 * S, padTop = 16 * S;
  const w = Math.max(hw, sw) + padX * 2 + 10 * S;
  const h = 104 * S;
  const x = (WIDTH - w) / 2;
  const y = HEIGHT - 186 * S + (1 - inP) * 12 * S; // slide up into place

  // Opacity lives on the group only, so panel + text fade together.
  return group(
    [
      rect(x, y, w, h, C.bg, 0.72),
      line(x, y, x + w, y, C.holo, 0.9),
      // bracket corner, top-left
      line(x, y, x, y + 20 * S, C.holo, 1, 2 * S),
      line(x, y, x + 18 * S, y, C.holo, 1, 2 * S),
      // amber tick in the left gutter, level with the header
      rect(x, y + padTop + 6 * S, 3 * S, headerSize * 0.8, C.amber),
      text(x + padX, y + padTop + headerSize * 0.86, e.header, {
        fill: C.holo, size: headerSize, bold: true, spacing: 1.4 * S,
      }),
      text(x + padX, y + padTop + headerSize * 0.86 + 38 * S, e.sub, {
        fill: C.text, size: subSize, mono: true, opacity: 0.85, spacing: 0.6 * S,
      }),
    ].join(""),
    op,
  );
}

// ---------------------------------------------------------------------------
// Frame renderer
// ---------------------------------------------------------------------------

async function sceneBody(scene: Scene, local: number, dir: string, tag: string): Promise<string> {
  if (scene.kind === "card") {
    return scene.id === "intro" ? cardIntro(local) : cardOutro(local);
  }
  if (scene.kind === "maps") return mapsScene(local);

  const seg = scene.segment!;
  const length = scene.end - scene.start;
  const idx = segFrame(seg, local, length);
  // Unique href per frame: 8 frames render concurrently into the same dir.
  const href = await asset(dir, `${tag}_${seg}.png`, framePath(seg, idx));
  if (!href) return rect(0, 0, WIDTH, HEIGHT, C.bg); // missing footage: stay black
  return plate(href);
}

async function renderFrame(t: number, dir: string, tag: string): Promise<string> {
  // Every scene paints a full frame, so a crossfade is: outgoing scene first,
  // incoming scene on top at rising opacity, across the 0.4s straddling the cut.
  // Driven from the cut boundaries, not from a t-index, so both halves blend.
  const i = Math.max(0, SCENES.findIndex((s) => t < s.end));
  let a = SCENES[i], aLocal = t - a.start, b: Scene | null = null, mix = 0;
  for (let k = 1; k < SCENES.length; k++) {
    const cut = SCENES[k].start;
    if (t >= cut - XFADE / 2 && t < cut + XFADE / 2) {
      a = SCENES[k - 1];
      aLocal = t - a.start; // runs slightly past a.end: segFrame/maps clamp, cards settle
      b = SCENES[k];
      mix = easeInOut(span(t, cut - XFADE / 2, cut + XFADE / 2));
      break;
    }
  }

  const parts: string[] = [rect(0, 0, WIDTH, HEIGHT, C.bg)];
  parts.push(await sceneBody(a, aLocal, dir, tag));
  if (b) parts.push(group(await sceneBody(b, Math.max(0, t - b.start), dir, `${tag}n`), mix));

  // Persistent tags (owned by one scene at a time, so they never double-draw).
  for (const s of SCENES) {
    if (t < s.start || t > s.end) continue;
    const op = Math.min(span(t, s.start, s.start + 0.4), 1 - span(t, s.end - 0.2, s.end));
    if (s.id === "combat_slow") {
      parts.push(cornerTag("0.5× SPEED", "3900–9000 px/s · swept per tick", op));
    } else if (s.id === "ai") {
      parts.push(cornerTag("LIVE AI TELEMETRY — F3 OVERLAY", "", op));
    }
  }

  // Callouts (independent of the scene dissolve, as scheduled).
  for (const c of CALLOUTS) parts.push(callout(c, t));

  return svgFrame(parts.join("\n"));
}

// ---------------------------------------------------------------------------
// Layout self-check (catches overflow at any --width)
// ---------------------------------------------------------------------------

function selfCheck(): void {
  const margin = 60 * S;
  const check = (label: string, w: number, max: number) => {
    if (w > max) throw new Error(`layout overflow: ${label} is ${Math.round(w)}px, max ${Math.round(max)}px`);
  };
  check("outro features", textWidth("12 WEAPONS · 5 CLASSES · 5 MAPS · 3 MODES · UP TO 12v12", 24 * S, true, 1.6 * S), WIDTH - 2 * margin);
  check("outro tagline", textWidth("Fair fights. Unfair odds.", 46 * S, false, 1.2 * S), WIDTH - 2 * margin);
  check("outro footer", textWidth("Playable vertical slice · Godot 4.7 · EUPL-1.2 · github.com/maxwelljens/kangur", 17 * S, true, 0.6 * S), WIDTH - 2 * margin);
  check("intro tagline", textWidth("A tactical shooter where the enemy plays like people.", 26 * S), WIDTH - 2 * margin);
  check("intro kicker", textWidth("NEAR-FUTURE EUROPE · CORPORATE PROXY WARS", 22 * S, true, 3.2 * S), WIDTH - 2 * margin);
  for (const c of CALLOUTS) {
    check(`callout "${c.header}"`, textWidth(c.header, 34 * S, false), WIDTH - 120 * S);
    check(`callout sub "${c.sub}"`, textWidth(c.sub, 20 * S, true, 0.6 * S), WIDTH - 120 * S);
    if (c.start < 0 || c.end > DURATION || c.end <= c.start) throw new Error(`callout out of range: ${c.header}`);
  }
  for (let k = 1; k < SCENES.length; k++) {
    if (SCENES[k].start !== SCENES[k - 1].end) throw new Error(`EDL gap at ${SCENES[k].id}`);
  }
  if (SCENES.at(-1)!.end !== DURATION) throw new Error("EDL does not reach DURATION");
  console.log("  layout ok");
}

// ---------------------------------------------------------------------------
// Placeholder footage (so the pipeline is testable before capture lands)
// ---------------------------------------------------------------------------

async function makePlaceholders(): Promise<void> {
  const fontUI = `${ROOT}assets/ui/fonts/ChakraPetch-Bold.ttf`;
  const fontMono = `${ROOT}assets/ui/fonts/ShareTechMono-Regular.ttf`;
  console.log(`Placeholder footage → ${FOOTAGE}`);
  await Deno.mkdir(FOOTAGE, { recursive: true });

  const manifest: Record<string, unknown> = { segments: {} };
  for (const [seg, frames] of Object.entries(SEGMENTS)) {
    const dir = `${FOOTAGE}/${seg}`;
    await Deno.mkdir(dir, { recursive: true });
    (manifest.segments as Record<string, unknown>)[seg] = { frames, fps: 30, time_scale: seg === "combat_slow" ? 0.5 : 1 };
    if (await exists(`${dir}/f0000.png`)) {
      console.log(`  ${seg}: kept (already captured)`);
      continue;
    }
    // Fake HUD blocks so callout placement can be judged against real frame
    // real estate: minimap TL, mode strip TC, killfeed TR, vitals BL, weapon BR.
    const hud = [
      "drawbox=x=24:y=24:w=250:h=190:color=0x7BEBD4@0.18:t=2",
      "drawbox=x=760:y=18:w=400:h=64:color=0x7BEBD4@0.14:t=2",
      "drawbox=x=1620:y=24:w=276:h=210:color=0xE0524A@0.16:t=2",
      "drawbox=x=24:y=880:w=330:h=168:color=0x6FD08C@0.16:t=2",
      "drawbox=x=1540:y=930:w=350:h=118:color=0xF2A541@0.16:t=2",
      `drawtext=fontfile=${fontMono}:text='minimap':fontcolor=0x7BEBD4@0.75:fontsize=20:x=44:y=40`,
      `drawtext=fontfile=${fontMono}:text='mode strip':fontcolor=0x7BEBD4@0.75:fontsize=20:x=800:y=26`,
      `drawtext=fontfile=${fontMono}:text='killfeed':fontcolor=0xE0524A@0.8:fontsize=20:x=1640:y=40`,
      `drawtext=fontfile=${fontMono}:text='vitals':fontcolor=0x6FD08C@0.8:fontsize=20:x=44:y=900`,
      `drawtext=fontfile=${fontMono}:text='weapon':fontcolor=0xF2A541@0.8:fontsize=20:x=1560:y=950`,
    ].join(",");
    const moving = "drawbox=x='mod(t*420\\,1500)+180':y='500+120*sin(t*0.9)':w=320:h=200:color=0x7BEBD4@0.20:t=fill";
    const label = `drawtext=fontfile=${fontUI}:text='${seg.toUpperCase().replaceAll("_", " ")}':fontcolor=0x7BEBD4:fontsize=150:x=(w-text_w)/2:y=620`;
    const counter = `drawtext=fontfile=${fontMono}:text='PLACEHOLDER  f %{n}':fontcolor=0xF2A541:fontsize=40:x=(w-text_w)/2:y=800`;

    await run("ffmpeg", [
      "-v", "error", "-y",
      "-f", "lavfi", "-i", `color=c=0x0B0E14:s=1920x1080:r=30`,
      "-vf", `format=rgb24,${hud},${moving},${label},${counter}`,
      "-frames:v", String(frames), "-start_number", "0", `${dir}/f%04d.png`,
    ]);
    console.log(`  ${seg}: ${frames} frames`);
  }
  await Deno.writeTextFile(`${FOOTAGE}/manifest.json`, JSON.stringify(manifest, null, 2));
}

// ---------------------------------------------------------------------------
// Pipeline
// ---------------------------------------------------------------------------

async function exists(p: string): Promise<boolean> {
  try {
    return (await Deno.stat(p)).isFile;
  } catch {
    return false;
  }
}

async function run(cmd: string, args: string[], env?: Record<string, string>): Promise<void> {
  const p = new Deno.Command(cmd, {
    args,
    env,
    stdout: "piped",
    stderr: "piped",
  });
  const { code, stderr, stdout } = await p.output();
  if (code !== 0) {
    throw new Error(`${cmd} ${args.join(" ")} failed (${code}):\n${new TextDecoder().decode(stderr) || new TextDecoder().decode(stdout)}`);
  }
}

/** Fontconfig: project TTFs first, system fonts as fallback. */
async function writeFontConf(dir: string): Promise<string> {
  const conf = `${dir}/fonts.conf`;
  await Deno.writeTextFile(
    conf,
    `<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <dir>${ROOT}assets/ui/fonts</dir>
</fontconfig>
`,
  );
  return conf;
}

async function renderPng(svgPath: string, pngPath: string, fontConf: string): Promise<void> {
  await run(
    "rsvg-convert",
    ["-w", String(WIDTH), "-h", String(HEIGHT), "-o", pngPath, svgPath],
    { FONTCONFIG_FILE: fontConf },
  );
}

async function main(): Promise<void> {
  await readManifest();
  console.log(`Kangur promo · ${WIDTH}×${HEIGHT} @ ${FPS}fps · ${DURATION}s · footage ${FOOTAGE}`);
  selfCheck();
  if (PLACEHOLDERS) await makePlaceholders();

  // Single-frame preview.
  if (AT !== "") {
    const t = Number(AT);
    const dir = `${PROMO}/frames`;
    await Deno.mkdir(dir, { recursive: true });
    await prepareAssets(dir);
    const fontConf = await writeFontConf(dir);
    const base = `${dir}/at-${t.toFixed(2)}`;
    await Deno.writeTextFile(`${base}.svg`, await renderFrame(t, dir, "at"));
    await renderPng(`${base}.svg`, `${base}.png`, fontConf);
    console.log(`Preview: ${base}.png`);
    return;
  }

  const dir = KEEP_FRAMES ? `${PROMO}/frames` : await Deno.makeTempDir({ dir: "/tmp/opencode", prefix: "kangur-promo-" });
  await Deno.mkdir(dir, { recursive: true });
  await prepareAssets(dir);
  const fontConf = await writeFontConf(dir);

  const total = Math.round(DURATION * FPS);
  console.log(`Rendering ${total} frames → ${dir}`);

  const BATCH = 16;
  const t0 = Date.now();
  for (let i = 0; i < total; i += BATCH) {
    await Promise.all(
      Array.from({ length: Math.min(BATCH, total - i) }, async (_, j) => {
        const idx = i + j;
        const base = `${dir}/f${String(idx).padStart(4, "0")}`;
        await Deno.writeTextFile(`${base}.svg`, await renderFrame(idx / FPS, dir, `f${idx}`));
        await renderPng(`${base}.svg`, `${base}.png`, fontConf);
        if (!KEEP_FRAMES) await Deno.remove(`${base}.svg`);
      }),
    );
    if ((i / BATCH) % 5 === 0) {
      const pct = ((i + BATCH) / total * 100).toFixed(0);
      console.log(`  ${Math.min(i + BATCH, total)}/${total} frames (${pct}%, ${((Date.now() - t0) / 1000).toFixed(0)}s)`);
    }
  }

  // 1. Silent video.
  await Deno.mkdir(OUT.replace(/\/[^/]+$/, ""), { recursive: true });
  const silent = `${dir}/silent.mp4`;
  console.log(`Encoding video → ${OUT}`);
  await run("ffmpeg", [
    "-v", "error", "-y",
    "-framerate", String(FPS), "-i", `${dir}/f%04d.png`,
    "-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p",
    "-c:v", "libx264", "-preset", "slow", "-crf", "21", "-r", String(FPS),
    "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
    silent,
  ]);

  // 2. Music bed: six blocks, 1s crossfades centred on each cut.
  // Block i is placed at [start-lead, ...] and fades out over the 1s that
  // straddles the cut, so it overlaps the next block's fade-in.
  console.log(`Mixing soundtrack (${MUSIC.length} blocks)`);
  const midi = `${ROOT}assets/audio/music`;
  const inputs: string[] = [];
  const filters: string[] = [];
  MUSIC.forEach((b, i) => {
    inputs.push("-i", `${midi}/${b.track}`);
    const isFirst = i === 0, isLast = i === MUSIC.length - 1;
    const lead = isFirst ? 0 : 0.5;
    const dur = (b.end - b.start) + lead + (isLast ? 0 : 0.5);
    const fadeIn = isFirst ? 0.5 : 1, fadeOut = isLast ? 2 : 1;
    filters.push(
      `[${i + 1}:a]atrim=0:${dur.toFixed(3)},asetpts=PTS-STARTPTS,` +
        `afade=t=in:st=0:d=${fadeIn},` +
        `afade=t=out:st=${(dur - fadeOut).toFixed(3)}:d=${fadeOut},` +
        `volume=0.85,adelay=${Math.round((b.start - lead) * 1000)}:all=1[a${i}]`,
    );
  });
  filters.push(
    `${MUSIC.map((_, i) => `[a${i}]`).join("")}amix=inputs=${MUSIC.length}:normalize=0:dropout_transition=0,` +
      `alimiter=limit=0.95,afade=t=in:st=0:d=0.5,afade=t=out:st=${DURATION - 2}:d=2,` +
      `aresample=48000[aout]`,
  );
  await run("ffmpeg", [
    "-v", "error", "-y",
    "-i", silent,
    ...inputs,
    "-filter_complex", filters.join(";"),
    "-map", "0:v", "-map", "[aout]",
    "-c:v", "copy", "-c:a", "aac", "-b:a", "160k",
    "-movflags", "+faststart", "-t", String(DURATION),
    OUT,
  ]);

  // 3. GIF highlight: straight from the finished video (one pass, split palette).
  const [gs, ge] = GIF_WINDOW.split(":").map(Number);
  const gifDur = Math.min(ge - gs, 12);
  const gifW = 800, gifH = Math.round(gifW * (HEIGHT / WIDTH));
  console.log(`Encoding GIF ${gs}s–${(gs + gifDur).toFixed(1)}s → ${GIF_OUT}`);
  await Deno.mkdir(GIF_OUT.replace(/\/[^/]+$/, ""), { recursive: true });
  await run("ffmpeg", [
    "-v", "error", "-y",
    "-ss", String(gs), "-t", String(gifDur), "-i", OUT,
    "-filter_complex",
    `[0:v]fps=12.5,scale=${gifW}:${gifH}:flags=lanczos,split[a][b];` +
      "[a]palettegen=stats_mode=diff:max_colors=128[p];" +
      "[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
    "-loop", "0", GIF_OUT,
  ]);

  const mb = (n: number) => `${(n / 1024 / 1024).toFixed(2)} MiB`;
  console.log(`Done: ${OUT} (${mb((await Deno.stat(OUT)).size)})`);
  console.log(`Done: ${GIF_OUT} (${mb((await Deno.stat(GIF_OUT)).size)})`);
  if (!KEEP_FRAMES) await Deno.remove(dir, { recursive: true });
}

if (import.meta.main) await main();