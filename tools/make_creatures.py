#!/usr/bin/env python3
"""
Meldlings creature generator (v2).

Silhouettes are per-row half-width tables; faces are hand-authored pixel grids.
Animation is derived from the base sprite via squash / stretch / lean, so a new
creature costs one silhouette rather than twelve frames.

Per creature:
  <name>_idle.png    6-frame strip
  <name>_attack.png  5-frame strip
  <name>_hurt.png    4-frame strip
  <name>.gif         looping idle preview (6x)
"""
from PIL import Image
import os

OUT = "/home/claude/out/assets/meldlings"
CLEAR = (0, 0, 0, 0)
WHITE = (246, 244, 238)
BLACK = (26, 24, 36)
GOLD = (232, 182, 76)
GOLD_D = (168, 124, 40)

# (outline, dark, mid, light, hilite, accent)
PAL = {
    "spade":   ((24, 22, 38), (52, 50, 92), (78, 75, 130), (110, 106, 172), (154, 152, 208), (196, 120, 150)),
    "heart":   ((72, 24, 42), (156, 54, 78), (200, 84, 108), (230, 126, 146), (250, 182, 194), (255, 150, 170)),
    "club":    ((20, 50, 32), (48, 108, 64), (74, 150, 88), (112, 186, 116), (170, 216, 164), (200, 160, 120)),
    "diamond": ((86, 52, 14), (180, 120, 30), (222, 166, 48), (242, 204, 90), (252, 234, 164), (250, 160, 90)),
    "wood":    ((38, 24, 18), (84, 54, 36), (122, 82, 52), (156, 114, 74), (190, 154, 110), (120, 60, 50)),
    "ghost":   ((34, 20, 52), (76, 44, 108), (108, 68, 150), (144, 104, 186), (194, 164, 224), (120, 220, 210)),
    "jester":  ((46, 18, 42), (126, 38, 90), (170, 60, 120), (206, 98, 156), (238, 158, 198), (232, 182, 76)),
    "king":    ((30, 26, 44), (64, 58, 94), (94, 86, 134), (130, 122, 176), (180, 174, 212), (232, 182, 76)),
    "nib":     ((28, 34, 48), (58, 84, 112), (84, 122, 156), (120, 166, 200), (176, 214, 240), (240, 190, 120)),
    "muggins": ((44, 30, 20), (108, 72, 44), (146, 100, 62), (184, 138, 92), (222, 188, 146), (200, 120, 90)),
}

PIPS = {
    "S": ["...#...", "..###..", ".#####.", "#######", "#######", "...#...", "..###.."],
    "H": [".##.##.", "#######", "#######", "#######", ".#####.", "..###..", "...#..."],
    "C": ["..###..", "..###..", "#######", "#######", "#.###.#", "...#...", "..###.."],
    "D": ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."],
}
CROWN = [
    "#..#..#..#..#",
    "#..#######..#",
    "#############",
    "#############",
    "#.#.#.#.#.#.#",
    "#############",
]

# mouths: '#' = outline colour, 'w' = white (teeth)
MOUTHS = {
    "smile":  ["#...#", ".###."],
    "smol":   [".##."],
    "o":      [".##.", "####", ".##."],
    "cat":    ["#.#.#", ".#.#."],
    "fang":   ["#########", "#w#w#w#w#", ".#######."],
    "grin":   ["###########", "#w#w#w#w#w#", ".#########."],
    "snarl":  [".#########.", "#w#w#w#w#w#", "###########", ".#########."],
}

BLINK = False   # flipped by build_strip when rendering the blink frame


# ------------------------------------------------------------------ primitives
def new_img(w, h):
    return Image.new("RGBA", (w, h), CLEAR)


def px(img, x, y, c):
    if 0 <= x < img.size[0] and 0 <= y < img.size[1]:
        img.putpixel((x, y), c)


