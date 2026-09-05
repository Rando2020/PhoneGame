# Completeness audit

Run it yourself: `python3 tools/audit_complete.py`

## Systems: 36/36 present in the build

Every system built across the whole project, verified by symbol in the shipped
`meldlings.html`:

| | |
|---|---|
| exact cribbage scoring · expected-value keep search · keep-then-cut ordering | core |
| tiered cut reveal · cut quality ranking · counterfactual MVP | the reveal |
| 43 charms · charm ordering · additive-mult charms · 6 marks · split cards + scoring | build |
| the Crib (4 cards) · crib multiplier · deck cycling · surplus + skips · early cash-out | round |
| 17 spoilers · suit affinity · wagers · system unlocks | opposition |
| 17 achievements · 5 streets · pegs + peddler · 6 card backs · lenses · run history | meta |
| tutorial · gallery · music proximity · crib voice · 4 ramp styles · speed control | shell |
| tooltips · deed notifications · collapsible table drawer | UI |

## Assets: all accounted for

- **64 images embedded** in the build
- **52 individual card faces are deliberately not embedded** — they're replaced by
  `card_atlas.png`, which is embedded. Shipping both would double the card payload.
- **5 remaining** (`frame_valid`, `frame_invalid`, `frame_selected`, `pile_draw`,
  `pile_empty`) are Godot-only UI pieces, unused by the web build
- `assets/audio/` (OGG + WAV) is **Godot-only**. The web game synthesises everything
  in `web/audio.js`, which is why the file has no audio payload at all

## Source: 18/18 files, 9/9 generators

Generators: `build_web`, `make_cards`, `make_creatures`, `make_audio`, `make_icons`,
`make_items`, `make_marks`, `make_backs`, `make_split`.

Test harnesses: `runtest` (drives every screen), `galtest` (all six gallery tabs),
`cribtest`, `cribsim`, `pick2`, `uiaudit`, `keep_cut`, `clutch`, `dopamine_audit`,
`audit_complete`.

## The Gallery

New screen, reachable from the select screen. Six tabs:

- **Cards** — all 52 faces, by suit
- **Split** — eight sample split cards, plus how the scoring resolves
- **Marks** — each of the six on a live card, with its rule
- **Backs** — all six, showing owned/locked, tap an owned one to equip
- **Meldlings** — all six, locked ones hidden behind `???`
- **Spoilers** — all 17, grouped by severity, with suit alignment

It's a collection screen, but it's also the fastest way to confirm an asset is
present and rendering without hunting through a run. All six tabs verified rendering
headlessly.
