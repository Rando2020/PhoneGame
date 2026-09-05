#!/usr/bin/env python3
"""Pixel overlays for marked cards — 70x98, composited over the card face."""
from PIL import Image
import os
OUT="/home/claude/out/assets/cards"
W,H=70,98
CLEAR=(0,0,0,0)

MARKS={
 "gilded":   ((232,182,76),(168,124,40),"sun"),
 "glass":    ((116,224,208),(58,150,140),"crack"),
 "chameleon":((201,111,214),(126,58,138),"wave"),
 "steel":    ((154,166,191),(92,102,124),"cross"),
 "coin":     ((111,201,138),(52,124,80),"coin"),
 "lucky":    ((232,128,76),(150,70,34),"star"),
}

def rounded(x,y):
    cx=min(x,W-1-x); cy=min(y,H-1-y)
    return cx+cy>=4

def frame(img,c1,c2):
    for y in range(H):
        for x in range(W):
            if not rounded(x,y): continue
            e=min(x,W-1-x,y,H-1-y)
            if e==2: img.putpixel((x,y),c1+(255,))
            elif e==3: img.putpixel((x,y),c2+(255,))

EMB={
 "sun":  ["..#..","#.#.#",".###.","#####",".###.","#.#.#","..#.."],
 "crack":["..#..","..#..",".##..","..##.","..#..",".#...",".#..."],
 "wave": [".....","##...","..#..","...##",".....","##...","..#.."],
 "cross":["..#..","..#..","#####","..#..","..#..","..#..","....."],
 "coin": [".###.","#...#","#.#.#","#.#.#","#.#.#","#...#",".###."],
 "star": ["..#..","..#..","#####",".###.","#...#",".....","....."],
}

def stamp(img,g,x,y,c):
    for j,row in enumerate(g):
        for i,ch in enumerate(row):
            if ch=="#" and 0<=x+i<W and 0<=y+j<H:
                img.putpixel((x+i,y+j),c)

def corner_plate(img,c1,c2,emb):
    # a small plate in the top-right so the mark reads even when cards overlap
    for y in range(4,16):
        for x in range(W-17,W-4):
            img.putpixel((x,y),c2+(255,))
    for y in range(5,15):
        for x in range(W-16,W-5):
            img.putpixel((x,y),c1+(255,))
    stamp(img,EMB[emb],W-14,5,(20,18,28,255))

def texture(img,kind,c1,c2):
    if kind=="glass":       # diagonal shine bands
        for y in range(H):
            for x in range(W):
                if rounded(x,y) and (x+y)%14==0:
                    img.putpixel((x,y),c1+(70,))
    elif kind=="gilded":    # sparse glints
        for (x,y) in ((14,30),(52,44),(20,66),(44,74),(30,20)):
            img.putpixel((x,y),c1+(200,)); img.putpixel((x+1,y),c1+(120,))
            img.putpixel((x,y+1),c1+(120,))
    elif kind=="steel":     # brushed vertical lines
        for x in range(6,W-6,5):
            for y in range(6,H-6):
                if rounded(x,y): img.putpixel((x,y),c2+(55,))
    elif kind=="chameleon": # shifting dither
        for y in range(6,H-6):
            for x in range(6,W-6):
                if rounded(x,y) and (x*y)%23==0: img.putpixel((x,y),c1+(80,))
    elif kind=="coin":      # scattered dots
        for (x,y) in ((16,36),(48,30),(24,72),(50,66)):
            img.putpixel((x,y),c1+(180,))
    elif kind=="lucky":     # corner pips
        for (x,y) in ((10,86),(58,10)):
            stamp(img,EMB["star"],x-2,y-3,c1+(160,))

def main():
    os.makedirs(OUT,exist_ok=True)
    for k,(c1,c2,emb) in MARKS.items():
        img=Image.new("RGBA",(W,H),CLEAR)
        frame(img,c1,c2)
        texture(img,k,c1,c2)
        corner_plate(img,c1,c2,emb)
        img.save(f"{OUT}/mark_{k}.png")
    sheet=Image.new("RGBA",(W*6*3,H*3),(244,236,224,255))
    base=Image.open(f"{OUT}/card_5H.png").convert("RGBA")
    for i,k in enumerate(MARKS):
        card=base.copy()
        card.alpha_composite(Image.open(f"{OUT}/mark_{k}.png"))
        sheet.alpha_composite(card.resize((W*3,H*3),Image.NEAREST),(i*W*3,0))
    sheet.convert("RGB").save("/home/claude/out/preview_marks.png")
    print("marks:",len(MARKS))
main()
