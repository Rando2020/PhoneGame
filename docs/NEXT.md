# This pass — fixes, the Crib rule, and the typing layer

## Fixed from your screenshot

**Cards overflowed the count screen.** The row was `flex-wrap: nowrap` at a fixed
1.45 scale, so five or six cards ran off both edges. It now wraps *and* scales to
the hand size — 1.3 for four cards, 1.15 for five, 1.0 for six (Facet keeps five,
so six with the cut).

## The Crib is now a real crib — and you were right that it's better

Your instinct was correct, so I went further than you asked: **the Crib holds
exactly four cards, filled by your earliest throws.** Once it's full, later
discards are **burned** and shown as such.

That changes the round shape completely:

- Your **first two keeps decide what the Crib will be worth** — you're choosing
  what to invest, not just what to dump
- Later keeps become pure hand optimisation, because the throw is free
- Feeding the Crib well and keeping well are now *different skills* in the same round

It's also the authentic cribbage crib size, which matters because Offering and
Miser's Curse both key off it. Capping the Crib removed a scoring source, so the
ladder eased to ×1.175 — clear rates came back to **13 / 13 / 9 / 11%**, the
tightest spread we've had.

## Tooltips that work on a phone

`title` attributes do nothing on touch. There's now a real tooltip: tap or hover
any named effect and it explains itself, positioned to stay on screen and dismissed
by tapping anywhere. Wired to **charms, marks in The Stall, Spoilers in the run
plan, and Reckonings**.

## Deed notifications, Steam-style

Moved from a centre-screen block to a **bottom-right slide-in** with a star badge,
"DEED UNLOCKED" kicker, name and description — and they **queue**, so earning three
at once plays them in sequence rather than stacking. Three-note ascending sting.

## The typing layer — built, without a separate mode

You asked whether there's a world where this isn't just cribbage-with-jokers, with
Pokémon-style attack/defend giving suits meaning.

There is, and I think it's better *inside* the main game than beside it:

**Every Spoiler is now aligned to a suit.** Cards of that suit score **weakly**
against it; cards of the opposing suit score **strongly** (♠↔♥, ♣↔♦). The effect
scales with how much of your counted hand is that suit.

That does the work Pokémon typing does:

- **Your Meldling's suit finally matters** — Clover ♣ is strong into ♦-aligned
  Spoilers and soft into ♣-aligned ones
- **The run plan is shown at Act 1**, so you can see the typing you'll face and
  build toward it
- **The Stall becomes strategic** — buying off-suit cards is now a counter-play
- Zero new screens, no combat turns, no dead time

I'd rather push this further than build a separate battle mode. A proper
attack/defend layer needs an opponent taking turns, which is the exact thing we cut
to make the game feel fast.

### If you do want the fuller version, here's the shape I'd build

An **alternate mode**, not a replacement: *Meldling Duel*. Both sides hold a
Meldling with HP. Each round you count a hand; your score becomes damage, and the
suit affinity between your Meldling and theirs multiplies it. They counter with
their own count. Charms become abilities with cooldowns.

The honest cost: it reintroduces opponent turns, which is what made the earlier
combat prototype feel slow — measured at 16 actions per hand with dead time between.
Worth prototyping only once the core mode is genuinely fun.

## Characters refreshed

Each Meldling now has its own face rather than a palette swap: **eye shapes**
(round, sharp, sleepy), **lashes** on Thump, **head tufts** on Pip and Clover,
**belly patches** for a front-and-back read, and a second lower catchlight in every
eye. Pip in particular reads as a character now rather than a coloured egg.

## Dopamine audit — what to double down on next

**Sound**
1. **Shop audio is undifferentiated** — buy, pawn and reroll are near-identical. The
   economy should have its own palette: a coin *chink* for buying, a dull *clack*
   for pawning, a riffle for rerolling.
2. **The Crib has no sound identity.** It's a second scoring event and it currently
   uses the same cascade ticks. It should sound *lower and rounder* — a payoff, not
   a count.
3. **Music never reacts.** The track is the same at 10% of target and at 99%. A
   filter opening as you approach the target would carry enormous tension for very
   little work.

**Visual**
4. **14 Spoilers share 4 sprites.** Severity recolouring plus a simple silhouette
   accessory would triple the apparent roster.
5. **No damage/impact language for Spoilers.** When one blocks points you get a red
   row; the Spoiler itself never reacts.
6. **The deck tracker is inert.** Cards leaving should tick down visibly.

**Gameplay**
7. **No tutorial.** Keep-then-cut, the Crib, and expected value are all taught by
   inference. This is now the single biggest barrier for a new player.
8. **No run history.** Deeds persist but you can't see your last ten runs.
9. **Nobs is still a Reckoning** and is still a trap purchase.
10. **Pip has been the outlier three passes running.** Currently level at 13%, but
    watch it.

## Untested

Balance measured. **UI unclicked, audio unheard.** New risk paths: tooltip position
near screen edges, the deed queue when three fire on one hand, and the burned-card
tag when the Crib fills mid-deal.
