# Dopamine & clarity audit — findings and fixes

`node web/dopamine_audit.js` runs this as a repeatable check.

## Before → after

| Pattern | Reference | Before | After |
|---|---|---|---|
| Goal visible at all times | Balatro pins the blind requirement | play screen only | **PASS** |
| Items visible while they trigger | Balatro's joker row wiggles in turn | charms hidden during the count | **PASS** |
| Distance-to-goal / required pace | Balatro lets you compute if you'll make it | a bar, no numbers | **PASS** |
| Penalties visible as they apply | Slay the Spire's intent + debuff icons | one small line; never saw it fire | **PASS** |
| Cross-run progress hook | Balatro / Spire unlocks | nothing persisted | **PASS** |
| Goal + items persist across screens | Balatro never leaves the play field | 7 screens, context lost | **PASS** |
| Reward events per round | ~4 scored hands per blind | 5 | PASS |
| Characters distinct in silhouette | any roster game | one egg shape, colour only | **PASS** |

## The points bar you asked for

There's now a **pinned HUD** on both the table and the count screen:

```
ACT 3-2                    [ The Auditor ]              DEAL 2
187 / 214
████████████████████░░░░
NEED 27          2 deals left          14 / deal
Fifteens score 1 instead of 2
```

Three things that weren't there before: the **big score/target numbers**, the
**distance to go**, and the **required pace per remaining deal** — which turns red
when the pace becomes implausible. That last line is the tension. It's what lets
you decide whether to gamble a keep or play safe, and it's the thing Balatro gets
right that we were missing entirely.

**And the bar now fills during the slam.** Previously the payoff happened on a
screen where the goal wasn't visible, so the biggest moment in the game was
disconnected from the thing it mattered for. The score counts up and the bar sweeps
toward the target together.

## Items now sit where they act

The charm row is pinned to the count screen, and **each contributing charm flashes
in sequence** just before the multiplier lands, with a rising blip per charm. You
see *what earned it*, not just a list afterwards.

## Negative effects are now impossible to miss

Two changes:

1. A **boss chip** in the HUD plus the rule text, always on screen during a boss
   round — with the ash suit named when Ashfall is active.
2. When a boss actually eats points, the cascade shows a **red struck row**:
   `The Auditor blocked  −14`, with a fail sound and a small shake. Computed by
   diffing the real count against a clean one, so it can never disagree with the
   maths.

## Two bosses weren't bosses

Measured how often each rule actually changes a hand:

| boss | before | after |
|---|---|---|
| Ashfall | **10%** | 24% |
| Shortstop | **7%** | 79% |
| The Auditor | 81% | 78% |
| Blight | 69% | 58% |
| Eclipse | — | 83% |

Flushes and long runs are simply rare with a four-card keep, so bosses attacking
them were nearly invisible. Rewritten:

- **Ashfall** — one random suit turns to ash and those cards go **inert**: they
  can't form fifteens, pairs, runs, flushes or nobs. Announced in the HUD.
- **Shortstop** — runs score nothing *and* pairs score half.

The resource bosses (Chains, Iron Grip, Famine, The Thief, Drought, Fog, Leaden,
Miser's Curse) show 0% "hand reduced" because they attack deals, keeps, mulligans,
deck size and multiplier ceilings instead. That's correct, not a gap.

## Character redesign

The four Meldlings shared one egg silhouette — colour was the only cue. Now
genuinely different shapes, measurable from their silhouette tables:

| | shape | height / max width |
|---|---|---|
| **Pip ♠** | tall narrow sliver | 22 / 8 |
| **Thump ♥** | wide squat boulder | 12 / 15 |
| **Clover ♣** | pear, heavy base, leaf ears | 19 / 13 |
| **Facet ♦** | angular crystal, straight tapers | 20 / 13 |

Recognisable at a glance, in thumbnail, and in silhouette.

## Session hook

Runs, best round reached, clears and best single hand now persist between sessions
and show on the title and select screens: *"Runs 12 · Best Act 3-4 · Cleared 0 ·
Best hand 96"*. A near miss now leaves a number behind, which is the whole point.

## One bug this pass caught

`CSUITS` was referenced in `cribrogue.js` but defined in `cribbage.js`. It worked in
the bundle purely because of concatenation order, and broke the moment the module was
loaded on its own. Replaced with a local literal.

## Balance after the changes

Growth ×1.205 — clears **Pip 18% · Thump 8% · Clover 23% · Facet 13%**.

Thump has drifted low twice now. Its +0.2 mult per fifteen is the least
boss-resistant identity in the set — The Auditor and Eclipse both halve fifteens,
so two of fourteen bosses directly gut it. Worth either buffing the deck or giving
it a fifteens-immunity clause.

## Remaining known gaps

- **Scoring still happens on a separate screen.** The HUD and charms are pinned
  there now, so context is preserved, but the true Balatro answer is to score in
  place over the table. That's a layout refactor, not a patch.
- **Round decision count is still 4 keeps + 2 mulligans.**
- **A run sees ~25–30% of the charm pool.**
