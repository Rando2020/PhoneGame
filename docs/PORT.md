# The Godot port

The App Store path. A webview wrapper gets rejected under Guideline 4.2; a Godot
export is a native binary. See `SHIPPING.md`.

**Where things live (GitHub `Rando2020/PhoneGame`, the source of truth since
2026-10-18):** `godot/` is the port (Godot 4.3, its own project; open that
folder). The repo root `project.godot` is the legacy Godot prototype; Godot skips
a subfolder holding its own project.godot, so CI (`--editor --quit` on 4.6.2)
passes with both. `web/` is the web game with all nine patches applied;
`meldlings.html` is built from it by `tools/build_web.py`. The patch files stay
in `web/` as the record of what changed. **Ziah ran the port on his phone
(2026-10-17): it works.** Speed and safe areas were not measured there.

## Status

The engine is ported and **proven identical to the JS**. A whole run is playable
in Godot: intro, keep and count, cut ceremony, round end, shop, next round, run won.

| layer | JS | GDScript | state |
|---|---|---|---|
| scoring | `web/cribbage.js` | `godot/engine/cribbage.gd` | exact |
| pegging | `web/pegging.js` | `godot/engine/pegging.gd` | exact |
| roguelite | `web/cribrogue.js` | `crib_data.gd`, `crib_run.gd`, `crib_round.gd` | exact |
| meta + save | `web/meta.js` | `meta.gd`, `achv.gd` (save in `user://`) | exact where tested |
| card layer | `godot-legacy/scripts/cards/` | `godot/ui/cards/` | salvaged; MeldRules removed |
| keep screen | part of `cribrogue_ui.js` | `godot/ui/keep_screen.gd` | deal, keep, count; adapts to any portrait shape |
| marks, split cards | `app.js` cardEl / splitCardEl | `card_view.gd` | all 6 marks + splits; art from make_marks/make_split |
| count cascade | `cascade.js` | `ui/cascade/cascade_plan.gd`, `cascade_view.gd` | plan + player, skip, speed; no audio/particles |
| round loop | `cribrogue_ui.js` renderCrib, cribCharmRow | `keep_screen.gd`, `ui/table/charm_bar.gd`, `crib_strip.gd` | mulligan, recut (Foresight), crib strip, charm bar lit by the cascade |
| cut ceremony | `cribrogue_ui.js` CUT_TIERS | `ui/cut/cut_plan.gd`, `cut_view.gd` | tiers from `cut_quality()`, tap to skip |
| shop | `cribrogue_ui.js` showCribShop | `ui/shop/shop_screen.gd` | charms, cards, reroll, Reckonings, selling, slot limits |
| run flow | cribRoundIntro, cribRoundEnd, NEXT ROUND, cribRunWon | `ui/run_flow.gd` (main scene) | wager, WALK AWAY, SKIP, boss intro, round end, run won, endless |
| The Play (pegging) | showPegging, renderPegging, pegLay | `ui/peg/peg_session.gd`, `peg_view.gd`, in `keep_screen.gd` | entered after the count exactly when the web does; tap to lay, tap to hurry the Spoiler |
| rest of UI, audio | `cribrogue_ui.js`, `app.js`, `audio.js` | none | not started: title/street menus (showCribSelect), Peddler, collection, save and resume mid-run, audio, particles, creature sprites |

## Parity test

```
node tools/parity/gen_fixtures.js                                   # after ANY engine change, JS side
godot --headless --path godot --script res://tests/parity_test.gd   # ~4 min, exit 0 = exact
PARITY_RUNS=5  ...                                                  # first 5 full runs only
PARITY_ONLY=36,43 ...                                               # specific runs
```

`gen_fixtures.js` runs the real `web/` engine with Math.random seeded, so the
unseeded code paths replay too. The fixture holds 4000 hands, 600 keep sets,
1800 pegging cases and 76 full scripted runs (every Meldling, Streets 1/3/5/8,
all Trials, endless, forced-mythic builds): 722 rounds, 1794 deals.

The harness was mutation-tested: a +1 change to one charm, a reordered deck and
reversed sort ties were each caught at the exact deal. A runtime error in a
group counts as failure (GDScript errors don't throw, so they'd otherwise pass).

Recycling only occurs on Facet and Thirteen (13 of 722 fixture rounds), so the
recycle path is covered by runs 36-61 only.

