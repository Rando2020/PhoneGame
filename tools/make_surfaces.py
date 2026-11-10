#!/usr/bin/env python3
"""
Table surfaces for the Godot port: tileable, generated (no hand art).

  felt_round.png    green baize for ordinary rounds
  felt_spoiler.png  a darker, colder baize for Spoiler rounds
  felt_menu.png     deep indigo baize for the front door and menus
  wood_rail.png     a horizontal wood rail (shop rail, The Play's table edge)

Felt: fibre noise (many short, faint strokes) over a soft low-frequency mottle,
with a gentle vignette baked into a separate overlay so the tile itself stays
seamless. Wood: grain lines warped by low-frequency noise, a lacquer highlight.

  python3 tools/make_surfaces.py OUTDIR
"""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/surfaces"
os.makedirs(OUT, exist_ok=True)
T = 512


def value_noise(size, cells, seed):
    """Smooth tileable noise: a small random grid, wrapped, bicubic-upscaled."""
    rnd = random.Random(seed)
    g = Image.new("L", (cells, cells))
    g.putdata([rnd.randint(0, 255) for _ in range(cells * cells)])
    big = Image.new("L", (cells * 3, cells * 3))
    for i in range(3):
        for j in range(3):
            big.paste(g, (i * cells, j * cells))
    big = big.resize((size * 3, size * 3), Image.BICUBIC)
    return big.crop((size, size, size * 2, size * 2))


def felt(base, seed, fibre=0.10, mottle=0.12):
    rnd = random.Random(seed)
    img = Image.new("RGB", (T, T), base)
    # low-frequency mottle
    m = ImageChops.add(value_noise(T, 6, seed), value_noise(T, 14, seed + 1), scale=2)
    dark = tuple(max(0, int(c * (1 - mottle))) for c in base)
    light = tuple(min(255, int(c * (1 + mottle))) for c in base)
    img = Image.composite(Image.new("RGB", (T, T), light), Image.new("RGB", (T, T), dark), m)
    # fibres: short strokes, drawn on a 3x3 wrap so the tile is seamless
    f = Image.new("L", (T * 3, T * 3), 128)
    d = ImageDraw.Draw(f)
    for _ in range(26000):
        x, y = rnd.uniform(T, 2 * T), rnd.uniform(T, 2 * T)
        a = rnd.uniform(0, math.pi)
        l = rnd.uniform(2, 7)
        v = 128 + rnd.choice((-1, 1)) * rnd.randint(18, 60)
        for ox in (-T, 0, T):
            for oy in (-T, 0, T):
                d.line([x + ox, y + oy, x + ox + math.cos(a) * l, y + oy + math.sin(a) * l], fill=v)
    f = f.crop((T, T, 2 * T, 2 * T)).filter(ImageFilter.GaussianBlur(0.6))
    hi = Image.new("RGB", (T, T), tuple(min(255, int(c * (1 + fibre * 2))) for c in base))
    lo = Image.new("RGB", (T, T), tuple(int(c * (1 - fibre * 2)) for c in base))
    up = f.point(lambda v: max(0, v - 128) * 2)
    dn = f.point(lambda v: max(0, 128 - v) * 2)
    img = Image.composite(hi, img, up.point(lambda v: v // 3))
    img = Image.composite(lo, img, dn.point(lambda v: v // 3))
    return img


def wood(seed, h=96):
    rnd = random.Random(seed)
    w = T
    warp = value_noise(T, 5, seed)
    img = Image.new("RGB", (w, h))
    px = img.load()
    wp = warp.load()
    c0, c1, c2 = (86, 52, 30), (120, 76, 44), (150, 100, 60)
    for y in range(h):
        for x in range(w):
            n = wp[x, (y * 5) % T] / 255.0
            g = math.sin((y + n * 18) * 0.55 + math.sin(x * 2 * math.pi / w * 3) * 1.4)
            k = (g + 1) / 2
            ring = 0.25 if (int(y + n * 18) % 9) == 0 else 0
            t = max(0.0, min(1.0, k * 0.8 + ring))
            a, b = (c0, c1) if t < 0.5 else (c1, c2)
            u = t * 2 if t < 0.5 else (t - 0.5) * 2
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * u) for i in range(3))
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, 0, w, 3], fill=(255, 220, 170, 70))           # lacquer catch on the top edge
    d.rectangle([0, h * 0.18, w, h * 0.30], fill=(255, 230, 190, 26))
    d.rectangle([0, h - 6, w, h], fill=(20, 10, 4, 120))          # the underside in shadow
    return img


def vignette(size=1024):
    """An overlay: transparent centre, dark edges (drawn over the tiled felt)."""
    v = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(v)
    steps = 60
    for i in range(steps):
        k = i / steps
        a = int(150 * (1 - k) ** 2.2)
        pad = int(k * size * 0.5)
        d.rectangle([pad, pad, size - pad, size - pad], outline=a, width=int(size * 0.5 / steps) + 1)
    v = v.filter(ImageFilter.GaussianBlur(size / 30))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.putalpha(v)
    return out


def main():
    felt((34, 92, 66), 11).save(f"{OUT}/felt_round.png")
    felt((30, 46, 64), 12, mottle=0.14).save(f"{OUT}/felt_spoiler.png")
    felt((32, 30, 54), 13, fibre=0.07).save(f"{OUT}/felt_menu.png")
    wood(14).save(f"{OUT}/wood_rail.png")
    vignette().save(f"{OUT}/vignette.png")
    # a preview: each felt tiled 2x2 with the vignette, and the rail on top
    prev = Image.new("RGB", (3 * 520, 560), (0, 0, 0))
    for i, n in enumerate(("felt_round", "felt_spoiler", "felt_menu")):
        t = Image.open(f"{OUT}/{n}.png").resize((256, 256))
        tile = Image.new("RGB", (512, 512))
        for a in (0, 256):
            for b in (0, 256):
                tile.paste(t, (a, b))
        tile = Image.alpha_composite(tile.convert("RGBA"), vignette(512)).convert("RGB")
        tile.paste(Image.open(f"{OUT}/wood_rail.png").resize((512, 48)), (0, 0))
        prev.paste(tile, (i * 520, 24))
    prev.save(f"{OUT}/surfaces_preview.png")
    print(f"{OUT}/surfaces_preview.png")


if __name__ == "__main__":
    main()
