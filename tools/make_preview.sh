#!/bin/sh
# The App Store preview (6.9", 886x1920): record a real scripted run with
# Godot's movie maker, encode H.264 at 30 fps, then check it against Apple's
# spec with ffprobe. Usage: tools/make_preview.sh [out.mp4]
set -e
OUT="${1:-store/preview/preview_886x1920.mp4}"
FR=/tmp/preview_frames
rm -rf "$FR" && mkdir -p "$FR" "$(dirname "$OUT")"
cd godot
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 886x1920 \
  --write-movie "$FR/f.png" --fixed-fps 30 --script res://tests/preview_run.gd | grep "preview:"
cd ..
# skip frames 0..1 (the title before the run starts); the movie maker's own
# audio (f.wav, the game's sound) trimmed to match. Constant 10 Mbps video:
# Apple's target is 10 to 12 Mbps, and still frames would undershoot it.
ffmpeg -y -loglevel error -framerate 30 -start_number 2 -i "$FR/f%08d.png" \
  -ss 0.0667 -i "$FR/f.wav" -shortest \
  -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p -r 30 \
  -b:v 10M -minrate 10M -maxrate 10M -bufsize 10M -x264-params nal-hrd=cbr \
  -c:a aac -b:a 256k -ar 44100 -ac 2 -movflags +faststart "$OUT"
python3 tools/check_preview.py "$OUT"
