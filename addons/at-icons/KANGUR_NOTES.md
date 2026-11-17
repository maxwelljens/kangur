# @icons — vendored

Upstream: <https://github.com/Voxybuns/at-icons>, release **v1.6.0** (2026-11-07).
Installed from the release ZIP only — the repo README forbids `git clone` / source-ZIP installs.
License: MIT (`LICENSE.txt`, kept). Vendored whole and **not trimmed**: the editor dock
(`icon_browser.tscn`) hardcodes `res://addons/at-icons/node3d/` and preloads all 705 icons, plus
`node/at.svg` as the dock icon, so the full tree is required.

Usage: `@icon("res://addons/at-icons/node2d/<name>.svg")` placed **before** `class_name`.

## Known issues

- **Upstream #28** (<https://github.com/Voxybuns/at-icons/issues/28>): in-editor dock can render
  blank on Godot 4.7.2 — exactly our version. Unresolved upstream (owner requested install details
  2026-10-10). Not reproduced in our import probe, but treat the dock as *nice-to-have*: icons are
  usable regardless of the dock. Never depend on the dock in CI.
- Icons do **not** rescale/recolour on editor theme or scale change (upstream #25, Godot bug);
  reimport the icons after changing those editor settings.
- `plugin.cfg` says `version="1.5.0"` at tag v1.6.0 — stale upstream, left verbatim.
- `EditorDock` / `EditorPlugin.add_dock()` exist only in Godot ≥ 4.6 (Experimental). Fine on 4.7.2;
  re-check before any 4.8 move.

## Project rules

- Keep this plugin **disabled** in `[editor_plugins]` on shared/CI paths; the icons work without it.
- Export settings: exclude `addons/at-icons/` from builds (34 MB of editor-only SVGs).
- `.svg.import` files ship with the release ZIP and are committed (AGENTS.md). The ZIP contains one
  orphan, `node3d/arrow_counter_clockwise.svg.import` (its SVG is named `arrow_counterclockwise.svg`);
  harmless, left verbatim so a re-download diffs clean.