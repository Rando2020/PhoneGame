#!/usr/bin/env python3
"""
Meldlings 2.0: the six playable Meldlings, illustrated style (B), six reaction
poses each, from one rig. Bodies are masks (so any silhouette works): the
outline is the mask grown, shading is the mask shrunk and offset, and the hat is
a small copy of the character's own suit.

Poses: idle, eager (the deal), nervous (near target, few deals), cheer (a big
count), victory (round cleared), deflated (run lost), plus one signature pose
each, tied to its rule (pip fifteen, thump slam, clover lucky, facet sparkle,
nib snip, muggins steal). Each Meldling has its own face (FACE).

  python3 tools/make_meldlings2.py OUTDIR [name ...]   (default: all six)
  OUTDIR/<name>_<pose>.png (256x256), OUTDIR/<name>_sheet.png, OUTDIR/cast.png
"""
import math, sys, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

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
    return [circle(0, -1, 14.8, 64), circle(-10.5, -12, 4.8), circle(10.5, -12, 4.8)]


CAST = {
    #            shape          palette                                                                                       eye spread, eye y, personality
    "pip":     (curve_spade,   pal((28, 24, 52), (70, 62, 132), (104, 96, 178), (146, 140, 216), (206, 204, 246), (255, 128, 168)), 7.5, 1, "eager, a little anxious"),
    "thump":   (curve_heart,   pal((72, 24, 42), (156, 54, 78), (204, 86, 110), (234, 130, 150), (252, 190, 202), (255, 214, 102)), 8.5, -2, "loud, all heart"),
    "clover":  (curve_club,    pal((20, 50, 32), (48, 108, 64), (78, 156, 92), (118, 192, 122), (178, 222, 170), (255, 170, 120)), 7.5, 1, "lucky, sunny"),
    "facet":   (curve_diamond, pal((86, 52, 14), (184, 124, 32), (226, 170, 52), (244, 206, 96), (255, 240, 180), (120, 210, 255)), 7.0, 0, "precious, a bit vain"),
    "nib":     (curve_nib,     pal((28, 34, 48), (58, 88, 120), (86, 128, 166), (124, 172, 208), (186, 222, 244), (255, 196, 120)), 6.0, 2, "sharp, quick"),
    "muggins": (curve_muggins, pal((44, 30, 20), (110, 74, 46), (150, 104, 66), (188, 142, 96), (226, 194, 152), (220, 110, 90)), 8.0, 0, "sly, scrappy"),
}

# Faces: personality that reads without colour.
#   eye (rx, ry): size; pupil: radius; brows: resting tilt (+ fierce, - worried) and
#   weight; mouth_dy: mouth height (keeps it out of the spade / heart notch);
#   traits: extras drawn on every pose.
FACE = {
    "pip":     dict(eye=(5.8, 7.0), pupil=2.1, brow=-1, brow_w=1.6, mouth_dy=6.5, hat=curve_spade, traits=["worry"]),
    "thump":   dict(eye=(4.6, 5.4), pupil=2.5, brow=1, brow_w=3.2, mouth_dy=5.5, hat=curve_heart, traits=["widegrin"]),
    "clover":  dict(eye=(4.8, 3.4), pupil=2.2, brow=0, brow_w=0, mouth_dy=8, hat=curve_club, traits=["freckles", "squint"]),
    "facet":   dict(eye=(4.8, 6.0), pupil=2.4, brow=0, brow_w=0, mouth_dy=8, hat=curve_diamond, traits=["lashes", "halflid"]),
    "nib":     dict(eye=(4.6, 3.0), pupil=1.9, brow=1, brow_w=1.4, mouth_dy=7, hat=curve_spade, traits=["narrow", "smirk"]),
    "muggins": dict(eye=(4.6, 5.6), pupil=2.4, brow=0, brow_w=1.8, mouth_dy=8, hat=curve_club, traits=["onebrow", "tooth"]),
}

