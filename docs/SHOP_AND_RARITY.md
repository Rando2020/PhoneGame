# Shop, rarity, UI pass

## The shop bug

`showCribShop()` called `run.shopOffer(3)` on every render — so **buying one item
re-randomised the other two**, and selling a charm rerolled the whole shelf. The
offer is now stored on `run.shopState` and only changes when you reroll or leave.

## Rarity

| Rarity | Odds | Look |
|---|---|---|
| Common | 50% | steel border |
| Uncommon | 30% | green border |
| Rare | 15% | gold border + glow |
| Legendary | 5% | violet border + **pulsing glow**, gradient shop row, milestone sting on purchase |

Measured over 20,000 rolls: 49.9 / 30.9 / 14.2 / 5.0 — rarity is rolled *first*,
then a charm is picked within that band, so legendaries stay at 5% no matter how
many of them exist. 34 charms total: 6 common, 7 uncommon, 14 rare, 7 legendary.

Each charm now carries a **pixel rarity plaque** (22×22) with a category glyph
inset — fifteens, pairs, runs, flush, nobs, ×mult, rule, deck. New assets from
`tools/make_items.py`.

## Five legendaries

| Charm | Effect |
|---|---|
| **Sovereign** | ×1.3 mult **per** J/Q/K in the counted hand — multiplicative, so a face-heavy hand explodes |
| **Overflow** | Your multiplier is **squared** |
| **Doubling Cube** | Your final deal of each round scores ×3 |
| **The Nineteen** | A hand scoring nothing scores **45** instead (19 is the score cribbage can't make) |
| **Alchemist** | Every 2, 3 and 4 in your deck **becomes a 5** |

## Shop rebuilt

- Persistent offer (the bug above)
- **Reroll** at 3 Essence, +2 each time
- Rarity gem, name, rarity tag, description, price per row
- Sell via a **×** on the charm chip itself, not a wall of buttons
- Empty charm slots render as dashed placeholders, so the 5-slot cap is always visible
- Category levels are now a 5-cell icon grid with current → next, not cramped buttons
- Legendary purchases get 30 particles and the milestone sting; commons get 12

## Deck passives, made properly impactful

Each deck now dictates a playstyle from the first deal, with a real cost:

| Deck | Upside | Cost |
|---|---|---|
| **Pip ♠** | Runs +9 base **and ×1.7 mult** | Pairs score **half** |
| **Thump ♥** | Each fifteen adds **+0.2 mult** — stack them | none (lowest ceiling) |
| **Clover ♣** | 3-card flushes count, flushes **×1.7 mult** | none (narrow) |
| **Facet ♦** | Dealt **7**, keep **5** — far more combinations | Deck starts **12 cards lighter** |

Pip actively pushes you away from pairs. Facet's bigger hands come with a real
chance of running the deck dry. That's the shape Balatro decks have.

**Tuning notes, since these took three passes:** Thump at +0.35 mult per fifteen
cleared 63% — fifteens are simply too common for a per-fifteen mult to be that
large. And Facet's first cost was −1 deal, which cleared 1% — losing 25% of your
scoring opportunities is far harsher than it reads, because multipliers compound
per deal. A thinner deck turned out to be the right price.

Final: **Pip 19% · Thump 13% · Clover 13% · Facet 22%**, ladder growth ×1.225.
Skill gap intact — skilled keeps reach round 19.5, naive keeps reach 3.8.

## UI and animation fixes

- **Screen transitions** — every screen fades and rises on entry
- **Button press** scales down, so taps feel confirmed
- **Toasts** for sales and events instead of silent state changes
- **Selection counter** ("2 / 4 kept — select 2 more") replaces a bare hint line
- **Zero-score hands** now show an explicit "No score" row with a fail sound; before,
  the cascade slid silently into the slam. That was the bug I flagged last time.
- Legendary charms pulse continuously in the charm row

## Still untested

Engine simulated hard; **UI unclicked**. Riskiest new paths: the sell **×** inside
a chip (nested click handling), reroll when Essence is exactly the cost, and the
shop when all three offers have been bought.
