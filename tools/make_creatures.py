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
def eyes(img, cx, y, spread, pal, ew=5, eh=6, brow=False, pupil_in=0, sclera=WHITE):
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
                if (j in (0, eh - 1)) and (i in (0, ew - 1)):
                    continue
                px(img, left + i, y + j, sclera)
        pxx = left + (ew - 2) // 2 + (pupil_in * -s)
        for j in range(3):
            for i in range(2):
                px(img, pxx + i, y + 2 + j, BLACK)
        px(img, pxx, y + 2, WHITE)
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
             crest_y, foot_spread, ears=None):
    pal = PAL[pal_key]
    img = new_img(size, size)
    cx = size // 2
    if ears:
        for s in (-1, 1):
            disc(img, cx + s * ears[0], y0 + ears[1], ears[2], pal[3])
    body(img, cx, y0, hws, pal)
    feet(img, cx, y0 + len(hws), foot_spread, pal)
    stamp(img, PIPS[pip], cx - 3, crest_y, pal[1])
    eyes(img, cx, eye_y, eye_spread, pal)
    blush(img, cx, eye_y + 5, eye_spread + 3, pal)
    mouth(img, cx, eye_y + 7, mouth_kind, pal)
    outline(img, pal[0])
    return img


def draw_pip():
    return meldling(32, "spade", "S",
                    [3, 5, 7, 8, 9, 10, 10, 11, 11, 11, 11, 11, 10, 10, 9, 9, 8, 7, 6, 4],
                    y0=9, eye_y=14, eye_spread=5, mouth_kind="cat",
                    crest_y=1, foot_spread=4)


def draw_thump():
    return meldling(32, "heart", "H",
                    [4, 7, 9, 11, 12, 12, 13, 13, 13, 12, 12, 11, 10, 9, 8, 6, 4],
                    y0=11, eye_y=16, eye_spread=6, mouth_kind="o",
                    crest_y=3, foot_spread=5)


def draw_clover():
    return meldling(32, "club", "C",
                    [3, 5, 6, 7, 8, 9, 9, 10, 10, 10, 10, 10, 10, 9, 9, 8, 7, 6, 5, 4],
                    y0=9, eye_y=15, eye_spread=5, mouth_kind="smile",
                    crest_y=1, foot_spread=4, ears=(9, 4, 3))


def draw_facet():
    return meldling(32, "diamond", "D",
                    [2, 4, 6, 7, 9, 10, 11, 12, 12, 12, 11, 11, 10, 9, 8, 6, 5, 3],
                    y0=10, eye_y=15, eye_spread=5, mouth_kind="smol",
                    crest_y=2, foot_spread=4)


# ------------------------------------------------------------------ enemies
def draw_deadwood(size=36):
    pal = PAL["wood"]
    img = new_img(size, size)
    cx = size // 2
    hws = [5, 6, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 15, 16]
    body(img, cx, 10, hws, pal)
    for s in (-1, 1):
        for i in range(5):
            for dy in range(2):
                px(img, cx + s * (7 + i), 13 - i // 2 + dy, pal[2] if dy == 0 else pal[1])
    for i in range(6):
        for y in range(20, 27):
            if (y + i * 3) % 5 == 0:
                px(img, cx - 10 + i * 4, y, pal[1])
    eyes(img, cx, 17, 6, pal, ew=5, eh=5, brow=True, sclera=(250, 232, 176))
    mouth(img, cx, 25, "fang", pal)
    outline(img, pal[0])
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
    for (ox, oy) in ((-14, 9), (13, 6), (-13, 21)):
        for j in range(5):
            for i in range(4):
                c = WHITE if 0 < i < 3 and 0 < j < 4 else pal[4]
                px(img, cx + ox + i, oy + j, c)
    eyes(img, cx, 13, 6, pal, ew=5, eh=6, brow=True, sclera=(200, 250, 240))
    mouth(img, cx, 21, "snarl", pal)
    outline(img, pal[0])
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
    eyes(img, cx, 16, 5, pal, ew=5, eh=5, brow=True, pupil_in=1, sclera=(250, 232, 176))
    mouth(img, cx, 23, "grin", pal)
    outline(img, pal[0])
    return img


def draw_kingpin(size=44):
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
    eyes(img, cx, 21, 8, pal, ew=6, eh=7, brow=True, sclera=(252, 208, 120))
    mouth(img, cx, 31, "snarl", pal)
    outline(img, pal[0])
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
