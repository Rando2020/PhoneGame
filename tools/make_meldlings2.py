#!/usr/bin/env python3
"""
Meldlings 2.0 prototype: one character (Pip) in two styles, six reaction poses.

  A "pixel"  : 64x64 pixel art, hard edges, 1px dark outline, 4-tone shading
  B "smooth" : 256x256 illustrated (drawn at 4x and downsampled), soft shading,
               rim light, glossy eyes

Poses: idle, eager (the deal), nervous (near target, few deals), cheer (a big
count), victory (round cleared), deflated (run lost).

  python3 tools/make_meldlings2.py OUTDIR
"""
import math, sys, os
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/meld2"
os.makedirs(OUT, exist_ok=True)

# Pip: spade, indigo, pink accent
PAL = dict(out=(28, 24, 52), dark=(70, 62, 132), mid=(104, 96, 178), light=(146, 140, 216),
           hi=(206, 204, 246), acc=(255, 128, 168), eye=(250, 248, 244), pupil=(26, 22, 40))

POSES = {
    #          squash  lean  hop   eyes          mouth      brows   arms    extra
    "idle":     (1.00,  0,   0.00, "open",       "smile",   0,      "down", None),
    "eager":    (0.96,  0,   0.04, "wide",       "grin",    1,      "up1",  "spark"),
    "nervous":  (1.02, -6,   0.00, "side",       "wobble",  -1,     "hug",  "sweat"),
    "cheer":    (0.90,  0,   0.12, "happy",      "open",    1,      "up",   "stars"),
    "victory":  (0.92,  4,   0.16, "happy",      "open",    1,      "up",   "crown"),
    "deflated": (1.10,  0,  -0.02, "down",       "frown",   -1,     "down", "drip"),
}


def spade(cx, cy, s, squash, lean):
    """Spade body outline as a polygon (body of a spade + rounded lobes), unit size s."""
    pts = []
    sx, sy = s / squash ** 0.5, s * squash
    for i in range(181):
        t = math.pi * i / 180  # 0..pi along the right side, mirrored later
        # heart-like spade: pointed top, two round lobes at the bottom
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((x, y))
    full = pts + [(-x, y) for x, y in reversed(pts)]
    out = []
    for x, y in full:
        yy = -y  # flip: point up
        k = (yy + 17) / 34  # 0 bottom .. 1 top, for lean
        out.append((cx + (x + lean * k * 0.6) * sx / 17, cy + yy * sy / 17))
    return out


