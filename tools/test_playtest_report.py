#!/usr/bin/env python3
"""tools/playtest_report.py: same math as Playtest.summary, and honest verdicts.
  python3 tools/test_playtest_report.py"""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import playtest_report as P  # noqa: E402

S = "s1"
SYN = [  # the same six entries as pass22_test
    {"session": S, "act": 1, "round": 1, "kind": "twist:pairs4", "mix": {"fifteen": 8, "pair": 2, "run": 0, "flush": 0}, "secs": 40.0, "mulligans": 1, "cleared": True},
    {"session": S, "act": 1, "round": 2, "kind": "shortage:fifteen", "mix": {"fifteen": 2, "pair": 6, "run": 0, "flush": 0}, "secs": 60.0, "mulligans": 0, "cleared": True},
    {"session": S, "act": 1, "round": 3, "kind": "spoiler", "mix": {"fifteen": 9, "pair": 0, "run": 0, "flush": 0}, "secs": 50.0, "mulligans": 2, "cleared": True},
    {"session": S, "act": 2, "round": 1, "kind": "twist:flush3", "mix": {"fifteen": 3, "pair": 6, "run": 0, "flush": 1}, "secs": 30.0, "mulligans": 0, "cleared": True},
    {"session": S, "act": 2, "round": 2, "kind": "shortage:pair", "mix": {"fifteen": 7, "pair": 1, "run": 0, "flush": 0}, "secs": 20.0, "mulligans": 1, "cleared": False},
    {"session": S, "act": 1, "round": 1, "kind": "plain", "mix": {"fifteen": 0, "pair": 0, "run": 5, "flush": 0}, "secs": 10.0, "mulligans": 0, "cleared": False},
]


def run_of(acts_rounds, cleared=True, kind="plain", secs=60.0, mix=None):
    return [{"session": S, "act": a, "round": r, "kind": "spoiler" if r == 3 else kind,
             "mix": mix or {"fifteen": 5, "pair": 0, "run": 0, "flush": 0}, "secs": secs, "mulligans": 0, "cleared": cleared}
            for a, r in acts_rounds]


class Report(unittest.TestCase):
    def test_summary_matches_godot(self):
        s = P.summary(SYN)
        self.assertEqual((s["rounds"], s["cleared_pct"], s["avg_secs"], s["mulligans_per_round"]), (6, 66.7, 35.0, 0.67))
        self.assertEqual(s["by_kind"]["shortage"], {"rounds": 2, "cleared_pct": 50.0, "avg_secs": 40.0})
        self.assertEqual((s["transitions"], s["lead_changes_pct"]), (3, 66.7))
        self.assertEqual(P.summary([SYN[0], dict(SYN[0])])["transitions"], 0)

    def test_runs_and_reach(self):
        rs = P.runs(SYN)
        self.assertEqual([len(r) for r in rs], [5, 1])
        self.assertEqual([P.reached_first_spoiler(r) for r in rs], [True, False])
        self.assertFalse(P.reached_first_spoiler(run_of([(1, 1), (1, 2)])))

    def test_small_session_is_unverified(self):
        q = P.report(SYN)["questions"]
        for k in ("q1_shortage", "q3_twist_read", "q4_mulligans", "q5_pace"):
            self.assertEqual(q[k]["read"], "unverified", k)
        self.assertEqual(q["q2_lead_changes"]["vs_sim"], "unverified")
        self.assertEqual(q["q6_difficulty"]["reach_first_spoiler"]["vs_sim"], "unverified")

    def test_within_and_outside(self):
        # 10 runs, 5 reach the Spoiler: 50% sits around 51.1
        lst = []
        for i in range(10):
            lst += run_of([(1, 1), (1, 2), (1, 3)] if i < 5 else [(1, 1)])
        self.assertEqual(P.report(lst)["questions"]["q6_difficulty"]["reach_first_spoiler"]["vs_sim"], "within")
        # 12 runs, none reach it: 0% (95% up to ~24) is outside 51.1
        lst = []
        for i in range(12):
            lst += run_of([(1, 1)], cleared=False)
        r6 = P.report(lst)["questions"]["q6_difficulty"]["reach_first_spoiler"]
        self.assertEqual(r6["vs_sim"], "outside")
        self.assertLess(r6["ci"][1], 51.1)

    def test_wilson(self):
        lo, hi = P.wilson(5, 10)
        self.assertAlmostEqual(lo, 23.66, places=1)
        self.assertAlmostEqual(hi, 76.34, places=1)
        self.assertEqual(P.wilson(0, 0), (0.0, 100.0))

    def test_reads(self):
        # 8 Shortage rounds that clear 50% faster than 8 twist rounds at 100%: a tax
        lst = []
        for i in range(8):
            lst += [{"session": S, "act": 1, "round": 1, "kind": "twist:x", "mix": {"fifteen": 1}, "secs": 50.0, "mulligans": 0, "cleared": True},
                    {"session": S, "act": 1, "round": 2, "kind": "shortage:pair", "mix": {"pair": 1}, "secs": 30.0, "mulligans": 3, "cleared": i % 2 == 0},
                    {"session": S, "act": 1, "round": 1, "kind": "plain", "mix": {"run": 1}, "secs": 100.0, "mulligans": 0, "cleared": True}]
        q = P.report(lst)["questions"]
        self.assertEqual(q["q1_shortage"]["read"], "tax")
        self.assertEqual(q["q3_twist_read"]["read"], "not read")
        self.assertEqual(q["q4_mulligans"]["read"], "a choice")
        self.assertEqual(q["q5_pace"]["read"], "in range")
        for e in lst:
            if e["kind"].startswith("shortage"):
                e["secs"] = 90.0
        self.assertEqual(P.report(lst)["questions"]["q1_shortage"]["read"], "puzzle")
        # Shortage as fast as twists and clearing as often: neither
        for e in lst:
            if e["kind"].startswith("shortage"):
                e["secs"], e["cleared"] = 50.0, True
        self.assertEqual(P.report(lst)["questions"]["q1_shortage"]["read"], "neither")
        # twist rounds slower than plain: read; all rounds fast
        for e in lst:
            e["secs"] = 40.0 if e["kind"].startswith("twist") else 20.0
        q = P.report(lst)["questions"]
        self.assertEqual(q["q3_twist_read"]["read"], "read")
        self.assertEqual(q["q5_pace"]["read"], "fast")

    def test_cli_reads_the_log(self):
        with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as f:
            for e in SYN:
                f.write(json.dumps(e) + "\n")
            f.write("not json\n\n")
            f.write(json.dumps(dict(SYN[0], session="other")) + "\n")
        try:
            self.assertEqual(len(P.load(f.name)), 7)
            self.assertEqual(len(P.load(f.name, "s1")), 6)
            self.assertIn("2 Lead changes", P.fmt(P.report(P.load(f.name, "s1"))))
        finally:
            os.unlink(f.name)


if __name__ == "__main__":
    unittest.main(verbosity=0)
