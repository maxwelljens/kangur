#!/usr/bin/env bash
# Build the Kangur release binaries (Linux x86_64 + Windows x86_64).
#
# Requires: Godot 4.7.2 (standard build, not .NET), curl, unzip, python3,
# sha512sum, sha256sum. Godot export templates for 4.7.2.stable are auto-installed (and
# SHA512-verified against the upstream release) if not already present.
#
# Usage: tools/build_release.sh [version]
#   version defaults to config/version from project.godot (currently 0.1.0).
#
# Output (all gitignored):
#   build/linux-x86_64/kangur.x86_64
#   build/windows-x86_64/kangur.exe
#   build/kangur-v<version>-linux-x86_64.zip
#   build/kangur-v<version>-windows-x86_64.zip
#   build/SHA256SUMS.txt
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="$ROOT/tools/godot.sh"
GODOT_VERSION="4.7.2"
TEMPLATE_TAG="${GODOT_VERSION}-stable"
TEMPLATES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}.stable"
TPZ_NAME="Godot_v${TEMPLATE_TAG}_export_templates.tpz"
TPZ_URL="https://github.com/godotengine/godot/releases/download/${TEMPLATE_TAG}/${TPZ_NAME}"
SUMS_URL="https://github.com/godotengine/godot/releases/download/${TEMPLATE_TAG}/SHA512-SUMS.txt"
WORK="${TMPDIR:-/tmp/opencode}/kangur-templates"

VERSION="${1:-$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)}"
if [ -z "$VERSION" ]; then
	echo "could not read config/version from project.godot" >&2
	exit 1
fi

echo "==> Kangur v${VERSION} release build"