## UI tests

```
godot --headless --path godot --script res://tests/screen_test_shapes.gd  # 3 phone shapes, input, skip
godot --headless --path godot --script res://tests/screen_test_play.gd    # mulligan, recut, crib, charms
godot --headless --path godot --script res://tests/card_test.gd       # marks, splits, view reuse
godot --headless --path godot --script res://tests/cascade_test.gd    # 1502 real results + 167 played/skipped
godot --headless --path godot --script res://tests/screen_leak_test.gd  # screens freed mid-count don't leak
xvfb-run godot --path godot --rendering-method gl_compatibility --script res://tests/card_gallery_shot.gd
xvfb-run godot --path godot --rendering-method gl_compatibility --script res://tests/shot.gd  # PNGs
godot --headless --path godot --script res://tests/cut_test.gd        # cut tiers vs JS, skip lands on same state
godot --headless --path godot --script res://tests/shop_test.gd       # 40 JS shop scenarios replayed by click
godot --headless --path godot --script res://tests/run_flow_test.gd   # whole runs by click vs the web's call order
godot --headless --path godot --script res://tests/peg_test.gd        # The Play vs JS fixture playui, by click
xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/peg_shot.gd   # /tmp/peg_*.png
xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/flow_shot.gd  # /tmp/flow_*.png
xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/shop_shot.gd  # /tmp/shop_*.png
```

`shop_test.gd` replays fixture group `shopui` (40 scenarios, 435 steps, made by
the real JS) through real clicks and compares the run after every step: 395
clicks over all five actions, fits without scrolling at all three shapes.

`run_flow_test.gd` plays four whole runs through RunFlow by click (best-EV keeps,
cut and cascade skipped by tap, a simple shop policy) and replays the web's
handler order (cribRoundIntro, afterCount, cribRoundEnd, NEXT ROUND) directly on
the engine with its own save and Math.random stream. Last run: 68 rounds
compared, 1,325 clicks, paths hit: wager played, WALK AWAY, SKIP, boss, run over,
run won. It also checks the screen order, the web's two flash lines, and that
every page's text stays above its buttons, buttons centred and on screen. Caught
by mutation: Glim paid twice, `shop_state` not cleared, `advance()` skipped,
skips not spent, the old `is_wager`.

`screen_test.gd` clicks cards and the Keep button with real input events, then
replays the same seed and keeps through `CribRound.commit()` and requires
identical results. It runs at 720x1280, 720x1560 (tall phone) and 960x1280
(wide), checking every element is on screen, stacked without overlap, centred,
the button in the thumb zone and the count text fitting its box. It also plays
a deck full of marks and split cards and checks each view shows its card. The
old absolute layout fails it (off-centre, dead space). One touch = one press.
`SHOT_SIZE=720x1560` makes `shot.gd` render other shapes.

UI facts learned the hard way:
- **Headless windows are 64x64.** Clicks below y=64 are silently dropped. UI
  tests must set `root.size = Vector2i(720, 1280)` first.
- **Touch fired twice.** CardView handled ScreenTouch AND the emulated mouse
  click, so every tap pressed twice. Now mouse only, with
  `emulate_mouse_from_touch=true` pinned in project.godot.
- **Use the generated card art, not project-knowledge copies.** Those are
  84x112 RGB re-encodes (alpha flattened to white). `make_cards.py` makes the
  real 70x98 RGBA set, which is what `CardArt` expects.
- **Layout is computed from `size` on every resize** (`KeepScreen._layout`),
  bottom-up for the thumb, with the OS safe area converted to canvas units.
  `aspect="expand"` means the canvas is never smaller than 720x1280, only taller
  or wider.
- **Marks and splits are generated, like the faces.** Run `make_marks.py` and
  `make_split.py` into `godot/assets/cards/`. Split cards are AtlasTexture
  children, not a composited image: reading pixels back from textures fails on
  the headless renderer and isn't reliable after export.
- **Split cards draw like the web: no mark.** Ziah prefers the web look. The
  engine still scores a split card's mark; it just isn't drawn.
- **Headless "ERR_CANT_OPEN" under xvfb is ALSA** (no sound device in the
  container). Harmless.
