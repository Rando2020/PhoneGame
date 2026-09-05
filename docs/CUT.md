# The cut reveal — tiered by how lucky you actually were

Your idea, and it turned out to be exactly computable. At the moment you commit, I
know your four kept cards **and every card still in the deck** — so I can score the
hand against *all* of them and rank the card you actually got.

That's not a guess or a heuristic. `cutQuality()` evaluates the full remaining
stock and returns your rank, the percentile, and what the cut actually added.

## Five tiers

| tier | frequency | avg gain | roll length | what happens |
|---|---|---|---|---|
| **cold** | 39% | 0 | 520ms | dull thud, sour minor 2nd, no particles |
| **okay** | 39% | 4.8 | 780ms | neutral fifth, small shine, 8 pips |
| **good** | 16% | 10.4 | 1080ms | major triad + kick, green glow, 18 pips |
| **great** | 5% | 19.3 | 1460ms | four-note rise + sparkle, gold glow, **double shine sweep**, 30 pips |
| **perfect** | 0.4% | 22+ | **2000ms** | seven-note fanfare, **triple shine**, pulsing card, 52 pips, music ducks, second burst |

## The trick is the roll length

A better card **rolls longer before it lands**. Cold resolves in half a second;
perfect makes you wait two full seconds.

That inverts the usual relationship between waiting and reward — the wait *becomes*
the reward, because you learn that a long roll means good news. By the third or
fourth round you'll catch yourself hoping when the drum keeps going. That's the
same mechanism a slot machine's slow-stopping reel uses, except here it's honest:
the length is derived from a real ranking, not theatre.

During the roll the card physically shakes harder as the wait stretches, and the
build-up ramp climbs toward a tier-specific ceiling — cold only reaches 35%,
perfect goes to 100%.

## One thing I had to fix

"Perfect" originally meant *the single best card left*, full stop. But on a weak
hand the best available card might only add 5 points — so you'd get the full
seven-note fanfare for almost nothing, which reads as the game lying to you.

Perfect now requires being the best card **and** gaining at least 6. Otherwise it
demotes to great. The celebration is always earned.

## What it tells you afterwards

Under the card: `+14 from the cut · 3 of 41 possible`. So even a cold cut teaches
you something — you see how close you came, and over time you start to feel which
keeps leave you the most live cards. That's the expected-value skill made visible.

## Untested

Frequencies and payoffs measured over 600 deals. **The reveal itself is unclicked
and unheard** — the shine sweep, the escalating shake and the fanfare timing are all
computed but not seen. If perfect feels too long at 2 seconds, `CUT_TIERS.perfect.roll`
is the single dial.
