#!/usr/bin/env python3
"""
Charm icons (pass 19): one 32x32 pixel icon per charm, plus a 2x (64x64).

Reads in three layers, in this order on a phone:
  1. the CATEGORY: a silhouette and colour per cat (fifteen coin, pair cards,
     run steps, flush fan, mult burst, rule scroll, deck box), shaded like
     the Meldlings: base, a light rim top-left, a dark rim bottom-right, a
     soft highlight, and a 1 px outline in the base's own dark;
  2. the CHARM: a 9x9 cream motif with a 1 px ink drop shadow;
  3. the RARITY: the plaque frame in the UI's rarity tint (CribData.RARITY),
     after make_items.py's plaques (rounded, lit top edge).
No two charms share (silhouette, motif): the script stops if they do.

  python3 tools/make_charms.py [out_dir]   (default godot/assets/charms)
writes charm_<id>.png and charm_<id>@2x.png, and a contact sheet (all charms
at 1x and 3x) to <out_dir>/../../../store/charm_sheet.png is NOT written:
the sheet goes to /tmp/charm_sheet.png for review.
"""
import os, re, sys, math
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "godot", "assets", "charms")

INK = (35, 32, 43, 255)
CREAM = (255, 250, 242, 255)
BG = (30, 27, 44, 255)
CLEAR = (0, 0, 0, 0)

RARITY = {  # CribData.RARITY tints
    "common": (143, 163, 200), "uncommon": (111, 201, 138), "rare": (232, 182, 76),
    "legendary": (208, 111, 214), "mythic": (255, 107, 138),
}
CAT_COLOR = {
    "fifteen": (226, 170, 70), "pair": (206, 74, 74), "run": (78, 132, 214),
    "flush": (152, 96, 204), "mult": (234, 128, 54), "rule": (56, 172, 160), "deck": (178, 128, 84),
}


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def lift(c, t):
    return tuple(int(v + (255 - v) * t) for v in c[:3]) + (255,)


# ------------------------------------------------------------- silhouettes
def rrect(x0, y0, x1, y1, r=2):
    def f(x, y):
        if x < x0 or x > x1 or y < y0 or y > y1:
            return False
        cx = x0 + r if x < x0 + r else (x1 - r if x > x1 - r else x)
        cy = y0 + r if y < y0 + r else (y1 - r if y > y1 - r else y)
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5
    return f


def union(*fs):
    return lambda x, y: any(f(x, y) for f in fs)


def coin(x, y):
    return (x - 15.5) ** 2 + (y - 16.5) ** 2 <= 10.6 ** 2


def burst(x, y):
    dx, dy = x - 15.5, y - 16.0
    a = math.atan2(dy, dx)
    r = math.hypot(dx, dy)
    return r <= 8.6 + 3.0 * (0.5 + 0.5 * math.cos(8 * a))


# Each silhouette is a list of layers, back to front: overlapping cards and
# steps keep their own outline, so a pair reads as two cards, not a blob.
SIL = {
    "fifteen": [coin],
    "pair": [rrect(4, 8, 16, 26, 2), rrect(14, 5, 27, 23, 2)],
    "run": [rrect(4, 18, 10, 26, 1), rrect(12, 12, 18, 26, 1), rrect(20, 6, 27, 26, 1)],
    "flush": [rrect(3, 9, 12, 25, 2), rrect(17, 9, 27, 25, 2), rrect(9, 6, 21, 24, 2)],
    "mult": [burst],
    "rule": [union(rrect(7, 7, 24, 25, 1), rrect(5, 5, 26, 9, 2), rrect(5, 23, 26, 27, 2))],
    "deck": [union(rrect(6, 9, 25, 26, 2), rrect(8, 6, 23, 9, 1))],
}
# where the motif sits (its centre), per silhouette
ANCHOR = {"fifteen": (16, 17), "pair": (20, 14), "run": (16, 16), "flush": (16, 15),
          "mult": (16, 16), "rule": (16, 16), "deck": (16, 17)}

