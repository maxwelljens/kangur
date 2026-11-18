#!/usr/bin/env bash
# Kangur verification gate. Sections run in order; a failure aborts (set -e).
# Every Godot invocation goes through tools/godot.sh (flock-serialized) —
# concurrent godot runs race on the .godot cache and can corrupt imports.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="$ROOT/tools/godot.sh"
GDU_DIR="tests/unit"
GDU_TOOL="addons/gdUnit4/bin/GdUnitCmdTool.gd"

echo "==> import (mandatory: gdUnit4 7.0.0 segfaults on a cold .godot cache)"
"$GODOT" --headless --path . --import

echo "==> unit tests (gdUnit4; 0 pass / 100 fail / 101 warnings)"
set +e
"$GODOT" --headless --path . -s "$GDU_TOOL" -a "$GDU_DIR" -c
UNIT_EXIT=$?
set -e
if [ "$UNIT_EXIT" -ne 0 ]; then
	echo "unit tests failed (exit $UNIT_EXIT)" >&2
	exit "$UNIT_EXIT"
fi

# Seeded battle sims: the three quick maps from tests/simulation/README.md
# (one seeded match each, hard invariants only). --fixed-fps 60 is mandatory:
# the harness steps the engine loop by hand (one sim tick per physics frame,
# because bullet sweeps read the physics space state), so real-time pacing
# would make a gate run take the full match length in wall clock.
echo "==> battle sims (fairness / termination / bunching)"
"$GODOT" --headless --path . --fixed-fps 60 -- --sim=dustworks:elimination:1:1
"$GODOT" --headless --path . --fixed-fps 60 -- --sim=compound:elimination:1:1
"$GODOT" --headless --path . --fixed-fps 60 -- --sim=terminal:battle:1:1

# Game-flow screenshots need a display; skipped on a headless box rather than
# failing the gate (CI without :0 still verifies all gameplay logic above).
if [ -n "${DISPLAY:-}" ]; then
	echo "==> game flow screenshots (title → lobby → match → debrief)"
	"$GODOT" --path . --resolution 2560x1440 tools/shot_flow.tscn \
		-- --mode=0 --map=dustworks --bots=6 --combat-frames=200
else
	echo "==> game flow screenshots skipped (no DISPLAY)"
fi

echo "==> verify OK"