# Signature poses, one each, tied to the Meldling's rule.
SIGNATURE = {
    "pip":     ("fifteen", (0.96, 0, 0.06, "wide", "grin", 1, "up1", "fifteen")),
    "thump":   ("slam",    (0.80, 0, -0.03, "happy", "open", 1, "slam", "slam")),
    "clover":  ("lucky",   (0.92, 0, 0.10, "happy", "open", 1, "up", "fourleaf")),
    "facet":   ("sparkle", (0.98, 3, 0.04, "wink", "smile", 0, "pose", "glints")),
    "nib":     ("snip",    (0.98, 0, 0.04, "open", "grin", 1, "snip", "snip")),
    "muggins": ("steal",   (0.98, -5, 0.02, "side", "grin", 1, "up1", "coin")),
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


def grow(mask, r):
    """Dilate by about r px (blur + threshold: far faster than MaxFilter)."""
    return mask.filter(ImageFilter.GaussianBlur(r / 2)).point(lambda v: 255 if v > 8 else 0)


def shrink(mask, r):
    return mask.filter(ImageFilter.GaussianBlur(r / 2)).point(lambda v: 255 if v > 247 else 0)


def star(d, X, Y, R, col):
    d.polygon([(X, Y - R * 2), (X + R * .5, Y - R * .5), (X + R * 2, Y), (X + R * .5, Y + R * .5),
               (X, Y + R * 2), (X - R * .5, Y + R * .5), (X - R * 2, Y), (X - R * .5, Y - R * .5)], fill=col)


def pose_of(name, pose):
    if pose in POSES:
        return POSES[pose]
    sig, tup = SIGNATURE[name]
    assert pose == sig, (name, pose)
    return tup


def draw_char(name, pose, W=512, out=256):
    shape, P, spread, eye_dy, _ = CAST[name]
    F = FACE[name]
    squash, lean, hop, eyes, mouth, brows, arms, extra = pose_of(name, pose)
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
           "up": [(-16, 0, -24, -12), (16, 0, 24, -12)], "hug": [(-15, 4, -6, 10), (15, 4, 6, 10)],
           "slam": [(-16, 2, -23, 15), (16, 2, 23, 15)], "pose": [(-17, 4, -21, 12), (16, 0, 12, -14)],
           "snip": [(-16, 2, -23, -6), (16, 2, 23, -6)]}[arms]
    for x0, y0, x1, y1 in arm:
        d.line([cx + x0 * S, cy + y0 * S, cx + x1 * S, cy + y1 * S], fill=P["out"], width=round(5 * S))
        d.line([cx + x0 * S, cy + y0 * S, cx + x1 * S, cy + y1 * S], fill=P["mid"], width=round(3 * S))
        r = 2.6 * S
        d.ellipse([cx + x1 * S - r, cy + y1 * S - r, cx + x1 * S + r, cy + y1 * S + r], fill=P["mid"], outline=P["out"], width=lw)
    # body: outline (grown mask), base, shade, light, highlight
    body = mask_of(W, place(shape(), cx, cy, s, squash, lean))
    fill(img, grow(body, 2.2 * S), P["out"])
    fill(img, body, P["mid"])
    shade = ImageChops.subtract(body, shift(body, 2.5 * S, -3 * S))
    fill(img, shade, P["dark"])
    light = ImageChops.multiply(body, shift(shrink(body, 5 * S), 2 * S, -2.5 * S))
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
        hat = mask_of(W, place(F["hat"](), cx + lean * 0.5 * S, top - 3.2 * S, 3.6 * S, 1.0, 0))
        fill(img, grow(hat, 1.4 * S), P["out"])
        fill(img, hat, P["acc"])
        d = ImageDraw.Draw(img, "RGBA")
    # face
    ey = cy + eye_dy * S
    T = F["traits"]
    rx0, ry0 = F["eye"]
    for side in (-1, 1):
        x = cx + side * spread * S + lean * 0.15 * S
        e = eyes
        if e == "wink" and side == 1:
            e = "happy"
        elif e == "wink":
            e = "open"
        if e == "happy":
            d.arc([x - 5 * S, ey - 4 * S, x + 5 * S, ey + 5 * S], 200, 340, fill=P["out"], width=round(2.2 * S))
        elif e == "down":
            d.chord([x - rx0 * S, ey - 4 * S, x + rx0 * S, ey + 6 * S], 0, 180, fill=EYE, outline=P["out"], width=lw)
            d.ellipse([x - 2 * S, ey + 1 * S, x + 2 * S, ey + 5 * S], fill=PUPIL)
        else:
            rx, ry = (rx0 * 1.12, ry0 * 1.1) if e == "wide" else (rx0, ry0)
            if "narrow" in T:          # almond eyes, tilted up at the outside
                pts = [(x - rx * S, ey + side * 0.0), (x, ey - ry * S - side * 0), (x + rx * S, ey), (x, ey + ry * S)]
                t = 1.6 * S * side
                pts = [(x - rx * S, ey + t), (x - rx * 0.2 * S, ey - ry * S), (x + rx * S, ey - t), (x + rx * 0.2 * S, ey + ry * S)]
                d.polygon(pts, fill=EYE, outline=P["out"])
                d.line(pts + [pts[0]], fill=P["out"], width=lw)
            else:
                d.ellipse([x - rx * S, ey - ry * S, x + rx * S, ey + ry * S], fill=EYE, outline=P["out"], width=lw)
            px = {"side": -2.0, "open": 0.3 * side, "wide": 0}[e] * S
            pr = F["pupil"] * (1.1 if e == "wide" else 1.0) * S
            pr = min(pr, ry * S * 0.85)
            pyo = 0.8 * S if ry > 4 else 0.2 * S
            d.ellipse([x + px - pr, ey - pr + pyo, x + px + pr, ey + pr + pyo], fill=PUPIL)
            g = min(1.1 * S, pr * 0.45)
            d.ellipse([x + px - pr * 0.6 - g, ey - pr * 0.6 - g + pyo, x + px - pr * 0.6 + g, ey - pr * 0.6 + g + pyo], fill=EYE)
            if "halflid" in T:        # smug: the top of the eye under a lid
                d.chord([x - rx * S - lw, ey - ry * S - lw, x + rx * S + lw, ey + ry * S * 0.25], 180, 360, fill=P["mid"])
                d.line([x - rx * S, ey - ry * S * 0.2, x + rx * S, ey - ry * S * 0.2], fill=P["out"], width=round(1.6 * S))
            if "worry" in T and e != "wide":   # big round eyes, a wobble of shine
                d.ellipse([x + px + pr * 0.3, ey + pr * 0.4 + pyo, x + px + pr * 0.7, ey + pr * 0.8 + pyo], fill=EYE)
        if "lashes" in T and e != "down":
            for k in range(3):
                a = math.radians(200 + k * 25) if side < 0 else math.radians(340 - k * 25)
                ox, oy = x + side * rx0 * 0.6 * S, ey - ry0 * 0.85 * S
                d.line([ox, oy, ox + side * (2.0 + k * 0.8) * S, oy - (2.6 - k * 0.6) * S], fill=P["out"], width=round(1.2 * S))
        # brows: the pose's brow plus the character's resting brow
        bw = F["brow_w"]
        tilt = brows if brows else F["brow"]
        if "onebrow" in T:
            if side < 0:
                by = ey - ry0 * S - 4.5 * S
                d.arc([x - 4.5 * S, by - 1 * S, x + 4.5 * S, by + 4 * S], 200, 340, fill=P["out"], width=round(bw * S))
            else:
                by = ey - ry0 * S - 1.8 * S
                d.line([x - 4 * S, by, x + 4 * S, by + 0.6 * S], fill=P["out"], width=round(bw * S))
        elif bw and (tilt or "worry" in T):
            by = ey - ry0 * S - 2.4 * S
            t = 1.8 * S * tilt * side
            d.line([x - 4 * S, by + t, x + 4 * S, by - t], fill=P["out"], width=round(bw * S))
    for side in (-1, 1):
        x = cx + side * (spread + 5.5) * S
        d.ellipse([x - 3 * S, ey + 5 * S, x + 3 * S, ey + 7.5 * S], fill=P["acc"] + (150,))
        if "freckles" in T:
            for fx, fy in ((-1.6, 2.6), (0.4, 3.4), (1.8, 2.4)):
                d.ellipse([x + fx * S - 0.6 * S, ey + fy * S - 0.6 * S, x + fx * S + 0.6 * S, ey + fy * S + 0.6 * S], fill=P["out"] + (190,))
    my = ey + (F["mouth_dy"] - (2 if mouth == "frown" else 0)) * S
    wide = 1.5 if "widegrin" in T else 1.0
    if mouth == "smile" and "smirk" in T:
        mouth = "smirk"
    if mouth == "smile":
        d.arc([cx - 4 * S, my - 3 * S, cx + 4 * S, my + 2.5 * S], 20, 160, fill=P["out"], width=round(1.8 * S))
    elif mouth == "smirk" or (mouth == "grin" and "smirk" in T):
        d.line([cx - 4 * S, my + 0.6 * S, cx + 1 * S, my + 1 * S, cx + 4.5 * S, my - 1.6 * S], fill=P["out"], width=round(1.8 * S), joint="curve")
    elif mouth == "grin":
        d.chord([cx - 5 * wide * S, my - 3 * S, cx + 5 * wide * S, my + 4 * S], 0, 180, fill=P["out"])
        d.chord([cx - 3 * wide * S, my + 0.5 * S, cx + 3 * wide * S, my + 3.6 * S], 0, 180, fill=P["acc"])
        if "widegrin" in T:
            d.rectangle([cx - 4.5 * wide * S, my + 0.4 * S, cx + 4.5 * wide * S, my + 1.4 * S], fill=EYE)
    elif mouth == "open":
        d.ellipse([cx - 4.5 * wide * S, my - 2 * S, cx + 4.5 * wide * S, my + 5 * S], fill=P["out"])
        d.ellipse([cx - 2.8 * wide * S, my + 1.5 * S, cx + 2.8 * wide * S, my + 4.6 * S], fill=P["acc"])
    elif mouth == "wobble":
        d.line([(cx - 5 * S + i * S, my + (0.9 if i % 2 else -0.9) * S) for i in range(11)], fill=P["out"], width=round(1.6 * S))
    elif mouth == "frown":
        d.arc([cx - 4 * S, my, cx + 4 * S, my + 6 * S], 200, 340, fill=P["out"], width=round(1.8 * S))
    if "tooth" in T and mouth in ("smile", "grin", "open", "smirk"):
        tx = cx + 1.8 * S
        d.polygon([(tx - 1.2 * S, my + 0.2 * S), (tx + 1.2 * S, my + 0.2 * S), (tx, my + 2.6 * S)], fill=EYE, outline=P["out"])
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
    gold, gold_d = (255, 206, 84), (176, 120, 30)
    if extra == "fifteen":       # Pip counts it out: a badge and three fingers
        X, Y = cx + 24 * S, cy - 10 * S
        for k in range(3):
            d.line([X - 1.5 * S + k * 1.5 * S, Y + 1 * S, X - 2.2 * S + k * 2.2 * S, Y - 3.4 * S], fill=P["out"], width=round(1.6 * S))
        bx, by = cx - 20 * S, cy - 22 * S
        d.ellipse([bx - 7 * S, by - 6 * S, bx + 7 * S, by + 6 * S], fill=gold, outline=P["out"], width=lw)
        f = ImageFont.truetype(FONT, int(8.5 * S))
        d.text((bx, by), "15", fill=P["out"], font=f, anchor="mm")
    if extra == "slam":          # Thump hits the table: impact lines
        y = cy + 15 * S
        d.line([cx - 30 * S, y + 3 * S, cx + 30 * S, y + 3 * S], fill=(120, 80, 50), width=round(2.4 * S))
        for side in (-1, 1):
            X = cx + side * 23 * S
            for k in range(3):
                a = math.radians(-60 - k * 30) if side > 0 else math.radians(-120 + k * 30)
                d.line([X + math.cos(a) * 4 * S, y + math.sin(a) * 4 * S, X + math.cos(a) * 8 * S, y + math.sin(a) * 8 * S], fill=gold, width=round(1.6 * S))
        f = ImageFont.truetype(FONT, int(9 * S))
        d.text((cx + 20 * S, cy - 22 * S), "!", fill=gold, font=f, anchor="mm", stroke_width=round(0.8 * S), stroke_fill=P["out"])
    if extra == "fourleaf":      # Clover's lucky cut: a four-leaf clover pops overhead
        X, Y, r = cx, cy - 30 * S, 3.4 * S
        green = (96, 196, 106)
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            d.ellipse([X + dx * r - r, Y + dy * r - r, X + dx * r + r, Y + dy * r + r], fill=green, outline=P["out"], width=lw)
        d.ellipse([X - 1.2 * S, Y - 1.2 * S, X + 1.2 * S, Y + 1.2 * S], fill=gold)
        star(d, X - 12 * S, Y + 2 * S, 1.8 * S, gold)
        star(d, X + 12 * S, Y - 2 * S, 1.5 * S, gold)
    if extra == "glints":        # Facet catches the light
        for x, y, r in ((-18, -12, 2.4), (19, -4, 3.0), (-14, 12, 1.6), (8, -24, 1.8)):
            star(d, cx + x * S, cy + y * S, r * S, (255, 255, 240))
    if extra == "snip":          # Nib's hands become scissor blades
        for side in (-1, 1):
            X, Y = cx + side * 23 * S, cy - 6 * S
            d.line([X - 3 * S, Y + 4 * S, X + 3 * S, Y - 6 * S], fill=(210, 220, 232), width=round(1.6 * S))
            d.line([X + 3 * S, Y + 4 * S, X - 3 * S, Y - 6 * S], fill=(210, 220, 232), width=round(1.6 * S))
            d.ellipse([X - 1.2 * S, Y - 2.2 * S, X + 1.2 * S, Y + 0.2 * S], fill=P["out"])
        for k in range(3):
            d.line([cx - 6 * S + k * 6 * S, cy - 26 * S, cx - 4 * S + k * 6 * S, cy - 23 * S], fill=(210, 220, 232), width=round(1.0 * S))
    if extra == "coin":          # Muggins pockets a coin
        X, Y, r = cx + 24 * S, cy - 13 * S, 4.2 * S
        d.ellipse([X - r, Y - r, X + r, Y + r], fill=gold, outline=gold_d, width=round(1.2 * S))
        d.ellipse([X - r * 0.55, Y - r * 0.55, X + r * 0.55, Y + r * 0.55], outline=gold_d, width=round(0.8 * S))
        star(d, X + 5 * S, Y - 5 * S, 1.2 * S, (255, 255, 240))
    small = img.resize((out, out), Image.LANCZOS)
    glow = small.getchannel("A").filter(ImageFilter.GaussianBlur(10 * out / 256)).point(lambda v: int(v * 0.35))
    halo = Image.new("RGBA", (out, out), P["light"] + (0,))
    halo.putalpha(glow)
    return Image.alpha_composite(halo, small)


