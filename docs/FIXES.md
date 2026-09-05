# Shop layout + the build-up sound

## The card overlap — one CSS rule, breaking three screens

Your screenshot showed the stall cards stacked on top of each other, bleeding out
of their slots. The cause was a single line:

```css
.card { margin-right: -68px; }   /* meant for the fanned hand */
```

That fanning margin was on the **card**, not the hand — so it applied to every card
in the game. Anywhere cards weren't in a container that happened to override it,
they piled up.

It was silently breaking **three** places, not just the one you spotted:

1. **The Stall** — the three shop cards overlapping (visible in your screenshot)
2. **Your Crib row** — the pile you feed would have stacked into a single smear
3. **The cascade card row** — the counted hand that lights up during scoring

Fixed by moving the rule where it belongs:

```css
.card { margin: 0; }
.hand .card { margin-right: -68px; }
```

Fanning is a behaviour of a hand, not a property of a card.

**The Stall is also rebuilt as a proper grid** — three equal columns that share the
width instead of overflowing it, cards scaled 1.25 → 1.05 to fit a phone, buttons
full-width in their slot, and a hover border. It should now sit in three tidy
columns on a 390px screen.

## The build-up sound — rebuilt

You were right that it wasn't landing. The old one was **bandpass-filtered noise
sweeping 240 Hz → 7 kHz**, and filtered noise sweeping upward reads as *wind*, not
tension. It was atmosphere, not anticipation.

What actually builds is an **accelerating roll** — the drum-roll and roulette-wheel
cue. Rebuilt around three layers:

| layer | at level 0 | at level 1 |
|---|---|---|
| **roll strikes** | 5.0 / sec | **26.3 / sec** |
| **fundamental** | 62 Hz | 248 Hz (two octaves, in semitone steps) |
| **tremolo** | 4 Hz | 26 Hz |

The pitch climbs in **quantised semitones** rather than a smooth glide, so it stays
musical against the track instead of sliding through it. The tremolo accelerating
alongside the roll is what sells "something is coming".

`rampBurst()` now ends with a **stutter** — seven strikes tightening geometrically
into the impact — then cuts dead as the slam chord lands.

### Three styles, since I can't hear it

I can compute the curve but not judge the timbre, so there's a **Build-up** toggle
on the table next to the animation speed. It plays a preview when you tap it:

- **roll** *(default)* — accelerating noise strikes plus a pitched click. The
  drum-roll read.
- **riser** — same acceleration, higher fundamental, more sweep character. Closer
  to an EDM riser.
- **choir** — no strikes at all. Stacked detuned triangles with a heavy accelerating
  tremolo. Cleaner and more tonal if the roll feels busy under the music.

Pick whichever lands and tell me — I'll make it the default and delete the others.

## Also in this pass

**Nobs remains a Reckoning** even though I cut the Knave charm last pass. Worth
flagging as a likely trap purchase: nobs needs a jack matching the cut suit, so a
Reckoning in it will almost never pay. It's a candidate for removal, but I didn't
want to cut a second nobs feature without you seeing the first change land.

## Untested

The layout fix is deterministic CSS and the audio curve is verified numerically,
but **I still can't see or hear the result.** If the stall still crowds on a narrow
phone, the dial is `grid-template-columns` in `.cardmarket` — dropping to two
columns with a wrap is the fallback.
