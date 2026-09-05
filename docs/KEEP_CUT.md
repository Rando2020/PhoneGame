# Gameplay audit — what stays, what leaves

## First: yes, the Crib discard was always implemented — it was just invisible

The two cards you don't keep have always gone to your Crib and scored at round end.
But the UI framed it as *"keep 4 of 6"* and the pile was **never shown**, so it
read as throwing cards away. That's a presentation failure, not a missing feature.

Now:

- **A Crib pile sits on the table**, always visible, showing every card you've fed
  it and whether it will score at half or full mult (or nothing, under Miser's Curse).
- Once you've selected four, **the other two are tagged `→ CRIB`** and shaded, so
  you see the throw before you commit.
- On commit those two **fly to the Crib** with a stagger and a sound.
- At round end the Crib hand is **laid out and counted** rather than appearing as a
  single number.

It runs every round, not just boss rounds. Under Miser (hands ×0.5, Crib ×3) it
becomes the whole game.

## Card marks now have real art

Six 70×98 pixel overlays, each with a coloured frame, a corner plate with its own
emblem, and a distinct texture: Sunlit's gold glints, Brittle's diagonal shine,
Mimic's shifting dither, Offering's brushed steel lines, Minted's flecks, Fickle's
scattered stars. They read at a glance even when cards overlap in hand.

## The keep/cut audit

160 simulated runs, tracking what was offered, what was taken, and what each charm
actually contributed.

### Cut

**Knave** (nobs scores 6) — offered 823 times, held **once**, contributed 1 point
per hold across the entire dataset. Nobs requires a jack matching the cut suit; it
fires far too rarely to build around. Deleted.

**Bless a rank** — the per-rank upgrade did the same job as the Sunlit mark but
worse, and it made the shop a wall of thirteen buttons. Deleted; card marks are the
per-card axis now, and the shop is meaningfully cleaner for it.

**All four legacy modes** (rummy rogue, gin, combat gauntlet, combat sandbox) —
removed from the title screen. They were scaffolding from earlier pivots and made
the first screen ask a question it shouldn't.

### Repriced, not cut

**Every Hallowed charm was never bought.** Sovereign, Overflow, Alchemist, The
Nineteen and Doubling Cube were offered ~50 times each across 160 runs and taken
**zero** times — at 15–20 Glim they were simply unaffordable against income. Cut to
10–13. They're meant to be run-defining, not theoretical.

### The audit's own blind spot, stated plainly

Contribution is measured by re-scoring with a charm removed. That only works for
charms that touch scoring. **Rule-only charms — Recut, Half a Flush, Aces High,
Crib Master, One More Deal, Generous Deal, Foresight, Double Cut, Whittled, Change
of Heart, Greedy Crib — never appear in the data at all**, because they change
legality and resources rather than points.

They show as 0 or slightly negative, and that number means nothing. Judging them
needs a win-rate-with-versus-without test, which I have not run. **I did not cut
any of them on this evidence**, and neither should you.

One methodology note worth keeping: my first audit run showed *every* Hallowed
charm at zero because the shop AI sorted by tier and actively deprioritised
rule-breakers. That was my bias, not the design's. Fixing the AI to value quality
and price with no tier prejudice changed the picture — always worth checking
whether the measuring instrument is the thing that's broken.

### Kept, and clearly earning it

| charm | points per hold |
|---|---|
| Deep Pockets | 1,645 |
| The Counting House | 831 |
| Keystone | 634 |
| Streak | 507 |
| Fifteen Fever | 436 |
| Third Time Lucky | 384 |
| Suited | 176 |

The multiplier charms are the backbone, exactly as intended. The Worn tier
(Fifteener 56, Twinner 25, Peacock 24) sits an order of magnitude below — correct
for a starter tier, and they're cheap.

## Shop cleanup

Sections now have proper headers with a rule beneath: **YOUR CHARMS · CHARMS ON
OFFER · THE STALL · RECKONINGS**. Removing the thirteen-button Bless grid took out
the worst of the clutter.

## Balance

Ladder ×1.19 — **Pip 26% · Thump 14% · Clover 16% · Facet 12%**. Pip is running
hot after the run-mult buff two passes ago; it's the next thing to trim.

## Untested

Engine measured across hundreds of runs. **UI unclicked.** Riskiest new paths: the
crib row when it holds 12+ cards late in a round, the fly-to-crib animation when a
marked card is thrown, and the shop with all three stall cards sold.
