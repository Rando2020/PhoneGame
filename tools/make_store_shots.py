#!/usr/bin/env python3
"""
App Store screenshots, from REAL game states rendered by the Godot build at
each required size (godot/tests/*_shot.gd with SHOT_SIZE=WxH, which write
/tmp/<state>_<W>x<H>.png), each under a short caption band on the menu felt.

Sizes (portrait, iPhone only: the export targets iPhone):
  6.9"  1320 x 2868     6.5"  1284 x 2778     5.5"  1242 x 2208

  python3 tools/make_store_shots.py OUTDIR      -> OUTDIR/<size>/<n>_<state>.png
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/store_shots"
SIZES = {"6.9in": (1320, 2868), "6.5in": (1284, 2778), "5.5in": (1242, 2208)}
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FELT = os.path.join(HERE, "..", "art", "surfaces", "felt_menu.png")
GOLD, INK = (232, 182, 76), (246, 238, 224)

# (source state, headline, sub-line). Order is the store order.
SHOTS = [
    ("shot_count", "Every count lands.", "Fifteens, pairs and runs tick up, then the multiplier slams."),
    ("flow_won_end", "They cheer you on.", "Six Meldlings, each with its own face and its own trick."),
    ("peg_busy", "The Play.", "Peg to 31 against the Spoiler, then add it to your score."),
    ("flow_boss", "Beat the Spoilers.", "Every third round a Spoiler breaks a rule. Build for it."),
    ("shop", "Build your run.", "Charms, marked cards and Reckonings at the Peg House."),
    ("menu_gallery_meld", "Collect them all.", "Every Meldling, every pose, in the Gallery."),
]


def felt(w, h):
    t = Image.open(FELT).convert("RGB")
    bg = Image.new("RGB", (w, h))
    for x in range(0, w, t.width):
        for y in range(0, h, t.height):
            bg.paste(t, (x, y))
    return bg


def wrap(d, text, font, width):
    words, lines, cur = text.split(), [], ""
    for wd in words:
        trial = (cur + " " + wd).strip()
        if d.textlength(trial, font=font) <= width:
            cur = trial
        else:
            lines.append(cur)
            cur = wd
    if cur:
        lines.append(cur)
    return lines


def compose(src, size, head, sub):
    W, H = size
    out = felt(W, H)
    d = ImageDraw.Draw(out)
    band = int(H * 0.17)
    hf = ImageFont.truetype(FONT, int(W * 0.072))
    sf = ImageFont.truetype(FONT, int(W * 0.034))
    y = int(band * 0.22)
    for ln in wrap(d, head, hf, W * 0.9):
        d.text((W / 2, y), ln, font=hf, fill=GOLD, anchor="ma")
        y += int(hf.size * 1.15)
    y += int(W * 0.012)
    for ln in wrap(d, sub, sf, W * 0.84):
        d.text((W / 2, y), ln, font=sf, fill=INK, anchor="ma")
        y += int(sf.size * 1.3)
    top = max(band, y + int(W * 0.03))
    # the game, scaled into the rest with rounded corners and a soft shadow
    shot = Image.open(src).convert("RGB")
    avail_h = H - top - int(H * 0.03)
    k = min(avail_h / shot.height, (W * 0.88) / shot.width)
    sw, sh = int(shot.width * k), int(shot.height * k)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    x0 = (W - sw) // 2
    r = int(W * 0.05)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], radius=r, fill=255)
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle([x0, top + 14, x0 + sw, top + sh + 14], radius=r, fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    out = Image.composite(Image.new("RGB", (W, H), (6, 5, 12)), out, shadow)
    out.paste(shot, (x0, top), mask)
    ImageDraw.Draw(out).rounded_rectangle([x0, top, x0 + sw - 1, top + sh - 1], radius=r, outline=GOLD + (0,), width=3)
    return out


def main():
    made = 0
    for name, (w, h) in SIZES.items():
        os.makedirs(f"{OUT}/{name}", exist_ok=True)
        for i, (state, head, sub) in enumerate(SHOTS):
            src = f"/tmp/{state}_{w}x{h}.png"
            if not os.path.exists(src):
                print("missing", src)
                continue
            im = compose(src, (w, h), head, sub)
            assert im.size == (w, h) and im.mode == "RGB"
            im.save(f"{OUT}/{name}/{i + 1}_{state}.png")
            made += 1
    print(f"{made} screenshots in {OUT}")


if __name__ == "__main__":
    main()
