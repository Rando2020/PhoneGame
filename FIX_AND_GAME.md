# Read this first

Two things in this drop:

1. **Why your text renders vertically** — diagnosis and the fix.
2. **A complete playable game** — title, options, character select, a run map you
   move across, real combat, rewards, rest sites, and a boss.

---

## 1. The vertical text bug

**Cause:** a `Label` with `autowrap_mode` set to anything other than `OFF`
reports a **minimum width of roughly one character**. Any container that sizes
children to their minimum will therefore squeeze it to ~10px, and it wraps after
every letter.

That's why `MELDLINGS` and `FIRST BLOOD • Rival 1: Croak` looked fine (autowrap
off → minimum width = the full string) while `ESSENCE`, `CPU • CROAK`, `40/40`,
`DRAW PILE` and `DISCARD` all went vertical. Those are sitting in an
`HBoxContainer` (or similar) where nothing claims the spare width.

**Fix — pick whichever matches the intent:**

```gdscript
# single-line label (the common case)
label.autowrap_mode = TextServer.AUTOWRAP_OFF

# label that genuinely should wrap
label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
label.custom_minimum_size.x = 240        # so it can never collapse
```

In the inspector: **Control > Layout > Container Sizing > Horizontal → Fill,
Expand**, and **Label > Autowrap Mode → Off**.

**Same bug on your card backs.** The little hatched squares are
`card_back.png` collapsed: `TextureRect.expand_mode = EXPAND_IGNORE_SIZE` sets
minimum size to **zero**, so the texture shrinks to nothing in a container.
Always pair it with an explicit size:

```gdscript
tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
tex.custom_minimum_size = tex.texture.get_size() * 2   # required
```

**Debug tip:** run with **Debug > Visible Collision Shapes** off but
**Editor > Layout > Show Container Bounds** on, or just set
`label.modulate = Color.RED` — a control squeezed to 10px is instantly obvious.

`scripts/game/ui_kit.gd` is a factory that makes this bug structurally
impossible. Every label in the new game is built through it.

---

## 2. The game

Set **`scenes/Game.tscn`** as the main scene
(Project > Project Settings > Application > Run > Main Scene) and press F5.

Recommended project settings for a portrait phone game:

```
Display > Window > Size > Viewport Width   540
Display > Window > Size > Viewport Height  960
Display > Window > Stretch > Mode          canvas_items
Display > Window > Stretch > Aspect        expand
Display > Window > Handheld > Orientation  portrait
Rendering > Textures > Default Texture Filter   Nearest
```

(The last one is optional — every texture in the game sets NEAREST in code.)

### Flow

```
Title ──> Select Meldling ──> Map ──┬──> Battle ──> Reward ──┐
  │                                 ├──> Rest ───────────────┤
  │                                 ├──> Cache ──────────────┤
  │                                 └──> Boss ──> Run Complete
  └──> Options                                    │
                                                  └──> Essence banked
```

### Movement

`MapScreen` builds a 7-row branching map. You occupy a node; only the nodes your
current node links **forward** to are enabled, and they pulse. Tapping one tweens
your Meldling token along the path before the encounter loads. Node types:
battle ⚔, elite ☠, rest ✚, cache ◆, boss ♛.

### Combat

`scripts/game/combat.gd` is the model — no nodes, no UI, so it's testable on its
own. `BattleScreen` only renders it.

- Shared 52-card deck; reshuffles the discard when it runs dry
- **2 Focus per turn.** Playing a meld costs 1. Cycling a card costs 1.
- **BRACE** (pair) → Block · **PREP** (2-run) → draw + Focus ·
  **STRIKE** (3+ run) → damage scaling with run length ·
  **RALLY** (3+ set) → damage + Burn · **GRAND MELD** (4-suit) → big damage + Hex + Block
- Statuses: Block (halves each turn), Burn (ticks, decays), Hex (weakens your
  attacks), Thorns (reflects)
- Enemy telegraphs its intent a turn ahead, exactly like your original prototype

### Meta progression

`SaveManager` persists Essence and the capped Vitality upgrade to
`user://meldlings_save.cfg`. Vitality is capped at 10 ranks (+4 max HP each) with
a rising cost — matching the README. Relics are run-scoped and read through
`RunState.relic_value(key)`, so adding one is a single dictionary entry in
`RunState.RELICS`.

### What I did NOT touch

`Main.tscn`, `main.gd`, `rummy_rules.gd`, `cpu_player.gd`, `sound_manager.gd`.
The new game is a parallel entry point. If you'd rather keep your existing battle
code, apply the autowrap fix above to `Main.tscn` and use `combat.gd` only as a
reference — or forward `MeldRules.classify()` to `rummy_rules.gd` and delete mine.
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

---

# Creatures

Eight creatures in `assets/meldlings/`, each with three animations as horizontal
sprite strips plus a looping GIF preview.

| id | role | frames |
|---|---|---|
| `pip` `thump` `clover` `facet` | Meldlings, one per suit (S/H/C/D) | 32×32 |
| `deadwood` `shuffler` | enemies | 36×36 |
| `jokester` | elite | 36×36 |
| `kingpin` | boss | 44×44 |

Files: `<id>_idle.png` (6 frames), `<id>_attack.png` (5), `<id>_hurt.png` (4),
`<id>.gif` (idle loop, for the README).

Frames are square, so `CreatureView` infers frame size and count from the strip —
adding a creature needs no code change.

```gdscript
var hero := CreatureView.new()
add_child(hero)
hero.setup("pip")        # loops idle
hero.attack()            # plays once, auto-returns to idle
await hero.animation_finished
hero.hurt()
```

`CreatureDB` holds roster metadata (name, suit, HP, blurb) and two helpers worth
knowing: `CreatureDB.for_suit("H")` → `thump`, and `CreatureDB.music_for(id)` →
the right track for that encounter tier.

