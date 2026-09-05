#!/usr/bin/env python3
"""Rarity plaques + charm category icons."""
from PIL import Image
import os
OUT = "/home/claude/out/assets/icons"
CLEAR=(0,0,0,0); INK=(22,20,32,255); WHITE=(246,244,238,255)

RARITY = {
  "common":    ((120,134,166,255),(78,88,116,255)),
  "uncommon":  ((110,201,138,255),(58,124,84,255)),
  "rare":      ((232,182,76,255),(150,110,34,255)),
  "legendary": ((208,111,214,255),(126,58,138,255)),
}

def plaque(light, dark, w=22, h=22):
    img = Image.new("RGBA",(w,h),CLEAR)
    for y in range(h):
        for x in range(w):
            # rounded corners
            cx = min(x, w-1-x); cy = min(y, h-1-y)
            if cx+cy < 2: continue
            edge = cx == 0 or cy == 0 or cx+cy == 2
            if edge: img.putpixel((x,y), light)
            else:
                t = y/(h-1)
                img.putpixel((x,y), dark if t > 0.55 else (
                    int(dark[0]*0.7+light[0]*0.3), int(dark[1]*0.7+light[1]*0.3),
                    int(dark[2]*0.7+light[2]*0.3), 255))
    # top highlight
    for x in range(3, w-3): img.putpixel((x,1), light)
    return img

GEMS = {
  "common":    ["..##..",".####.","######","######",".####.","..##.."],
  "uncommon":  [".#..#.","######","######","######",".####.","..##.."],
  "rare":      ["#.##.#","######","######",".####.",".####.","..##.."],
  "legendary": ["#.##.#","######","##..##","######","#.##.#",".####."],
}

CATS = {
  "mult":  ["#....#",".#..#.","..##..",".#..#.","#....#","......"],
  "rule":  ["..#...","#####.","..#...",".###..","#...#.","......"],
  "deck":  ["#####.","#...#.","#####.","#...#.","#####.","......"],
}

def stamp(img, grid, x, y, c):
    for j,row in enumerate(grid):
        for i,ch in enumerate(row):
            if ch=="#" and 0<=x+i<img.size[0] and 0<=y+j<img.size[1]:
                img.putpixel((x+i,y+j), c)

def main():
    os.makedirs(OUT, exist_ok=True)
    for name,(light,dark) in RARITY.items():
        p = plaque(light,dark)
        stamp(p, GEMS[name], 8, 8, WHITE)
        p.save(f"{OUT}/rar_{name}.png")
    for name,grid in CATS.items():
        img = Image.new("RGBA",(8,8),CLEAR)
        stamp(img, grid, 1, 1, WHITE)
        out = Image.new("RGBA",(8,8),CLEAR)
        for y in range(8):
            for x in range(8):
                if img.getpixel((x,y))[3]:
                    for dx,dy in ((1,1),):
                        if 0<=x+dx<8 and 0<=y+dy<8 and not img.getpixel((x+dx,y+dy))[3]:
                            out.putpixel((x+dx,y+dy), INK)
        out.alpha_composite(img)
        out.save(f"{OUT}/cat_{name}.png")
    # preview
    sheet = Image.new("RGBA",(22*5*4, 22*5),(26,24,38,255))
    for i,n in enumerate(RARITY):
        im = Image.open(f"{OUT}/rar_{n}.png").resize((22*5,22*5),Image.NEAREST)
        sheet.alpha_composite(im,(i*22*5,0))
    sheet.convert("RGB").save("/home/claude/out/preview_rarity.png")
    print("rarity plaques:", len(RARITY), "cat icons:", len(CATS))

main()
