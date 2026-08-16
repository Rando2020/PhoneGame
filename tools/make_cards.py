#!/usr/bin/env python3
"""
Meldlings card asset generator.
Emits pixel-art playing cards at a 70x98 base resolution (5:7).
Scale with NEAREST filtering in Godot (2x -> 140x196 fits a 720x1280 portrait hand).
"""
from PIL import Image
import os

W, H = 70, 98
OUT = "/home/claude/out/assets/cards"

# ---------------------------------------------------------------- palette
BONE      = (244, 236, 224, 255)
PANEL     = (255, 250, 242, 255)
INK       = (35, 32, 43, 255)
INK_SOFT  = (92, 86, 104, 255)
RED       = (198, 58, 58, 255)
RED_DARK  = (143, 38, 38, 255)
BLK       = (44, 43, 58, 255)
BLK_DARK  = (26, 25, 36, 255)
GOLD      = (232, 182, 76, 255)
GOLD_DARK = (168, 124, 40, 255)
INDIGO    = (59, 54, 84, 255)
INDIGO_D  = (40, 36, 60, 255)
INDIGO_L  = (78, 71, 108, 255)
GREEN     = (108, 190, 106, 255)
CLEAR     = (0, 0, 0, 0)

# ---------------------------------------------------------------- 5x7 font
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
    "J": ["..###", "....#", "....#", "....#", "#...#", "#...#", ".###."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
}
NARROW_1 = ["..#", ".##", "..#", "..#", "..#", "..#", ".###"]

# ---------------------------------------------------------------- 7x7 pips
PIPS = {
    "H": [".##.##.", "#######", "#######", "#######", ".#####.", "..###..", "...#..."],
    "D": ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."],
    "S": ["...#...", "..###..", ".#####.", "#######", "#######", "...#...", "..###.."],
    "C": ["..###..", "..###..", "#######", "#######", "#.###.#", "...#...", "..###.."],
}
CROWN = [
    "#.....#.....#",
    "#.....#.....#",
    "#..#######..#",
    "#############",
    ".###########.",
    ".#.#.#.#.#.#.",
    ".###########.",
]

RED_SUITS = ("H", "D")
SUIT_ORDER = ["S", "H", "C", "D"]
RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]


# ---------------------------------------------------------------- helpers
def blit(img, glyph, x, y, color, flip=False):
    """Draw a list-of-strings bitmap at x,y. flip=True rotates 180."""
    rows = glyph[::-1] if flip else glyph
    for j, row in enumerate(rows):
        line = row[::-1] if flip else row
        for i, ch in enumerate(line):
            if ch == "#":
                img.putpixel((x + i, y + j), color)


def glyph_w(g):
    return len(g[0])


def rank_glyph(rank):
    """Return (bitmap, width) for a rank label."""
    if rank == "10":
        merged = [NARROW_1[r] + "." + FONT["0"][r] for r in range(7)]
        return merged
    return FONT[rank]


def rounded_mask(w, h, r=4):
    """Boolean grid: True where the card body exists."""
    m = [[True] * w for _ in range(h)]
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    for cx, cy in corners:
        for y in range(h):
            for x in range(w):
                dx = abs(x - cx)
                dy = abs(y - cy)
                if dx < r and dy < r:
                    # distance from the rounding pivot
                    px = r - 1 - dx
                    py = r - 1 - dy
                    if px * px + py * py > (r - 1) * (r - 1) + 1:
                        m[y][x] = False
    return m


MASK = rounded_mask(W, H, 5)


