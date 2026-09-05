# Meldlings

**A cribbage roguelite.** Keep four of six, then the cut decides.

Open `meldlings.html` in any browser. One file, no server, no install, works
offline on a phone.

```
Count it. Cut it. Break it.
```

---

## The game

You're dealt six cards and keep four. The two you throw go to your **Crib**, which
holds exactly four and scores for you at the end of the round. **Only then** is a
starter card cut — so every keep is a bet on what's still live in the deck, not a
lookup.

Score is `base × mult`, counted aloud the way cribbage always has been:
*fifteen two, fifteen four, and a pair is six.* Charms multiply it, Marks sit on
individual cards, and Reckonings raise a whole scoring category forever.

- **5 Acts × 5 Rounds.** Every fifth round is a **Spoiler** that breaks a rule.
- **17 Spoilers**, drawn per run, each aligned to a suit — cards of that suit score
  weakly against it, the opposing suit scores strongly.
- **43 Charms** across four qualities: Worn, Keen, Gleaming, Hallowed. Five slots.
- **6 Marks** on cards: Sunlit, Brittle, Mimic, Offering, Minted, Fickle.
- **6 Meldlings**, two unlockable.
- **5 Streets** of difficulty, each unlocked by clearing the last.

## Repository layout

```
meldlings.html      the built game — this is the deliverable
web/                source: engine, UI, audio, and the test harnesses
assets/             pixel art (cards, marks, creatures, icons, backs) + audio
tools/              Python generators; re-run to regenerate any asset
docs/               design notes and audit reports, newest last
godot-legacy/       STALE — an abandoned combat prototype, kept for reference only
```

### Source files that matter

| file | what it is |
|---|---|
| `web/cribbage.js` | exact cribbage scoring + expected-value search |
| `web/cribrogue.js` | run, round, charms, Marks, Spoilers, economy |
| `web/meta.js` | achievements, Streets, Pegs, Lenses, run history |
| `web/cribrogue_ui.js` | the play screen, shop, Peddler |
| `web/cascade.js` | the scoring cascade |
| `web/audio.js` | the whole 16-bit synth — no audio files anywhere |
| `web/tutorial.js` | six-beat tutorial |

## Building

```bash
python3 tools/build_web.py      # bundles web/ + assets/ into meldlings.html
```

Everything is inlined as base64, which is why the game is a single file.

## Testing

```bash
node web/runtest.js     # drives every screen against a DOM shim — run this first
node web/cribtest.js    # scoring correctness, dopamine density, skill gap
node web/cribsim.js     # full 25-round runs per Meldling
node web/pick2.js       # sweep the difficulty ladder
node web/uiaudit.js     # vertical layout budget on a 390x844 phone
```

`runtest.js` is the important one. It loads the built bundle and plays through the
whole game headlessly; it catches the reference errors that simulation can't.

## Regenerating art and audio

```bash
python3 tools/make_cards.py      # 52 cards, marks, frames, atlas
python3 tools/make_creatures.py  # Meldlings + Spoilers, 3 animations each
python3 tools/make_marks.py      # card mark overlays
python3 tools/make_backs.py      # card back skins
python3 tools/make_icons.py      # scoring category icons
python3 tools/make_items.py      # charm quality plaques
```

Palettes and silhouettes are data at the top of each script.

## Balance

All dials live at the top of `web/cribrogue.js`: `CRIB_LADDER`, `CHARM_SLOTS`,
`CRIB_SIZE`, `BOSS_POOL`, `CRIB_DECKS`, `CCHARMS`.

Current: ladder ×1.18, clear rates **14 / 14 / 23 / 23%** across the four starting
Meldlings on First Street.

After changing anything, re-sweep:

```bash
GS=1.18 N=50 node web/pick2.js
```

## Status

The web build is playable and tested. `godot-legacy/` is **not** the current game —
it's an HP-combat prototype from before the design settled on cribbage, kept only
because its asset pipeline is shared. A Godot port of the cribbage game has not been
written yet.