def draw_char(d, W, pose, smooth):
    squash, lean, hop, eyes, mouth, brows, arms, extra = POSES[pose]
    S = W / 64.0
    cx, cy = W / 2, W * (0.58 - hop * 0.6)
    s = 20 * S
    body = spade(cx, cy, s, squash, lean)
    P = PAL
    lw = max(1, round(1.4 * S)) if smooth else max(1, round(S))
    # shadow
    sh_w = 18 * S * (1 - hop * 2)
    d.ellipse([cx - sh_w, W * 0.90 - 2.5 * S, cx + sh_w, W * 0.90 + 2.5 * S], fill=(0, 0, 0, 70))
    # feet
    fy = cy + s * squash * 0.86
    for side in (-1, 1):
        fx = cx + side * 8 * S
        d.ellipse([fx - 5 * S, fy - 2.5 * S, fx + 5 * S, fy + 3 * S], fill=P["dark"], outline=P["out"], width=lw)
    # arms
    arm = {"down": [(-17, 4, -21, 12), (17, 4, 21, 12)],
           "up1": [(-17, 2, -21, 10), (17, 0, 24, -10)],
           "up": [(-16, 0, -24, -12), (16, 0, 24, -12)],
           "hug": [(-15, 4, -6, 10), (15, 4, 6, 10)]}[arms]
    for x0, y0, x1, y1 in arm:
        d.line([cx + x0 * S, cy + y0 * S, cx + x1 * S, cy + y1 * S], fill=P["out"], width=round(5 * S))
        d.line([cx + x0 * S, cy + y0 * S, cx + x1 * S, cy + y1 * S], fill=P["mid"], width=round(3 * S))
        r = 2.6 * S
        d.ellipse([cx + x1 * S - r, cy + y1 * S - r, cx + x1 * S + r, cy + y1 * S + r], fill=P["mid"], outline=P["out"], width=lw)
    # body with tone bands
    # outline: the same shape grown, underneath (clean on both styles)
    grow = spade(cx, cy + 0.2 * S, s + (2.2 if smooth else 1.6) * S, squash, lean)
    d.polygon(grow, fill=P["out"])
    d.polygon(body, fill=P["mid"])
    # shading: darker lower-left band, light upper-right
    for k, col, dx, dy, sc in ((0, P["dark"], -2.5, 3.0, 0.92), (1, P["light"], 2.0, -2.5, 0.62), (2, P["hi"], 4.5, -7.5, 0.18)):
        if k == 0:
            continue
        b = spade(cx + dx * S, cy + dy * S, s * sc, squash, lean)
        d.polygon(b, fill=col)
    # stem pip on top (the spade's foot, turned into a little hat)
    ty = cy - s * squash * 1.0
    if extra != "crown": d.polygon([(cx - 4 * S, ty + 1 * S), (cx + 4 * S, ty + 1 * S), (cx, ty - 7 * S)], fill=P["dark"], outline=P["out"])
    if extra != "crown": d.ellipse([cx - 2.6 * S, ty - 10 * S, cx + 2.6 * S, ty - 5 * S], fill=P["acc"], outline=P["out"], width=lw)
    # face
    ex, ey = 7.5 * S, cy + 1 * S
    for side in (-1, 1):
        x = cx + side * ex + lean * 0.15 * S
        if eyes == "happy":
            d.arc([x - 5 * S, ey - 4 * S, x + 5 * S, ey + 5 * S], 200, 340, fill=P["out"], width=round(2.2 * S))
            continue
        if eyes == "down":
            d.chord([x - 5 * S, ey - 4 * S, x + 5 * S, ey + 6 * S], 0, 180, fill=P["eye"], outline=P["out"], width=lw)
            d.ellipse([x - 2 * S, ey + 1 * S, x + 2 * S, ey + 5 * S], fill=P["pupil"])
            continue
        rx, ry = (5.5, 6.5) if eyes == "wide" else (4.8, 6.0)
        d.ellipse([x - rx * S, ey - ry * S, x + rx * S, ey + ry * S], fill=P["eye"], outline=P["out"], width=lw)
        px = {"side": -2.2, "open": 0.3 * side, "wide": 0}[eyes] * S
        pr = 2.8 * S if eyes == "wide" else 2.5 * S
        d.ellipse([x + px - pr, ey - pr + 0.8 * S, x + px + pr, ey + pr + 0.8 * S], fill=P["pupil"])
        g = 1.1 * S
        d.ellipse([x + px - 1.6 * S - g, ey - 1.6 * S - g, x + px - 1.6 * S + g, ey - 1.6 * S + g], fill=P["eye"])
        if brows:
            by = ey - ry * S - 2.5 * S
            tilt = 1.8 * S * brows * side
            d.line([x - 4 * S, by + tilt, x + 4 * S, by - tilt], fill=P["out"], width=round(1.8 * S))
    # blush
    for side in (-1, 1):
        x = cx + side * 13 * S
        d.ellipse([x - 3 * S, ey + 5 * S, x + 3 * S, ey + 7.5 * S], fill=P["acc"] + (150,))
    my = ey + (7 if mouth == "frown" else 9) * S
    if mouth == "smile":
        d.arc([cx - 4 * S, my - 3 * S, cx + 4 * S, my + 2.5 * S], 20, 160, fill=P["out"], width=round(1.8 * S))
    elif mouth == "grin":
        d.chord([cx - 5 * S, my - 3 * S, cx + 5 * S, my + 4 * S], 0, 180, fill=P["out"])
        d.chord([cx - 3 * S, my + 0.5 * S, cx + 3 * S, my + 3.6 * S], 0, 180, fill=P["acc"])
    elif mouth == "open":
        d.ellipse([cx - 4.5 * S, my - 2 * S, cx + 4.5 * S, my + 6 * S], fill=P["out"])
        d.ellipse([cx - 2.8 * S, my + 2 * S, cx + 2.8 * S, my + 5.5 * S], fill=P["acc"])
    elif mouth == "wobble":
        pts = [(cx - 5 * S + i * S, my + (0.9 * S if i % 2 else -0.9 * S)) for i in range(11)]
        d.line(pts, fill=P["out"], width=round(1.6 * S))
    elif mouth == "frown":
        d.arc([cx - 4 * S, my, cx + 4 * S, my + 6 * S], 200, 340, fill=P["out"], width=round(1.8 * S))
    # extras
    if extra == "sweat":
        x, y = cx + 15 * S, cy - 10 * S
        d.polygon([(x, y - 4 * S), (x - 2.5 * S, y + 1 * S), (x + 2.5 * S, y + 1 * S)], fill=(140, 210, 255))
        d.ellipse([x - 2.5 * S, y - 1 * S, x + 2.5 * S, y + 3.5 * S], fill=(140, 210, 255), outline=P["out"])
    if extra == "drip":
        x, y = cx - 12 * S, cy - 4 * S
        d.ellipse([x - 2 * S, y, x + 2 * S, y + 4 * S], fill=(140, 210, 255))
    if extra in ("spark", "stars"):
        for (x, y, r) in ((-24, -16, 3.2), (23, -20, 2.6), (26, 2, 2.0))[: 1 if extra == "spark" else 3]:
            X, Y, R = cx + x * S, cy + y * S, r * S
            d.polygon([(X, Y - R * 2), (X + R * 0.5, Y - R * 0.5), (X + R * 2, Y), (X + R * 0.5, Y + R * 0.5),
                       (X, Y + R * 2), (X - R * 0.5, Y + R * 0.5), (X - R * 2, Y), (X - R * 0.5, Y - R * 0.5)], fill=(255, 214, 102))
    if extra == "crown":
        y = cy - s * squash * 1.0 + 1 * S
        c = (240, 190, 70)
        d.polygon([(cx - 8 * S, y + 3 * S), (cx - 8 * S, y - 4 * S), (cx - 4 * S, y), (cx, y - 6 * S),
                   (cx + 4 * S, y), (cx + 8 * S, y - 4 * S), (cx + 8 * S, y + 3 * S)], fill=c, outline=P["out"])
        for k in (-4, 0, 4):
            d.ellipse([cx + k * S - S, y - S, cx + k * S + S, y + S], fill=P["acc"])