# ------------------------------------------------------------- motifs (9x9)
G = {
 "n15": ["#..###...", "#..#.....", "#..###...", "#....#...", "#..###...", ".........", ".........", ".........", "........."],
 "K":   ["##...##..", "##..##...", "##.##....", "####.....", "##.##....", "##..##...", "##...##..", ".........", "........."],
 "pie": ["..#####..", ".###..##.", "####...##", "####...##", "#########", "#########", ".#######.", "..#####..", "........."],
 "heart": [".##...##.", "####.####", "#########", "#########", ".#######.", "..#####..", "...###...", "....#....", "........."],
 "eq":  [".........", "#########", "#########", ".........", ".........", "#########", "#########", ".........", "........."],
 "arrow": ["....#####", ".....####", "....#####", "...###.##", "..###...#", ".###.....", "###......", ".#.......", "........."],
 "pips3": ["##.......", "##.......", ".........", "...##....", "...##....", ".........", "......##.", "......##.", "........."],
 "peye": ["...###...", "..#####..", ".##...##.", "##..#..##", "##.###.##", "##..#..##", ".##...##.", "..#####..", "...###..."],
 "half": ["...####..", ".#####...", "####.....", "####.....", "####.....", "####.....", ".#####...", "...####..", "........."],
 "abacus": ["#########", "#.##.#..#", "#########", "#..#.##.#", "#########", "#.#..#.##", "#########", ".........", "........."],
 "flame": ["....#....", "...##....", "...###...", "..####.#.", ".#######.", "####.####", "###...###", ".##...##.", "..#####.."],
 "spade": ["....#....", "...###...", "..#####..", ".#######.", "#########", "#########", ".##.#.##.", "...###...", "..#####.."],
 "bolt": ["....####.", "...####..", "..####...", ".#######.", "...####..", "..####...", ".###.....", ".##......", "#........"],
 "arch": ["..#####..", ".##...##.", "##.....##", "##.###.##", "##.###.##", "##.###.##", "##.....##", ".........", "........."],
 "n3":  ["#######..", ".....##..", "...###...", ".....##..", ".....##..", "##...##..", ".#####...", ".........", "........."],
 "bag": ["...#.#...", "..#####..", "...###...", ".#######.", "##..#..##", "##.###.##", "##..#..##", ".#######.", "........."],
 "crown": ["#...#...#", "##.###.##", "#########", "#########", "#########", ".........", "#########", ".........", "........."],
 "die": ["#########", "#.......#", "#.##.##.#", "#.......#", "#...#...#", "#.......#", "#.##.##.#", "#########", "........."],
 "cup": ["#.......#", "#########", "#########", ".#######.", "..#####..", "...###...", "....#....", "..#####..", "........."],
 "hourglass": ["#########", ".#.....#.", "..#...#..", "...###...", "...###...", "..#.#.#..", ".#.###.#.", "#########", "........."],
 "bubble": [".#######.", "#########", "##.#.#.##", "#########", ".#######.", "..##.....", ".##......", "#........", "........."],
 "snow": ["#...#...#", ".#..#..#.", "..#.#.#..", "...###...", "#########", "...###...", "..#.#.#..", ".#..#..#.", "#...#...#"],
 "coins": [".#####...", "#######..", ".#####...", "...#####.", "..#######", "...#####.", ".#####...", "#######..", ".#####..."],
 "anchor": ["...###...", "...#.#...", "...###...", "....#....", ".#######.", "....#....", "#...#...#", ".##.#.##.", "..#####.."],
 "tally": ["#.#.#.#..", "#.#.#.#..", "#########", "#.#.#.#..", "#.#.#.#..", "#.#.#.#..", ".........", ".........", "........."],
 "candle": ["....#....", "...###...", "....#....", "..#####..", "..#####..", "..#####..", "..#####..", ".#######.", "#########"],
 "brick": ["#########", "#...#...#", "#########", "##...#..#", "#########", "#...#...#", "#########", ".........", "........."],
 "drop": ["....#....", "...###...", "...###...", "..#####..", ".#######.", ".#######.", ".###.###.", "..#####..", "........."],
 "pct": ["##....##.", "##...##..", "....##...", "...##....", "..##.....", ".##...##.", "##....##.", ".........", "........."],
 "waves": ["..##..##.", ".##..##..", "##..##...", ".##..##..", "..##..##.", ".##..##..", "##..##...", ".........", "........."],
 "clock": ["..#####..", ".#..#..#.", "#...#...#", "#...#...#", "#...####.", "#.......#", ".#.....#.", "..#####..", "........."],
 "pillars": ["....#....", "..#####..", "#########", ".#.#.#.#.", ".#.#.#.#.", ".#.#.#.#.", "#########", "#########", "........."],
 "A":   ["...###...", "..##.##..", ".##...##.", ".##...##.", ".#######.", ".##...##.", ".##...##.", ".........", "........."],
 "loop": ["..####...", ".##..##..", "##....##.", "##....##.", "##..#####", "##...###.", ".##...#..", "..##.....", "........."],
 "scissors": ["##.....##", ".##...##.", "..##.##..", "...###...", "..##.##..", "####.####", "#..#.#..#", "####.####", "........."],
 "key": [".###.....", "#...#....", "#...#####", "#...#.#.#", ".###..#.#", ".........", ".........", ".........", "........."],
 "plus": ["...###...", "...###...", "...###...", "#########", "#########", "#########", "...###...", "...###...", "...###..."],
 "n7":  ["#######..", ".....##..", "....##...", "...##....", "...##....", "..##.....", "..##.....", ".........", "........."],
 "eye": [".........", "..#####..", ".##...##.", "##.###.##", "##.###.##", ".##...##.", "..#####..", ".........", "........."],
 "cut2": ["#########", ".........", "...###...", "..#####..", "...###...", ".........", "#########", ".........", "........."],
 "jaws": ["#.#.#.#.#", "#########", "#########", ".........", ".........", "#########", "#########", "#.#.#.#.#", "........."],
 "lock": ["..#####..", ".##...##.", ".##...##.", "#########", "####.####", "####.####", "#########", "#########", "........."],
 "n19": ["#..####..", "#..#..#..", "#..####..", "#.....#..", "#..####..", ".........", ".........", ".........", "........."],
 "dagger": ["........#", ".......##", "......##.", ".....##..", "#...##...", ".#.##....", "..##.....", ".#.#.....", "#........"],
 "level": [".........", "#########", "#.......#", "#...#...#", "#..###..#", "#.......#", "#########", ".........", "........."],
 "magnet": ["##.....##", "##.....##", "##.....##", "##.....##", "##.....##", ".##...##.", "..#####..", ".........", "........."],
 "swap": ["......#..", "#########", "......#..", ".........", "..#......", "#########", "..#......", ".........", "........."],
 "wheat": ["....#....", "...#.#...", "..#.#.#..", "...#.#...", "..#.#.#..", "...#.#...", "....#....", "....#....", "....#...."],
 "knife": [".......##", "......###", ".....###.", "....###..", "...###...", "..#.#....", ".#.#.....", "#.#......", "........."],
 "flask": ["...###...", "...#.#...", "...#.#...", "..#...#..", ".#.....#.", "#.#####.#", "#########", ".#######.", "........."],
 "ring": ["...#.#...", "....#....", "..#####..", ".##...##.", "##.....##", "##.....##", ".##...##.", "..#####..", "........."],
 "feather": ["......###", ".....####", "....####.", "...####..", "..####...", ".####....", ".##......", "#........", "........."],
 "seven": ["#########", "#.......#", "#.#####.#", "#.....#.#", "#....#..#", "#...#...#", "#########", ".........", "........."],
}

