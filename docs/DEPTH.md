# Charm order, Surplus, and Wagers

Built from your post-playtest notes. Three of the five; the rest are queued.

## Charm ordering — and a correction

I told you order already mattered mathematically. **I was wrong, and the test caught
it.** Six arrangements of the same three charms all scored 49:

```
[Fifteener > Keystone > Counting House]   49
[Keystone > Counting House > Fifteener]   49
...spread: 0
```

The reason: base and mult accumulated in separate buckets and multiplied once at the
end, so order was irrelevant. The cascade *displayed* a chain that the maths didn't
actually have.

Order only matters when charms that **add** to mult mix with charms that
**multiply** it — and every cribbage mult charm multiplied. So I added a family of
additive ones: **Ballast** (+1.2 mult), **Tallyman** (+0.5 per category),
**Slow Burn** (+0.4 per Reckoning), **Groundwork** (+0.35 per scoring event),
**Bloodline** (+2 if one colour).

Now:

```
best  [Ballast > Tallyman > Keystone]  = 175
worst                                  = 134
ordering is worth 41 points — 31%
```

Ballast before Keystone is `(1 + 1.2) × 1.6`. After, it's `1 × 1.6 + 1.2`. That's
the whole puzzle, and it's the same one Balatro's joker row poses.

**In the shop**: a CHARM ORDER panel. Tap a charm, tap where it goes. A
**Test arrangement** button plays a sample hand through every permutation and tells
you whether a better order exists, without telling you which — the search is yours.

Your Meldling's own knack always resolves first and can't be moved.

## Surplus — overshoot finally means something

You said you were clearing 200 and hitting 600. That overshoot was pure waste, and
it's why the mid-game went on autopilot.

Overshoot now converts: `surplus = 100 × overshoot / target`. Beat a target by 2×
and that's **100 Surplus — one banked Skip.** The HUD shows the bar filling.

A Skip takes a non-Spoiler round off the board entirely: you collect Glim, go
straight to the Peg House, and move on. **Spoilers can never be skipped.**

This is the run-length fix, and it's self-balancing. A weak run plays all 25 rounds.
A strong one compresses to 15–18 and reaches the hard Acts faster. You shorten the
game by being good at it rather than by me trimming content — and every "easy" round
now has a live question: cash out, or push for the Skip?

## Wagers — your lucky boss, and how the game grows

A **Wager** appears on 1–2 random non-Spoiler rounds per run. It's optional — you
can walk away — and the terms are stark:

> **SCORE IT EXACTLY.** Finish on exactly 330. Not one point more.

The target is 55% of normal, so hitting it is easy; hitting it *precisely* inverts
every instinct the game has trained. Miss and the run ends.

**It pays in a system unlock, not Glim.** These are permanent and change what the
game *is*:

| unlock | what changes |
|---|---|
| **The Crib's Own Cut** | your Crib gets its own cut card at round end, with its own reveal |
| **The Gathering** | the Crib builds a multiplier as you feed it — matching suits and courts raise it |
| **Split Cards** | the Stall starts selling cards that are two ranks at once |
| **The Sixth Slot** | one more charm slot, forever |
| **The Deep Stall** | four cards on offer instead of three |

The first two are the Crib answer you were reaching for. Once you own both, the
Crib stops being a bin: you're feeding a second hand that has its own cut, its own
multiplier, and its own moment. Suddenly throwing two hearts away isn't a loss.

A system unlock takes over the screen — it deserves more than a toast.

## Balance

The additive charms landed badly on first try — Facet cleared **66%** because
per-event charms scale with its 7-dealt/5-kept hand. Groundwork alone was giving
+2.1 mult for 6 Glim.

Retuned across the board (Groundwork +0.35 → +0.14, Slow Burn +0.4 → +0.12,
Ballast +1.2 → +0.8), Facet's deck cost raised to 22 cards, ladder to ×1.20.

Final: **Pip 13% · Thump 13% · Clover 11% · Facet 24%**.

## Still queued

- **Oddities** — the half-card. Split Cards is the unlock that opens the door; the
  card type itself isn't built.
- **Objective-breaking Spoilers** — The Ascetic (only the Crib counts), The Motley
  (every kept card a different suit).
- The Crib cut ceremony reuses the standard reveal; it should have its own voice.

## Split cards — 4 files, 2704 combinations

The naive build is 52×52 pre-rendered faces. Instead the card is **composed at
runtime** from four shared images:

| file | size | what it is |
|---|---|---|
| `split_frame.png` | 494 b | one 70×98 frame: two-tone halves, stepped gold divider |
| `glyphs.png` | 503 b | 13 ranks × 2 colours, corner size |
| `glyphs_big.png` | 653 b | the same 13 at 2×, for the centre |
| `suitpips.png` | 247 b | 4 suits × 2 colours |

**Under 2 KB total**, and any of 2,704 rank/suit pairs renders by positioning
background-position on shared strips. Adding a rank or suit later costs one strip
regeneration, not a combinatorial rebuild.

The divider is a *stepped* diagonal — two pixels of x for every three of y — so the
edge stays chunky instead of anti-aliasing into mush like a CSS clip-path would.

Each card shows its two ranks small in opposite corners and large either side of the
divider, so it reads at a glance in a hand.

### Scoring

Rather than special-casing every rule, a hand containing splits is **expanded into
each combination and the best kept**:

```
hand: [2/3] 4 5 10 + cut 6
  scores 8  ->  Fifteen 2, Fifteen 4, Run of 4
  with a plain 2: 7        with a plain 3: 8
```

The 2/3 takes whichever rank pays more, per hand. With a cap of 64 variants that's
a handful of counts, not a blow-up — and it means splits interact correctly with
every charm, Mark and Spoiler without any of them knowing splits exist.

They appear in The Stall at 22% once **Split Cards** is won from a Wager, priced
about 7 Glim above a plain card.