# ================================================================ Spoilers
# Same rig, a villain read: heavier outline, fierce brows, a silhouette or prop
# that hints at the rule. Severity cools and darkens the palette; sev 3 glows red.
SPOILER_USES = {   # art id -> severities it appears at (CribData.BOSS_POOL)
    "auditor": [1, 3], "famine": [1, 2, 3], "jokester": [1, 3], "deadwood": [1],
    "leaden": [1, 2, 3], "thief": [2], "kingpin": [2], "fog": [2], "eclipse": [3],
}
SPOILER_POSES = {
    #          squash lean hop   eyes      mouth    arms     extra
    "idle":     (1.00, 0, 0.00, "glare",  "sneer", "down",  None),
    "smug":     (1.00, 4, 0.02, "lidded", "smirk", "cross", None),
    "stung":    (1.04, -7, 0.03, "shock", "grit",  "flail", "sweat"),
    "defeated": (1.14, 0, -0.03, "xx",    "frown", "down",  "drip"),
    "gloat":    (0.92, 0, 0.10, "evil",   "laugh", "up",    "spark"),
}


def curve_ledger():   # The Auditor: a closed ledger standing up
    return [[(-14, -17), (13, -17), (15, -15), (15, 16), (13, 17), (-14, 17), (-15, 15), (-15, -15)]]