# Each charm: (motif, optional motif colour). Category and rarity come from the game data.
MOTIF = {
    "fifteener": "n15", "twinner": "heart", "rambler": "arrow", "peacock": "peye", "facecard": "K",
    "counting": "abacus", "fever": "flame", "suited": "spade", "streak": "bolt", "keystone2": "arch",
    "thirdtime": "n3", "purse": "bag", "aceeleven": "A", "wrap": "loop", "shortflush": "half",
    "recut": "scissors", "cribmaster": "key", "fifthdeal": "plus", "widedeal": "seven", "foresight": "eye",
    "doublecut": "cut2", "royalblood": "crown", "peasant": "wheat", "loaded": "flame", "thindeck": "knife",
    "secondchance": "heart", "greedycrib": "jaws", "miser": "lock", "sovereign": "crown", "nineteen": "n19",
    "doubling": "die", "alchemist": "flask", "overflow": "cup", "quartermaster": "pie", "evenhand": "eq",
    "oddfellow": "pips3", "shortmemory": "hourglass", "lastword": "bubble", "thinice": "snow",
    "hoarder": "coins", "cutpurse": "dagger", "steadyhand": "level", "ballast": "anchor",
    "tallyman": "tally", "slowburn": "candle", "groundwork": "brick", "bloodline": "drop",
    "collector": "magnet", "exchange": "swap", "echo": "waves", "usury": "pct", "thelong": "clock",
    "thebank": "pillars",
}
MOTIF_COLOR = {"bloodline": (128, 16, 30, 255), "thinice": (210, 240, 255, 255)}


