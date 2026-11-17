#!/usr/bin/env bash
# Kangur: serialize ALL Godot invocations on this project.
# Concurrent godot --import / editor runs race on the .godot cache and can
# corrupt imports or segfault (gdUnit4). Every agent/tool MUST use this
# wrapper instead of calling /usr/bin/godot directly.
# Usage: tools/godot.sh --headless --path . --import   (same args as godot)
exec flock -w 600 /tmp/opencode/kangur_godot.lock /usr/bin/godot "$@"
