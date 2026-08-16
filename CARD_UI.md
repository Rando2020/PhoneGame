# Meldlings — card art + card UI drop-in

Self-contained. Nothing here overwrites `main.gd`, `rummy_rules.gd`, or `Main.tscn`.

## Install

Copy into the repo, preserving paths:

```
assets/cards/          59 PNGs (52 faces, back, 3 frames, 2 pile graphics, 1 atlas)
scripts/cards/         card_art.gd, card_view.gd, hand_view.gd, pile_view.gd, meld_rules.gd, card_table_demo.gd
scenes/CardTable.tscn  runnable demo
```

Then open `scenes/CardTable.tscn` and press **F6**. No autoloads, no project settings changes.

Controls: tap to select, tap again to deselect, double-tap to discard, drag a card
onto the discard pile, tap the draw pile to draw, **R** to redeal, **Esc** to clear.

## The art

Base resolution is **70×98 px** (5:7). Everything renders at `PIXEL_SCALE = 2`
→ 140×196 on screen, which fits a 10-card hand in your 720×1280 portrait viewport
with overlap. Change `CardView.PIXEL_SCALE` to 3 for a chunkier look.

All `TextureRect`s set `TEXTURE_FILTER_NEAREST` in code, so the pixels stay crisp
without touching **Project → Rendering → Textures → Default Texture Filter**.

Naming is `card_<RANK><SUIT>.png` — `card_AS.png`, `card_10H.png`, `card_KD.png`.
Suits are `S H C D`. `card_atlas.png` is the same 52 cards as a 13×4 grid
(cols A→K, rows S/H/C/D) if you'd rather use `AtlasTexture` and one draw call.

Regenerate or recolour everything by editing the palette constants at the top of
the generator and re-running it — `BONE`, `RED`, `BLK`, `INDIGO`, `GOLD`.

## Card data format

A card is a plain dictionary:

```gdscript
{"rank": 7, "suit": "H"}   # rank 1 = Ace ... 11 = J, 12 = Q, 13 = K
```

`CardArt.suit_letter()` also accepts an int index (0=S, 1=H, 2=C, 3=D), so if
your existing code uses ints it will work unchanged.

**If your card representation differs**, that's the only adapter you need — write
two functions converting your card to/from this dictionary and everything else
drops in as-is.

## The three widgets

```gdscript
var hand := HandView.new()
hand.selection_changed.connect(_on_selection)   # (cards: Array, verdict: Dictionary)
hand.card_activated.connect(_on_double_tap)     # (index: int)
hand.set_cards(my_hand)

var draw := PileView.new()
draw.mode = PileView.Mode.DRAW
draw.draw_requested.connect(_on_draw)
draw.set_count(deck.size())

var pile := PileView.new()
pile.mode = PileView.Mode.DISCARD
pile.card_dropped.connect(_on_dropped)          # (card: Dictionary, source: CardView)
pile.set_top_card(discard.back())
```

`verdict` is `{kind, valid, label, action}` — e.g. `{valid: true, label: "3-RUN", action: "STRIKE"}`.

## Playability features (the point of all this)

| Feature | Where |
|---|---|
| Illegal cards dim as you build a meld | `HandView._apply_states()` → `MeldRules.can_join()` |
| Illegal taps shake instead of silently failing | `CardView.flash_reject()` |
| Live "3-RUN → STRIKE" readout | `selection_changed` verdict |
| Sort by rank / by suit, selection preserved | `sort_by_rank()`, `sort_by_suit()` |
| One-tap "show me a play" | `autoselect_best_meld()` |
| Drag-to-discard **and** double-tap-to-discard | `CardView._get_drag_data`, `card_activated` |
| Hand auto-compresses so 15+ cards still fit | `HandView._layout()` |

The dimming is the big one. It's what lets someone who doesn't know Rummy learn
the meld rules by touch instead of by reading a tutorial.

## Wiring into your real game

`MeldRules` is deliberately standalone so the demo runs without `rummy_rules.gd`.
Once you're integrating, make your existing file the single authority:

```gdscript
# in meld_rules.gd
static func classify(cards: Array) -> Dictionary:
	return RummyRules.classify(cards)   # forward to your implementation
```

Keep `can_join()` here either way — it's UI logic, not rules logic, and it's what
drives the hints.

Ace handling: runs are ace-low by default. Set `MeldRules.ace_high_runs = true`
if Q-K-A should count in your ruleset.
