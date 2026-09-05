#!/usr/bin/env python3
"""Card back skins for the profile shop."""
from PIL import Image
import os, math
OUT="/home/claude/out/assets/cards"
W,H=70,98
CLEAR=(0,0,0,0); INK=(24,22,34,255)

SKINS = {
 "indigo":  ((59,54,84),(40,36,60),(78,71,108),(232,182,76)),
 "crimson": ((104,34,44),(70,22,30),(140,54,64),(240,190,120)),
 "moss":    ((38,74,54),(24,52,38),(58,104,74),(214,224,150)),
 "bone":    ((196,186,168),(150,140,124),(224,216,200),(96,70,44)),
 "void":    ((26,24,38),(14,13,22),(46,42,66),(150,120,220)),
 "brass":   ((110,84,36),(78,58,22),(146,114,52),(250,232,170)),
}
PATTERNS = ["lattice","weave","rays","dots","chevron","rings"]

def mask(w,h,r=5):
    m=[[True]*w for _ in range(h)]
    for cx,cy in ((0,0),(w-1,0),(0,h-1),(w-1,h-1)):
        for y in range(h):
            for x in range(w):
                dx,dy=abs(x-cx),abs(y-cy)
                if dx<r and dy<r:
                    px_,py_=r-1-dx,r-1-dy
                    if px_*px_+py_*py_>(r-1)*(r-1)+1: m[y][x]=False
    return m
M=mask(W,H)

def make(name,pal,pat):
    base,dark,light,accent=[c+(255,) for c in pal]
    img=Image.new("RGBA",(W,H),CLEAR)
    for y in range(H):
        for x in range(W):
            if not M[y][x]: continue
            c=base
            if pat=="lattice": c=dark if (x+y)%4==0 else (light if (x-y)%8==0 else base)
            elif pat=="weave": c=dark if (x//3+y//3)%2==0 else base
            elif pat=="rays":
                a=math.atan2(y-H/2,x-W/2)
                c=light if int(a*7)%2==0 else base
            elif pat=="dots": c=light if (x%6==3 and y%6==3) else (dark if (x+y)%9==0 else base)
            elif pat=="chevron": c=light if ((x+abs((y%12)-6))%7)<2 else base
            elif pat=="rings":
                d=math.hypot(x-W/2,y-H/2)
                c=light if int(d)%7<2 else base
            img.putpixel((x,y),c)
    # border
    for y in range(H):
        for x in range(W):
            if not M[y][x]: continue
            if any(not M[y+dy][x+dx] if 0<=y+dy<H and 0<=x+dx<W else True
                   for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))):
                img.putpixel((x,y),INK)
    for x in range(6,W-6):
        img.putpixel((x,6),accent); img.putpixel((x,H-7),accent)
    for y in range(6,H-6):
        img.putpixel((6,y),accent); img.putpixel((W-7,y),accent)
    cx,cy=W//2,H//2
    for y in range(cy-12,cy+13):
        for x in range(cx-11,cx+12):
            if abs(x-cx)+abs(y-cy)<=13: img.putpixel((x,y),dark)
    for y in range(cy-8,cy+9):
        for x in range(cx-7,cx+8):
            if abs(x-cx)+abs(y-cy)==8: img.putpixel((x,y),accent)
    img.putpixel((cx,cy),accent)
    img.save(f"{OUT}/back_{name}.png")

def main():
    os.makedirs(OUT,exist_ok=True)
    for i,(n,p) in enumerate(SKINS.items()):
        make(n,p,PATTERNS[i%len(PATTERNS)])
    sheet=Image.new("RGBA",(W*6*3,H*3),(26,24,38,255))
    for i,n in enumerate(SKINS):
        sheet.alpha_composite(Image.open(f"{OUT}/back_{n}.png").resize((W*3,H*3),Image.NEAREST),(i*W*3,0))
    sheet.convert("RGB").save("/home/claude/out/preview_backs.png")
    print("backs:",len(SKINS))
main()
