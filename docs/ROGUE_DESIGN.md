# Rogue mode — the Balatro-shaped Rummy loop

`meldlings.html` → **PLAY**. Old modes are still there under "Legacy".

## Structure

```
5 acts x 5 rounds = 25 rounds.  Round 5 of each act is a boss.
round = reach the target within 12 turns
turn  = draw (stock or dig) -> lay melds -> lay off -> discard
score = base (pip value) x mult, charms firing on every lay
```

No opponent turns. The enemy is a **rule**, not a player — which is the change
that removes dead time and adds run variety at the same time.

## Bosses are rule-warps

| Act | Boss | Rule |
|---|---|---|
| 1 | Deadwood | Unmelded cards cost double at round end |
| 2 | The Shuffler | Discard pile is face down — no digging |
| 3 | Jokester | Runs score half |
| 4 | The Reshuffler | Only one meld may be laid per turn |
| 5 | Kingpin | PREP melds score nothing |

Each attacks a *different* build, which is what makes them worth meeting twice.

## PREP is the load-bearing rule-break

Solitaire Rummy 500 only gave **2.4 scoring beats per round** — too quiet for
abilities to feel alive. Letting players lay **incomplete 2-card melds** at half
value, completable later:

| hand | without PREP | with PREP |
|---|---|---|
| 10 | 2.4 beats | **5.5** |
| 12 | 3.2 beats | **6.4** |
| 14 | 4.0 beats | **7.2** |

Real Rummy forbids this, which is exactly why it belongs — it's the design pillar
as a mechanic instead of a slogan. It also creates board state charms can read,
and a real risk: a PREP that never completes is exposed value.

## Charms — three layers, as you asked

- **Tier 1 · flat base** (Runner, Rallier, Prepper, Spadebound, Long Hand) — your
  old BRACE/STRIKE/RALLY vocabulary, now firing ~6× a round instead of once.
- **Tier 2 · multipliers** (Sharpener, Momentum, Keystone, Crescendo, Twin Suit,
  Fat Stack, Engine) — the escalation engine.
- **Tier 3 · rule-breakers** (Loose Meld, Excavator, Ace Zero, Long Con, Second
  Wind, Wide Hand) — build-defining.

**An exponential ladder needs multiplicative charms.** Additive mult alone cannot
climb it — the same reason Balatro needs ×mult jokers. Crescendo, Engine, Twin
Suit and Fat Stack multiply; the rest add.

## Two bugs the simulator caught

**1. Deadwood made every round unwinnable.** Subtracting a full 14-card hand
(~72 points) from a 35-point target meant a 0% clear rate at round 1. Fix:
deadwood no longer gates the round — pass/fail is gross score, and deadwood
**taxes your Essence** instead. Hoarding costs you your build, not your run.
That's a better incentive anyway.

**2. My shop AI was buying rule-breakers over multipliers**, so builds never
scaled. Fixing the preference order moved the average run from round 3.8 to 10.9.

## Measured ladder

`LADDER = { baseTarget: 30, growth: 1.14 }`, so round 25 needs ~23× round 1.

Full-run clear rates, 400 runs per deck with a competent AI:

| deck | starting rule | avg round reached | full clears |
|---|---|---|---|
| Pip | +3 digs | 11.6 | 11.3% |
| Thump | +12 base on first lay | 16.3 | 18.8% |
| Clover | +1 hand, +1 turn | 15.0 | 28.8% |
| Facet | runs ×1.55, sets ×0.8 | 11.7 | 18.8% |

A human plays worse than the AI early and better late, so expect a similar band.
Growth is the single dial: ×1.12 roughly doubles clear rates, ×1.16 halves them.

**Hand size keeps dominating.** Clover was +2 hand size and cleared 39%; cutting
it to +1 brought it to 29%. That's the third time in this project hand size has
turned out to be the strongest lever — worth remembering when you add content.

## Tuning it yourself

```bash
node web/roundsim.js    # score curve, beats per round, PREP effect
node web/roguesim.js    # full 25-round runs per deck
node web/pick.js        # sweep the growth rate
```

All balance lives in `LADDER`, `MELDLING_DECKS`, `BOSSES` and `CHARMS` at the top
of `web/roguelite.js`.

## Not yet verified

The engine is simulated hard (thousands of full runs). The **UI is untested** —
I can't click it. Most likely rough spots: the lay-off flow when a PREP completes
into a run, and the cash-out button appearing mid-turn.

## Godot port

None of this is in the Godot build yet. The engine is pure logic in one file with
no DOM dependencies, so it ports about as directly as `combat.gd` did — but I'd
settle the feel here first. That's the whole point of having the HTML.
