#!/usr/bin/env python3
"""Completeness audit: is every asset on disk actually in the build, and is every
system from the design reachable in the shipped HTML?"""
import os, re, base64

ROOT = "/home/claude/work"
html = open(f"{ROOT}/meldlings.html", encoding="utf-8").read()

# --- every PNG/OGG/WAV on disk, and whether its bytes are embedded
missing, embedded = [], 0
for dirpath, _, files in os.walk(f"{ROOT}/assets"):
    for f in files:
        if not f.lower().endswith((".png", ".ogg", ".wav")):
            continue
        p = os.path.join(dirpath, f)
        b64 = base64.b64encode(open(p, "rb").read()).decode()
        rel = os.path.relpath(p, ROOT)
        # audio is Godot-only by design; only check images
        if f.lower().endswith((".ogg", ".wav")):
            continue
        if b64[:80] in html:
            embedded += 1
        else:
            missing.append(rel)

print("=== ASSETS ===")
print(f"  images embedded in the build : {embedded}")
if missing:
    print(f"  NOT embedded ({len(missing)}):")
    for m in missing[:20]:
        print("     ", m)
else:
    print("  every image on disk is in the build")

# --- systems built across the whole project, and the symbol that proves each
SYSTEMS = [
    ("exact cribbage scoring",        "countHandCore"),
    ("expected-value keep search",    "keepEVFast"),
    ("keep-then-cut ordering",        "cutStarter"),
    ("tiered cut reveal",             "CUT_TIERS"),
    ("cut quality ranking",           "cutQuality"),
    ("counterfactual MVP",            "runMVP"),
    ("charms (43)",                   "CCHARMS"),
    ("charm ordering",                "charmOrderPanel"),
    ("additive-mult charms",          "ballast"),
    ("card marks (6)",                "ENHANCEMENTS"),
    ("split cards",                   "splitCardEl"),
    ("split scoring",                 "expandSplits"),
    ("the Crib (4 cards)",            "CRIB_SIZE"),
    ("crib multiplier",               "cribMult"),
    ("deck cycling",                  "recycle"),
    ("surplus + skips",               "SURPLUS_PER_SKIP"),
    ("early cash-out",                "cashOut"),
    ("spoilers (17)",                 "BOSS_POOL"),
    ("suit affinity",                 "SUIT_OPPOSE"),
    ("wagers",                        "planWagers"),
    ("system unlocks",                "SYSTEMS"),
    ("achievements (17)",             "ACHIEVEMENTS"),
    ("streets (5)",                   "STREETS"),
    ("pegs + peddler",                "showPeddler"),
    ("card backs (6)",                "CARD_BACKS"),
    ("lenses",                        "LENSES"),
    ("run history",                   "showHistory"),
    ("tutorial",                      "TUT_STEPS"),
    ("gallery",                       "showGallery"),
    ("music proximity",               "setProximity"),
    ("crib voice",                    "cribTick"),
    ("tension ramp (4 styles)",       "RAMP_STYLES"),
    ("animation speed control",       "Speed.cycle"),
    ("tooltips",                      "tipbox"),
    ("deed notifications",            "DeedQueue"),
    ("collapsible table drawer",      "tablestrip"),
]
print("\n=== SYSTEMS ===")
gone = [n for n, sym in SYSTEMS if sym not in html]
for n, sym in SYSTEMS:
    print(f"  {'ok ' if sym in html else 'MISSING'}  {n}")
print(f"\n  {len(SYSTEMS)-len(gone)}/{len(SYSTEMS)} systems present")

# --- source files that should exist
SRC = ["cribbage.js","cribrogue.js","meta.js","cribrogue_ui.js","cascade.js","audio.js",
       "app.js","tutorial.js","gallery.js","runtest.js","domtest.js","cribsim.js",
       "cribtest.js","pick2.js","uiaudit.js","keep_cut.js","clutch.js","dopamine_audit.js"]
print("\n=== SOURCE ===")
absent = [f for f in SRC if not os.path.exists(f"{ROOT}/web/{f}")]
print(f"  {len(SRC)-len(absent)}/{len(SRC)} expected source files present")
for f in absent:
    print("  MISSING", f)

TOOLS = ["build_web.py","make_cards.py","make_creatures.py","make_audio.py","make_icons.py",
         "make_items.py","make_marks.py","make_backs.py","make_split.py"]
absent_t = [f for f in TOOLS if not os.path.exists(f"{ROOT}/tools/{f}")]
print(f"  {len(TOOLS)-len(absent_t)}/{len(TOOLS)} generators present")
for f in absent_t:
    print("  MISSING", f)
