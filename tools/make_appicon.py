#!/usr/bin/env python3
"""
The iOS app icon, generated from the game's own art (no hand art, no text):
Pip mid-cheer on the green table felt, a soft gold halo behind, the felt's vignette.
Opaque RGB at every size (Apple rejects transparency in app icons).

  python3 tools/make_appicon.py OUTDIR
  OUTDIR/icon_1024.png (App Store) and every size Godot 4.3's iOS preset asks for:
  iPhone 120 180, iPad 76 152 167, Spotlight 40 80 120, Settings 58 87,
  Notification 40 60; plus icon_preview.png (the icon at three sizes).
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/appicon"
os.makedirs(OUT, exist_ok=True)
sys.argv = [sys.argv[0], "/tmp/_meld2_unused"]     # the rig reads argv at import
sys.path.insert(0, HERE)
import make_meldlings2 as M

SIZES = [1024, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40]
FELT = os.path.join(HERE, "..", "art", "surfaces", "felt_round.png")


def icon(size=1024):
    S = 1024
    felt = Image.open(FELT).convert("RGB")
    bg = Image.new("RGB", (S, S))
    for x in range(0, S, felt.width):
        for y in range(0, S, felt.height):
            bg.paste(felt, (x, y))
    # a warm glow behind the character, a cool vignette at the corners
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse([S * 0.14, S * 0.12, S * 0.86, S * 0.84], fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.09))
    bg = Image.composite(Image.new("RGB", (S, S), (126, 92, 40)), bg, glow.point(lambda v: int(v * 0.55)))
    vig = Image.new("L", (S, S), 0)
    ImageDraw.Draw(vig).ellipse([-S * 0.18, -S * 0.18, S * 1.18, S * 1.18], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(S * 0.08))
    bg = Image.composite(bg, Image.new("RGB", (S, S), (12, 10, 22)), vig)
    # Pip, cheering (reads at 40 px: a big shape, big eyes)
    pip = M.draw_char("pip", "cheer", W=2048, out=int(S * 1.02))
    bg.paste(pip, (int((S - pip.width) / 2), int(S * 0.0)), pip)
    return bg.convert("RGB").resize((size, size), Image.LANCZOS) if size != S else bg.convert("RGB")


def main():
    big = icon(1024)
    for s in SIZES:
        (big if s == 1024 else big.resize((s, s), Image.LANCZOS)).save(f"{OUT}/icon_{s}.png")
    # a preview: the icon as a rounded app tile at 1024, 180 and 60
    prev = Image.new("RGB", (1024 + 180 + 60 + 80, 1024 + 40), (240, 240, 244))
    x = 20
    for s in (1024, 180, 60):
        t = big.resize((s, s), Image.LANCZOS)
        m = Image.new("L", (s, s), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.225), fill=255)
        prev.paste(t, (x, 20), m)
        x += s + 20
    prev.save(f"{OUT}/icon_preview.png")
    print(f"{OUT}: {len(SIZES)} icon sizes")


if __name__ == "__main__":
    main()
