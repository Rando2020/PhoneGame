# Balance report — measured, not guessed

The HTML build let me actually *run* the combat model. These numbers come from
roughly 100,000 simulated battles (`web/tune.js`, `web/sweep.js`,
`web/playthrough.js`). Run them yourself with `node web/sweep.js`.

## The finding that mattered

**A hand of 8 cards can produce a damage-dealing meld only 20.9% of the time.**

| hand | pair | 2-run | 3+ run | 3+ set | **any damage** | dead hand |
|---|---|---|---|---|---|---|
| 8  | 82.9% | 62.2% | 10.0% | 11.4% | **20.9%** | 3.2% |
| 10 | 92.6% | 77.2% | 20.4% | 23.0% | **40.0%** | 0.3% |
| 12 | 96.8% | 85.9% | 33.8% | 37.7% | **60.5%** | 0.0% |

Pairs are everywhere. Runs and sets — the things that actually deal damage — are
rare. So four turns in five you could only BRACE, dealing zero, while the enemy
chipped away. The old build was **unwinnable**: 0% against Kingpin over 6,000
battles, and only 20.9% against the *first* enemy.

Hand size turned out to dominate every other lever:

```
hand  edmg  ehp | deadwood  jokester  kingpin
   9  0.90  1.00 |    72%      49%       8%
  10  0.90  1.00 |    94%      87%      45%      <- shipped
  11  0.90  1.00 |    99%      99%      83%
  12  0.90  1.00 |   100%     100%      97%
```

## What changed

| | before | after |
|---|---|---|
| Hand size | 8 | **10** |
| STRIKE (n-run) | `5n + 3(n-3)` | `5n + 4(n-3)` |
| RALLY (n-set) | `4n` | `6n` |
| BRACE (pair) | `6 + n` | `8 + 2n` |
| PREP draw | 2 | **3** |
| Enemy damage | ×1.0 | **×0.9** |

Result — optimal AI, 1,200 battles each: **Deadwood 94% · Jokester 87% · Kingpin 45%**.
Full gauntlet clear rate: **41.1%**, with losses concentrated at the boss
(360 of 589 failed runs). A human plays worse than the greedy AI, so expect
lower. That's a healthy roguelite curve.

Both builds now use these numbers — `web/rules.js` (`TUNING`) and
`scripts/game/combat.gd` (`BASE_HAND`, `strike_damage()`, `rally_damage()`,
`brace_block()`, `ENEMY_DMG`).

## What I could NOT answer

**Is patience rewarded?** Still open, and I want to be straight about why.

My "patient" AI scored *worse* than greedy — but that's not evidence against
patience, because the policy doesn't model real patience. It plays weaker melds
sooner; it never actually *holds cards and passes*. A proper test needs a policy
that declines to act, and that's a harder AI to write than it sounds.

What the data does say: runs scale (`5n + 4(n-3)` → 15, 23, 31, 39 at n=3,4,5,6)
while sets are capped at four cards (24 max). So the *incentive* to build long
runs exists in the math. Whether a player feels that in play is a question for
the sandbox, not the simulator.

## Suggested next experiments

Each is a one-line change to `TUNING`, then `node web/sweep.js`:

1. **Deadwood cost.** Penalise unplayed cards at end of turn. Would make hoarding
   hurt and give the discard decision teeth — currently there's no cost to holding.
2. **Focus economy.** Try `focus: 1` and `focus: 3`. At 2 the greedy AI usually
   plays two melds a turn; at 1 the hold-versus-play tension sharpens a lot.
3. **Differentiate runs from sets further.** Runs are your scaling payoff; consider
   making sets purely utility (status, draw, block) rather than damage, so the two
   stop competing on the same axis.
4. **Boss difficulty.** Kingpin at 45% for an optimal AI may be too generous or too
   harsh depending on your target. `enemyHpScale: 1.15` drops it to 29%.