def charms():
    """(id, name, cat, rarity) from the port's data (the web's list is checked by the test)."""
    s = open(os.path.join(ROOT, "godot", "engine", "crib_data.gd"), encoding="utf-8").read()
    pat = r'C\.call\(\{"id": "([a-z0-9_]+)", "name": "([^"]+)", "tier": \d, "cost": \d+, "rarity": "([a-z]+)", "cat": "([a-z]+)"'
    return [(i, n, c, r) for i, n, r, c in re.findall(pat, s)]


def frame(img, rarity):
    tint = RARITY[rarity] + (255,)
    light, dark = lift(tint, 0.35), shade(tint, 0.55)
    body = rrect(0, 0, 31, 31, 4)
    inner = rrect(2, 2, 29, 29, 3)
    for y in range(32):
        for x in range(32):
            if body(x, y):
                if inner(x, y):
                    t = y / 31
                    img.putpixel((x, y), tuple(int(BG[k] * (1 - 0.25 * t)) for k in range(3)) + (255,))
                else:
                    img.putpixel((x, y), dark if y > 16 else tint)
    for x in range(4, 28):               # lit top edge (make_items' plaque)
        img.putpixel((x, 0), light)
    # outer ink edge
    out = Image.new("RGBA", (32, 32), CLEAR)
    for y in range(32):
        for x in range(32):
            if body(x, y) and not (body(x - 1, y) and body(x + 1, y) and body(x, y - 1) and body(x, y + 1)):
                out.putpixel((x, y), INK)
    img.alpha_composite(out)