def blank_card(fill=BONE, border=INK):
    img = Image.new("RGBA", (W, H), CLEAR)
    for y in range(H):
        for x in range(W):
            if MASK[y][x]:
                img.putpixel((x, y), fill)
    # 1px border = any filled pixel adjacent to an empty one
    edge = []
    for y in range(H):
        for x in range(W):
            if not MASK[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= W or ny >= H or not MASK[ny][nx]:
                    edge.append((x, y))
                    break
    for x, y in edge:
        img.putpixel((x, y), border)
    return img


# ---------------------------------------------------------------- pip layout
# column x-centres and row y-centres for the classic pip grid
COL_L, COL_C, COL_R = 21, 32, 43   # left edge of a 7px pip
ROW = {"t": 22, "ut": 32, "u": 38, "m": 46, "l": 63, "lb": 69, "b": 79}

LAYOUTS = {
    "2":  [(COL_C, "t"), (COL_C, "b")],
    "3":  [(COL_C, "t"), (COL_C, "m"), (COL_C, "b")],
    "4":  [(COL_L, "t"), (COL_R, "t"), (COL_L, "b"), (COL_R, "b")],
    "5":  [(COL_L, "t"), (COL_R, "t"), (COL_C, "m"), (COL_L, "b"), (COL_R, "b")],
    "6":  [(COL_L, "t"), (COL_R, "t"), (COL_L, "m"), (COL_R, "m"),
           (COL_L, "b"), (COL_R, "b")],
    "7":  [(COL_L, "t"), (COL_R, "t"), (COL_C, "ut"), (COL_L, "m"), (COL_R, "m"),
           (COL_L, "b"), (COL_R, "b")],
    "8":  [(COL_L, "t"), (COL_R, "t"), (COL_C, "ut"), (COL_L, "m"), (COL_R, "m"),
           (COL_C, "lb"), (COL_L, "b"), (COL_R, "b")],
    "9":  [(COL_L, "t"), (COL_R, "t"), (COL_L, "u"), (COL_R, "u"), (COL_C, "m"),
           (COL_L, "l"), (COL_R, "l"), (COL_L, "b"), (COL_R, "b")],
    "10": [(COL_L, "t"), (COL_R, "t"), (COL_C, "ut"), (COL_L, "u"), (COL_R, "u"),
           (COL_L, "l"), (COL_R, "l"), (COL_C, "lb"), (COL_L, "b"), (COL_R, "b")],
}
MID_Y = 49


def draw_face(rank, suit):
    color = RED if suit in RED_SUITS else BLK
    shade = RED_DARK if suit in RED_SUITS else BLK_DARK
    img = blank_card()

    # inner panel for a bit of depth
    for y in range(4, H - 4):
        for x in range(4, W - 4):
            if MASK[y][x]:
                img.putpixel((x, y), PANEL)

    pip = PIPS[suit]
    rg = rank_glyph(rank)
    rw = glyph_w(rg)

    # ---- corner indices (top-left, and mirrored bottom-right)
    blit(img, rg, 6, 7, color)
    blit(img, pip, 6 + max(0, (rw - 7) // 2), 16, color)
    blit(img, rg, W - 6 - rw, H - 7 - 7, color, flip=True)
    blit(img, pip, W - 6 - max(7, rw) + max(0, (rw - 7) // 2), H - 16 - 7, color, flip=True)

    # ---- centre
    if rank == "A":
        # decorative lozenge around a single pip
        cx, cy = W // 2, 49
        for k in range(13):
            for (dx, dy) in ((k, 12 - k), (-k, 12 - k), (k, k - 12), (-k, k - 12)):
                if abs(dx) + abs(dy) == 12:
                    px, py = cx + dx, cy + dy
                    if 4 < px < W - 4 and 4 < py < H - 4:
                        img.putpixel((px, py), shade)
        blit(img, pip, cx - 3, cy - 3, color)
    elif rank in ("J", "Q", "K"):
        cx = W // 2
        # crown
        blit(img, CROWN, cx - 6, 30, GOLD_DARK)
        for j, row in enumerate(CROWN):
            for i, ch in enumerate(row):
                if ch == "#" and j < 5:
                    img.putpixel((cx - 6 + i, 30 + j), GOLD)
        # big rank letter (3x scale of the 5x7 glyph)
        g = FONT[rank]
        for j, row in enumerate(g):
            for i, ch in enumerate(row):
                if ch == "#":
                    for oy in range(3):
                        for ox in range(3):
                            img.putpixel((cx - 7 + i * 3 + ox, 44 + j * 3 + oy), color)
        blit(img, pip, cx - 3, 68, color)
    else:
        for (x, key) in LAYOUTS[rank]:
            y = ROW[key]
            blit(img, pip, x, y, color, flip=(y > MID_Y))

    return img


def draw_back():
    img = blank_card(fill=INDIGO, border=INK)
    for y in range(3, H - 3):
        for x in range(3, W - 3):
            if not MASK[y][x]:
                continue
            img.putpixel((x, y), INDIGO_D if (x + y) % 4 == 0 else INDIGO)
            if (x - y) % 8 == 0:
                img.putpixel((x, y), INDIGO_L)
    # inner keyline
    for x in range(6, W - 6):
        img.putpixel((x, 6), GOLD_DARK)
        img.putpixel((x, H - 7), GOLD_DARK)
    for y in range(6, H - 6):
        img.putpixel((6, y), GOLD_DARK)
        img.putpixel((W - 7, y), GOLD_DARK)
    # centre emblem: three interlocked pips = "a meld"
    cx, cy = W // 2, H // 2
    for y in range(cy - 14, cy + 15):
        for x in range(cx - 13, cx + 14):
            if abs(x - cx) + abs(y - cy) <= 16:
                img.putpixel((x, y), INDIGO_D)
    blit(img, PIPS["S"], cx - 10, cy - 8, GOLD)
    blit(img, PIPS["H"], cx - 3, cy - 3, GOLD)
    blit(img, PIPS["D"], cx + 4, cy + 2, GOLD)
    return img


def draw_frame(color, thickness=2):
    """Transparent card-shaped outline used as a selection / validity highlight."""
    img = Image.new("RGBA", (W, H), CLEAR)
    for y in range(H):
        for x in range(W):
            if not MASK[y][x]:
                continue
            near_edge = False
            for dy in range(-thickness, thickness + 1):
                for dx in range(-thickness, thickness + 1):
                    nx, ny = x + dx, y + dy
                    if nx < 0 or ny < 0 or nx >= W or ny >= H or not MASK[ny][nx]:
                        near_edge = True
            if near_edge:
                img.putpixel((x, y), color)
    return img


def draw_slot():
    """Dashed empty-pile placeholder."""
    img = Image.new("RGBA", (W, H), CLEAR)
    for y in range(H):
        for x in range(W):
            if MASK[y][x]:
                img.putpixel((x, y), (255, 255, 255, 18))
    for y in range(H):
        for x in range(W):
            if not MASK[y][x]:
                continue
            edge = any(
                (x + dx < 0 or y + dy < 0 or x + dx >= W or y + dy >= H
                 or not MASK[y + dy][x + dx])
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            )
            if edge and ((x + y) // 4) % 2 == 0:
                img.putpixel((x, y), (255, 255, 255, 120))
    return img


def draw_pile_stack():
    """Three offset backs for the draw pile."""
    img = Image.new("RGBA", (W + 6, H + 6), CLEAR)
    back = draw_back()
    for i in (2, 1, 0):
        img.alpha_composite(back, (i * 3, i * 3))
    return img


# ---------------------------------------------------------------- run
def main():
    os.makedirs(OUT, exist_ok=True)
    faces = {}
    for suit in SUIT_ORDER:
        for rank in RANKS:
            img = draw_face(rank, suit)
            name = f"{rank}{suit}"
            img.save(f"{OUT}/card_{name}.png")
            faces[(suit, rank)] = img

    draw_back().save(f"{OUT}/card_back.png")
    draw_frame(GOLD, 2).save(f"{OUT}/frame_selected.png")
    draw_frame(GREEN, 2).save(f"{OUT}/frame_valid.png")
    draw_frame((236, 96, 96, 255), 2).save(f"{OUT}/frame_invalid.png")
    draw_slot().save(f"{OUT}/pile_empty.png")
    draw_pile_stack().save(f"{OUT}/pile_draw.png")

    # atlas: 13 cols x 4 rows, row order S H C D
    atlas = Image.new("RGBA", (W * 13, H * 4), CLEAR)
    for r, suit in enumerate(SUIT_ORDER):
        for c, rank in enumerate(RANKS):
            atlas.alpha_composite(faces[(suit, rank)], (c * W, r * H))
    atlas.save(f"{OUT}/card_atlas.png")

    # 4x preview sheet for eyeballing
    prev = atlas.resize((W * 13 * 3, H * 4 * 3), Image.NEAREST)
    bg = Image.new("RGBA", prev.size, (26, 24, 38, 255))
    bg.alpha_composite(prev)
    bg.convert("RGB").save("/home/claude/out/preview_deck.png")
    print("cards:", len(faces))


if __name__ == "__main__":
    main()