def curve_gaunt():    # Famine: tall and thin
    return [circle(0, 0, 1, 64)] and [[(9.5 * math.cos(t), 17.5 * math.sin(t)) for t in [2 * math.pi * i / 64 for i in range(64)]]]


def curve_jester():   # Shortstop / Shears: round body, two-pointed cap
    return [circle(0, 3, 14.5, 64), [(-14, -6), (-19, -21), (-5, -10)], [(14, -6), (19, -21), (5, -10)], [(-9, -9), (0, -15), (9, -9)]]


def curve_stump():    # Blight: a stump with two twig horns
    return [[(-14, 17), (-13, -11), (-8, -15), (8, -15), (13, -11), (14, 17)], [(-9, -14), (-15, -24), (-6, -16)], [(9, -14), (15, -24), (6, -16)]]


def curve_block():    # Leaden / Chains / Iron Grip: a heavy rounded block
    pts = []
    for i in range(64):
        t = 2 * math.pi * i / 64
        c, s_ = math.cos(t), math.sin(t)
        pts.append((16 * math.copysign(abs(c) ** 0.45, c), 16 * math.copysign(abs(s_) ** 0.45, s_)))
    return [pts]


def curve_sack():     # The Thief / The Levy: a fat sack, tied at the top
    return [circle(0, 4, 14.5, 64), [(-5, -10), (5, -10), (8, -18), (-8, -18)]]


