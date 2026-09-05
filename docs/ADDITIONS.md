# Additions — deck persistence, mulligans, and passives that change how you play

## The problem you spotted

Every deal was pulling from a **fresh shuffled 52**. No deck knowledge, no
planning, no way for a deck-building passive to even exist. You were right that
it was just random.

## Fixed as two layers

**Run layer — you own a deck.** `run.cards` starts as a standard 52 and is a
persistent, modifiable object. Passives add cards, remove cards, or reshape the
whole thing. The shop shows your current deck size.

**Round layer — dealt down, no reshuffle.** Each round shuffles *your* deck once
and deals from it until the round ends. Nothing is put back. So:

- Late deals in a round have a genuinely known composition
- Cards you fed the Crib are gone from that round's supply
- **Running out of deck ends the round** — a real fail state, which is what makes
  deck-thinning a gamble instead of a free upgrade

**Deck tracker** sits above your hand: a 13-cell strip showing exactly how many of
each rank remain, greying out as ranks are exhausted. Cribbage players track this
in their heads; showing it makes the skill expressible instead of hidden.

## Mulligan

Two per round (`Second Chance` makes it four). Re-deals your six — and **the old
six go to the Crib and leave your deck for the round**. So it's never free: you
spend deck depth and you pump a pile that only scores at half mult. With
`Crib Master` (full mult) or `Miser` (×3) that downside inverts into a build.

## Nine passives that change how you play

Not stat bumps — these change the decision itself:

| Passive | What it does to your play |
|---|---|
| **Blind Cut** | The starter is **hidden** until you commit. ×1.45 mult. Turns every keep into a pure expected-value bet — the deepest version of the decision. |
| **Double Cut** | Two starters are cut; your hand counts against the **better** one. Keeps get greedier. |
| **Royal Blood** | Strips every 2–6 from your deck (52 → 32). J/Q/K score +7. A face-card deck. |
| **Peasant Stock** | Strips every J/Q/K (52 → 40). ×1.6 mult. The inverse build. |
| **Loaded Deck** | Four extra 5s (52 → 56). Fifteens everywhere. |
| **Thin Deck** | Removes 8 random cards, grants +1 deal. More deals from a thinner deck — you *will* sometimes run out. |
| **Greedy Crib** | The Crib keeps its best **5** instead of 4. |
| **Miser** | Hands score ×0.5, the Crib scores **×3**. Inverts the whole game: you play to feed the Crib. |
| **Second Chance** | +2 mulligans. |

All nine smoke-tested end to end (deck size, mulligan count, crib size, deals, and
a scored round each). `Royal Blood` at 32 cards scored 109 in a test round —
against a 52-card baseline of ~60. Concentrated decks hit much harder, and they
also flirt with running dry. That's exactly the tension you want in a build.

## Dopamine additions

**The Meldling is now on the count screen** and reacts to the slam — attack
animation on a good hand, hurt on a weak one. That was the biggest gap I flagged
last time: your chosen creature was invisible during the game's best moment.

**Score tiers.** A hand is measured against the pace you need (target ÷ deals) and
lands in a band, each with its own chord, particle count, colour and word:

```
      >0.55x  SOLID     blue,   3-note chord, 12 pips
      >1.20x  STRONG    green,  4-note,       18 pips
      >2.00x  HUGE      gold,   4-note wide,  26 pips
      >3.20x  MASSIVE   white,  5-note,       36 pips
   base >= 29  TWENTY-NINE — its own celebration
```

So an average hand and a monster hand no longer feel the same, which was the
flattest thing about the last build.

## Balance after all of it

Clear rates held: **Pip 12% · Thump 8% · Clover 15% · Facet 18%**, and the skill
gap is intact — skilled keeps reach round 17.3, naive keeps reach 2.2.

Thump drifted low (8%). Its bonus (+2 per fifteen) is the weakest now that
`Loaded Deck` and `Ace Eleven` do the same job better; worth a buff next pass.

## Still untested

The engine is simulated hard and every passive is smoke-tested. **The UI remains
unclicked.** Highest-risk new paths: the deck tracker when a rank hits zero, the
mulligan button when the deck is nearly empty, and Blind Cut's preview suppression
(it must hide the score preview *and* still let you commit).