# ---------------------------------------------------------------- templates --
if [ ! -f "$TEMPLATES_DIR/version.txt" ]; then
	echo "==> installing Godot ${TEMPLATE_TAG} export templates"
	mkdir -p "$WORK" "$TEMPLATES_DIR"
	curl -fL --retry 4 --retry-delay 3 -o "$WORK/$TPZ_NAME" "$TPZ_URL"
	curl -fL --retry 4 --retry-delay 3 -o "$WORK/SHA512-SUMS.txt" "$SUMS_URL"
	( cd "$WORK" && grep -F "$TPZ_NAME" SHA512-SUMS.txt | sha512sum -c - )
	rm -rf "$WORK/unpacked"
	unzip -q "$WORK/$TPZ_NAME" -d "$WORK/unpacked"
	cp -f "$WORK"/unpacked/templates/* "$TEMPLATES_DIR"/
	chmod +x "$TEMPLATES_DIR"/linux_* "$TEMPLATES_DIR"/*.exe 2>/dev/null || true
else
	echo "==> export templates already installed ($(cat "$TEMPLATES_DIR/version.txt"))"
fi

# -------------------------------------------------------------------- import --
# Mandatory: a cold .godot import cache makes exports (and gdUnit4) unreliable.
echo "==> headless import pass"
"$GODOT" --headless --path . --import

# -------------------------------------------------------------------- exports --
LINUX_DIR="$ROOT/build/linux-x86_64"
WIN_DIR="$ROOT/build/windows-x86_64"
mkdir -p "$LINUX_DIR" "$WIN_DIR"

echo "==> export Linux x86_64"
"$GODOT" --headless --path . --export-release "Linux x86_64" "$LINUX_DIR/kangur.x86_64"
chmod +x "$LINUX_DIR/kangur.x86_64"

echo "==> export Windows x86_64"
"$GODOT" --headless --path . --export-release "Windows x86_64" "$WIN_DIR/kangur.exe"

# --------------------------------------------------------------------- checks --
LINUX_BIN="$LINUX_DIR/kangur.x86_64"
WIN_BIN="$WIN_DIR/kangur.exe"
for f in "$LINUX_BIN" "$WIN_BIN"; do
	if [ ! -s "$f" ]; then
		echo "export produced no output: $f" >&2
		exit 1
	fi
done
echo "    linux:   $(du -h "$LINUX_BIN" | cut -f1)"
echo "    windows: $(du -h "$WIN_BIN" | cut -f1)"

# Headless boot check on the native build: proves the embedded PCK loads.
if [ "${KANGUR_SKIP_SMOKE:-0}" != "1" ]; then
	echo "==> smoke test (headless boot of the exported Linux binary)"
	( cd "$LINUX_DIR" && DISPLAY= ./kangur.x86_64 --headless --quit-after 120 ) \
		>/tmp/opencode/kangur-smoke.log 2>&1 || {
		echo "smoke test failed; log:" >&2
		tail -40 /tmp/opencode/kangur-smoke.log >&2
		exit 1
	}
	# NB: a benign engine warning ("Parent node is busy adding/removing children",
	# remove_child during a scene swap) is emitted by the game on headless boot;
	# it is present in source runs too and is not an export/load failure.
	if grep -qiE "SCRIPT ERROR|Parse Error|Failed to load|Cannot open file|Error parsing|Couldn't load" /tmp/opencode/kangur-smoke.log; then
		echo "smoke test logged script/load errors:" >&2
		grep -iE "SCRIPT ERROR|Parse Error|Failed to load|Cannot open file|Error parsing|Couldn't load" /tmp/opencode/kangur-smoke.log >&2 | head -20
		exit 1
	fi
	echo "    smoke OK"
fi

# ------------------------------------------------------------------ packaging --
STAGE="$ROOT/build/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/linux-x86_64" "$STAGE/windows-x86_64"

cat > "$STAGE/README.txt" <<EOF
Kangur v${VERSION}
==================

Singleplayer topdown tactical shooter. Built with Godot ${GODOT_VERSION}.

Linux:   chmod +x kangur.x86_64   (already executable in this archive)
         ./kangur.x86_64
Windows: kangur.exe

Both builds are self-contained: the game data is embedded in the executable.
No installation, no dependencies. Audio and rendering need a working desktop
session; the game also runs headless for simulations.

Controls and contract flow: title -> operations desk -> match -> debrief.
F3 toggles the AI debug overlay, F12 saves a screenshot.

Source and full documentation: https://github.com/maxwelljens/kangur
Licence: EUPL-1.2 (LICENCE). Third-party asset credits in docs/credits.md.
EOF

cp -f "$LINUX_BIN" "$STAGE/linux-x86_64/"
cp -f "$WIN_BIN"   "$STAGE/windows-x86_64/"
for d in linux-x86_64 windows-x86_64; do
	cp -f "$ROOT/LICENCE"     "$STAGE/$d/LICENCE"
	cp -f "$STAGE/README.txt" "$STAGE/$d/README.txt"
done

LINUX_ZIP="$ROOT/build/kangur-v${VERSION}-linux-x86_64.zip"
WIN_ZIP="$ROOT/build/kangur-v${VERSION}-windows-x86_64.zip"
rm -f "$LINUX_ZIP" "$WIN_ZIP"

# zip(1) is not guaranteed on minimal hosts; python3's zipfile is. ZipFile.write
# preserves the source file mode, so the Linux executable keeps its +x bit.
make_zip() {
	python3 - "$1" "$2" <<'PY'
import os, sys, zipfile
out, root = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(root)):
        path = os.path.join(root, name)
        if os.path.isfile(path):
            z.write(path, name)
PY
}
make_zip "$LINUX_ZIP" "$STAGE/linux-x86_64"
make_zip "$WIN_ZIP"   "$STAGE/windows-x86_64"

# ------------------------------------------------------------------ checksums --
( cd "$ROOT/build" && sha256sum "$(basename "$LINUX_ZIP")" "$(basename "$WIN_ZIP")" > SHA256SUMS.txt )

echo "==> done"
echo "    $LINUX_ZIP"
echo "    $WIN_ZIP"
echo "    $ROOT/build/SHA256SUMS.txt"