def curve_kingpin():  # Miser's Curse: broad shoulders
    return [[(x * 1.15, y) for x, y in circle(0, 2, 15.5, 64)]]


def curve_cloud():    # The Fog / The Hush
    return [circle(-8, 3, 9), circle(8, 3, 9), circle(0, -5, 10.5), circle(-12, 9, 6), circle(12, 9, 6), [(-14, 6), (14, 6), (12, 14), (-12, 14)]]


def curve_eclipse():  # Eclipse: a dark disc
    return [circle(0, 0, 16.5, 72)]


SPOILERS = {
    # art: (shape, base hue palette (out, dark, mid, light, hi, acc), eye spread, prop)
    "auditor":  (curve_ledger,  pal((30, 26, 22), (84, 62, 44), (118, 90, 64), (150, 120, 90), (196, 172, 140), (220, 60, 60)), 6.5, "spectacles"),
    "famine":   (curve_gaunt,   pal((32, 28, 20), (96, 88, 60), (132, 122, 86), (164, 154, 112), (204, 196, 160), (190, 150, 60)), 4.6, "bowl"),
    "jokester": (curve_jester,  pal((40, 16, 40), (110, 40, 96), (148, 62, 128), (180, 98, 160), (220, 160, 206), (232, 200, 60)), 6.5, "bells"),
    "deadwood": (curve_stump,   pal((28, 22, 16), (70, 52, 36), (98, 74, 50), (126, 98, 68), (166, 138, 104), (120, 170, 80)), 6.5, "rings"),
    "leaden":   (curve_block,   pal((22, 24, 30), (70, 76, 88), (100, 108, 122), (132, 140, 156), (180, 186, 198), (200, 170, 70)), 7.0, "padlock"),
    "thief":    (curve_sack,    pal((26, 22, 30), (70, 62, 84), (98, 88, 116), (128, 118, 146), (172, 164, 188), (230, 190, 70)), 6.5, "mask"),
    "kingpin":  (curve_kingpin, pal((30, 20, 34), (84, 48, 92), (116, 70, 126), (146, 100, 156), (190, 150, 196), (232, 182, 76)), 7.0, "crown"),
    "fog":      (curve_cloud,   pal((40, 44, 56), (112, 118, 136), (146, 152, 170), (178, 184, 200), (214, 218, 230), (150, 230, 220)), 6.5, None),
    "eclipse":  (curve_eclipse, pal((8, 6, 14), (26, 22, 40), (40, 34, 58), (60, 52, 84), (255, 170, 80), (255, 110, 60)), 6.5, "corona"),
}


