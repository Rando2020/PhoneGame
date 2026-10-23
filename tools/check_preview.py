#!/usr/bin/env python3
"""
Checks an app preview against Apple's App Preview specifications (App Store
Connect Help, "App preview specifications", read 2026-10-19):
  15 to 30 s; at most 500 MB; up to 30 fps; H.264 (.mov/.m4v/.mp4), progressive,
  up to High Profile Level 4.0, target 10 to 12 Mbps; stereo AAC 256 kbps at
  44.1 or 48 kHz; 6.9" and 6.5" portrait: 886 x 1920.
  python3 tools/check_preview.py file.mp4      exit 0 = within spec
"""
import json, os, subprocess, sys

path = sys.argv[1]
info = json.loads(subprocess.check_output(
    ["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", path]))
v = [s for s in info["streams"] if s["codec_type"] == "video"]
a = [s for s in info["streams"] if s["codec_type"] == "audio"]
fails = []
def check(ok, msg):
    print(("ok   " if ok else "FAIL ") + msg)
    if not ok:
        fails.append(msg)

dur = float(info["format"]["duration"])
size = os.path.getsize(path)
check(15.0 <= dur <= 30.0, f"length {dur:.2f} s (15 to 30)")
check(size <= 500 * 1024 * 1024, f"size {size / 1e6:.1f} MB (at most 500)")
check(path.lower().endswith((".mov", ".m4v", ".mp4")), "container .mov/.m4v/.mp4")
check(len(v) == 1, "one video stream")
if v:
    s = v[0]
    num, den = map(int, s["avg_frame_rate"].split("/"))
    fps = num / den if den else 0
    check(s["codec_name"] == "h264", f"codec {s['codec_name']} (h264)")
    check(0 < fps <= 30.0001, f"frame rate {fps:.2f} (up to 30)")
    check((s["width"], s["height"]) == (886, 1920), f"resolution {s['width']}x{s['height']} (886x1920)")
    check(s.get("profile", "") in ("High", "Main", "Constrained Baseline", "Baseline"), f"profile {s.get('profile')}")
    check(int(s.get("level", 99)) <= 40, f"level {s.get('level')} (up to 40)")
    check(s.get("field_order", "progressive") in ("progressive", "unknown"), f"scan {s.get('field_order', 'progressive')} (progressive)")
    check(s.get("pix_fmt") == "yuv420p", f"pixel format {s.get('pix_fmt')} (yuv420p)")
    br = int(info["format"]["bit_rate"])
    check(8e6 <= br <= 13e6, f"overall bit rate {br / 1e6:.1f} Mbps (target 10 to 12)")
check(len(a) == 1, "one audio stream")
if a:
    s = a[0]
    check(s["codec_name"] == "aac", f"audio {s['codec_name']} (aac)")
    check(int(s["channels"]) == 2, f"channels {s['channels']} (stereo)")
    check(int(s["sample_rate"]) in (44100, 48000), f"sample rate {s['sample_rate']}")
    abr = int(s.get("bit_rate", 0))
    check(200e3 <= abr <= 270e3, f"audio bit rate {abr / 1e3:.0f} kbps (256)")
print(f"preview: {len(fails)} fails")
sys.exit(1 if fails else 0)