**How the animation works:** only one base sprite is authored per creature. Idle,
attack and hurt are derived from it via squash/stretch, lean and hit-flash in
`tools/make_creatures.py`. So a ninth creature costs one silhouette table
(a list of per-row half-widths) — not twelve hand-drawn frames.

The Meldlings wear their suit pip as a crest, drawn from the same 7×7 bitmaps as
the card corner indices, so the cards and creatures share a visual language.

# Audio

Everything is synthesised — no samples, no licensing.

**Music** (`assets/audio/music/`, seamless OGG loops):

- `bgm_battle.ogg` — 132 BPM, D minor, 29s
- `bgm_boss.ogg` — 148 BPM, E phrygian, 13s
- `bgm_menu.ogg` — 84 BPM, calm, 23s

Loop lengths land exactly on bar boundaries, so they're gapless.

**SFX** (`assets/audio/sfx/`, 22 mono WAVs): `ui_click` `card_select`
`card_deselect` `card_draw` `card_place` `card_invalid` `shuffle` `meld_brace`
`meld_prep` `meld_strike` `meld_rally` `meld_grand` `hit_light` `hit_heavy`
`block` `burn` `hex` `thorns` `relic` `victory` `defeat` `level_up`

Each meld action has its own signature: BRACE is a warm low triad, PREP a rising
third, STRIKE a descending stab, RALLY a four-note climb, GRAND MELD a six-note
fanfare into a chord. Players will learn what happened without reading the banner.

```gdscript
AudioDirector.instance.sfx("card_place")
AudioDirector.instance.sfx_for_action(verdict.action)   # maps STRIKE -> meld_strike
AudioDirector.instance.music("bgm_battle")              # crossfades
AudioDirector.instance.duck(-9.0, 0.15, 0.9)            # dip music under a big moment
```

Add `scripts/audio/audio_director.gd` as an autoload named `Audio`, or just add
one to your scene — `AudioDirector.instance` resolves either way. It pools 12
voices and applies slight pitch jitter so repeated taps don't machine-gun.

**On `sound_manager.gd`:** your existing runtime square-wave generator and this
can coexist. `AudioDirector` plays baked assets; if you'd rather keep everything
procedural, use these as reference targets and keep synthesising.

# Regenerating

```bash
python3 tools/make_cards.py       # 52 cards + UI frames
python3 tools/make_creatures.py   # sprite strips + GIFs
python3 tools/make_audio.py       # music + SFX   (needs numpy + ffmpeg)
```

Palettes, silhouettes, note patterns and SFX recipes are all data at the top of
each file.

---

# Animation

`CardAnimator` is a full-rect overlay that owns cards *while they are in flight*
between widgets. Add it as the **last child** of your battle root so it draws on
top of everything; `CardAnimator.instance` then resolves from anywhere.

```gdscript
var anim := CardAnimator.new()
add_child(anim)                     # last child

await anim.fly_draw(card, draw_pile.card_global_position(), hand.next_slot_global_position())
await anim.fly_discard(card, hand.slot_global_position(i), discard_pile.card_global_position())
await anim.fly_meld(cards, start_positions, focus_point, enemy_point, true)
anim.impact(hit_point, Color(1, 0.86, 0.42), 8)
```

Flights travel along a bowed arc with ease-out, optional spin, and a mid-flight
flip — so a drawn card is face-down leaving the pile and face-up landing in hand.
`fly()` takes an options dict (`time`, `lift`, `spin`, `flip_at`, `scale_from`,
`scale_to`, `fade_out`) if you want something the presets don't cover.

## What moves now

| Moment | What happens |
|---|---|
| Round start | Draw pile riffles, cards deal in one at a time, hand sorts itself |
| Draw | Pile squashes, count badge ticks, card arcs out and flips face-up mid-air |
| Select | Card lifts and gains a slow hover wobble; valid melds pop |
| Illegal tap | Card shakes horizontally and stays put |
| Sort | Cards **slide** to new positions — views keep identity, so it reads as reordering |
| Discard | Card arcs to the pile, lands with a squash-bounce and a slight random tilt |
| Play meld | Cards gather to a focus point, scale up, then strike toward the enemy and fade |
| Impact | Pip burst, screen shake, hero attack + enemy hurt animation |

## The structural change

`HandView` used to destroy and rebuild every card view on any change, which made
animation impossible. It now keeps views alive and mutates incrementally:

- `append_card(card, hidden)` adds one view without touching the others
- `remove_at(i, animate)` / `remove_selected(animate)` remove in place
- sorting reorders **card+view pairs together**, so views slide instead of popping
- selection is tracked by `CardView` reference, not index, so sorting can't scramble it
- `slot_global_position(i)` and `next_slot_global_position()` give flight targets

The `hidden` flag on `append_card` is the key to clean draws: reserve the slot,
fly a card into it, then `reveal_at(i)` once the flight lands. Otherwise you see
the card in hand and in the air at the same time.

`PileView` gained `punch()`, `receive(card)`, `tick_count(n)` and
`shuffle_flourish()`. `CardView` gained `flip_to()`, `pop()`, `appear()`,
`vanish()` and `set_hover()`.

## Tuning

Most of the feel lives in a few exported values:

- `HandView.slide_time` (0.22) — how fast cards re-flow
- `HandView.fan_tilt_deg` (0 by default, demo uses 2.0) — arc across the hand
- `HandView.lift_amount` (24) — selection lift
- `CardAnimator.arc_lift` (90) / `default_time` (0.34) — flight shape

A `_busy` flag in the demo gates input during multi-step sequences. Keep that
pattern when you wire this to real turns, or a fast tapper will desync the state.
