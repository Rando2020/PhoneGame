#!/usr/bin/env python3
"""Split-card assets, built for runtime composition.

A split card is two ranks on one card. Pre-rendering every pair would be 52x52.
Instead we ship THREE small pieces and assemble any combination in CSS:

    split_frame.png   one 70x98 frame: two-tone halves, divider, border
    glyphs.png        13 ranks x 2 colours, in a strip
    suitpips.png      4 suits x 2 colours, in a strip

Any split card = frame + 2 glyphs + 1-2 pips, positioned. Three files, 2704
possible cards.
"""
from PIL import Image
import os

OUT = "/home/claude/work/assets/cards"
W, H = 70, 98
CLEAR = (0, 0, 0, 0)
BONE = (244, 236, 224, 255)
PANEL = (255, 250, 242, 255)
SHADE = (232, 222, 206, 255)      # the darker half
INK = (35, 32, 43, 255)
RED = (198, 58, 58, 255)
BLK = (44, 43, 58, 255)
GOLD = (232, 182, 76, 255)

FONT = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
    "4": ["#...#", "#...#", "#...#", "#####", "....#", "....#", "....#"],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": [".###.", "#...#", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "#...#", ".###."],
    "0": [".###.", "#..##", "#.#.#", "##..#", "#...#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "J": ["..###", "....#", "....#", "....#", "#...#", "#...#", ".###."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
}
PIPS = {
    "S": ["...#...", "..###..", ".#####.", "#######", "#######", ".#.#.#.", "..###.."],
    "H": [".##.##.", "#######", "#######", ".#####.", ".#####.", "..###..", "...#..."],
    "C": ["..###..", ".#####.", "#.###.#", "#######", "##.#.##", "...#...", "..###.."],
    "D": ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."],
}
RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
SUITS = ["S", "H", "C", "D"]

GLYPH_W, GLYPH_H = 11, 7      # widest is "10"


def stamp(img, grid, x, y, c):
    for j, row in enumerate(grid):
        for i, ch in enumerate(row):
            if ch == "#" and 0 <= x + i < img.size[0] and 0 <= y + j < img.size[1]:
                img.putpixel((x + i, y + j), c)


def rank_grid(r):
    if r == "10":
        return [FONT["1"][k][:3] + "." + FONT["0"][k] for k in range(7)]
    return FONT[r]


def mask(r=5):
    m = [[True] * W for _ in range(H)]
    for cx, cy in ((0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)):
        for y in range(H):
            for x in range(W):
                dx, dy = abs(x - cx), abs(y - cy)
                if dx < r and dy < r:
                    px_, py_ = r - 1 - dx, r - 1 - dy
                    if px_ * px_ + py_ * py_ > (r - 1) * (r - 1) + 1:
                        m[y][x] = False
    return m


M = mask()


def frame():
    """Two-tone halves split by a stepped diagonal — pixel art, no anti-aliasing."""
    img = Image.new("RGBA", (W, H), CLEAR)
    for y in range(H):
        # a stepped diagonal: 2px of x for every 3px of y, so the edge stays chunky
        edge = int(W * 0.5 + (H * 0.5 - y) * 0.42)
        edge = (edge // 2) * 2
        for x in range(W):
            if not M[y][x]:
                continue
            img.putpixel((x, y), PANEL if x < edge else SHADE)
        # the divider itself
        for d in (0, 1):
            if 0 <= edge + d < W and M[y][edge + d]:
                img.putpixel((edge + d, y), GOLD if d == 0 else (200, 150, 60, 255))
    # border
    for y in range(H):
        for x in range(W):
            if not M[y][x]:
                continue
            if any((not M[y + dy][x + dx]) if 0 <= y + dy < H and 0 <= x + dx < W else True
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                img.putpixel((x, y), INK)
    img.save(f"{OUT}/split_frame.png")
    return img


def big_glyph_strip():
    """The same 13 ranks at 2x, for the centre of a split card."""
    gw, gh = GLYPH_W * 2, GLYPH_H * 2
    img = Image.new("RGBA", (gw * len(RANKS), gh * 2), CLEAR)
    for i, r in enumerate(RANKS):
        g = rank_grid(r)
        for row, col in ((0, BLK), (1, RED)):
            for j, line in enumerate(g):
                for k, ch in enumerate(line):
                    if ch != "#":
                        continue
                    for dy in range(2):
                        for dx in range(2):
                            x = i * gw + k * 2 + dx
                            y = row * gh + j * 2 + dy
                            if x < img.size[0] and y < img.size[1]:
                                img.putpixel((x, y), col)
    img.save(f"{OUT}/glyphs_big.png")
    return img


def glyph_strip():
    """13 ranks x 2 colours. Row 0 dark, row 1 red."""
    img = Image.new("RGBA", (GLYPH_W * len(RANKS), GLYPH_H * 2), CLEAR)
    for i, r in enumerate(RANKS):
        g = rank_grid(r)
        for row, col in ((0, BLK), (1, RED)):
            stamp(img, g, i * GLYPH_W, row * GLYPH_H, col)
    img.save(f"{OUT}/glyphs.png")
    return img


def pip_strip():
    img = Image.new("RGBA", (7 * len(SUITS), 7 * 2), CLEAR)
    for i, s in enumerate(SUITS):
        for row, col in ((0, BLK), (1, RED)):
            stamp(img, PIPS[s], i * 7, row * 7, col)
    img.save(f"{OUT}/suitpips.png")
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    f = frame(); glyph_strip(); pip_strip(); bg = big_glyph_strip()

    # preview: assemble a few split cards the way the browser will
    gl = Image.open(f"{OUT}/glyphs.png"); pp = Image.open(f"{OUT}/suitpips.png")
    demo = [("2", "3", "H", "H"), ("A", "K", "S", "D"), ("10", "J", "C", "C"), ("5", "9", "D", "S")]
    sheet = Image.new("RGBA", (W * 4 * 4, H * 4), (26, 24, 38, 255))
    for n, (r1, r2, s1, s2) in enumerate(demo):
        card = f.copy()
        for (r, s, x, y) in ((r1, s1, 5, 7), (r2, s2, W - 16, H - 22)):
            gi = RANKS.index(r); row = 1 if s in ("H", "D") else 0
            card.alpha_composite(gl.crop((gi * GLYPH_W, row * GLYPH_H,
                                          (gi + 1) * GLYPH_W, (row + 1) * GLYPH_H)), (x, y))
            si = SUITS.index(s)
            card.alpha_composite(pp.crop((si * 7, row * 7, (si + 1) * 7, (row + 1) * 7)),
                                 (x + 2, y + 8))
        # big centre ranks, one either side of the divider
        gw, gh = GLYPH_W * 2, GLYPH_H * 2
        for (r, s, x, y) in ((r1, s1, 6, 34), (r2, s2, W - 28, 52)):
            gi = RANKS.index(r); row = 1 if s in ("H", "D") else 0
            card.alpha_composite(bg.crop((gi * gw, row * gh, (gi + 1) * gw, (row + 1) * gh)), (x, y))
        sheet.alpha_composite(card.resize((W * 4, H * 4), Image.NEAREST), (n * W * 4, 0))
    sheet.convert("RGB").save("/home/claude/work/preview_split.png")
    print("4 files ->", len(RANKS) * len(RANKS) * len(SUITS) * len(SUITS), "renderable split cards")


main()
