#!/usr/bin/env bash
# Promo capture — records every segment in Godot Movie Maker mode and normalises
# the frames into a contiguous, 0-based f%04d.png contract.
#
#   tools/promo/capture.sh                    # all segments
#   tools/promo/capture.sh --seg=combat       # one segment
#   tools/promo/capture.sh --stills-only      # README stills only
#   tools/promo/capture.sh --footage DIR      # output root
#
# Movie mode writes `<base><8 digits>.png` (Godot 4.7.2, verified), at whatever
# the project's window override says — 1920x1080 is forced by a transient
# override.cfg, because --resolution loses to window_width_override.
#
# Godot is ALWAYS invoked through tools/godot.sh (flock-serialized).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FOOTAGE="/tmp/opencode/kangur_promo/footage"
SCRATCH="/tmp/opencode/kangur_promo/scratch"
STILLS="docs/media"
FPS=30
ONLY_SEG=""
STILLS_ONLY=0

for arg in "$@"; do
	case "$arg" in
		--seg=*) ONLY_SEG="${arg#--seg=}" ;;
		--footage=*) FOOTAGE="${arg#--footage=}" ;;
		--stills-only) STILLS_ONLY=1 ;;
		--help|-h) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
		*) echo "capture.sh: unknown flag $arg" >&2; exit 2 ;;
	esac
done

cd "$REPO"
mkdir -p "$FOOTAGE" "$SCRATCH" "$STILLS"

# The niri WM rewrites window geometry, so a transient root override.cfg is the
# only lever that reaches movie mode (and plain --shot). `keep` aspect pins the
# layout to the requested size; without it the WM's resize stretches the HUD.
# Removed on every exit.
cleanup() { rm -f override.cfg; }
trap cleanup EXIT

write_override() {
	cat > override.cfg <<-EOF
	[display]

	window/size/viewport_width=$1
	window/size/viewport_height=$2
	window/size/window_width_override=$1
	window/size/window_height_override=$2
	window/stretch/aspect="keep"
	EOF
}

fail() { echo "capture.sh: $1 failed — last log lines:" >&2; tail -n 20 "$2" >&2; echo >&2; exit 1; }

# movie SEG FRAMES SCENE [args…] — record one segment into footage/SEG.
movie() {
	local seg="$1" frames="$2" scene="$3"; shift 3
	local raw="$SCRATCH/${seg}_raw"
	local log="$SCRATCH/${seg}.log"
	rm -rf "$raw"; mkdir -p "$raw"
	local out="$FOOTAGE/$seg"
	rm -rf "$out"; mkdir -p "$out"

	local extra=()
	if [[ "$seg" == "combat_slow" ]]; then extra+=(--time-scale 0.5); fi

	write_override 1920 1080
	# Trim the head frames the fixture spent posing (it prints PROMO_TRIM).
	tools/godot.sh --path . --audio-driver Dummy --fixed-fps "$FPS" --disable-vsync \
		"${extra[@]}" --write-movie "$raw/f.png" --quit-after "$frames" \
		"$scene" "$@" > "$log" 2>&1 || fail "$seg" "$log"
	rm -f override.cfg

	# A script parse error still records N black frames and exits 0: refuse it.
	if grep -qE "SCRIPT ERROR|Failed to load script" "$log"; then
		fail "$seg" "$log"
	fi
	local trim
	trim=$(sed -n 's/^PROMO_TRIM \([0-9]*\)$/\1/p' "$log" | tail -n 1)
	trim=${trim:-0}
	# Godot appends its own 8-digit counter; normalise to 0-based f%04d.png and
	# drop the staging lead-in so every segment starts on its money moment.
	local i=0 n=0 f
	for f in $(ls "$raw"/f*.png | sort); do
		if (( i >= trim )); then
			printf -v name 'f%04d.png' "$n"
			mv "$f" "$out/$name"
			n=$(( n + 1 ))
		fi
		i=$(( i + 1 ))
	done
	rm -rf "$raw"
	# A dead segment is all-black; a sky-coloured frame is all the fixture ever
	# produced before the match booted. Both mean the take is empty.
	if (( n == 0 )); then fail "$seg" "$log"; fi
	echo "  $seg: $n frames"
}

# still NAME SCENE FRAMES [args…] — one frame through the existing --shot harness.
still() {
	local name="$1" scene="$2" frames="$3"; shift 3
	local log="$SCRATCH/still_$name.log"
	write_override 1600 900
	tools/godot.sh --path . --audio-driver Dummy --resolution 1600x900 \
		-- --shot="$scene:$frames:$STILLS/$name.png" "$@" > "$log" 2>&1 \
		|| fail "still $name" "$log"
	rm -f override.cfg
	grep -q SHOT_OK "$log" || fail "still $name" "$log"
	echo "  $name.png"
}