- **The cascade is a pure plan plus a player.** `CascadePlan.build(res, rd,
  keep_rank)` makes the beats (testable without animating); `CascadeView`
  plays them as ONE node-owned Tween sequence. Skip renders the plan's end
  state, so it lands on `res.total` by construction.
- **No coroutines tied to node lifetime.** Awaiting SceneTreeTimers in the
  cascade leaked one object per screen freed mid-count (measured); node-bound
  tweens die with the node. Prefer tweens or one-shot signal connections.
- **Presentation never draws from `JS.unseeded`.** Shake uses Godot's `randf()`.
  Drawing from the engine stream would shift Fickle/Brittle rolls.
- **Containers inflate to fit children.** A VBoxContainer's `size` grows with
  its rows, so "rows <= rows that fit in list.size" can never fail. Keep the
  intended height in its own variable (`CascadeView.list_h`).
- **A test script that fails to load can HANG the runner** (crash before
  quit()). Check `can_instantiate()` and require each section to report in.
- **UI tests run the clock fast** with `Engine.time_scale` (screen 8x, cascade
  16x); timers and tweens honour it.
- **Fluidity rules for the count (Ziah: fluidity matters most).** The footer
  says at most two things: coaching and ONE banner (a clutch line replaces
  TARGET MET). Round-end facts (result, crib) live in the status bar and the
  button. During a count the whole screen is the skip target; continuing uses
  the button so a stray tap can't deal. Never make the player scroll mid-count.
- **The web build inlines sources with a fixed transform** (`build_web.py`
  js()): to test a JS patch without rebuilding assets, apply the same transform
  and swap the text inside meldlings.html.
- **No `await` anywhere in UI code.** Awaiting timers or tween signals leaks
  one object per node freed mid-wait (measured for the cascade, the deal and
  the flip). Use node-owned tween sequences and one-shot signal connections:
  `HandView.deal` emits `deal_finished`; the commit continues in `_after_flip`.
- **Legacy views reset `mouse_filter` in `_ready`** (HandView -> PASS, CardView
  -> STOP). Set it AFTER add_child. A PASS row on top swallowed the Recut
  button's clicks; STOP cards in the counted row ate tap-to-skip.
- **CardView scales about its centre**: offset positions when scaling it.
  `CardView.pop()` ends at scale 1: on a scaled card use your own pop (PegView._pop).
- **Controls only while usable**: Mulligan and Recut hide while cards deal,
  during the count and when spent.
- **Stagger parallel Godot launches by a few seconds.** Two started in the same
  instant once failed with "File not found" on a script that exists (likely
  .godot cache contention; unproven). Rerun alone to tell a launch failure
  from a real one.
- **Applying the web patches.** fixes, sidefx, recycle, trim, wrap in any
  order; then marks, attribution, doublecut, balance in that order; cribend
  (UI only) last (they stack
  on lines the others touch). All 120 orderings verified. **Already applied in
  the repo's web/** (2026-10-18); the .patch files are the record. The pre-patch
  sources are the commit "Bring web sources up to the newest shipped build".
- **A check that can't fail proves nothing; a fixture set that can't fail
  doesn't verify a port.** The Double Cut fix initially passed parity on the
  OLD GDScript because no fixture reshuffled with Double Cut. Always run the
  old GDScript against new fixtures, and add targeted fixtures when it passes.
- **Build the html with `python3 tools/build_web.py`** from web/. It bundles 16
  creatures, pegging.js and admin.js (the dev panel; `DEV = true` in admin.js).
  On the pre-patch commit it reproduces the shipped 520 KB meldlings.html byte
  for byte. Web harnesses that load the html read `../meldlings.html`.
- **Web checks take a FOLDER where they load cribsim** (daily_check, tap_check):
  cribsim.js loads its own cribrogue.js, so a file argument would test a mix.
- **The screen test is two runners** (`screen_test_shapes.gd`,
  `screen_test_play.gd`, ~3 min each, can run in parallel). Each requires
  only what its own cases produce.
- **The simulator never calls cutQuality/preview/bestOrder and its shop never
  buys mythics**: use `web/forced_sweep.js` to measure charms it can't reach.
- **HandView copies its cards and can re-sort.** Map a selection back to the
  engine through the `_i` index tag, never by hand position.
- **SafeArea.insets only on mobile.** On desktop `DisplayServer` reports the
  safe area relative to the monitor; under xvfb it measured a bogus 256 px.
  `ui/safe_area.gd` returns zero insets off-phone. Unverified on a real phone.
