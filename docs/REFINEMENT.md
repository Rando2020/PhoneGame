# Refinement pass — cards, characters, and the tension ramp

## Cards

**The club pip was the problem you spotted.** Its three lobes weren't separated, so
it read as a solid blob. Redrawn with notch rows:

```
before          after
..###..        ..###..
..###..        .#####.
#######        #.###.#   <- notches separate the lobes
#######        #######
#.###.#        ##.#.##   <- and again at the base
...#...        ...#...
..###..        ..###..
```

Spades gained a waisted shoulder, hearts a softer cleft.

**Rim lighting on every pip.** Any pixel whose upper-left neighbour is empty is
drawn in a lighter tint of the suit colour. That softens the hard edges you
mentioned without leaving the pixel grid or introducing blur — it's the standard
16-bit trick for making flat shapes read as forms.

**Court cards are now portraits, not letters.** J/Q/K get an inset framed panel
with a crown, the rank letter, and the suit pip beneath. They finally look
different in kind from the number cards.

**Aces** get a double-line lozenge in suit colour plus a rim-lit pip.

One thing I tried and abandoned: oversized 11×11 and disc-generated centre pips for
the aces. Hearts, diamonds and spades looked great, but **every large club read as a
mushroom** — three round lobes merge into a mass at that scale, and adding a stem
and flared base made it worse. A consistent, legible ace beats an ornate one, so
all four now use the proven 7×7 pip. Worth knowing if you revisit it.

## Characters

**Contact shadows** under everything — a soft elliptical shadow so creatures sit on
a surface instead of floating. The Shuffler's is deliberately faint because it
hovers.

**Specular gleam** — a two-pixel white highlight on the upper-left of each body.
Cheap, and it's what reads as volume in this era of art.

**Enemies got real silhouettes** rather than blob-plus-face:

- **Deadwood** — taller, with a crown of six jagged branches of varied length,
  bark grain, and roots at the base. Now reads as a gnarled stump.
- **The Shuffler** — its orbiting shards are now actual little cards: white with a
  dark border and a coloured pip. Previously they were noise.
- **Jokester** — gained a scalloped ruff collar under the cap.
- **Kingpin** — bigger, with a cape sweeping behind the shoulders and a gold
  sceptre. Canvas grew 44→48px to fit.

## The ramping tension bed

Exactly what you asked for, and it's my favourite addition in this pass.

A sustained bed starts when the count begins: **bandpass-filtered noise** climbing
from 240 Hz toward 7 kHz, over **two detuned sawtooths** rising from 52 Hz through a
lowpass. Volume, filter cutoff and pitch all climb together.

**How far it climbs depends on how much you're scoring**, blending banked points
against progress through the count:

| hand | ramp path | peak |
|---|---|---|
| weak (8 pts, 2 events) | 0.09 → 0.20 | **0.20** |
| average (24 pts, 4 events) | 0.14 → 0.28 → 0.42 → 0.56 | **0.56** |
| strong (62 pts, 6 events) | 0.22 → ... → 0.87 | **0.87** |
| monster (140 pts, 8 events) | 0.30 → ... → 1.00 | **1.00** |

So a weak hand barely lifts; a monster hand screams. Then at the multiplier reveal
the ramp pushes to its ceiling, and **`rampBurst()` surges it to 7 kHz and cuts it
dead** as the slam chord hits. The silence-into-impact contrast is what makes the
total actually land.

The cut ceremony now uses the same language — the drum roll rides a rising bed that
bursts on the flip, so anticipation sounds consistent across the game.

## Files

`tools/make_cards.py`, `tools/make_creatures.py` regenerate the art.
Ramp lives in `web/audio.js` (`rampStart` / `rampTo` / `rampBurst` / `rampKill`),
driven from `web/cascade.js` and the cut ceremony in `web/cribrogue_ui.js`.

## Untested

Art is verified visually. The ramp's **curve is verified numerically but never
heard** — I can't listen to it. Most likely issue is level: if it swamps the music,
lower the `0.018 + 0.085 * ease` gain in `rampTo`. If it doesn't build enough,
raise the ceiling in the same line.
