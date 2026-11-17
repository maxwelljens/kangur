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

# TODO(sim): seeded battle sims — parity + fairness invariants.
#   tools/godot.sh --headless --path . -- --sim=<map>:<mode>:<seed>:<count>
# TODO(screenshots): UI screenshots via the shot harness (needs DISPLAY).
#   tools/godot.sh --path . -- --shot=res://src/ui/title/title_screen.tscn:20:reports/screenshots/title.png

echo "==> verify OK"