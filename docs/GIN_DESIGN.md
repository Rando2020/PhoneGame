# Gin mode — the pivot, measured

`meldlings.html` → **GIN MODE · real Rummy**.

Real Rummy turn structure: draw from stock **or** discard, arrange, discard, and
knock when your deadwood is low enough. Gin, undercut, and layoff all implemented.

## Why this is the right move

**It solves the deadwood problem for free.** I've been recommending a hoarding
cost since our first conversation. You don't bolt it on — in Rummy, deadwood *is*
your score penalty. Holding a King costs you 10 points if the opponent knocks first.

**It makes your shared deck matter.** Taking the top discard is information: the
CPU now knows what you're collecting. That two-way leak is the best decision in
Rummy and the thing no Balatro-alike has.

**It makes "break Rummy" a real progression axis.** Rule-breaking relics now have
something to break — `Loose Knock` (knock at 15 instead of 10), `Purist` (gin
bonus 25→40), `Counterpunch` (undercut bonus 25→40). Compare that to a fifth
status effect.

## The deadwood optimiser

Finding the best meld arrangement is the hard part, and naive versions get it
wrong. Given `5♥ 6♥ 7♥ 8♥ 5♠ 5♣`:

- greedy takes the four-run `5♥6♥7♥8♥` → leaves `5♠5♣` = **10 deadwood**
- correct answer is the set `5♥5♠5♣` + run `6♥7♥8♥` = **0 deadwood**

`bestArrangement()` searches all disjoint meld combinations, memoised on a
used-card bitmask. Exact, and instant at 10–11 cards.

## Measured pacing — read this before setting the target

4,000 simulated hands, both sides playing a competent policy:

| | |
|---|---|
| avg points per hand | 14.1 (median 9, max 93) |
| avg actions per hand | 16.1 |
| gin | 8.0% |
| undercut | 4.3% |
| wash (stock out) | 0.7% |

Hands needed to reach a target:

| target | hands | rough actions |
|---|---|---|
| 25 | 3.0 | ~48 |
| 50 | 5.9 | ~95 |
| 75 | 8.9 | ~143 |
| **100** | **11.9** | **~190** |

**So a flat "first to 100" is too slow for every encounter.** Twelve hands against
a basic enemy is a slog, and seven of those per run is a multi-hour session.

Shipped instead — target scales with tier:

```
Deadwood / Shuffler   25   (~3 hands)
Jokester (elite)      50   (~6 hands)
Kingpin (boss)       100   (~12 hands)
```

That keeps 100 as the real Gin match it should be, but reserves it for the fight
that deserves the length. Change it in `TARGETS` in `web/gin_ui.js`.

## The teaching device

The hand auto-groups into melds, dims the deadwood cards, and shows a **live
deadwood total** that turns gold the moment you can legally knock. That does for
Rummy scoring what the dimming hints did for meld legality — you learn the rule
by watching the number move, not by reading it.

## Open design decisions — your call

**1. Does the HP/combat layer survive?** My recommendation: **no.** Score becomes
the health bar. Running "first to 100" *and* HP/Block/Burn/Hex is two win
conditions competing for the player's attention. Points to target is cleaner,
it is true Rummy, and abilities have a better job modifying legality and scoring.

The cost is real, though: a combat turn gives feedback every action, while a Gin
hand has one scoring moment at the end. That's worse for short-video clips. If
you want the drama back, lean on **undercuts** — currently only 4.3% of hands,
and by far the most exciting outcome. Abilities that bait or punish knocks would
raise that number and make the moment the game's signature.

**2. Where do creature abilities attach?** Suggested hooks, all cheap to add:
- knock threshold (Loose Knock, shipped)
- gin / undercut bonuses (shipped)
- draw the *second* card down in the discard, not just the top
- see one CPU card
- one card counts as any rank (a wild)
- aces count 0 deadwood instead of 1
- lay off onto the CPU's melds even when they went gin

The last three are the real "break Rummy" moves and would define builds.

**3. Should the CPU knock more aggressively?** Right now it knocks at ≤6 deadwood
or gin. Loosening that makes hands shorter and undercuts more common — worth
sweeping once you've played a few.

## Still unverified

The Gin *engine* is tested (4,000 simulated hands, optimiser spot-checked against
known-hard cases). The Gin *UI* is not — I can't click it. Expect rough edges in
the discard browser and the knock flow specifically.
