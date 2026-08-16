# Meldlings: First Blood Design

## North Star

**Learn Rummy. Master Rummy. Break Rummy. Make your own rules.**

Meldlings is a portrait-first creature card roguelite. Both the player and CPU use the same shared deck and Rummy-derived card relationships. Complete melds create offense. Incomplete melds create survival and setup.

## Combat Vocabulary

- **Pair → BRACE:** defensive Meldling abilities.
- **2-card same-suit sequence → PREP:** setup and utility.
- **3+ same-suit sequence → STRIKE:** focused single-suit offense.
- **3+ same-rank cards → RALLY:** multi-suit offense.
- **4 cards of one rank across all suits → GRAND MELD:** jackpot activation.
- Future: **LINK** for co-op, **ASCEND** for evolution, **FUSE** for suit-pair fusions.

## Starter Suit Identities

- Hearts: pressure, Burn, cleanse and recovery.
- Diamonds: economy, card manipulation and scaling.
- Clubs: Block, Thorns, growth and healing.
- Spades: Hex, discard manipulation and disruption.

## First Blood Success Criterion

The prototype succeeds when the player has a real hesitation between spending a pair on BRACE now or holding it to chase a stronger RALLY next turn.

## Progression Layers

1. **Encounter:** HP, Block, statuses, opponent reading.
2. **Run:** relics and future Meldling level-up choices.
3. **Account:** Essence, restrained stat growth, new Meldlings, relics, evolutions and Fusions.

Permanent numeric power should stay bounded so mastery remains valuable. Ranked multiplayer should eventually normalize permanent stat bonuses.

## Planned Roster

Three base Meldlings per suit, each planned for three post-base evolution stages. The prototype implements one starter per suit and keeps the rest data-driven.

## Co-op Direction

Co-op should use Rummy-native cooperation rather than two independent combat turns. Planned signature mechanic: **LINK MELD**, allowing partners to combine partial patterns for a shared payoff. Helpful discards and protection build Bond.

## Multiplayer Principle

CPU opponents use the same card legality and combat resolution model as players. This is intentional groundwork for eventual deterministic PvP and co-op synchronization.
