#!/usr/bin/env python3
"""Read a playtest.log (pass 22) and print the 6 PLAYTEST.md numbers next to
the sims' predictions.

  python3 tools/playtest_report.py path/to/playtest.log [--session ID] [--json]

The summary math matches Playtest.summary() in godot/engine/playtest.gd
(tests/test_playtest_report.py checks it on the same entries as pass22_test).

Comparisons use a 95% Wilson interval around the observed share. "within" means
the sim's prediction sits inside that interval. "outside" means it doesn't.
Below MIN_N observations the line says "unverified": one short session can't
settle it.
"""
import json
import math
import sys

CATS = ["fifteen", "pair", "run", "flush"]
MIN_N = 8  # fewer observations than this and a share is not evidence

# the sims' predictions (LOOP_AUDIT, pass 20: Shortage on round 2 of each act)
SIM_LEAD_CHANGES = 66.8   # autopilot: leading category changes between rounds
SIM_STRONG_CLEARS = 15.3  # a strong bot wins the whole game
SIM_BEGINNER_REACH = 51.1  # a beginner reaches the first Spoiler (act 1, round 3)

PACE = (60.0, 120.0)  # PLAYTEST.md's target seconds a round (unverified target)


def load(path, session=None):
    out = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if isinstance(d, dict) and (session is None or str(d.get("session", "")) == session):
                out.append(d)
    return out


def snap(x, step):
    # Godot's snappedf: round half away from zero to the nearest step
    q = x / step
    return round(math.floor(abs(q) + 0.5) * step * (1 if q >= 0 else -1), 6)


def lead(mix):
    best = ""
    for k in CATS:
        if best == "" or float(mix.get(k, 0)) > float(mix.get(best, 0)):
            best = k
    return best if float(mix.get(best, 0)) > 0 else "none"


def _pos(e):
    return int(e["act"]) * 10 + int(e["round"])


def new_run(e, prev):
    return prev is None or e.get("session") != prev.get("session") or _pos(e) <= _pos(prev)


def summary(lst):
    s = {"rounds": len(lst), "cleared_pct": 0.0, "avg_secs": 0.0, "mulligans_per_round": 0.0,
         "by_kind": {}, "lead_changes_pct": 0.0, "transitions": 0}
    if not lst:
        return s
    won = sum(1 for e in lst if e["cleared"])
    raw = {}
    for e in lst:
        k = str(e["kind"]).split(":")[0]
        b = raw.setdefault(k, {"rounds": 0, "won": 0, "secs": 0.0})
        b["rounds"] += 1
        b["won"] += 1 if e["cleared"] else 0
        b["secs"] += float(e["secs"])
    for k, b in raw.items():
        s["by_kind"][k] = {"rounds": b["rounds"], "cleared_pct": snap(100.0 * b["won"] / b["rounds"], 0.1),
                           "avg_secs": snap(b["secs"] / b["rounds"], 0.1)}
    s["cleared_pct"] = snap(100.0 * won / len(lst), 0.1)
    s["avg_secs"] = snap(sum(float(e["secs"]) for e in lst) / len(lst), 0.1)
    s["mulligans_per_round"] = snap(sum(int(e["mulligans"]) for e in lst) / len(lst), 0.01)
    prev, trans, changed = None, 0, 0
    for e in lst:
        if str(e["kind"]) == "spoiler":
            continue
        if not new_run(e, prev):
            trans += 1
            if lead(e["mix"]) != lead(prev["mix"]):
                changed += 1
        prev = e
    s["transitions"] = trans
    s["lead_changes_pct"] = snap(100.0 * changed / trans, 0.1) if trans else 0.0
    return s


def runs(lst):
    """Split every logged round (Spoilers too) into runs, in order."""
    out, prev = [], None
    for e in lst:
        if new_run(e, prev):
            out.append([])
        out[-1].append(e)
        prev = e
    return out


def reached_first_spoiler(run):
    return any(int(e["act"]) > 1 or (int(e["act"]) == 1 and int(e["round"]) >= 3) for e in run)


