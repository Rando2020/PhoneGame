# Naming pass — our own vocabulary

You were right that we'd drifted into borrowed language. **Glass** and **Steel**
are Balatro's enhancement names verbatim, and Common/Uncommon/Rare/Legendary is
generic RPG loot.

Cribbage has a genuinely strange, lovely vocabulary that nobody is using —
nobs, nibs, muggins, the crib, the cut, streets, pegs, skunks. That plus the
Meldling creature world is a register no other game occupies.

Display names only. Every internal key is unchanged, so no behaviour moved.

## Marks — what a card bears

| was | now | |
|---|---|---|
| Gilded | **Sunlit** ☀ | +6 base whenever counted |
| Glass | **Brittle** ✧ | ×1.4 mult, 1-in-4 it breaks for good |
| Chameleon | **Mimic** ≈ | wears any suit it likes, for flushes |
| Steel | **Offering** † | +0.6 mult, but only if you give it to the Crib |
| Coin | **Minted** ◈ | +3 Glim each time counted |
| Lucky | **Fickle** ? | 1-in-4 for +25 base. Otherwise nothing |

**Offering** is the one that earns its name — you're sacrificing the card to the
Crib, and the mechanic only exists because cribbage has a crib. That's the flare:
the name and the rule come from the same place.

## Charm quality — craftsmanship, not loot tiers

| was | now | odds |
|---|---|---|
| Common | **Worn** | 50% |
| Uncommon | **Keen** | 30% |
| Rare | **Gleaming** | 15% |
| Legendary | **Hallowed** | 5% |

Worn → Keen → Gleaming → Hallowed reads as a charm being cared for and passed
down, which fits creatures who wear their suit as a crest.

## The rest of the register

| system | was | now |
|---|---|---|
| Currency | Essence | **Glim** — the glints Meldlings collect |
| Shop | The Sanctum | **The Peg House** |
| Card stall | The Market | **The Stall** |
| Category levels | Category Levels | **Reckonings** — you study a count, forever |
| Rank enhancement | Gild a rank | **Bless a rank** (so it stops colliding with Sunlit) |
| Bosses | Boss / Boss Rule | **Spoilers** — "THE SPOILER DECREES" |
| Boss severity | Threat / Severe / Deadly | **A Spoiler / A Grim Spoiler / A Ruinous Spoiler** |
| Selling charms | Sell | **Pawn** |
| Tagline | "Learn Rummy. Master Rummy. Break Rummy." | **"Count it. Cut it. Break it."** |

A few charms got a pass too, for rhythm rather than to fix anything borrowed:
Deep Purse → **Deep Pockets**, Wrap Around → **Round the Bend**, Short Flush →
**Half a Flush**, Ace Eleven → **Aces High**, Loaded Deck → **Cooked Deck**,
Thin Deck → **Whittled**, Second Chance → **Change of Heart**, Fifth Deal →
**One More Deal**.

The boss names were already ours and stay: Ashfall, The Auditor, Shortstop,
Blight, Chains, Iron Grip, Famine, The Thief, Miser's Curse, The Fog, Leaden,
Puritan, Drought, Eclipse.

## Where the flare actually lives

Naming alone isn't identity. The things that make this *not* a Balatro reskin are
structural, and they're already in:

- **The cut.** You commit four cards and then fate decides. Balatro has no
  equivalent moment — it's pure cribbage, and it's our best beat.
- **The Crib.** A second scoring pile you feed from your own hand, which makes the
  discard an investment rather than a loss. Offering and Miser's Curse both exist
  only because of it.
- **The counting cascade.** "Fifteen two, fifteen four, and a pair is six" is a
  real thing people say out loud at a table. Our scoring animation is a 400-year-old
  ritual, not an invented one.

## Verified

All effects fire correctly under the new names — internal keys untouched, spot
checked (Sunlit +6 base, Brittle ×1.40, Minted +3 Glim). No leftover
Gilded/Glass/Steel/Chameleon/Common/Uncommon/Legendary strings in the cribbage path.

The legacy Rummy mode still says "The Sanctum" — deliberately left alone, since it
isn't the game any more.
