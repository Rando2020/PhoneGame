#!/usr/bin/env python3
"""
Checks store/listing.md against App Store Connect's limits: each "## Field (N)"
heading's text block must be at most N characters. Also: no em or en dashes,
no emoji, keywords comma-separated with no spaces after commas and no word
repeated from the name, and every number in the description that names a
content count matches the game data passed in (--counts JSON).

  python3 tools/check_listing.py [store/listing.md] [--counts counts.json]
Exit 0 = all pass.
"""
import json, re, sys

path = "store/listing.md"
counts = None
args = sys.argv[1:]
if args and not args[0].startswith("--"):
    path = args.pop(0)
if "--counts" in args:
    counts = json.load(open(args[args.index("--counts") + 1]))

text = open(path, encoding="utf-8").read()
fields = {}
for m in re.finditer(r"^## (.+?)(?: \((\d+)\))?\n\n```text\n(.*?)\n```", text, re.S | re.M):
    fields[m.group(1)] = (int(m.group(2)) if m.group(2) else None, m.group(3))

fails = []
def check(ok, msg):
    if not ok:
        fails.append(msg)

for need in ["Name", "Subtitle", "Promotional text", "Description", "Keywords", "What's new"]:
    check(need in fields, f"missing field: {need}")

for name, (limit, body) in fields.items():
    n = len(body)
    if limit is not None:
        check(n <= limit, f"{name}: {n} chars, limit {limit}")
        print(f"{name:18} {n:5} / {limit}")
    check("—" not in body and "–" not in body, f"{name}: em or en dash")
    check(not re.search(r"[\U0001F300-\U0001FAFF☀-➿]", body), f"{name}: emoji")

check("—" not in text, "em dash somewhere in listing.md")

if "Keywords" in fields:
    kw = fields["Keywords"][1]
    check(", " not in kw, "keywords: space after a comma wastes characters")
    words = [w.strip().lower() for w in kw.split(",")]
    check(len(words) == len(set(words)), "keywords: a repeat")
    name_words = set(re.findall(r"[a-z]+", fields.get("Name", (0, ""))[1].lower()))
    rep = [w for w in words if w in name_words]
    check(not rep, f"keywords repeat the name (Apple indexes the name already): {rep}")

if counts and "Description" in fields:
    d = fields["Description"][1]
    for label, key in [("charms", "charms"), ("Spoilers", "spoilers"), ("card marks", "marks"),
                       ("streets", "streets"), ("trials", "trials"), ("deeds", "deeds"),
                       ("acts", "acts"), ("rounds", "rounds")]:
        for m in re.finditer(r"(\d+) " + re.escape(label), d):
            check(int(m.group(1)) == counts[key], f"description says {m.group(1)} {label}, game has {counts[key]}")
    m = re.search(r"(\d+) Meldlings to play as", d)
    check(m is not None and int(m.group(1)) == counts["base_meldlings"], "description: Meldling count")
    m = re.search(r"(\d+) ascended forms", d)
    check(m is not None and int(m.group(1)) == counts["ascended"], "description: ascended count")
    m = re.search(r"(\d+)-step How to play", d)
    check(m is not None and int(m.group(1)) == counts["howto_steps"], "description: How to play steps")
    m = re.search(r"(\d+) more acts", d)
    check(m is not None and int(m.group(1)) == counts["acts"] - 1, "description: 'N more acts' should be acts - 1")
    check("Free to try" in fields.get("Promotional text", (0, ""))[1] or "FREE TO TRY" in d, "the listing doesn't say it's free to try")
    check("com.meldlings.full" in text, "the in-app purchase's product id is missing")
    for mk in counts.get("mark_names", []):
        check(mk in d, f"description: mark {mk} missing")

for f in fails:
    print("FAIL", f)
print(f"listing: {len(fails)} fails")
sys.exit(1 if fails else 0)
