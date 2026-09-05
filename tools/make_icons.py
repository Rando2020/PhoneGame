#!/usr/bin/env python3
"""Pixel icons for the five cribbage scoring categories, plus particle sprites."""
from PIL import Image
import os
OUT = "/home/claude/out/assets/icons"
CLEAR = (0,0,0,0)
GOLD=(232,182,76,255); GOLD_D=(168,124,40,255); WHITE=(246,244,238,255)
BLUE=(116,174,235,255); GREEN=(115,199,122,255); RED=(220,90,90,255)
PURP=(190,120,220,255); INK=(26,24,36,255)

ICONS = {
 # 15 — two digits
 "fifteen": (["..#...#####.",
              ".##...#.....",
              "..#...####..",
              "..#.......#.",
              "..#.......#.",
              "..#...#...#.",
              ".###...###.."], GOLD),
 # pair — two stacked cards
 "pair":    ([".####.......",
              ".#..#.####..",
              ".#..#.#..#..",
              ".####.#..#..",
              "......####..",
              "............",
              "............"], BLUE),
 # run — ascending steps
 "run":     ([".........##.",
              ".......##.#.",
              ".....##.#.#.",
              "...##.#.#.#.",
              ".##.#.#.#.#.",
              ".#.#.#.#.#.#",
              ".##########."], GREEN),
 # flush — a fan of one suit
 "flush":   ["...#....#...",
             "..###..###..",
             ".#####.####.",
             "..###..###..",
             "...#....#...",
             "............",
             "............"],
 # nobs — a crowned J
 "nobs":    (["...#####....",
              ".....##.....",
              ".....##.....",
              ".....##.....",
              ".#...##.....",
              ".#...##.....",
              "..####......"], PURP),
}

def stamp(img, grid, x, y, c):
    for j,row in enumerate(grid):
        for i,ch in enumerate(row):
            if ch=="#":
                if 0<=x+i<img.size[0] and 0<=y+j<img.size[1]:
                    img.putpixel((x+i,y+j),c)

def make(name, grid, color):
    img = Image.new("RGBA",(14,9),CLEAR)
    stamp(img, grid, 1, 1, color)
    # 1px dark outline under for readability
    out = Image.new("RGBA",(14,9),CLEAR)
    for y in range(9):
        for x in range(14):
            if img.getpixel((x,y))[3]:
                for dx,dy in ((1,1),(1,0),(0,1)):
                    px,py=x+dx,y+dy
                    if 0<=px<14 and 0<=py<9 and not img.getpixel((px,py))[3]:
                        out.putpixel((px,py),INK)
    out.alpha_composite(img)
    out.save(f"{OUT}/icon_{name}.png")

def main():
    os.makedirs(OUT, exist_ok=True)
    for k,v in ICONS.items():
        if isinstance(v, tuple): grid,color = v
        else: grid,color = v, RED
        make(k, grid, color)
    # particles: tiny pips in 4 colours
    for name,c in (("gold",GOLD),("blue",BLUE),("green",GREEN),("white",WHITE)):
        p = Image.new("RGBA",(4,4),CLEAR)
        for y in range(4):
            for x in range(4):
                if (x in (1,2)) or (y in (1,2)): p.putpixel((x,y),c)
        p.save(f"{OUT}/pip_{name}.png")
    # preview
    sheet = Image.new("RGBA",(14*6*5, 9*5),(26,24,38,255))
    for i,k in enumerate(ICONS):
        im = Image.open(f"{OUT}/icon_{k}.png").resize((14*5,9*5),Image.NEAREST)
        sheet.alpha_composite(im,(i*14*5,0))
    sheet.convert("RGB").save("/home/claude/out/preview_icons.png")
    print("icons:", len(ICONS))

main()
