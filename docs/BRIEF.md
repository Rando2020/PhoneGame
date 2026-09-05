# BRIEF — Meldlings: Cribbage Roguelite

The self-prompt. Everything below is a constraint I'm building against, not a wish list.

## Objective

Maximise three things, in this order when they conflict:

1. **Dopamine density** — how many escalating numbers per minute
2. **Skill expression** — how much a good player outperforms a bad one
3. **Fun** — the "one more run" pull

## Why cribbage is the substrate

| | Rummy 500 | Cribbage |
|---|---|---|
| Hand size | 10–14, and it dominated every balance sweep | **fixed at 4 + starter** |
| Scoring shape | discrete lays, ~6 per round | **cascading sub-scores, 4–8 per hand** |
| Core decision | which meld to lay | **which 4 of 6 to keep** — famously deep, repeats every deal |
| Screen fit | 14-card fan on a phone | 6 cards |
| Ability surface | meld types (2 categories) | **fifteens, pairs, runs, flush, nobs (5 categories)** |

The fixed hand size is the point. It removes the lever that kept swamping
everything else, so charms become the only axis that scales.

## Core loop

```
run   = 5 acts x 5 rounds (boss on round 5)
round = reach TARGET within N deals (default 4)
deal  = draw 6 -> KEEP 4, throw 2 to the Crib -> cut a starter -> COUNT
count = cascade of cribbage scores, each x mult, ticking up on screen
round end = score the Crib as a banked payoff
```

**The crib is yours.** In real cribbage you feed your opponent's crib; here you
score it yourself at the end of the round. That turns the discard from a loss into
an investment decision — the same shape as the original, but the tension is
"immediate vs banked" instead of "mine vs theirs." It is also a rule-break in the
player's favour, which is on-theme.

## Non-negotiables

- **No opponent turns.** The enemy is a rule. Zero dead time.
- **Scoring must animate as a cascade.** Each sub-score appears in sequence with a
  running total. The count-up *is* the reward; never show only a final number.
- **Every deal must present a real choice.** 6-choose-4 is 15 options; charms must
  make different subsets correct rather than always "keep the highest count."
- **Hand size is not a balance dial.** If a charm grants extra cards it must cost
  something real, and there should be at most one such charm.
- **Skill must be legible.** After a keep decision, show what the *best* keep would
  have scored. Players learn from the delta. This is the single strongest
  skill-teaching device available and it costs almost nothing.

## Scoring must be exact cribbage

Non-negotiable, because players who know cribbage will notice instantly:

- **Fifteens** — every subset summing to 15 = 2 pts (A=1, face=10)
- **Pairs** — 2 pts per pair; trips = 6, quads = 12
- **Runs** — length pts per run, with multiplicity, maximal only
  (4-5-5-6 is two runs of three = 6, not a run of four)
- **Flush** — 4 in hand = 4, +1 if the starter matches; crib needs all five
- **Nobs** — jack in hand matching the starter's suit = 1
- Perfect hand = **29** (5♠5♥5♣J♦ + 5♦). If the engine can't produce 29, it's wrong.

## Charm space — five natural categories

| Category | Example |
|---|---|
| Fifteens | +3 per fifteen; aces count 11 toward fifteen |
| Pairs | pairs score double; trips grant mult |
| Runs | +2 per card in a run; runs may wrap K-A-2 |
| Flush | flushes ×2 mult; 3-card flushes count |
| Nobs / starter | nobs scores 5; cut two starters and keep the better |
| Crib | crib scores at full mult; crib holds 3 |
| Multipliers | ×mult per category hit; ×mult compounding per deal |
| Rule-breakers | keep 5 not 4; re-cut the starter; a card counts as any rank |

**At least a third must be multiplicative.** An exponential target ladder cannot
be climbed with additive bonuses — established the hard way in ROGUE_DESIGN.md.

## Bosses attack scoring categories

Each must invalidate a *different* build so they're worth meeting twice:
kill flushes, kill fifteens, cap runs at three, force a crib donation,
shrink the keep to three cards.

## Validation gates — build isn't done until these pass

1. Engine produces **29** for the perfect hand, and correct totals for a set of
   known reference hands.
2. Measured **scoring events per deal ≥ 4** (the dopamine gate).
3. Measured gap between a **greedy keep** and an **optimal keep** ≥ 15% of score
   (the skill gate — if optimal play barely beats naive play, there's no game).
4. Full-run clear rate lands **10–30%** for a competent AI across all decks.
5. No single stat (hand size, deals, target growth) may swing clear rate more than
   ~2× on its own.

## Deliberately out of scope for v1

Pegging (needs an opponent), multiplayer, meta-progression beyond Essence,
narrative. Get the count-up loop to feel great first.
