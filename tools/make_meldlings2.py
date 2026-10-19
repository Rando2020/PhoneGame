#!/usr/bin/env python3
"""
Meldlings 2.0: the six playable Meldlings, illustrated style (B), six reaction
poses each, from one rig. Bodies are masks (so any silhouette works): the
outline is the mask grown, shading is the mask shrunk and offset, and the hat is
a small copy of the character's own suit.

Poses: idle, eager (the deal), nervous (near target, few deals), cheer (a big
count), victory (round cleared), deflated (run lost).

  python3 tools/make_meldlings2.py OUTDIR [name ...]   (default: all six)
  OUTDIR/<name>_<pose>.png (256x256), OUTDIR/<name>_sheet.png, OUTDIR/cast.png
"""
import math, sys, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/meld2"
ONLY = sys.argv[2:]
os.makedirs(OUT, exist_ok=True)
EYE, PUPIL = (250, 248, 244), (26, 22, 40)


def pal(out, dark, mid, light, hi, acc):
    return dict(out=out, dark=dark, mid=mid, light=light, hi=hi, acc=acc)


# ---------------------------------------------------------------- shapes
# Unit coordinates: x right, y down, the body fits about [-17, 17].
def curve_spade(n=120):
    pts = []
    for i in range(n + 1):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x * 17 / 17, y * 17 / 17))     # point up (a heart flipped)
    return [pts]


def curve_heart(n=120):
    return [[(x * 1.2, -y * 0.92) for x, y in curve_spade(n)[0]]]


def circle(cx, cy, r, n=48):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def curve_club():
    return [circle(0, -6.5, 8.2), circle(-8, 3.5, 8.2), circle(8, 3.5, 8.2), circle(0, 2, 7)]


def curve_diamond():
    pts = []
    for i in range(64):            # a superellipse: a diamond with soft corners
        t = 2 * math.pi * i / 64
        c, s = math.cos(t), math.sin(t)
        x = 15.5 * math.copysign(abs(c) ** 1.6, c)
        y = 18.0 * math.copysign(abs(s) ** 1.6, s)
        pts.append((x, y))
    return [pts]


def curve_nib():
    return [[(x * 0.8, y * 1.04) for x, y in curve_spade()[0]], [(-17, 2), (-11, -3), (-11, 6)], [(17, 2), (11, -3), (11, 6)]]


def curve_muggins():
    return [circle(0, 1, 16.5, 64), circle(-11.5, -11, 5.2), circle(11.5, -11, 5.2)]


CAST = {
    #            shape          palette                                                                                       eye spread, eye y, personality
    "pip":     (curve_spade,   pal((28, 24, 52), (70, 62, 132), (104, 96, 178), (146, 140, 216), (206, 204, 246), (255, 128, 168)), 7.5, 1, "eager, a little anxious"),
    "thump":   (curve_heart,   pal((72, 24, 42), (156, 54, 78), (204, 86, 110), (234, 130, 150), (252, 190, 202), (255, 214, 102)), 8.5, -2, "loud, all heart"),
    "clover":  (curve_club,    pal((20, 50, 32), (48, 108, 64), (78, 156, 92), (118, 192, 122), (178, 222, 170), (255, 170, 120)), 7.5, 1, "lucky, sunny"),
    "facet":   (curve_diamond, pal((86, 52, 14), (184, 124, 32), (226, 170, 52), (244, 206, 96), (255, 240, 180), (120, 210, 255)), 7.0, 0, "precious, a bit vain"),
    "nib":     (curve_nib,     pal((28, 34, 48), (58, 88, 120), (86, 128, 166), (124, 172, 208), (186, 222, 244), (255, 196, 120)), 6.0, 2, "sharp, quick"),
    "muggins": (curve_muggins, pal((44, 30, 20), (110, 74, 46), (150, 104, 66), (188, 142, 96), (226, 194, 152), (220, 110, 90)), 8.0, 0, "sly, scrappy"),
}

POSES = {
    #          squash  lean  hop   eyes     mouth     brows arms    extra
    "idle":     (1.00,  0,   0.00, "open",  "smile",  0,    "down", None),
    "eager":    (0.96,  0,   0.04, "wide",  "grin",   1,    "up1",  "spark"),
    "nervous":  (1.02, -6,   0.00, "side",  "wobble", -1,   "hug",  "sweat"),
    "cheer":    (0.90,  0,   0.12, "happy", "open",   1,    "up",   "stars"),
    "victory":  (0.92,  4,   0.16, "happy", "open",   1,    "up",   "crown"),
    "deflated": (1.10,  0,  -0.02, "down",  "frown",  -1,   "down", "drip"),
}