def wilson(k, n, z=1.96):
    if n == 0:
        return (0.0, 100.0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (100.0 * max(0.0, c - h), 100.0 * min(1.0, c + h))


def compare(k, n, predicted):
    """(observed %, low, high, verdict) for k of n against a predicted %."""
    lo, hi = wilson(k, n)
    obs = 100.0 * k / n if n else 0.0
    if n < MIN_N:
        return obs, lo, hi, "unverified"
    return obs, lo, hi, "within" if lo <= predicted <= hi else "outside"


def report(lst):
    s = summary(lst)
    bk = s["by_kind"]
    rs = runs(lst)
    lines = {}

    # 1. puzzle or tax: Shortage vs twist cleared % and seconds
    sh, tw = bk.get("shortage"), bk.get("twist")
    if sh and tw and min(sh["rounds"], tw["rounds"]) >= MIN_N // 2:
        gap = tw["cleared_pct"] - sh["cleared_pct"]
        v = "tax" if gap > 20 and sh["avg_secs"] <= tw["avg_secs"] else ("puzzle" if sh["avg_secs"] > tw["avg_secs"] else "neither")
    else:
        gap, v = None, "unverified"
    lines["q1_shortage"] = {"shortage": sh, "twist": tw, "cleared_gap": gap, "read": v}

    # 2. lead changes vs the autopilot (a player adapting should be at or above it)
    changed = round(s["lead_changes_pct"] * s["transitions"] / 100.0)
    obs, lo, hi, v = compare(changed, s["transitions"], SIM_LEAD_CHANGES)
    lines["q2_lead_changes"] = {"observed": obs, "ci": [lo, hi], "n": s["transitions"], "sim": SIM_LEAD_CHANGES, "vs_sim": v}

    # 3. twist read: twist rounds' seconds vs plain rounds'
    pl = bk.get("plain")
    if tw and pl and min(tw["rounds"], pl["rounds"]) >= MIN_N // 2:
        v = "read" if tw["avg_secs"] > pl["avg_secs"] else "not read"
    else:
        v = "unverified"
    lines["q3_twist_read"] = {"twist_secs": tw and tw["avg_secs"], "plain_secs": pl and pl["avg_secs"], "read": v}

    # 4. mulligans a round
    m = s["mulligans_per_round"]
    v = "unverified" if s["rounds"] < MIN_N else ("unseen" if m == 0 else ("hands feel bad" if m > 1.5 else "a choice"))
    lines["q4_mulligans"] = {"per_round": m, "read": v}

    # 5. pace
    a = s["avg_secs"]
    v = "unverified" if s["rounds"] < MIN_N else ("in range" if PACE[0] <= a <= PACE[1] else ("fast" if a < PACE[0] else "slow"))
    lines["q5_pace"] = {"avg_secs": a, "target": list(PACE), "read": v}

    # 6. difficulty: beginner reach vs the sim, Spoiler cleared %, whole-game wins
    reach = sum(1 for r in rs if reached_first_spoiler(r))
    obs, lo, hi, v = compare(reach, len(rs), SIM_BEGINNER_REACH)
    sp = bk.get("spoiler")
    won_runs = sum(1 for r in rs if any(int(e["act"]) >= 5 and str(e["kind"]) == "spoiler" and e["cleared"] for e in r))
    wobs, wlo, whi, wv = compare(won_runs, len(rs), SIM_STRONG_CLEARS)
    lines["q6_difficulty"] = {"runs": len(rs), "reach_first_spoiler": {"observed": obs, "ci": [lo, hi], "sim": SIM_BEGINNER_REACH, "vs_sim": v},
                              "spoiler_cleared_pct": sp and sp["cleared_pct"], "overall_cleared_pct": s["cleared_pct"],
                              "game_wins": {"observed": wobs, "ci": [wlo, whi], "sim": SIM_STRONG_CLEARS, "vs_sim": wv}}
    return {"summary": s, "questions": lines}


def fmt(r):
    s, q = r["summary"], r["questions"]
    o = [f"rounds {s['rounds']}, runs {q['q6_difficulty']['runs']}, cleared {s['cleared_pct']}%, "
         f"avg {s['avg_secs']} s, mulligans {s['mulligans_per_round']} a round", ""]
    q1 = q["q1_shortage"]
    f = lambda b: f"{b['rounds']} rounds, {b['cleared_pct']}% cleared, {b['avg_secs']} s" if b else "none"
    o.append(f"1 Puzzle or tax   Shortage {f(q1['shortage'])}; twist {f(q1['twist'])}: {q1['read']}")
    q2 = q["q2_lead_changes"]
    o.append(f"2 Lead changes    {q2['observed']:.1f}% of {q2['n']} (95% {q2['ci'][0]:.0f} to {q2['ci'][1]:.0f}) vs sim {q2['sim']}%: {q2['vs_sim']}")
    q3 = q["q3_twist_read"]
    o.append(f"3 Twist read      twist {q3['twist_secs']} s vs plain {q3['plain_secs']} s: {q3['read']}")
    q4 = q["q4_mulligans"]
    o.append(f"4 Mulligans       {q4['per_round']} a round: {q4['read']}")
    q5 = q["q5_pace"]
    o.append(f"5 Pace            {q5['avg_secs']} s a round (target {q5['target'][0]:.0f} to {q5['target'][1]:.0f}): {q5['read']}")
    q6 = q["q6_difficulty"]
    rr, gw = q6["reach_first_spoiler"], q6["game_wins"]
    o.append(f"6 Difficulty      reach the first Spoiler {rr['observed']:.1f}% (95% {rr['ci'][0]:.0f} to {rr['ci'][1]:.0f}) vs sim {rr['sim']}%: {rr['vs_sim']}")
    o.append(f"                  Spoiler cleared {q6['spoiler_cleared_pct']}%; game wins {gw['observed']:.1f}% vs strong-bot sim {gw['sim']}%: {gw['vs_sim']}")
    return "\n".join(o)


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip())
        return 2
    session = argv[argv.index("--session") + 1] if "--session" in argv else None
    r = report(load(argv[1], session))
    print(json.dumps(r, indent=1) if "--json" in argv else fmt(r))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