def silhouette(img, cat):
    layers = SIL[cat]
    for li, f in enumerate(layers):
        # back layers a touch darker, so the front one reads on top
        base = shade(CAT_COLOR[cat] + (255,), 1.0 - 0.14 * (len(layers) - 1 - li))
        light, dark, line = lift(base, 0.32), shade(base, 0.68), shade(base, 0.32)
        inside = lambda x, y, f=f: 0 <= x < 32 and 0 <= y < 32 and f(x, y)
        for y in range(32):
            for x in range(32):
                if inside(x, y):
                    edge_tl = not inside(x - 1, y) or not inside(x, y - 1)
                    edge_br = not inside(x + 1, y) or not inside(x, y + 1)
                    c = dark if edge_br else (light if edge_tl else base)
                    img.putpixel((x, y), c)
                elif any(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    img.putpixel((x, y), line)
        pts = [(x, y) for y in range(32) for x in range(32) if inside(x, y)]
        x0 = min(p[0] for p in pts); y0 = min(p[1] for p in pts)
        for dx, dy in ((2, 2), (3, 2), (2, 3)):
            if inside(x0 + dx, y0 + dy) and inside(x0 + dx + 1, y0 + dy + 1):
                img.putpixel((x0 + dx, y0 + dy), lift(base, 0.6))


def motif(img, cat, name, color=CREAM):
    g = G[name]
    ax, ay = ANCHOR[cat]
    x0, y0 = ax - 4, ay - 4
    for j, row in enumerate(g):
        for i, ch in enumerate(row):
            if ch == "#":
                sx, sy = x0 + i + 1, y0 + j + 1
                if 0 <= sx < 32 and 0 <= sy < 32 and not (j + 1 < 9 and i + 1 < 9 and g[j + 1][i + 1] == "#"):
                    img.putpixel((sx, sy), INK)
    for j, row in enumerate(g):
        for i, ch in enumerate(row):
            if ch == "#":
                img.putpixel((x0 + i, y0 + j), color)


def make(cid, cat, rarity):
    img = Image.new("RGBA", (32, 32), CLEAR)
    frame(img, rarity)
    silhouette(img, cat)
    motif(img, cat, MOTIF[cid], MOTIF_COLOR.get(cid, CREAM))
    return img


def make_silhouette(cat):
    """The unseen state: a neutral frame and the category's shape in flat
    shadow. Shows the category, never which charm or how rare."""
    img = Image.new("RGBA", (32, 32), CLEAR)
    body = rrect(0, 0, 31, 31, 4)
    for y in range(32):
        for x in range(32):
            if body(x, y):
                edge = not (body(x - 1, y) and body(x + 1, y) and body(x, y - 1) and body(x, y + 1))
                img.putpixel((x, y), (70, 64, 92, 255) if edge else (34, 31, 50, 255))
    for f in SIL[cat]:
        for y in range(32):
            for x in range(32):
                if f(x, y):
                    img.putpixel((x, y), (58, 53, 80, 255))
                elif any(0 <= x + dx < 32 and 0 <= y + dy < 32 and f(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) \
                        and img.getpixel((x, y))[:3] != (58, 53, 80):
                    img.putpixel((x, y), (24, 22, 36, 255))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    cs = charms()
    missing = [c[0] for c in cs if c[0] not in MOTIF]
    assert not missing, f"no motif for {missing}"
    unknown = [c[2] for c in cs if c[2] not in SIL]
    assert not unknown, f"no silhouette for categories {set(unknown)}"
    seen = {}
    for cid, name, cat, rarity in cs:
        key = (cat, MOTIF[cid])
        assert key not in seen, f"{cid} and {seen[key]} share silhouette {cat} and motif {MOTIF[cid]}"
        seen[key] = cid
    for k, g in G.items():
        assert len(g) == 9 and all(len(r) == 9 for r in g), f"glyph {k} isn't 9x9"
    for cid, name, cat, rarity in cs:
        im = make(cid, cat, rarity)
        im.save(os.path.join(OUT, f"charm_{cid}.png"))
        im.resize((64, 64), Image.NEAREST).save(os.path.join(OUT, f"charm_{cid}@2x.png"))
    for cat in SIL:
        sil = make_silhouette(cat)
        sil.save(os.path.join(OUT, f"sil_{cat}.png"))
        sil.resize((64, 64), Image.NEAREST).save(os.path.join(OUT, f"sil_{cat}@2x.png"))
    # contact sheet: each charm at 1x and 3x, grouped by category, with its id
    from PIL import ImageDraw
    order = sorted(cs, key=lambda c: (list(SIL).index(c[2]), c[0]))
    cols, cw, ch = 8, 150, 118
    rows = (len(order) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (24, 40, 32, 255))
    d = ImageDraw.Draw(sheet)
    for i, (cid, name, cat, rarity) in enumerate(order):
        im = Image.open(os.path.join(OUT, f"charm_{cid}.png"))
        x, y = (i % cols) * cw, (i // cols) * ch
        sheet.alpha_composite(im, (x + 6, y + 8))
        sheet.alpha_composite(im.resize((96, 96), Image.NEAREST), (x + 46, y + 4))
        d.text((x + 4, y + 102), name[:22], fill=(246, 238, 224, 255))
    sheet.save("/tmp/charm_sheet.png")
    print(f"{len(cs)} charm icons in {OUT}; sheet /tmp/charm_sheet.png")


if __name__ == "__main__":
    main()
