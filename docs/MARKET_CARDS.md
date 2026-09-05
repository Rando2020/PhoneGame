# The card market & per-card enhancements

Both of your calls, built — and the per-card version is a much better axis than
the per-rank gilding I had.

## Enhancements — cards themselves are now the build

Six, each cribbage-native rather than a Balatro copy:

| | effect | why it fits cribbage |
|---|---|---|
| **Gilded** ★ | +6 base whenever counted | the flat-chips analogue |
| **Glass** ◇ | ×1.4 mult, **25% chance to shatter** | permanent loss from your deck — real risk |
| **Chameleon** ≈ | counts as any suit for flushes | flush is the only suit-dependent score |
| **Steel** ▪ | +0.6 mult **if it lands in the Crib** | rewards throwing it away — a cribbage inversion |
| **Coin** $ | +3 Essence each time counted | funds the economy from play |
| **Lucky** ☘ | 1-in-4 chance of +25 base | variable reward inside a single count |

Enhanced cards render with a coloured glow and a corner badge, so you can spot
them in hand instantly.

**Steel is the one I'd point at.** Every other enhancement wants the card in your
hand; Steel wants you to throw it in the Crib. That makes the keep decision harder
in a way that only works in a game with a crib.

## The market — weighted so fives stay scarce

You were right that fives had to be rare. In cribbage a 5 makes fifteen with every
ten-value card, so an unweighted market would solve the game.

Measured over 8,000 offers:

| rank | appears | avg cost |
|---|---|---|
| **5** | **1.7%** | **16.2** |
| 10 / K | 4.8% | 10.6 |
| A / 4 | 11% | 7.4 |
| 7 | 8.3% | 7.5 |

A five costs more than twice a low card and shows up six times less often. About
55% of offers carry an enhancement, priced on top.

## What this broke, and the fix

Adding the market took clear rates to **0% across all four decks.** Not a bug — an
economy failure, and an instructive one.

The market became a **fourth** sink competing with charms, category levels and
gilding. Tracing a run showed the AI reaching round 16 with 21 levels, five charms,
and **zero gilding** — it never had spare Essence. Meanwhile:

> **level costs scale linearly (4 + 3·lv) while targets scale exponentially (×1.19)**

At round 15 a level cost 64 Essence against ~12 income. Scaling simply stopped.

Three changes:

1. **Income now scales with round depth** — `6 + round×0.9 + overshoot`, because
   late rounds must fund late upgrades.
2. **Level cost growth softened** to `4 + 2.2·lv`.
3. **Buy priority fixed** so levels are funded before discretionary card buys.

## Deck rebalance

The market interacts with deck identity in a way I didn't predict: **Facet's
thinner deck means you draw your purchased cards more often**, so it jumped to 27%
while the rest sat near 7%. Its trim went 12 → 17 cards to price that in.

Clover then became the low outlier — a pure flush identity is the narrowest in the
set — so its flushes now give ×1.9 mult *and* +6 base.

Final: **Pip 13% · Thump 7% · Clover 15% · Facet 13%**, ladder ×1.19 (down from
×1.205, since the fourth sink slows scaling).

## Files

`ENHANCEMENTS`, `CARD_WEIGHT`, `RANK_PREMIUM`, `rollCardOffer` at the top of
`web/cribrogue.js`. Wild-suit handling lives in `countHand` in `web/cribbage.js`.
Re-sweep with `GS=1.19 N=60 node web/pick2.js` after any change.

## Untested

Engine measured across hundreds of runs. **UI unclicked.** Riskiest new paths:
the market when all three cards are bought, a Glass card shattering out of a deck
that is already near-empty, and Chameleon interacting with Ashfall's dead suit.
