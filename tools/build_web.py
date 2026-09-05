#!/usr/bin/env python3
"""Bundle the web build into a single self-contained meldlings.html.

Embeds the card atlas and every creature sprite strip as base64, so the file
opens straight from disk with no server and no network.
"""
import base64, os, json, struct

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(BASE, "web")
CARDS = os.path.join(BASE, "assets", "cards")
CREAT = os.path.join(BASE, "assets", "meldlings")
OUT = os.path.join(BASE, "meldlings.html")

CREATURES = ["pip", "thump", "clover", "facet", "nib", "muggins",
             "deadwood", "shuffler", "jokester", "kingpin"]
ANIMS = ["idle", "attack", "hurt"]
ICON_DIR = os.path.join(BASE, "assets", "icons")
ICONS = ["fifteen", "pair", "run", "flush", "nobs"]
PIPS = ["gold", "blue", "green", "white"]
RARS = ["common", "uncommon", "rare", "legendary"]
MARKS = ["gilded", "glass", "chameleon", "steel", "coin", "lucky"]
BACKS = ["indigo", "crimson", "moss", "bone", "void", "brass"]
CATS = ["mult", "rule", "deck"]


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    w, h = struct.unpack(">II", head[16:24])
    return w, h


def data_url(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def build():
    art = {
        "atlas": data_url(os.path.join(CARDS, "card_atlas.png")),
        "back": data_url(os.path.join(CARDS, "card_back.png")),
        "icons": {k: data_url(os.path.join(ICON_DIR, f"icon_{k}.png")) for k in ICONS},
        "pips": {k: data_url(os.path.join(ICON_DIR, f"pip_{k}.png")) for k in PIPS},
        "rarity": {k: data_url(os.path.join(ICON_DIR, f"rar_{k}.png")) for k in RARS},
        "marks": {k: data_url(os.path.join(CARDS, f"mark_{k}.png")) for k in MARKS},
        "backs": {k: data_url(os.path.join(CARDS, f"back_{k}.png")) for k in BACKS},
        "split": {
            "frame": data_url(os.path.join(CARDS, "split_frame.png")),
            "glyphs": data_url(os.path.join(CARDS, "glyphs.png")),
            "glyphsBig": data_url(os.path.join(CARDS, "glyphs_big.png")),
            "pips": data_url(os.path.join(CARDS, "suitpips.png")),
        },
        "cats": {k: data_url(os.path.join(ICON_DIR, f"cat_{k}.png")) for k in CATS},
    }

    sprites = {}
    for c in CREATURES:
        sprites[c] = {}
        for a in ANIMS:
            p = os.path.join(CREAT, f"{c}_{a}.png")
            w, h = png_size(p)
            sprites[c][a] = {"h": h, "frames": max(1, w // h), "url": data_url(p)}

    def js(name):
        t = open(os.path.join(WEB, name), encoding="utf-8").read()
        t = t.replace('if (typeof module !== "undefined") {', 'if (false) {')
        t = t.replace('if (typeof module !== "undefined")\n  module.exports', 'if (false)\n  var _x')
        return t

    rules = (js("rules.js") + "\n" + js("gin.js") + "\n" + js("roguelite.js") + "\n"
             + js("cribbage.js") + "\n" + js("meta.js") + "\n" + js("cribrogue.js"))
    app = (js("audio.js") + "\n" + js("app.js") + "\n" + js("gin_ui.js") + "\n"
           + js("roguelite_ui.js") + "\n" + js("cascade.js") + "\n" + js("cribrogue_ui.js") + "\n" + js("tutorial.js") + "\n" + js("gallery.js"))
    css = open(os.path.join(WEB, "style.css"), encoding="utf-8").read()

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<meta name="theme-color" content="#14121f">
<title>Meldlings</title>
<style>
{css}
</style>
</head>
<body>
<div id="app"></div>
<script>
const ART = {json.dumps(art)};
const SPRITES = {json.dumps(sprites)};
</script>
<script>
{rules}
</script>
<script>
{app}
</script>
</body>
</html>
"""
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"wrote {OUT}  ({len(html)/1024:.0f} KB)")


if __name__ == "__main__":
    build()
