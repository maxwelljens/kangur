#!/usr/bin/env bash
# UI wave verification: import, then screenshot every menu + HUD fixture.
# Every godot call goes through tools/godot.sh (flock); screenshots need DISPLAY.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

GODOT=tools/godot.sh
FRAMES="${FRAMES:-30}"
OUT=reports/screenshots
mkdir -p "$OUT"

run_shot() {
	local scene="$1" name="$2" frames="${3:-$FRAMES}"
	echo "==> $name"
	# 2560x1440 at the project's 1.6 canvas stretch = the 1600x900 design viewport.
	timeout 180 $GODOT --path . --resolution 2560x1440 -- ${EXTRA_ARGS:-} \
		--shot="${scene}:${frames}:${OUT}/ui_${name}.png" 2>&1 | grep -vE "^$" | tail -25
}

echo "==> import"
timeout 900 $GODOT --headless --path . --import 2>&1 \
	| grep -iE "SCRIPT ERROR|Parse Error|error at|ERROR:" | head -40
echo "IMPORT_DONE"

run_shot res://src/ui/title/title_screen.tscn title
run_shot res://src/ui/menus/lobby_screen.tscn lobby
run_shot res://tools/shot_ui_settings.tscn settings
EXTRA_ARGS="--tab=1" run_shot res://tools/shot_ui_settings.tscn settings_audio
EXTRA_ARGS="--tab=2" run_shot res://tools/shot_ui_settings.tscn settings_controls
EXTRA_ARGS="--tab=3" run_shot res://tools/shot_ui_settings.tscn settings_gameplay
run_shot res://src/ui/menus/credits_screen.tscn credits
run_shot res://tools/shot_ui_credits_music.tscn credits_music
run_shot res://tools/shot_ui_debrief.tscn debrief
run_shot res://tools/shot_ui_pause.tscn pause
run_shot res://tools/shot_ui_hud.tscn hud
echo "ALL_DONE"