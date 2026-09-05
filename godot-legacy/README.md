# Stale — not the current game

This directory holds a Godot 4 prototype of an **HP-combat card battler** that was
abandoned when the design moved to Rummy and then to cribbage.

It does not implement the cribbage game in `meldlings.html`. Nothing here is
current. It's kept because:

- the card art, creature sprites and audio in `assets/` are shared
- `scripts/cards/` (CardView, HandView, PileView, CardAnimator) is a reasonable
  starting point for a Godot port, since it's UI-layer code that isn't tied to the
  old combat model

If you port the cribbage game, the files worth reading first are
`scripts/cards/card_art.gd` and `scripts/cards/card_view.gd`.
