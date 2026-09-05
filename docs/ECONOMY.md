# Economy, cycles, the Peddler and a tutorial

## Two new ways to be paid

Both of your suggestions, and they pull in opposite directions in a good way.

**Finish early.** Once you're over the target a **CASH OUT** button appears, pulsing
green. Every deal you leave unspent is **+4 Glim**.

**Finish clean.** Every mulligan you didn't use is **+3 Glim**.

Measured on a real round: grinding all four deals paid **7 Glim**; clearing on deal
one with both mulligans intact paid **25**. That's a 3.5× swing for playing well,
which turns "am I over the line?" into a live decision rather than a formality.

It also creates a genuine tension: pushing for one more deal grows your score but
costs the early bonus.

## Deck cycles

Your instinct was already half-true — cards dealt never came back within a round.
What was missing is what happens when the deck runs dry. It used to **end the
round**. Now it **recycles**:

- Everything used is gathered, reshuffled, and you continue in **Cycle 2**
- The HUD reads `18 left in cycle 2 · used cards return only when the deck runs dry`
- **Recycling costs you a deal**

That last line matters. Without it, cycling made deck-thinning pure upside — a thin
deck simply meets its best cards more often. I caught that in the sim: Facet jumped
to 28% clears the moment cycling landed. Charging a deal restored the tradeoff.

## The Peddler — a shop outside the run

**Pegs** are the profile currency. Glim is spent inside a run and dies with it;
Pegs outlive it. They're paid for **how far you get**, not for grinding:

```
pegs = floor(rounds reached / 2)
     + (cleared ? 20 + street × 10 : 0)
     + deeds earned × 5
```

So a deep failed run still pays, and clearing a high Street pays a lot. Spend them
on **six card backs** — Indigo (free), Crimson, Mosswork, Bone, The Void, Brass —
each a different pattern and palette, 25 to 80 Pegs. Equipped backs show everywhere
the deck does.

That's the frame for cosmetics generally; card faces, creature palettes and
cascade themes can all hang off the same currency.

## The tutorial

Six beats, each with a live illustration built from real cards rather than
screenshots, and a different Meldling presenting each:

1. **Six cards, keep four** — with four lit and two dimmed
2. **Then the cut decides** — four cards and a face-down fifth, bobbing
3. **The Crib is yours** — the two thrown cards, arrowed
4. **Counting** — a live cascade of Fifteen 2 / Fifteen 4 / Pair / Run
5. **Charms and Marks** — three marked cards showing Sunlit, Brittle, Minted
6. **Spoilers** — three boss sprites

Reachable any time from **How to play** on the select screen. Progress pips at the
top, Back/Next, and a Skip.

## Balance

The early-cash-out bonus is a real Glim injection, so the ladder moved twice to
absorb it. Final: growth **×1.18** — **Pip 20% · Thump 13% · Clover 17% · Facet 20%**.
Tightest spread the game has had.

**Clover took three attempts.** Buffing its flush multiplier did nothing, because
flushes are simply too rare to build around with a four-card keep — the problem was
never the reward, it was the *frequency*. It now starts with **two Mimic cards**
(wear any suit), which makes flushes reachable rather than merely valuable. 4% → 17%.

## Untested

Balance measured across hundreds of runs. **UI unclicked.** New risk paths: the
cash-out button appearing mid-deal, the cycle counter when a thin deck recycles
twice in one round, and the Peddler when you can't afford anything.
