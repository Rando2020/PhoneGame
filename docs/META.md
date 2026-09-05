# Audio mix, achievements, unlockables

## The ramp was drowning the count — fixed by mixing, not by volume

You were right and the numbers were damning. The build-up and the ticks were both
going to the same bus, and the roll was firing 26 times a second.

Three changes, the way a mix engineer would do it rather than just turning a knob:

1. **The build-up has its own bus** at 0.30 gain. It can never compete on level.
2. **Sidechain ducking** — every tick dips the ramp to 30% for 90ms, then releases.
   That's the trick that lets a quiet element win: you *hear* the count punch a
   hole in the noise.
3. **The roll calmed down** — peak rate 26/sec → 16/sec, strike gain roughly halved.

| | before | after |
|---|---|---|
| tick body | 0.11 | **0.16** |
| ramp bed at max | 0.054 | **0.016** |
| roll strike at max | 0.085 | **0.011** |
| **tick above ramp** | ~1.3× | **~10×** |

The slam now ducks the ramp to **silence** for half a second as it lands.

## The tick itself — built like a 16-bit point pickup

It was one square wave. Now it's four layers:

- **transient** — 12ms noise click at 5.2kHz, so it has an edge
- **body** — square with a fast upward pitch blip (0.72×f → f), detuned
- **sparkle** — octave up, 60ms, quiet
- **weight** — triangle a fifth below, so it isn't thin

Pitch still climbs a pentatonic ladder per tick, so a long count plays an ascending
arpeggio — but now each note has an attack, a body and a tail instead of a beep.

## Deeds — 17 achievements

Named from cribbage, not from a checklist. A few worth calling out:

- **Twenty-Nine** — count the perfect hand (secret). Unlocks a Meldling.
- **Nineteen** — count a hand worth *nothing*. The score cribbage cannot make.
- **His Heels** — cut a Jack.
- **Down to the Cut** — win a round your four cards couldn't have won.
- **Sharp Eye** — make the best possible keep five times in one run.
- **Skunked** — clear a round at triple the target.
- **Brittle Heart** — break three marked cards in one run.

They announce themselves the moment they're earned with a toast, a burst and the
milestone sting, and there's a **DEEDS** screen off the select. Secrets show as
`???` until earned.

## Streets — five difficulty tiers

Named for the rows of a cribbage board. Each unlocks by clearing the one before.

| | effect | measured clear rate |
|---|---|---|
| **First Street** | the road as it comes | 6–23% |
| Second Street | targets +25% | — |
| **Third Street** | +25%, **Spoilers also hold Round 3** | 3–9% |
| Fourth Street | +35%, one fewer charm slot | — |
| **The Stink Hole** | +50%, one fewer slot, deck starts 8 lighter | 0–3% |

That last tier is deliberately near-impossible for the AI. It should be the thing
you're still chasing months in.

## Two unlockable Meldlings

- **Nib** ♠ — a thin blade of a creature. *+2 recuts a round, and whatever the cut
  adds, it adds twice.* Earned with **Twenty-Nine**.
- **Muggins** ♣ — low, wide, lopsided. *When a Spoiler blocks points, take half of
  them anyway.* Earned with **The Long Road**.

Muggins is the one I'm pleased with: it's named for the cribbage rule where you
claim points your opponent overlooked, and it's the only anti-Spoiler identity in
the game. It makes the hardest Streets — which stack Spoilers — its best home.

## What I'd flag next, unprompted

**1. Pip is overtuned.** 23% on First Street against Clover's 6%. Its ×2.0 run mult
has been too strong for two passes now.

**2. Nobs is still a Reckoning.** I cut the Knave charm for being worthless; the
nobs Reckoning is the same trap and should probably go, leaving four.

**3. There's no tutorial.** The keep-then-cut decision, the Crib, and expected value
are all taught by inference. The coaching line helps after the fact, but a first-time
player gets no explanation of *why* a keep was poor.

**4. No run history.** Deeds and best-round persist, but you can't see your last ten
runs or which Meldling you do best with. Cheap to add and it feeds the compulsion.

**5. The Spoilers have no art variety** — 14 bosses share 4 sprites. Recolouring by
severity would cost little and make them feel distinct.

**6. Sound for the shop is thin.** Buying, pawning and rerolling all use near-identical
stings. The economy deserves its own audio identity.

## Untested

Balance measured across Streets. **UI unclicked, audio unheard.** The mix ratios are
computed, not listened to — if the ticks now feel *too* dominant, the single dial is
`rampGain.gain.value` (0.30) in `web/audio.js`.