def _sev_pal(P, sev):
    """Severity cools and darkens: 1 grumpy (as drawn), 2 menacing, 3 ruinous."""
    if sev == 1:
        return P
    k, cool = (0.80, 18) if sev == 2 else (0.62, 30)
    out = {}
    for key, (r, g, b) in P.items():
        if key == "acc":
            out[key] = (r, g, b) if sev == 2 else (255, 70, 60)
            continue
        out[key] = (int(r * k), int(g * k), min(255, int(b * k) + cool))
    return out


def draw_spoiler(art, sev, pose, W=512):
    shape, P0, spread, prop = SPOILERS[art]
    P = _sev_pal(P0, sev)
    squash, lean, hop, eyes, mouth, arms, extra = SPOILER_POSES[pose]
    S = W / 64.0
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy, s = W / 2, W * (0.58 - hop * 0.6), 20 * S
    lw = max(1, round(1.8 * S))
    sw = 18 * S * (1 - hop * 2)
    d.ellipse([cx - sw, W * 0.90 - 2.5 * S, cx + sw, W * 0.90 + 2.5 * S], fill=(0, 0, 0, 90))
    fy = cy + s * squash * 0.86
    for side in (-1, 1):
        fx = cx + side * 8 * S
        d.ellipse([fx - 5 * S, fy - 2.5 * S, fx + 5 * S, fy + 3 * S], fill=P["dark"], outline=P["out"], width=lw)
    arm = {"down": [(-15, 4, -20, 13), (15, 4, 20, 13)], "up": [(-15, 0, -24, -13), (15, 0, 24, -13)],
           "cross": [(-15, 4, 4, 9), (15, 4, -4, 9)], "flail": [(-15, 2, -25, -4), (15, 2, 22, 12)]}[arms]
    def arms_(dd):
        for x0, y0, x1, y1 in arm:
            dd.line([cx + x0 * S, cy + y0 * S, cx + x1 * S, cy + y1 * S], fill=P["out"], width=round(5.6 * S))
            dd.line([cx + x0 * S, cy + y0 * S, cx + x1 * S, cy + y1 * S], fill=P["mid"], width=round(3.2 * S))
            r = 2.8 * S
            dd.ellipse([cx + x1 * S - r, cy + y1 * S - r, cx + x1 * S + r, cy + y1 * S + r], fill=P["mid"], outline=P["out"], width=lw)
    if arms != "cross":
        arms_(d)
    polys = place(shape(), cx, cy, s, squash, lean)
    body = mask_of(W, polys)
    fill(img, grow(body, 3.2 * S), P["out"])            # heavier outline: a villain read
    fill(img, body, P["mid"])
    fill(img, ImageChops.subtract(body, shift(body, 2.5 * S, -3 * S)), P["dark"])
    fill(img, ImageChops.multiply(body, shift(shrink(body, 5 * S), 2 * S, -2.5 * S)), P["light"])
    d = ImageDraw.Draw(img, "RGBA")
    if arms == "cross":
        arms_(d)              # folded arms sit in front of the body
    top = min(y for poly in polys for _, y in poly)
    # props that hint at the rule
    if prop == "padlock":
        x, y = cx, cy + 9 * S
        d.arc([x - 3.4 * S, y - 7 * S, x + 3.4 * S, y], 180, 360, fill=P["acc"], width=round(1.8 * S))
        d.rounded_rectangle([x - 5 * S, y - 2 * S, x + 5 * S, y + 6 * S], radius=1.4 * S, fill=P["acc"], outline=P["out"], width=lw)
        d.ellipse([x - 1 * S, y + 1 * S, x + 1 * S, y + 3 * S], fill=P["out"])
    if prop == "rings":
        for r in (4, 7):
            d.arc([cx - r * S, top + 1 * S, cx + r * S, top + 5 * S], 0, 180, fill=P["dark"], width=round(1 * S))
    if prop == "crown":
        y = top + 1.5 * S
        dk = (130, 100, 40) if sev > 1 else (232, 182, 76)
        d.polygon([(cx - 9 * S, y + 3 * S), (cx - 9 * S, y - 5 * S), (cx - 4.5 * S, y - 1 * S), (cx, y - 7 * S),
                   (cx + 4.5 * S, y - 1 * S), (cx + 9 * S, y - 5 * S), (cx + 9 * S, y + 3 * S)], fill=dk, outline=P["out"])
    if prop == "bells":
        for x, y in ((-19, -21), (19, -21)):
            X, Y = cx + x * S + lean * 0.6 * S, cy + y * S * squash
            d.ellipse([X - 2.2 * S, Y - 2.2 * S, X + 2.2 * S, Y + 2.2 * S], fill=P["acc"], outline=P["out"], width=lw)
    if prop == "corona":
        for k in range(14):
            a = 2 * math.pi * k / 14
            r0, r1 = 18 * S, (21 if k % 2 else 23) * S
            d.line([cx + math.cos(a) * r0, cy + math.sin(a) * r0, cx + math.cos(a) * r1, cy + math.sin(a) * r1], fill=P["acc"], width=round(1.4 * S))
    # face: fierce brows, narrow mean eyes
    ey = cy - 2 * S
    if prop == "mask":
        d.rounded_rectangle([cx - 16 * S, ey - 5 * S, cx + 16 * S, ey + 4.5 * S], radius=3 * S, fill=P["out"])
        d.line([cx + 15 * S, ey - 1 * S, cx + 22 * S, ey - 4 * S], fill=P["out"], width=round(1.6 * S))
    for side in (-1, 1):
        x = cx + side * spread * S + lean * 0.15 * S
        if eyes == "xx":
            for a in (-1, 1):
                d.line([x - 3 * S, ey + a * 3 * S, x + 3 * S, ey - a * 3 * S], fill=EYE if prop == "mask" else P["out"], width=round(1.8 * S))
            continue
        if eyes == "evil":
            d.arc([x - 4.5 * S, ey - 2 * S, x + 4.5 * S, ey + 6 * S], 200, 340, fill=EYE if prop == "mask" else P["out"], width=round(2.2 * S))
        else:
            rx, ry = {"glare": (4.2, 3.2), "lidded": (4.2, 2.2), "shock": (5.2, 5.6)}[eyes]
            glow = sev == 3 or art in ("fog", "eclipse")
            ecol = (255, 120, 90) if (sev == 3 and art != "fog") else ((170, 255, 240) if art == "fog" else EYE)
            d.ellipse([x - rx * S, ey - ry * S, x + rx * S, ey + ry * S], fill=ecol, outline=P["out"], width=lw)
            pr = min(ry * 0.8, 2.0) * S
            px = -side * 0.8 * S if eyes != "shock" else 0
            d.ellipse([x + px - pr, ey - pr, x + px + pr, ey + pr], fill=PUPIL if not glow else (60, 10, 10))
            if eyes == "lidded":
                d.line([x - rx * S, ey - 1 * S, x + rx * S, ey - 1 * S], fill=P["out"], width=round(1.8 * S))
        if prop == "spectacles" and eyes != "xx":
            d.ellipse([x - 5.4 * S, ey - 4.6 * S, x + 5.4 * S, ey + 4.6 * S], outline=(200, 190, 150), width=round(1.2 * S))
        # brows slant down to the middle: angry; stung: up in alarm
        by = ey - 5.6 * S
        t = 2.2 * S * side * (-0.6 if eyes == "shock" else 1)
        d.line([x - 4.5 * S, by - t, x + 4.5 * S, by + t], fill=P["out"] if prop != "mask" else P["dark"], width=round(2.6 * S))
    if prop == "spectacles":
        d.line([cx - spread * S + 5.4 * S, ey, cx + spread * S - 5.4 * S, ey], fill=(200, 190, 150), width=round(1.2 * S))
    my = ey + 8.5 * S
    if mouth == "sneer":
        d.line([cx - 5 * S, my + 1 * S, cx, my, cx + 5 * S, my - 1.6 * S], fill=P["out"], width=round(1.8 * S), joint="curve")
    elif mouth == "smirk":
        d.line([cx - 4 * S, my + 0.6 * S, cx + 1 * S, my + 1 * S, cx + 5 * S, my - 2.2 * S], fill=P["out"], width=round(1.8 * S), joint="curve")
    elif mouth == "grit":
        d.rounded_rectangle([cx - 5 * S, my - 1.6 * S, cx + 5 * S, my + 2.4 * S], radius=1 * S, fill=EYE, outline=P["out"], width=lw)
        for k in (-2.5, 0, 2.5):
            d.line([cx + k * S, my - 1.6 * S, cx + k * S, my + 2.4 * S], fill=P["out"], width=round(0.8 * S))
    elif mouth == "frown":
        d.arc([cx - 4.5 * S, my, cx + 4.5 * S, my + 6 * S], 200, 340, fill=P["out"], width=round(1.8 * S))
    elif mouth == "laugh":
        d.chord([cx - 6 * S, my - 3 * S, cx + 6 * S, my + 5 * S], 0, 180, fill=P["out"])
        d.polygon([(cx - 4 * S, my + 1 * S), (cx - 2.6 * S, my + 1 * S), (cx - 3.3 * S, my + 2.6 * S)], fill=EYE)
        d.polygon([(cx + 2.6 * S, my + 1 * S), (cx + 4 * S, my + 1 * S), (cx + 3.3 * S, my + 2.6 * S)], fill=EYE)
    if prop == "bowl":
        x, y = cx - 22 * S, cy + 14 * S
        d.chord([x - 5 * S, y - 3 * S, x + 5 * S, y + 4 * S], 0, 180, fill=P["acc"], outline=P["out"], width=lw)
    if extra == "sweat":
        x, y = cx + 15 * S, cy - 12 * S
        d.polygon([(x, y - 4 * S), (x - 2.5 * S, y + 1 * S), (x + 2.5 * S, y + 1 * S)], fill=(140, 210, 255))
        d.ellipse([x - 2.5 * S, y - 1 * S, x + 2.5 * S, y + 3.5 * S], fill=(140, 210, 255), outline=P["out"])
    if extra == "drip":
        d.ellipse([cx - 13 * S, cy - 5 * S, cx - 9 * S, cy - 1 * S], fill=(140, 210, 255))
    if extra == "spark":
        for x, y, r in ((-24, -16, 2.6), (24, -18, 2.2)):
            star(d, cx + x * S, cy + y * S, r * S, P["acc"])
    small = img.resize((256, 256), Image.LANCZOS)
    if sev == 3 or art == "eclipse":
        gcol, ga = (255, 60, 40), 0.75     # ruinous: a red glow
    else:
        gcol, ga = P["dark"], 0.35
    glow = small.getchannel("A").filter(ImageFilter.GaussianBlur(12 if sev == 3 else 9)).point(lambda v: int(v * ga))
    halo = Image.new("RGBA", (256, 256), gcol + (0,))
    halo.putalpha(glow)
    return Image.alpha_composite(halo, small)


