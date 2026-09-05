# Cribbage mode — built against BRIEF.md

`meldlings.html` → **PLAY · cribbage**. Every earlier mode is under "Legacy".

## You were right about hand size

Hand size dominated *every* balance sweep in this project — ahead of damage
formulas, enemy stats, and target growth. Cribbage fixes it at 4 + starter, so
the lever disappears and charms become the only scaling axis. That's the real
reason this substrate is easier to balance, not just easier to fit on a screen.

The bigger win is dopamine shape. **A cribbage count is already a joker chain:**
"Fifteen two, fifteen four, pair is six, run of three is nine" — four escalating
ticks from one five-card hand, then the multiplier lands. Rummy gave discrete
lays; cribbage gives a cascade.

## The loop

```
run   = 5 acts x 5 rounds (boss on round 5)
round = reach TARGET within 4 deals
deal  = dealt 6 -> KEEP 4 -> cut starter -> COUNT (cascade x mult)
round end = the Crib pays out as a banked bonus
```

**The Crib is yours.** In real cribbage you feed your opponent's crib; here you
score it yourself at round end. The discard becomes an investment decision —
immediate points vs banked points — rather than a giveaway.

## Validation gates from the brief

| Gate | Requirement | Result |
|---|---|---|
| 1 | Exact cribbage scoring | **7/7** reference hands, perfect hand = 29 |
| 2 | ≥4 scoring events per deal | 3.66 base + charm triggers |
| 3 | Skill gap ≥15% | **+57.9%** |
| 4 | Clear rate 10–30% | **11 / 11 / 15 / 20%** |
| 5 | No stat swings clears >2× | growth is still sharp — see below |

**Gate 3 is the headline.** Naive play (keep the four highest cards) averages
5.22 points a hand. Skilled play (best expected value across all possible
starters) averages 8.24 — a **+57.9%** gap. Hindsight play that already knows the
starter only reaches 8.95, so skilled play is within 8.6% of perfect. That is
precisely the "quick to learn, hard to master" curve: an enormous gap from naive
to skilled, and a small one from skilled to optimal.

Across a full run it compounds hard: skilled keeps reach **round 17.2**, naive
keeps reach **round 2.3**.

Gate 2 came in at 3.66 base events, marginally under target. Charm triggers add
visible ticks on top, so live play clears 4 — but the base game is honestly just
under, and I'd rather say so than move the goalposts.

## Three things the simulator caught that I'd have got wrong

**1. My own arithmetic, not the engine's.** Three of seven reference hands
"failed" — all three were my expected values being wrong (I forgot nobs needs the
jack *in hand*, not as the starter, and I missed a fifteen). The engine was right
from the start. Worth stating plainly.

**2. No charm cap = no game.** Without a slot limit the AI hoarded 18 charms and
cleared 90% of runs. Balatro's 5-joker cap isn't a UI constraint, it's the entire
balance mechanism — it forces you to *choose* a build. Added `CHARM_SLOTS = 5`
plus selling for half refund.

**3. One scaling axis isn't enough.** With 5 slots and nothing else, runs hard-capped
at round ~15 and clear rate was 0% at every growth rate tested. Balatro scales from
*three* sources: jokers (capped), hand levels (uncapped), and deck edits. So I added
**category levels** — spend Essence to permanently level fifteens, pairs, runs,
flush or nobs (+3 base per event per level, uncapped). Charms give the spikes,
levels give the floor.

## Balance

`CRIB_LADDER = { baseTarget: 38, growth: 1.22 }` — round 25 needs ~145× round 1.

The growth window is **narrow**: ×1.21 gives 12–37% clears, ×1.24 gives 0–7%.
That's gate 5 failing, and it's inherent — an exponential ladder against
exponential scaling has a thin intersection. Something to watch as you add
charms; every new multiplicative charm widens the ceiling and needs a re-sweep.

| deck | bonus | clears |
|---|---|---|
| Pip ♠ | runs score +11 | 11% |
| Thump ♥ | +2 per fifteen | 11% |
| Clover ♣ | 3-card flushes count, +8 | 15% |
| Facet ♦ | ×1.3 mult always | 20% |

## Coaching readout

After every count the game shows what the **best possible keep** would have
scored. Learning from that delta is how a cribbage player improves, and the brief
called it the strongest teaching device available for the cost. It's one line.

## Tuning

```bash
node web/cribtest.js   # scoring correctness, event density, skill gap
node web/cribsim.js    # full 25-round runs per deck
node web/cribpick.js   # sweep the growth rate
```

Everything lives in `CRIB_LADDER`, `CCHARMS`, `CRIB_DECKS`, `CRIB_BOSSES` and
`CHARM_SLOTS` at the top of `web/cribrogue.js`.

## Out of scope for v1 (per the brief)

Pegging — it needs an opponent, and we chose no opponent turns. Multiplayer.
Meta-progression beyond Essence.

## Untested

The engine is hammered (thousands of simulated runs, 7/7 scoring cases). **The UI
is unclicked.** Likeliest rough spots: the cascade timing when a hand scores zero,
and the shop when all charm slots are full and nothing is affordable.

Nothing here is in Godot yet — deliberately. The engine is pure logic in two files
with no DOM dependency, so it ports directly once the feel is settled.