def render(pose, style):
    if style == "pixel":
        W = 64
        img = Image.new("RGBA", (W * 4, W * 4), (0, 0, 0, 0))
        draw_char(ImageDraw.Draw(img, "RGBA"), W * 4, pose, smooth=False)
        img = img.resize((W, W), Image.NEAREST)
        # hard alpha (pixel art has no soft edges)
        a = img.getchannel("A").point(lambda v: 255 if v > 110 else 0)
        img.putalpha(a)
        return img.resize((256, 256), Image.NEAREST)
    W = 256
    big = Image.new("RGBA", (W * 4, W * 4), (0, 0, 0, 0))
    draw_char(ImageDraw.Draw(big, "RGBA"), W * 4, pose, smooth=True)
    img = big.resize((W, W), Image.LANCZOS)
    # soft glow behind (reads as "alive" on dark felt)
    glow = img.getchannel("A").filter(ImageFilter.GaussianBlur(10)).point(lambda v: int(v * 0.35))
    halo = Image.new("RGBA", (W, W), PAL["light"] + (0,))
    halo.putalpha(glow)
    return Image.alpha_composite(halo, img)


def sheet():
    poses = list(POSES)
    pad, cell = 24, 256
    W = pad + len(poses) * (cell + pad)
    H = 60 + 2 * (cell + 60)
    out = Image.new("RGBA", (W, H), (30, 52, 44, 255))   # felt green, where they'll live
    d = ImageDraw.Draw(out)
    for r, style in enumerate(("pixel", "smooth")):
        y = 40 + r * (cell + 60)
        d.text((pad, y - 26), {"pixel": "A  PIXEL 64", "smooth": "B  ILLUSTRATED"}[style], fill=(240, 220, 160))
        for i, p in enumerate(poses):
            x = pad + i * (cell + pad)
            im = render(p, style)
            out.alpha_composite(im, (x, y))
            im.save(f"{OUT}/pip_{style}_{p}.png")
            d.text((x + 4, y + cell + 6), p, fill=(220, 230, 220))
    out.save(f"{OUT}/pip_compare.png")
    print(f"{OUT}/pip_compare.png")


if __name__ == "__main__":
    sheet()