def body(img, cx, y0, hws, pal, rim=True):
    n = len(hws)
    for i, hw in enumerate(hws):
        if hw <= 0:
            continue
        y = y0 + i
        t = i / max(1, n - 1)
        base = pal[4] if t < 0.18 else pal[3] if t < 0.46 else pal[2] if t < 0.76 else pal[1]
        for x in range(cx - hw, cx + hw):
            c = base
            if rim and x < cx - hw + 2 and t < 0.55:
                c = pal[4]
            if x >= cx + hw - 2 and t > 0.35:
                c = pal[1]
            px(img, x, y, c)


def disc(img, cx, cy, r, c):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r // 2:
                px(img, x, y, c)


def stamp(img, grid, x0, y0, c, white=WHITE):
    for j, row in enumerate(grid):
        for i, ch in enumerate(row):
            if ch == "#":
                px(img, x0 + i, y0 + j, c)
            elif ch == "w":
                px(img, x0 + i, y0 + j, white)


def shadow(img, cx, y, rx, ry=2, a=90):
    """Soft contact shadow so creatures sit on a surface instead of floating."""
    for j in range(-ry, ry + 1):
        for i in range(-rx, rx + 1):
            if (i / max(1, rx)) ** 2 + (j / max(1, ry)) ** 2 <= 1.0:
                px_, py_ = cx + i, y + j
                if 0 <= px_ < img.size[0] and 0 <= py_ < img.size[1]:
                    if img.getpixel((px_, py_))[3] == 0:
                        img.putpixel((px_, py_), (12, 10, 20, a))


def specular(img, cx, cy, pal):
    """A two-pixel gleam on the upper-left, the classic 16-bit read for volume."""
    for (dx, dy) in ((0, 0), (1, 0), (0, 1)):
        x, y = cx + dx, cy + dy
        if 0 <= x < img.size[0] and 0 <= y < img.size[1] and img.getpixel((x, y))[3]:
            img.putpixel((x, y), (255, 255, 255, 235))