def spoilers(out_dir):
    poses = list(SPOILER_POSES)
    cell, pad = 256, 16
    rows = [(a, sv) for a in SPOILER_USES for sv in SPOILER_USES[a]]
    sheet = Image.new("RGBA", (pad + len(poses) * (cell + pad) + 150, pad + len(rows) * (cell + pad)), (24, 26, 34, 255))
    sd = ImageDraw.Draw(sheet)
    for r, (art, sv) in enumerate(rows):
        y = pad + r * (cell + pad)
        sd.text((pad, y + cell // 2), f"{art}\nsev {sv}", fill=(230, 220, 200))
        for i, p in enumerate(poses):
            im = draw_spoiler(art, sv, p)
            im.save(f"{out_dir}/spoiler_{art}_s{sv}_{p}.png")
            sheet.alpha_composite(im, (150 + i * (cell + pad), y))
    sheet.save(f"{out_dir}/spoilers_sheet.png")
    print(f"{out_dir}/spoilers_sheet.png ({len(rows) * len(poses)} sprites)")


def main():
    names = ONLY or list(CAST)
    poses = list(POSES)
    cell, pad = 256, 20
    felt = (30, 52, 44, 255)
    cast = Image.new("RGBA", (pad + len(names) * (cell + pad), cell + 70), felt)
    for ni, name in enumerate(names):
        poses = list(POSES) + [SIGNATURE[name][0]]
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
    if ONLY == ["spoilers"]:
        spoilers(OUT)
    else:
        main()
        if not ONLY:
            spoilers(OUT)
