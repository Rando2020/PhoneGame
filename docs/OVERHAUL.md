# Final push — audit and overhaul

## The audit finding that mattered

**I had built cribbage backwards, and it was quietly destroying the skill layer.**

The starter was cut *before* the keep, and the preview showed the exact resulting
score. So the optimal strategy was: tap through all 15 combinations, take the
highest. No judgement required.

Measured, 2,500 deals:

| play | points/hand |
|---|---|
| naive (keep highest cards) | 5.28 |
| **EV keep — starter unknown** | **8.27** ← the real cribbage skill |
| hindsight — starter known | 9.02 ← what the UI was handing you free |

The +57% skill gap I reported two versions ago was **unavailable**: the game was
answering its own question, and better than a skilled player could.

## The fix — cut after the keep

Real cribbage order: dealt six, commit four, *then* cut. Now implemented.

- The preview shows **LOCKED IN** (points guaranteed by your four cards) and
  **EXPECTED AFTER CUT** (EV against your actual remaining deck). Two numbers that
  frequently disagree — which is the entire decision.
- Because EV is computed against **the round's remaining stock**, tracking the deck
  genuinely sharpens the estimate. The tracker finally has teeth.
- Coaching changed from hindsight to decision quality: *"Keep ranked 4 of 15 by
  expected value (best expected 9.2)"*. That teaches the right lesson.
- **Blind Cut is now Foresight** — a legendary that cuts *before* you keep. What was
  a drawback became the most powerful information charm in the game.

**And it created the anticipation beat the design was missing.** Committing your
keep runs a cut ceremony: a rising drum roll, the card spinning face-down, then a
flip-reveal with a slam, shake and particle burst. Every deal now has a moment
where you don't yet know.

The reorder made the game genuinely harder (you lost ~8% scoring per hand), so the
ladder came down from ×1.225 to **×1.205**.

## Bosses — a pool, not a script

Before: 5 bosses, one fixed per act. **Every run fought the same five in the same
order.** That was the biggest replayability hole.

Now **14 bosses in severity bands**, one drawn per act, no repeats:

| Sev | Bosses |
|---|---|
| 1 | Ashfall (no flushes) · The Auditor (fifteens score 1) · Shortstop (runs capped at 3) · Blight (pairs halved) · Chains (no mulligans or recuts) |
| 2 | Iron Grip (keep one fewer) · Famine (one fewer deal) · The Thief (10 cards stolen) · Miser's Curse (Crib scores nothing) · The Fog (deck tracker hidden) |
| 3 | Leaden (mult capped at ×4) · Puritan (pairs score nothing) · Drought (fewer deals, no mulligans) · Eclipse (fifteens 1, no flush, no nobs) |

Acts 1–2 draw severity 1, act 3–4 severity 2, act 5 severity 3. Each attacks a
different build — Ashfall ruins Clover, The Auditor ruins Thump, Shortstop ruins
Pip, Miser's Curse ruins crib builds.

All 14 verified playable end to end. Their bite varies as intended: Iron Grip held
a test round to 30 points where Chains allowed 95.

**The whole boss plan is shown on every round intro**, so you can build toward what
is coming instead of being ambushed — Balatro shows you the boss blind a round
ahead for exactly this reason.

Boss presentation scales with severity: colour, glow, a bobbing sprite, a low
sawtooth sting with a kick and screen shake, and a pulsing frame at severity 3.

## Balance after the overhaul

Growth ×1.205 — clears **Pip 22% · Thump 18% · Clover 28% · Facet 25%**.
Skill still dominates: EV keeps reach round 17.0, naive keeps reach 3.5.

## Audit items I did NOT fix, and why

**Round decision count is still thin.** Four keeps plus two mulligans per round,
against Balatro's four hands plus three discards. The reorder made each keep much
*deeper* (a real EV judgement rather than a lookup), which I judged better value
than adding a fifth shallow decision. Still the most obvious place to add next.

**A run sees only ~25-30% of the charm pool.** 34 charms, 5 slots, ~8-10 bought per
run. That's arguably correct for replayability, but it means many charms are rarely
seen — worth watching once you have played enough runs to have favourites.

## Files

Engine: `web/cribbage.js` (scoring + EV), `web/cribrogue.js` (run/round/charms/bosses).
UI: `web/cribrogue_ui.js`, `web/cascade.js`, `web/audio.js`.
Harness: `node web/audit.js`, `cribtest.js`, `cribsim.js`, `pick2.js`.

Balance dials live at the top of `cribrogue.js`: `CRIB_LADDER`, `CHARM_SLOTS`,
`BOSS_POOL`, `ACT_SEVERITY`, `CRIB_DECKS`, `CCHARMS`.

## Untested

The engine is hammered — every boss, every passive, thousands of simulated runs.
**The UI has still never been clicked.** Highest-risk new paths: the cut ceremony
when Foresight is owned (it must skip the ceremony entirely), Iron Grip's keep-3
interacting with Facet's keep-5, and the boss plan chips on the first round intro.
