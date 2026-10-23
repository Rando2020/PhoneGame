#!/bin/sh
# The playtest build (pass 22): Linux, Windows and macOS exports of the Godot
# game with the "playtest" feature (the hidden menu and the private session log,
# docs/PLAYTEST.md). Needs Godot 4.3 and its export templates.
#   tools/playtest_build.sh            -> build/playtest/{linux,windows,macos}/
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/godot"
for p in linux windows macos; do mkdir -p "$ROOT/build/playtest/$p"; done
godot --headless --path . --export-release "Playtest Linux" ../build/playtest/linux/Meldlings.x86_64
godot --headless --path . --export-release "Playtest Windows" ../build/playtest/windows/Meldlings.exe
godot --headless --path . --export-release "Playtest macOS" ../build/playtest/macos/Meldlings.zip
ls -la "$ROOT/build/playtest"/*/