def place(polys, cx, cy, s, squash, lean):
    """Unit polys -> canvas polys, with squash (wider and shorter) and lean (top shifts)."""
    sx, sy = s / 17 / squash ** 0.5, s / 17 * squash
    out = []
    for poly in polys:
        q = []
        for x, y in poly:
            k = (17 - y) / 34          # 0 at the feet, 1 at the top
            q.append((cx + (x + lean * k * 0.6) * sx, cy + y * sy))
        out.append(q)
    return out


def mask_of(W, polys):
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    for p in polys:
        d.polygon(p, fill=255)
    return m


def fill(img, mask, col):
    layer = Image.new("RGBA", img.size, col + (255,))
    img.paste(layer, (0, 0), mask)


def shift(mask, dx, dy):
    return ImageChops.offset(mask, int(dx), int(dy))


def draw_char(name, pose, W=1024):
    shape, P, spread, eye_dy, _ = CAST[name]
    squash, lean, hop, eyes, mouth, brows, arms, extra = POSES[pose]
    S = W / 64.0
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy, s = W / 2, W * (0.58 - hop * 0.6), 20 * S
    lw = max(1, round(1.4 * S))
    # shadow
    sw = 18 * S * (1 - hop * 2)
    d.ellipse([cx - sw, W * 0.90 - 2.5 * S, cx + sw, W * 0.90 + 2.5 * S], fill=(0, 0, 0, 70))
    # feet
    fy = cy + s * squash * 0.86
    for side in (-1, 1):
        fx = cx + side * 8 * S
        d.ellipse([fx - 5 * S, fy - 2.5 * S, fx + 5 * S, fy + 3 * S], fill=P["dark"], outline=P["out"], width=lw)
    # arms
    arm = {"down": [(-17, 4, -21, 12), (17, 4, 21, 12)], "up1": [(-17, 2, -21, 10), (17, 0, 24, -10)],
           "up": [(-16, 0, -24, -12), (16, 0, 24, -12)], "hug": [(-15, 4, -6, 10), (15, 4, 6, 10)]}[arms]
    for x0, y0, x1, y1 in arm:
        d.line([cx + x0 * S, cy + y0 * S, cx + x1 * S, cy + y1 * S], fill=P["out"], width=round(5 * S))
        d.line([cx + x0 * S, cy + y0 * S, cx + x1 * S, cy + y1 * S], fill=P["mid"], width=round(3 * S))
        r = 2.6 * S
        d.ellipse([cx + x1 * S - r, cy + y1 * S - r, cx + x1 * S + r, cy + y1 * S + r], fill=P["mid"], outline=P["out"], width=lw)
    # body: outline (grown mask), base, shade, light, highlight
    body = mask_of(W, place(shape(), cx, cy, s, squash, lean))
    k = round(2.2 * S) | 1
    fill(img, body.filter(ImageFilter.MaxFilter(k if k < 60 else 59)), P["out"])
    fill(img, body, P["mid"])
    shade = ImageChops.subtract(body, shift(body, 2.5 * S, -3 * S))
    fill(img, shade, P["dark"])
    light = ImageChops.multiply(body, shift(body.filter(ImageFilter.MinFilter(round(5 * S) | 1)), 2 * S, -2.5 * S))
    fill(img, light, P["light"])
    hx, hy = cx + 5 * S + lean * 0.4 * S, cy - 9 * S
    hm = Image.new("L", (W, W), 0)
    ImageDraw.Draw(hm).ellipse([hx - 3.2 * S, hy - 4.5 * S, hx + 3.2 * S, hy + 2.5 * S], fill=255)
    fill(img, ImageChops.multiply(hm, body), P["hi"])
    d = ImageDraw.Draw(img, "RGBA")
    # hat: a tiny copy of the suit, or a crown on victory
    top = min(y for poly in place(shape(), cx, cy, s, squash, lean) for _, y in poly)
    if extra == "crown":
        y = top + 1 * S
        c = (240, 190, 70)
        d.polygon([(cx - 8 * S, y + 3 * S), (cx - 8 * S, y - 4 * S), (cx - 4 * S, y), (cx, y - 6 * S),
                   (cx + 4 * S, y), (cx + 8 * S, y - 4 * S), (cx + 8 * S, y + 3 * S)], fill=c, outline=P["out"])
        for kk in (-4, 0, 4):
            d.ellipse([cx + kk * S - S, y - S, cx + kk * S + S, y + S], fill=P["acc"])
    else:
        hat = mask_of(W, place(shape(), cx + lean * 0.5 * S, top - 3.2 * S, 3.6 * S, 1.0, 0))
        fill(img, hat.filter(ImageFilter.MaxFilter(round(1.4 * S) | 1)), P["out"])
        fill(img, hat, P["acc"])
        d = ImageDraw.Draw(img, "RGBA")
    # face
    ey = cy + eye_dy * S
    for side in (-1, 1):
        x = cx + side * spread * S + lean * 0.15 * S
        if eyes == "happy":
            d.arc([x - 5 * S, ey - 4 * S, x + 5 * S, ey + 5 * S], 200, 340, fill=P["out"], width=round(2.2 * S))
            continue
        if eyes == "down":
            d.chord([x - 5 * S, ey - 4 * S, x + 5 * S, ey + 6 * S], 0, 180, fill=EYE, outline=P["out"], width=lw)
            d.ellipse([x - 2 * S, ey + 1 * S, x + 2 * S, ey + 5 * S], fill=PUPIL)
            continue
        rx, ry = (5.5, 6.5) if eyes == "wide" else (4.8, 6.0)
        d.ellipse([x - rx * S, ey - ry * S, x + rx * S, ey + ry * S], fill=EYE, outline=P["out"], width=lw)
        px = {"side": -2.2, "open": 0.3 * side, "wide": 0}[eyes] * S
        pr = (2.8 if eyes == "wide" else 2.5) * S
        d.ellipse([x + px - pr, ey - pr + 0.8 * S, x + px + pr, ey + pr + 0.8 * S], fill=PUPIL)
        g = 1.1 * S
        d.ellipse([x + px - 1.6 * S - g, ey - 1.6 * S - g, x + px - 1.6 * S + g, ey - 1.6 * S + g], fill=EYE)
        if brows:
            by = ey - ry * S - 2.5 * S
            t = 1.8 * S * brows * side
            d.line([x - 4 * S, by + t, x + 4 * S, by - t], fill=P["out"], width=round(1.8 * S))
    for side in (-1, 1):
        x = cx + side * (spread + 5.5) * S
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
        d.line([(cx - 5 * S + i * S, my + (0.9 if i % 2 else -0.9) * S) for i in range(11)], fill=P["out"], width=round(1.6 * S))
    elif mouth == "frown":
        d.arc([cx - 4 * S, my, cx + 4 * S, my + 6 * S], 200, 340, fill=P["out"], width=round(1.8 * S))
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
            d.polygon([(X, Y - R * 2), (X + R * .5, Y - R * .5), (X + R * 2, Y), (X + R * .5, Y + R * .5),
                       (X, Y + R * 2), (X - R * .5, Y + R * .5), (X - R * 2, Y), (X - R * .5, Y - R * .5)], fill=(255, 214, 102))
    small = img.resize((256, 256), Image.LANCZOS)
    glow = small.getchannel("A").filter(ImageFilter.GaussianBlur(10)).point(lambda v: int(v * 0.35))
    halo = Image.new("RGBA", (256, 256), P["light"] + (0,))
    halo.putalpha(glow)
    return Image.alpha_composite(halo, small)


def main():
    names = ONLY or list(CAST)
    poses = list(POSES)
    cell, pad = 256, 20
    felt = (30, 52, 44, 255)
    cast = Image.new("RGBA", (pad + len(names) * (cell + pad), cell + 70), felt)
    for ni, name in enumerate(names):
        sheet = Image.new("RGBA", (pad + len(poses) * (cell + pad), cell + 60), felt)
        sd = ImageDraw.Draw(sheet)
        for i, p in enumerate(poses):
            im = draw_char(name, p)
            im.save(f"{OUT}/{name}_{p}.png")
            sheet.alpha_composite(im, (pad + i * (cell + pad), 20))
            sd.text((pad + i * (cell + pad) + 4, cell + 26), p, fill=(220, 230, 220))
            if p == "cheer":
                cast.alpha_composite(im, (pad + ni * (cell + pad), 20))
        sheet.save(f"{OUT}/{name}_sheet.png")
        ImageDraw.Draw(cast).text((pad + ni * (cell + pad) + 4, cell + 30), f"{name}: {CAST[name][4]}", fill=(240, 220, 160))
    cast.save(f"{OUT}/cast.png")
    print(f"{OUT}/cast.png")


if __name__ == "__main__":
    main()