# want SEG — true when that segment was asked for.
want() { [[ -z "$ONLY_SEG" || "$ONLY_SEG" == "$1" ]]; }

# --- segments --------------------------------------------------------------
if (( ! STILLS_ONLY )); then
	echo "Recording segments → $FOOTAGE"
	if want deploy; then
		movie deploy 360 res://tools/promo/promo_shot.tscn -- --seg=deploy
	fi
	if want title; then
		movie title 90 res://src/ui/title/title_screen.tscn
	fi
	if want lobby; then
		movie lobby 120 res://src/ui/menus/lobby_screen.tscn
	fi
	if want combat; then
		movie combat 360 res://tools/promo/promo_shot.tscn -- --seg=combat
	fi
	if want combat_slow; then
		movie combat_slow 120 res://tools/promo/promo_shot.tscn -- --seg=combat_slow
	fi
	if want wounds; then
		movie wounds 360 res://tools/promo/promo_shot.tscn -- --seg=wounds
	fi
	if want smoke; then
		movie smoke 240 res://tools/promo/promo_shot.tscn -- --seg=smoke
	fi
	if want ai; then
		movie ai 300 res://tools/promo/promo_shot.tscn -- --seg=ai
	fi
	if want battle; then
		movie battle 450 res://tools/promo/promo_shot.tscn -- --seg=battle
	fi
	if want debrief; then
		movie debrief 219 res://tools/promo/promo_shot.tscn -- --seg=debrief
	fi
fi

# --- README stills ---------------------------------------------------------
# Static screens use the --shot harness. Staged segments are taken from the
# recorded footage instead: --shot counts RENDERED frames, which at unlocked
# speed is not the same as the physics tick a beat is staged on, so its frame
# number cannot land on a burst or a blast. Extracting the exact recorded frame
# and rescaling keeps "real scene, real moment".
if (( STILLS_ONLY )) || [[ -z "$ONLY_SEG" ]]; then
	echo "Recording stills → $STILLS"
	still shot_title   res://src/ui/title/title_screen.tscn 40
	still shot_lobby   res://src/ui/menus/lobby_screen.tscn 60
	for m in dustworks compound terminal oldtown range; do
		log="$SCRATCH/map_$m.log"
		write_override 1600 900
		tools/godot.sh --path . --audio-driver Dummy --resolution 1600x900 \
			-- --shot="res://tools/shot_map.tscn:15:$FOOTAGE/map_$m.png" --map="$m" > "$log" 2>&1 \
			|| fail "map_$m" "$log"
		rm -f override.cfg
		grep -q SHOT_OK "$log" || fail "map_$m" "$log"
		echo "  map_$m.png"
	done
fi

# grab NAME SEG FRAME — one recorded frame, rescaled to the still size.
grab() {
	local name="$1" seg="$2" frame="$3"
	local src="$FOOTAGE/$seg/$(printf 'f%04d.png' "$frame")"
	[[ -f "$src" ]] || { echo "capture.sh: missing $src (record --seg=$seg first)" >&2; return 1; }
	ffmpeg -y -loglevel error -i "$src" -vf "scale=1600:900:flags=lanczos" \
		"$STILLS/$name.png"
	echo "  $name.png"
}

if (( STILLS_ONLY )) || [[ -z "$ONLY_SEG" ]]; then
	# Money frames, picked off the verified takes (fog cone + squad, mid-burst,
	# leg wound + bandage channel, frag blast in the smoke, AI telemetry mid-fight,
	# objective fight, finished debrief).
	grab shot_fog     deploy     170
	grab shot_combat  combat     240
	grab shot_wounds  wounds     220
	grab shot_smoke   smoke      225
	grab shot_ai      ai         200
	grab shot_battle  battle     150
	grab shot_debrief debrief     40
fi

# --- manifest -------------------------------------------------------------
python3 - "$FOOTAGE" <<-'PY'
import json, os, sys
root = sys.argv[1]
segments = {}
for name in sorted(os.listdir(root)):
    d = os.path.join(root, name)
    if not os.path.isdir(d):
        continue
    n = len([f for f in os.listdir(d) if f.endswith(".png")])
    if n:
        segments[name] = {"frames": n, "fps": 30,
                          "time_scale": 0.5 if name == "combat_slow" else 1.0}
stills = sorted(f for f in os.listdir("docs/media") if f.endswith(".png"))
manifest = {"segments": segments, "stills": stills}
with open(os.path.join(root, "manifest.json"), "w") as fh:
    json.dump(manifest, fh, indent=2)
print("manifest: %d segments, %d stills" % (len(segments), len(stills)))
PY