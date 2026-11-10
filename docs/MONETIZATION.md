# Monetization: free to try, one purchase

Decided with Ziah, 2026-10-20. Code: `godot/engine/entitlement.gd` (the one
place the game asks), the end card in `godot/ui/run_flow.gd`
(`show_free_end`), the store hook `MeldStore` (`ios_plugin/meld_store/`).
Tests: `godot/tests/entitlement_test.gd`, the soak in free mode.

## The offer

- **Free download.** Every run plays act 1 in full, through its Spoiler.
- **One purchase, "Full game"** (a non-consumable in-app purchase, product
  id `com.meldlings.full`): acts 2 to 5, every street, the trials, the Long
  Count. Once, forever, on every device with the same Apple ID (Restore).
- **Price:** set in App Store Connect, not in the game. Suggested $2.99 with
  a $0.99 launch week; it can change any time.
- **Later:** cosmetic packs (card backs, felts, Meldling skins), each with
  fixed, listed contents. No random packs.

## What's free, and why

| free | why |
|---|---|
| Act 1 of every run, including its Spoiler, on First Street | the whole loop (keep, cut, count, The Play, the shop, a Spoiler fight) in about 4 to 9 minutes a run; the free part ends on a win, the best moment to offer more |
| All four starting Meldlings (Pip, Thump, Clover, Facet) | trying different tricks is the hook; act 1 already limits how far each goes |
| Nib and Muggins, if earned by their deeds | an earned unlock should work; Nib's deed (a 29 hand) can land in act 1 |
| The Play, from the first run | the best second loop (LOOP_AUDIT.md); hiding it would hide the game |
| How to play, the Gallery (everything in it), the Record, Deeds, Settings | showing what's coming is honest and makes the unlock concrete |
| The Peddler and Pegs | every run pays Pegs (5 + 2 a round cleared); a free player can buy backs and lenses with what they earn |
| The Daily | capped at act 1 like any run |

Not free: acts 2 to 5 (and so the other streets, the trials, ascended
Meldlings and the Long Count, which open only after clearing a run).

## The rules (healthy by design)

- The end card shows **once a run, after a win** (the first Spoiler beaten).
  Never after a loss, never on the title, never as a pop-up mid-play.
- It says plainly what the purchase adds, with real counts from the data.
- **Not now** always works: the run ends as a free finish, recorded in the
  Record, and pays its Pegs.
- **Restore Purchases** is on the card (Apple requires one).
- Unlocking on the card **continues the same run** into the shop for act 2.
- **Nothing paid changes scoring.** The unlock opens more of the same game;
  `parity_test` (the port against the web) passes with the game unlocked.
- Progress made in free mode (deeds, Pegs, the Record, unlocked Meldlings)
  is kept as is after unlocking.
- No ads, no timers, no energy, no notifications asking you to buy.

## How it decides "full"

1. A saved flag ("full" in the save), set by a purchase or a restore, so the
   game stays unlocked offline.
2. With no store plugin in a development build (the editor binary that runs
   every test): unlocked, so the whole game stays testable. A shipped build
   without the plugin stays free-only.
3. Tests can force either answer.

Unverified until a Mac build: the StoreKit side (`ios_plugin/meld_store/`).