- **A Button grows rightward when its label is wider than its size**, so a
  centred button with a long label sits off centre (SKIP THIS ROUND). Size
  buttons to `get_combined_minimum_size()`; run_flow_test checks centring.
- **KeepScreen in a run** (`in_run = true`, set before add_child) does not deal
  a round of its own in `_ready`. It did, and the real deal killed that tween
  and left a one-shot `deal_finished` connection dangling (an engine error per
  round). The round end hands back via `round_finished`; RunFlow owns the rest.
- **An unrecorded session happened** (shop work, 2026-10-09) whose docs were
  never updated. Its code was verified this session before building on it. If
  the zip and the docs disagree, trust tests, then the code.

## Porting rules learned

- **Use the `JS` helpers.** `JS.or_` for `a || b`, `JS.nn` for `a ?? b`,
  `JS.round_` for Math.round, `JS.num_keys` where JS iterates integer keys,
  `JS.stable_sort_desc` for any sort. Reversing sort ties alone broke 295 of 300
  keep lists.
- **Charms are objects, not Dictionaries.** The engine compares them by identity.
- **Count results keep the JS camelCase keys** (`levelContrib`, `cutGain`,
  `steps`...) so the UI ports against the same field names.
- **Never store `round` or `run` inside a count result.** It forms a RefCounted
  cycle and every round leaks. `run_count` strips them before returning.
- **Call order is part of the contract.** `run_count` consumes randomness
  (Fickle) and can mutate the run (Cutpurse, Collector), so the number and
  order of calls must match the JS.

## The Play (ported 2026-10-18)

