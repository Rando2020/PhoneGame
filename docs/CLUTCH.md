# Clutch audit — "I'd have lost without that"

## The measurement

Before building anything, I measured whether the feeling was even available.
2,148 rounds across real runs, all four decks:

| moment | frequency |
|---|---|
| **a charm, level or the cut was DECISIVE** | **26.5%** |
| target crossed on the **final deal** | 13.2% |
| the **cut** is what pushed you over | 4.0% |
| narrow win (cleared by ≤12%) | 3.0% |
| near miss (lost by ≤12%) | 1.3% |

"Decisive" means: remove that one thing and the round is a loss.

**And it ramps exactly where it should:**

| act | decisive |
|---|---|
| 1 | 16% |
| 2 | 11% |
| 3 | 29% |
| 4 | 41% |
| **5** | **56%** |

By the final act, **more than half of all rounds are won by a single identifiable
thing.** The feeling was already in the game — it was just never spoken aloud.
So this pass is about surfacing, not inventing.

## How it's computed

Exactly, not estimated. On every commit the engine re-scores the same hand with
each charm removed, with category levels removed, and **with no cut at all**:

```js
for (const ch of run.activeCharms()) {
  const without = this.runCount(hand, false, null, { skip: ch });
  res.contrib[ch.name] = res.total - without.total;
}
res.cutGain = res.total - this.runCount(hand, false, null, { noStarter: true }).total;
```

So attribution can never disagree with the maths.

## What you now see

**During the count** — a `From the cut  +14` row in its own colour, so the cut's
contribution is always visible. It's zero 31% of the time, median 4, up to 27 —
rare enough that a big one feels earned.

**The moment you cross the target**, a banner naming the cause:

- `THE CUT SAVED IT` — if your four cards alone weren't enough
- `SOVEREIGN SAVED IT` — if removing that charm would have left you short
- `ON THE LAST DEAL` — if it happened with no deals remaining

Each with a burst, a shake and the milestone sting.

**At round end**, the counterfactual spelled out:

```
        THIS WON YOU THE ROUND
              Sovereign
              +187 points
  Without it you'd have finished on 143 — you needed 214.
```

The box pulses white-gold when it was decisive, and stays a calm gold when the
charm merely contributed most.

**Margin framing.** Clearing by 3 now reads `CLEARED BY 3` in gold with a heartbeat
animation instead of a generic "ROUND CLEARED". Losing by 7 reads `7 SHORT` in
amber — near misses are the strongest retention beat there is, and they were
previously indistinguishable from being crushed.

**Run MVP** on the death and victory screens: *"Run MVP: Sovereign — 1,240 points
across the run."* Attribution accumulates across every round.

## Design note

I deliberately did **not** add a comeback mechanic (an extra life, a rescue
resource). The measurement showed the drama already exists at 26.5% and rising to
56% — inventing a save mechanic on top would have diluted it and needed a full
rebalance. Surfacing beats manufacturing.

## Bugs caught this pass

- `settle()` never received the margin fields — my patch anchor matched a stale
  version of the function, so `narrow` / `soClose` were silently `undefined`.
- A duplicated three-line block redeclared `const rmv`, which was a hard parse
  error the `node --check` gate caught before packaging.
- `CSUITS` was referenced across module boundaries and only worked because of
  bundle concatenation order.

## Untested

Engine measured over thousands of rounds. **UI still unclicked.** Riskiest new
paths: two clutch banners firing on the same hand (cut-saved *and* final deal),
and the MVP box when the only contributor is "The cut".
