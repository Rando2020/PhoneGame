# The bug, and the UI audit

## The console error — found by actually running the game

I built a DOM shim and executed the real bundle in node (`web/domtest.js`,
`web/runtest.js`). It drives every screen: title, select, tutorial, deeds, peddler,
starting a run, dealing, selecting a keep, committing, the cut, the cascade, the
shop, round end, and a mulligan.

First run found it immediately:

```
FAIL  commit + cut + cascade
        ReferenceError: quality is not defined
```

When I added the tiered cut reveal last pass, the patch that computes `quality`
landed in a branch that never ran, but the call site referencing it did. So **every
single cut threw** — the game was broken from the first deal, exactly as you saw.

Fixed, and all 14 steps now pass. **This harness is the thing I should have built
ten versions ago.** It runs in about a second and would have caught several of the
bugs we found by screenshot. Run it with `node web/runtest.js` after any change.

## The UI audit

I measured the rendered tree against a 390×844 phone:

```
before:  1462px of content  ->  2.09 screens
after:    644px             ->  0.92 screens
```

You were right that the screen carries too much that isn't needed *upfront*.

### What stays on screen

The HUD (score, target, bar, NEED / deals left / per-deal pace, Spoiler rule), your
hand, the keep preview with **locked in** and **expected after cut**, and the primary
actions. That's the decision, and nothing else.

### What collapsed

The Crib pile, the deck tracker, and the charm row now live behind a single
**TABLE** strip that always shows the state in one line:

```
TABLE  ·  deck 34  ·  crib 2/4  ·  cycle 1              show ▼
```

Tap it and everything opens, including the animation-speed and build-up toggles
that were cluttering the bottom. Nothing is lost; it's one tap away and the summary
line means you rarely need it.

## Lenses — your idea, built

You suggested making display options something you buy. That's exactly what they
should be, because it turns UI density into a player choice rather than my guess.

**Lenses** are bought from the Peddler with **Pegs**, and each one **pins a panel
open permanently**:

| Lens | Pegs | |
|---|---|---|
| **Counter's Lens** | 30 | pins the deck tracker — every rank still live |
| **Crib Glass** | 30 | pins your Crib, so you always see what you've fed it |
| **The Ledger** | 35 | pins your charms during play |
| **Odds Glass** | 45 | how many live cards would improve each keep |

Owned Lenses toggle **ON/OFF** so you can tune the screen per run. A new player gets
a clean, single-screen game; a veteran builds the cockpit they want.

The design point worth keeping: **nothing is paywalled.** Everything a Lens shows is
free in the Table drawer. A Lens buys *convenience*, not information — which is the
only version of this that's fair.

## Untested

The runtime harness proves every screen renders without throwing, and the layout
budget is computed. **The actual look on a real phone is still unverified** — the
estimate treats the hand as 200px and panels as their content, so a real device may
differ. If it still scrolls, the next thing to collapse is the keep preview's event
list, which only matters when you're learning to count.
