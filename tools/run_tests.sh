#!/usr/bin/env bash
# Run GUT headless. Usage: tools/run_tests.sh [res://tests/unit/test_x.gd]
set -u
GODOT="${GODOT:-/c/Users/aming/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1
if [ $# -gt 0 ]; then
  "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest="$1" -gexit
else
  "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
fi