The web pegs after every count once `the_play` is owned (the fifth system, one
per Wager won) and 4+ cards remain. Order, all UI code in the web, mirrored in
`PegSession`: the Spoiler's four come off the FRONT of the stock; the play rides
the count's mult (at least x1); net = your pegs minus half the Spoiler's
(rounded down); gain = round(net x mult) joins the score; only THEN does the
round go on or end. So KeepScreen does not settle at commit when the Play is
owed: settling first would pay the Crib and draw the Crib's Own Cut before the
Spoiler's hand. Fixture group `playui` (36 runs, 61 rounds) is the real JS doing
this. `tests/peg_test.gd`: Part A replays it on the engine, Part B plays it by
click at 3 shapes (half the Spoiler's beats waited out, half tapped through).
Mutations caught: hand off the back, no mult, ceil instead of floor, settling
before the Play, dealing on past the target.

## Web bug fixed: the Crib was paid twice (`web/cribend.patch`)

cribRoundEnd settled the Crib, then called `settle()`, which settles it again.
Every round that ended naturally paid the Crib twice (and drew a second Crib's
Own Cut); the screen showed it once. The simulator, the engine fixtures and
Godot all paid it once, so every balance number assumed once. Measured (600
runs each, Street 1, same seeds): clear rate once vs twice, Pip 15.5% vs 19.3%,
Thump 11.8% vs 17.7%, Clover 18.8% vs 22.7%, Facet 34.5% vs 38.7% (about +-3).
Fix: settle() first, then read cribResult. `web/cribend_check.js` plays real
rounds in the built html: 120 round ends, 0 failures; 102 failures before.
Reversible: revert the patch. **Ziah to confirm** (it makes the web game harder
than players have known it).

## Test harness bug fixed: lambdas capture by value

run_flow_test swapped two saves inside a lambda; GDScript lambdas capture locals
by value, so the swaps never persisted and both sides silently ran on reset
saves. Fixed with a shared Dictionary; the comparison now checks WHICH systems
are unlocked, not how many. A run with The Play owned found it.

## Found, not fixed: Ziah's call

| what | where | detail |
|---|---|---|
| Skips are dead | web and Godot | `skipProgress`/`skips` are never incremented, so SKIP THIS ROUND only appears if something sets `run.skips`. DEPTH.md and SUBTRACTION.md describe overshoot accrual (100 x overshoot / target toward a Skip; 100 = one Skip). The web's round-end line still reads a leftover `run.surplus`. Restoring it is a balance change: simulate first |
| `noCashOut` is dead | web and Godot | merged in `rules()` but never read; the web ends a round the moment the target falls. So Stink Hole and Skunk Line's "every round runs full" does nothing. Godot now matches the web (it used to honour the rule, which was a parity break) |
| em dashes in game copy | web and Godot | the shop-full line ("Every charm slot is spoken for..."), the skip flash ("Round skipped...") and The Gathering's text each contain one. Godot copies the web exactly |

## Port bugs found by UI tests

| bug | found by | fix |
|---|---|---|
| `is_wager()` used `wager_at.has(key)`; the JS tests truthiness, so WALK AWAY (which sets the key to false) did nothing | run_flow_test walk path | `JS.truthy(wager_at.get(key))`. Parity still exact; no fixture ever walked away, which is why it hid |

## Known JS bugs, ported bug-for-bug

Each is marked `JS-PARITY(...)` in the GDScript. Fix in the JS first,
regenerate the fixture, then mirror the fix. Never fix on one side only.

| tag | bug | measured |
|---|---|---|
| ~~`mimic`~~ | **FIXED** (JS + GDScript, parity regenerated). Mimic is now wild for flushes and lights in the flush | Balance-neutral at N=400 (Clover 20.0% -> 20.3%, CI ±3.9) but flushes +21% in scripted runs (287 -> 348 deals). Still open: `flushPairs` (Clover Ascended) ignores wilds; a design question |
| ~~`side-effects`~~ | **FIXED and APPROVED by Ziah** (`web/sidefx.patch`). Charms record effects as intents (`ctx.essence`, `ctx.addCards`); `applyEffects` lands them once, on real counts only | Forced from round 1 (Pip, N=400): Cutpurse 33.0% -> 16.8%, Cutpurse+Bank 73.5% -> 31.0%. `web/sidefx_check.js` |
| ~~`recycle-dupes`~~ | **FIXED** (`web/recycle.patch`, independent of sidefx; JS + GDScript, parity regenerated). Plus `canMulligan()`: a mulligan must leave a card for the starter. Without duplicates padding the stock, a mulligan could empty it and commit() crashed (not reachable in the original: 0 crashes in 3000 aggressive Thirteen rounds) | `web/recycle_check.js`: 30,000 conservation checks over 1,280 recycles, 0 duplicates; fails 27,684 on the old code. Balance-neutral (N=1200): Facet 30.8% -> 28.7% (±2.6), Thirteen 27.8% -> 26.7% (±2.5), though single runs swing hard (one Facet run 1 -> 15 rounds) |
| ~~`doublecut-leak`~~ | **FIXED** (`web/doublecut.patch`, stacked). Double Cut's second starter returns to `used` at commit | `recycle_check.js` now ASSERTS zero cards out of circulation (was only printed): 0 across 42,001 checks; the old engine fails (9 missing). Two Double Cut thin-deck runs added to the fixtures (the old GDScript passed without them; now it fails both). Balance-neutral: forced Double Cut 17.7% -> 17.8% (±3.1) |
| ~~`unseeded-trim`~~ | **FIXED** (`web/trim.patch`, independent; JS + GDScript, parity regenerated). `removeRandom` shuffles with the run rng. Covers Facet/Facet Ascended trims AND the Whittled charm | `web/daily_check.js` over 160 real Daily dates: Facet Daily decks differed for all 38 Facet days, now 0; Whittled differed in 40/40 seeded runs, now 0. Balance-neutral by construction (the simulator's runs are unseeded): Facet 28.0% -> 29.3% (±3.1) |
| ~~`unseeded-marks`~~ | **FIXED** (JS + GDScript, parity regenerated). Fickle rolls ONCE per real count from the run rng (`rollLuck`, before commit's counterfactuals, shared with them); hypothetical counts (cutQuality, preview, bestOrder, bestKeep) draw nothing and show Fickle's expected +6.25 (`FICKLE_PREVIEW_EV = true`, Ziah's call). Brittle shatters from the run rng. Patch: `marks.patch` applies LAST (it overlaps sidefx in commit/settleCrib) | Before: ~70% of Daily days gave different outcomes for identical play. Now `STRICT=1 node web/daily_check.js` passes all 160 days; `web/tap_check.js` (extra looks between deals must not change outcomes; 3,290 Fickle cards counted) passes, and FAILS on both the old engine and the naive fix (rolling from the run rng inside every count), which passes the Daily check. Balance-neutral: mark-heavy Pip N=1500, 23.7% -> 24.4% (±2.2); an N=600 run showed a 5-point gap that the larger run proved to be noise |
| ~~`deck-attribution`~~ | **FIXED** (`web/attribution.patch`, stacked). The deck charm is built once per run, so commit's skip-by-identity finally matches it | `web/attribution_check.js`: the Meldling fired in 1,513 deals and was credited in 0 before, all 1,513 after; it was a round's MVP 346 times (0 before); every score identical to the old engine across 175 runs. Fails on the old engine |
| ~~`wrap`~~ | **IMPLEMENTED** (Ziah: make it work). Round the Bend: a run may pass K-A (Q-K-A, K-A-2). A stretch ending at K joins one starting at A; the joined run takes the A stretch's place in event order; all run rules (need, cap, multiplicity, bonus) apply. `web/wrap.patch`, independent | `web/wrap_check.js` 17 checks (fails on old code). Fixtures now include 599 wrapRuns hands, 34 with a run through K-A; old GDScript fails exactly those 34. Forced Pip N=600: 12.2% -> 13.8% (±2.8), a modest buff |
| ~~(cascade)~~ | **FIXED** in `web/cascade.js`: `levelStep` continues to `gildStep` | Verified in the harness DOM (`web/cascadecheck.js`): a level-bonus hand renders 2 rows before, 5 after. All 6 web harnesses pass on both builds |

## Performance

GDScript is far slower than V8, so the hot paths were optimized under the parity
test (exact before and after). Desktop, averaged over 40 deals:

| call | before | after | how |
|---|---|---|---|
| `count_hand` | 95-119 us | 45 us | fifteens: incremental subset sums, card lists only for hits |
| keep decision (`best_keep_ev` + `keep_rank`) | 50.7 ms | 9.6 ms | per-deal EV table cache (`keep_table()`) |
| `cut_quality` | 7.0 ms | 4.7 ms | via count_hand |
| `best_order` (5 charms) | 15.5 ms | 12.5 ms | via count_hand; auto-sort button only |
| full parity suite | 235 s | 57 s | |

The EV cache is Godot-only (not in the JS). It is keyed on the dealt array and
stock size, and cleared by every operation that touches either. A recut under
Foresight changes the stock without changing its size, which is why both guards
exist. `tests/cache_test.gd` checks the cache against a fresh table after every
deal, mulligan, cut and recut (1949 checks at last run), and was mutation-tested: removing
the guards makes it fail on recut.

Not optimized, on purpose: `run_count` has side effects (Cutpurse, Collector,
Fickle's random draw), so caching inside it changes behaviour, not just speed.
Revisit after the `side-effects` and `unseeded-marks` bugs are decided.

Phones will be several times slower; ~10 ms on desktop for the keep decision
should still land within a frame or two. Measure on a device before threading.

Probes: `tests/perf_probe.gd`, `tests/leak_probe.gd`, `tests/cache_test.gd`.

## Balance decisions SHIPPED (`web/balance.patch`, JS + GDScript, parity green)

Ziah delegated these ("make the next best decisions"). Each is one place in the
code and reversible.

| change | before | after (shipped code, forced/sim) |
|---|---|---|
| Clover Ascended: a Mimic joins your largest natural suit under flushPairs | Mimics inert, 5.4% | 9.9% (±2.1, N=800); base Clover 17.3% |
| Usury: x2 mult, -4 Glim per count (was x3) | 64.6% when owned early | 28.0% (±3.1, N=800) vs 13.8% with no charm |
| The Collector redesigned: once a round your BEST counted card (most scoring events) joins the deck; +2 base per card collected this run | 4.6% (copied the random starter), below no charm | 22.0% (±3.3, N=600) vs 12.0% with no charm |

Rejected Collector designs (all lost to no charm, because a deck-only charm
costs one of five slots and scores nothing): once per round 4.8%; deck-size
swap 7.4%; best card joins 8.7%; best joins + lowest rank leaves 4.7%. A +3
variant (29.3%) was rejected for rivalling Usury. Checks: `web/balance_check.js`,
`web/collector_check.js` (both fail on the old engine). The GDScript Collector
matches cards by identity (is_same), not Array.has, which compares
Dictionaries by value and would credit duplicate cards with each other's events.