def outline(img, c):
    w, h = img.size
    filled = [[img.getpixel((x, y))[3] > 0 for x in range(w)] for y in range(h)]
    edge = []
    for y in range(h):
        for x in range(w):
            if filled[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and filled[ny][nx]:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px(img, x, y, c)


# ------------------------------------------------------------------ features
def eyes(img, cx, y, spread, pal, ew=5, eh=6, brow=False, pupil_in=0, sclera=WHITE,
         shape="round", lash=False):
    """Big readable eyes: sclera with clipped corners, solid pupil, glint."""
    for s in (-1, 1):
        ex = cx + s * spread
        left = ex - ew // 2
        if BLINK:
            for i in range(ew):
                px(img, left + i, y + eh // 2, pal[0])
                px(img, left + i, y + eh // 2 + 1, pal[0])
            continue
        for j in range(eh):
            for i in range(ew):
                if shape == "round" and (j in (0, eh - 1)) and (i in (0, ew - 1)):
                    continue
                if shape == "sharp" and (j == 0 and i in (0, ew - 1)):
                    continue
                if shape == "sleepy" and j == 0:
                    continue
                px(img, left + i, y + j, sclera)
        if lash:
            for i in range(ew):
                px(img, left + i, y - 1, pal[0])
            px(img, left + (ew if s > 0 else -1), y - 1, pal[0])
        pxx = left + (ew - 2) // 2 + (pupil_in * -s)
        for j in range(3):
            for i in range(2):
                px(img, pxx + i, y + 2 + j, BLACK)
        px(img, pxx, y + 2, WHITE)
        # second, smaller catchlight low in the eye
        px(img, pxx + 1, y + 4, (255, 255, 255, 170))
        if brow:
            span = ew + 2
            for i in range(span):
                t = i / float(span - 1)
                rel = t if s < 0 else 1.0 - t      # 0 outer -> 1 inner
                yy = y - 4 + int(round(rel * 4))
                px(img, left - 1 + i, yy, pal[0])
                px(img, left - 1 + i, yy + 1, pal[0])


def mouth(img, cx, y, kind, pal):
    g = MOUTHS[kind]
    stamp(img, g, cx - len(g[0]) // 2, y, pal[0])


def blush(img, cx, y, spread, pal):
    for s in (-1, 1):
        for i in range(3):
            px(img, cx + s * spread + (i if s > 0 else -i), y, pal[5])
            px(img, cx + s * spread + (i if s > 0 else -i), y + 1, pal[5])


def feet(img, cx, y, spread, pal, w=4, h=2):
    for s in (-1, 1):
        for dx in range(w):
            for dy in range(h):
                px(img, cx + s * spread + (dx if s > 0 else -dx), y + dy, pal[1])


# ------------------------------------------------------------------ meldlings
def meldling(size, pal_key, pip, hws, y0, eye_y, eye_spread, mouth_kind,
             crest_y, foot_spread, ears=None, eye_shape="round", lash=False,
             eye_w=5, eye_h=6, tuft=0, belly=False):
    pal = PAL[pal_key]
    img = new_img(size, size)
    cx = size // 2
    if ears:
        for s in (-1, 1):
            disc(img, cx + s * ears[0], y0 + ears[1], ears[2], pal[3])
    body(img, cx, y0, hws, pal)
    feet(img, cx, y0 + len(hws), foot_spread, pal)
    stamp(img, PIPS[pip], cx - 3, crest_y, pal[1])
    if belly:
        # a lighter belly patch gives the body a front and a back
        n = len(hws)
        for i in range(int(n * 0.35), int(n * 0.88)):
            hw = max(1, hws[i] - 4)
            for x in range(cx - hw, cx + hw):
                px(img, x, y0 + i, pal[4])
    if tuft:
        for i in range(tuft):
            px(img, cx - 1 + (i % 2), y0 - 1 - i, pal[3])
            px(img, cx + (i % 2), y0 - 2 - i, pal[4])
    specular(img, cx - hws[0] - 2, y0 + 2, pal)
    eyes(img, cx, eye_y, eye_spread, pal, ew=eye_w, eh=eye_h,
         shape=eye_shape, lash=lash)
    blush(img, cx, eye_y + 5, eye_spread + 3, pal)
    mouth(img, cx, eye_y + 7, mouth_kind, pal)
    outline(img, pal[0])
    shadow(img, cx, y0 + len(hws) + 3, max(6, hws[len(hws) // 2] - 1), 2)
    return img


def draw_pip():
    # TALL and NARROW — a standing sliver
    return meldling(32, "spade", "S",
                    [2, 4, 5, 6, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8, 7, 7, 7, 6, 6, 5, 4, 3],
                    y0=6, eye_y=12, eye_spread=4, mouth_kind="cat",
                    crest_y=0, foot_spread=3,
                    eye_shape="sharp", eye_w=5, eye_h=7, tuft=3, belly=True)


def draw_thump():
    # WIDE and SQUAT — a boulder
    return meldling(32, "heart", "H",
                    [7, 11, 13, 14, 15, 15, 15, 15, 14, 13, 11, 8],
                    y0=14, eye_y=18, eye_spread=7, mouth_kind="o",
                    crest_y=5, foot_spread=7,
                    eye_shape="round", eye_w=6, eye_h=6, lash=True, belly=True)


def draw_clover():
    # PEAR — narrow shoulders, heavy base, with leaf ears
    return meldling(32, "club", "C",
                    [3, 4, 5, 6, 6, 7, 8, 9, 10, 11, 12, 12, 13, 13, 13, 12, 11, 9, 6],
                    y0=10, eye_y=15, eye_spread=4, mouth_kind="smile",
                    crest_y=2, foot_spread=6, ears=(8, 3, 3),
                    eye_shape="round", eye_w=5, eye_h=6, tuft=2, belly=True)


def draw_facet():
    # ANGULAR — a hard crystal, straight tapers, no curves
    return meldling(32, "diamond", "D",
                    [1, 3, 5, 7, 9, 11, 12, 13, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2],
                    y0=7, eye_y=14, eye_spread=5, mouth_kind="smol",
                    crest_y=0, foot_spread=3,
                    eye_shape="sharp", eye_w=5, eye_h=5)


def draw_nib():
    # THE CUT — a thin blade of a creature, sharp and upright
    return meldling(32, "nib", "S",
                    [1, 2, 3, 4, 5, 5, 6, 6, 7, 7, 7, 7, 7, 6, 6, 6, 5, 5, 4, 4, 3, 2],
                    y0=6, eye_y=13, eye_spread=3, mouth_kind="smol",
                    crest_y=0, foot_spread=2,
                    eye_shape="sharp", eye_w=4, eye_h=7)


def draw_muggins():
    # THE THIEF — low, wide and lopsided, with a sack of a body
    return meldling(32, "muggins", "C",
                    [5, 9, 11, 12, 13, 14, 14, 14, 13, 13, 12, 10, 7],
                    y0=13, eye_y=17, eye_spread=6, mouth_kind="cat",
                    crest_y=4, foot_spread=6, ears=(11, 2, 2),
                    eye_shape="sleepy", eye_w=6, eye_h=6, belly=True)


# ------------------------------------------------------------------ enemies
def draw_deadwood(size=38):
    pal = PAL["wood"]
    img = new_img(size, size)
    cx = size // 2
    hws = [4, 5, 6, 7, 8, 8, 9, 9, 10, 10, 11, 12, 12, 13, 14, 15, 16, 17]
    body(img, cx, 9, hws, pal)
    # a crown of jagged branches, varied length so the silhouette is spiky
    for s in (-1, 1):
        for k, (dx, up, ln) in enumerate(((5, 4, 5), (8, 7, 4), (11, 3, 3))):
            for i in range(ln):
                px(img, cx + s * (dx + i // 2), 10 - up - i, pal[2])
                px(img, cx + s * (dx + i // 2), 11 - up - i, pal[1])
    # bark grain
    for i in range(7):
        for y in range(18, 28):
            if (y * 2 + i * 5) % 7 == 0:
                px(img, cx - 12 + i * 4, y, pal[1])
    # roots
    for s in (-1, 1):
        for i in range(4):
            px(img, cx + s * (10 + i), 27 - i // 2, pal[1])
    eyes(img, cx, 16, 6, pal, ew=5, eh=5, brow=True, sclera=(250, 232, 176))
    mouth(img, cx, 24, "fang", pal)
    outline(img, pal[0])
    shadow(img, cx, 29, 15, 2)
    return img


def draw_shuffler(size=36):
    pal = PAL["ghost"]
    img = new_img(size, size)
    cx = size // 2
    hws = [4, 7, 9, 10, 11, 12, 12, 13, 13, 13, 13, 12, 12, 11, 11, 10]
    body(img, cx, 6, hws, pal)
    for i, hw in enumerate([10, 9, 8, 6]):
        y = 22 + i
        for x in range(cx - hw, cx + hw):
            if ((x + i * 2) // 3) % 2 == 0:
                px(img, x, y, pal[1] if i > 1 else pal[2])
    # orbiting card shards, drawn as actual little cards with a pip
    for (ox, oy, sui) in ((-15, 8, "S"), (13, 5, "H"), (-13, 22, "D")):
        for j in range(7):
            for i in range(5):
                edge = i in (0, 4) or j in (0, 6)
                px(img, cx + ox + i, oy + j, pal[0] if edge else WHITE)
        col = (200, 70, 70, 255) if sui in ("H", "D") else pal[0]
        px(img, cx + ox + 2, oy + 3, col)
        px(img, cx + ox + 2, oy + 2, col)
    specular(img, cx - 9, 8, pal)
    eyes(img, cx, 13, 6, pal, ew=5, eh=6, brow=True, sclera=(200, 250, 240))
    mouth(img, cx, 21, "snarl", pal)
    outline(img, pal[0])
    shadow(img, cx, 31, 9, 2, a=55)      # faint: it hovers
    return img


def draw_jokester(size=36):
    pal = PAL["jester"]
    img = new_img(size, size)
    cx = size // 2
    hws = [5, 8, 10, 11, 12, 12, 13, 13, 12, 12, 11, 10, 8, 6]
    body(img, cx, 12, hws, pal)
    feet(img, cx, 26, 6, pal)
    for s in (-1, 1):
        for i in range(9):
            wdt = max(1, 4 - i // 3)
            for k in range(wdt):
                px(img, cx + s * (3 + i) + (k if s > 0 else -k), 11 - i,
                   pal[1] if i % 2 else pal[3])
        disc(img, cx + s * 12, 3, 2, GOLD)
        px(img, cx + s * 12 - 1, 2, (255, 240, 200))
    for x in range(cx - 9, cx + 9):
        px(img, x, 11, pal[1])
        px(img, x, 12, pal[2])
    # ruff collar
    for i in range(9):
        r = 2 if i % 2 == 0 else 3
        disc(img, cx - 8 + i * 2, 26, r, pal[4] if i % 2 == 0 else pal[3])
    specular(img, cx - 8, 14, pal)
    eyes(img, cx, 16, 5, pal, ew=5, eh=5, brow=True, pupil_in=1, sclera=(250, 232, 176))
    mouth(img, cx, 23, "grin", pal)
    outline(img, pal[0])
    shadow(img, cx, 30, 11, 2)
    return img


def draw_kingpin(size=48):
    pal = PAL["king"]
    img = new_img(size, size)
    cx = size // 2
    hws = [6, 9, 12, 14, 15, 16, 17, 17, 18, 18, 18, 18, 17, 17, 16, 15, 13, 11, 8]
    body(img, cx, 13, hws, pal)
    feet(img, cx, 32, 9, pal, w=5, h=3)
    stamp(img, CROWN, cx - 6, 4, GOLD_D)
    stamp(img, CROWN[:3], cx - 6, 4, GOLD)
    for x in range(cx - 7, cx + 7):
        px(img, x, 10, GOLD_D)
    for i in range(2):
        for x in range(cx - 17 + i, cx + 17 - i):
            px(img, x, 20 + i, pal[1])
    # cape sweeping behind the shoulders
    for s in (-1, 1):
        for i in range(9):
            for j in range(3):
                px(img, cx + s * (16 + j), 22 + i, pal[1] if j else pal[2])
    # sceptre
    for y in range(12, 30):
        px(img, cx + 19, y, GOLD_D)
    disc(img, cx + 19, 11, 2, GOLD)
    specular(img, cx - 13, 15, pal)
    eyes(img, cx, 21, 8, pal, ew=6, eh=7, brow=True, sclera=(252, 208, 120))
    mouth(img, cx, 31, "snarl", pal)
    outline(img, pal[0])
    shadow(img, cx, 36, 18, 3)
    return img


# ------------------------------------------------------------------ animation
def transform(img, sy=1.0, sx=1.0, dx=0, dy=0, lean=0, flash=0.0):
    w, h = img.size
    bbox = img.getbbox()
    if bbox is None:
        return img.copy()
    x0, y0, x1, y1 = bbox
    bw, bh = x1 - x0, y1 - y0
    nw, nh = max(1, round(bw * sx)), max(1, round(bh * sy))
    part = img.crop(bbox).resize((nw, nh), Image.NEAREST)

    out = new_img(w, h)
    ox = x0 + (bw - nw) // 2 + dx
    oy = y1 - nh + dy
    out.alpha_composite(part, (max(0, min(w - 1, ox)), max(0, min(h - 1, oy))))

    if lean:
        src = out
        out = new_img(w, h)
        for y in range(h):
            t = 1.0 - (y / float(h))
            off = int(round(lean * t * t))
            row = src.crop((0, y, w, y + 1))
            if off >= 0:
                out.alpha_composite(row.crop((0, 0, w - off, 1)), (off, y))
            else:
                out.alpha_composite(row.crop((-off, 0, w, 1)), (0, y))

    if flash > 0:
        p = out.load()
        for y in range(h):
            for x in range(w):
                r, g, b, a = p[x, y]
                if a:
                    p[x, y] = (round(r + (255 - r) * flash),
                               round(g + (255 - g) * flash),
                               round(b + (255 - b) * flash), a)
    return out


IDLE = [
    dict(),
    dict(sy=0.95, sx=1.05),
    dict(dy=-1),
    dict(sy=1.05, sx=0.96, dy=-1),
    dict(),
    dict(sy=0.97, sx=1.03, blink=True),
]
ATTACK = [
    dict(sy=0.88, sx=1.12, lean=-3),
    dict(sy=1.06, sx=0.95, dy=-1, lean=-5),
    dict(sy=1.12, sx=0.92, dy=-2, lean=7),
    dict(sy=0.92, sx=1.08, lean=4),
    dict(),
]
HURT = [
    dict(sy=0.94, sx=1.06, dx=3, flash=0.85),
    dict(sy=0.96, sx=1.04, dx=-3, flash=0.45),
    dict(sy=1.02, sx=0.98, dx=1, flash=0.15),
    dict(),
]


def build_strip(builder, frames):
    global BLINK
    BLINK = False
    base = builder()
    BLINK = True
    blinked = builder()
    BLINK = False

    imgs = []
    for f in frames:
        src = blinked if f.get("blink") else base
        imgs.append(transform(src, sy=f.get("sy", 1.0), sx=f.get("sx", 1.0),
                              dx=f.get("dx", 0), dy=f.get("dy", 0),
                              lean=f.get("lean", 0), flash=f.get("flash", 0.0)))
    w, h = base.size
    strip = new_img(w * len(imgs), h)
    for i, im in enumerate(imgs):
        strip.alpha_composite(im, (i * w, 0))
    return strip, imgs


ROSTER = [
    ("nib", draw_nib, "Meldling / unlockable"),
    ("muggins", draw_muggins, "Meldling / unlockable"),
    ("pip", draw_pip, "Meldling / Spades"),
    ("thump", draw_thump, "Meldling / Hearts"),
    ("clover", draw_clover, "Meldling / Clubs"),
    ("facet", draw_facet, "Meldling / Diamonds"),
    ("deadwood", draw_deadwood, "Enemy"),
    ("shuffler", draw_shuffler, "Enemy"),
    ("jokester", draw_jokester, "Elite"),
    ("kingpin", draw_kingpin, "Boss"),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    previews = []
    for name, fn, kind in ROSTER:
        for anim, frames, ms in (("idle", IDLE, 150), ("attack", ATTACK, 80), ("hurt", HURT, 70)):
            strip, imgs = build_strip(fn, frames)
            strip.save(f"{OUT}/{name}_{anim}.png")
            if anim == "idle":
                flat = []
                for im in imgs:
                    big = im.resize((im.size[0] * 6, im.size[1] * 6), Image.NEAREST)
                    bg = Image.new("RGBA", big.size, (26, 24, 38, 255))
                    bg.alpha_composite(big)
                    flat.append(bg.convert("P", palette=Image.ADAPTIVE, colors=64))
                flat[0].save(f"{OUT}/{name}.gif", save_all=True, append_images=flat[1:],
                             duration=ms, loop=0, disposal=2)
        previews.append((name, kind, fn()))
        print("built", name)

    cell = 44 * 5 + 20
    sheet = Image.new("RGBA", (cell * 4, cell * 2), (26, 24, 38, 255))
    for i, (name, kind, im) in enumerate(previews):
        big = im.resize((im.size[0] * 5, im.size[1] * 5), Image.NEAREST)
        col, row = i % 4, i // 4
        sheet.alpha_composite(big, (col * cell + (cell - big.size[0]) // 2,
                                    row * cell + (cell - big.size[1]) // 2))
    sheet.convert("RGB").save("/home/claude/out/preview_roster.png")


if __name__ == "__main__":
    main()
