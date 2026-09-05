# Design notes

Written as the game was built, oldest first. They record *why* decisions were made
and — more usefully — which ideas were measured and thrown away.

## Read these

| doc | what's in it |
|---|---|
| `BRIEF.md` | the design brief the cribbage game was built against, with validation gates |
| `CRIBBAGE.md` | why cribbage beat Rummy: hand size stopped dominating every balance sweep |
| `CUT.md` | the tiered cut reveal — how "good for you" is computed exactly |
| `CLUTCH.md` | counterfactual attribution: 28% of rounds are won by one identifiable thing |
| `MARKET_AUDIT.md` | benchmarked against Balatro and current market data |
| `KEEP_CUT.md` | what got cut and why, with the measurement behind each removal |
| `UIFIX.md` | the layout audit: 2.09 screens down to 0.92 |
| `NAMING.md` | moving off borrowed vocabulary into cribbage's own |

## Superseded

`FIX_AND_GAME.md`, `INTEGRATION.md`, `ASSETS.md` and `GIN_DESIGN.md` describe the
Godot combat prototype and the Gin Rummy build — both abandoned. `ROGUE_DESIGN.md`
covers the Rummy 500 roguelite that cribbage replaced. Kept for the reasoning, not
as instructions.

## The recurring lesson

Three separate times, an underperforming archetype was "fixed" by raising its
reward, and three times that failed. Clover's flushes didn't need a bigger
multiplier; they needed to *happen more often* (two Mimic cards). When something
underperforms, check frequency before payoff.
