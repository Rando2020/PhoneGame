#!/bin/sh
# Three 9:16 social clips (TikTok, Reels, Shorts) cut from the App Store
# preview: 1080x1920, 30 fps, H.264 + AAC, each under 15 s, with a caption band.
#   tools/make_clips.sh            -> docs/clips/clip_{1_count,2_play,3_shop}.mp4
# Re-run after tools/make_preview.sh makes a new preview. Needs ffmpeg and a
# bold font (Inter ExtraBold, falling back to DejaVu Sans Bold).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/store/preview/preview_886x1920.mp4"
OUT="$ROOT/docs/clips"
mkdir -p "$OUT"
FONT=/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf
[ -f "$FONT" ] || FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
BG=0x161423
GOLD=0xe8b54c
DIM=0xb9b0a3

# name start end caption (the preview is 21.0 s: keep and count 0-11,
# The Play 11-17, the Peg House 16-21)
clip() {
  name=$1; ss=$2; to=$3; cap=$4
  # the game, 775x1680, under a 240 px caption band, on the game's own background
  ffmpeg -v error -y -ss "$ss" -to "$to" -i "$SRC" \
    -filter_complex "[0:v]scale=-2:1680,setsar=1[g];color=c=${BG}:s=1080x1920:r=30[bg];[bg][g]overlay=(W-w)/2:240:shortest=1,drawtext=fontfile=${FONT}:text='${cap}':fontcolor=${GOLD}:fontsize=58:x=(w-text_w)/2:y=70,drawtext=fontfile=${FONT}:text='MELDLINGS  ·  CRIBBAGE ROGUELITE':fontcolor=${DIM}:fontsize=30:x=(w-text_w)/2:y=160,format=yuv420p[v]" \
    -map "[v]" -map 0:a? -c:v libx264 -preset veryfast -crf 20 -r 30 -c:a aac -b:a 128k \
    -movflags +faststart "$OUT/$name.mp4"
}

clip clip_1_count 0.0 11.0 "Keep four. Throw two. Count big."
clip clip_2_play 10.6 17.2 "Then peg to 31 against the Spoiler."
clip clip_3_shop 15.8 21.0 "Spend your Glim. Build the run."

# check: 9:16, under 15 s, 30 fps
fails=0
for f in "$OUT"/clip_*.mp4; do
  w=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$f")
  h=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$f")
  d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  ok=$(python3 -c "print(1 if $w*16==$h*9 and $d<15.0 and $d>3.0 else 0)")
  echo "$(basename "$f"): ${w}x${h}, ${d} s, $(du -k "$f" | cut -f1) KB $( [ "$ok" = 1 ] && echo ok || echo FAIL)"
  [ "$ok" = 1 ] || fails=$((fails+1))
done
echo "clips: $fails fails"
[ "$fails" -eq 0 ]
