# CLAUDE.md: Meldlings

Read this first, every session. Then read `docs/FINISH_LINE.md` and take the
first unchecked task that is not marked (Ziah). Do not start features that are
not on that list.

## What this is

**Meldlings** is a cribbage roguelite. Keep four of six, throw two to the Crib,
then the starter is cut. Score is `base x mult`, counted the cribbage way.
Charms, Marks and Reckonings bend the math. Owner: Ziah (GitHub `Rando2020`).

State (2026-10-31): the web game is finished and the **Godot port is done**:
every screen, audio, haptics, save and resume, the free-to-try unlock, store
shots, preview video and listing. The engine is proven identical to the JS.
What is left is release work: merging the PR stack, a playtest, and the App
Store steps only Ziah can do. Godot 4.3 cannot run on the iOS Simulator;
test on a device.

## Where the truth lives

| Thing | Path | Notes |
|---|---|---|
| The plan | `docs/FINISH_LINE.md` | The single list of what is left. |
| App Store build | `godot/` | Godot **4.3**. Main scene `scenes/run_flow.tscn`. |
| Port history and rules | `docs/PORT.md`, `docs/AUDIT.md`, `docs/LOOP_AUDIT.md` | Newest pass wins. The status table at the top of PORT.md is old; later sections are current. |
| Release gates | `docs/RELEASE_CHECKLIST.md` | Run before any build goes to a Mac. |
| Mac steps | `docs/MAC_HANDOFF.md` | Accounts, export, Xcode, TestFlight, review. |
| Playtest | `docs/PLAYTEST.md`, `tools/playtest_build.sh`, `tools/playtest_report.py` | 20-minute script and 6 questions. |
| Monetization | `docs/MONETIZATION.md`, `godot/engine/entitlement.gd` | Product id `com.meldlings.full`. |
| Store listing | `store/listing.md` | Checked by `tools/check_listing.py`. The only listing copy. |
| Store art | `store/screenshots/{6.9in,6.5in,5.5in}/`, `store/preview/` | Rendered from the real Godot build. |
| iOS plugins | `ios_plugin/` (source), `godot/ios/plugins/` (prebuilt) | Compiled by `ios-plugins.yml`; never run on a device. `ios-build.yml` exports and builds the app. |
| Web game | `meldlings.html`, `web/` | Ground truth for rules. Build: `python3 tools/build_web.py`. |
| CI | `.github/workflows/`, `docs/CI.md` | Root project on 4.6.2 (legacy), `godot/` on 4.3. |
| Old prototype | root `project.godot`, `scenes/`, `scripts/`, `godot-legacy/` | Do not delete root `project.godot` (CI needs it). |

`docs/NEXT_SESSION.md` and `docs/ROADMAP.md` are older handoffs. Their traps and
non-negotiables still hold; their task lists are done.

## Why Godot and not a wrapper

A webview wrapper of the HTML was rejected under Guideline 4.2 and would also
hit 4.7 (HTML5 mini games). The Godot iOS export is a native binary.

## Vocabulary (do not swap for Balatro terms)

Glim = currency. Pegs = meta currency at the Peddler. The Peg House = shop.
Reckonings = scoring categories. Spoilers = bosses (suit-aligned). Streets =
difficulty tiers. Trials = challenge runs. Deeds = achievements. Charm
qualities: Worn, Keen, Gleaming, Hallowed, Mythic. Card marks: Sunlit, Brittle,
Mimic, Offering, Minted, Fickle.

## Design rules (do not break)

1. **No hindsight play.** The cut happens after the keep.
2. **Charm math has buckets.** Base and mult never share one.
3. **The Crib is strategic.** It holds four, filled by the earliest throws.
4. **Earned dopamine.** Celebrate what caused the win; no fake near-misses.
5. **Fluidity first.** Controls only while usable; no await in UI code.
6. **Simulate before you tune.** Before/after numbers in the PR.
7. **Fair monetization.** Act 1 free, one non-consumable unlock, no ads, no
   loot boxes, no energy.

## Working rules for any AI session

- Branch, PR, one task per PR. The PR stack (#3 to #9) is unmerged: until Ziah
  merges it, base new work on the stack tip, not `main`.
- Never fix one engine side only. JS and GDScript change together and parity
  stays green (`godot/tests/parity_test.gd`).
- After any `web/` change: `python3 tools/build_web.py`, then the web checks in
  `docs/CI.md`. After any `godot/` change: the suites in RELEASE_CHECKLIST gate 1.
- Every new test counts its cases, cannot hang (run under `timeout`, output to a
  file) and is mutation-tested once.
- Say "unverified" when it is. Measure before fixing.
- No em dashes anywhere, in game text or docs.
- Tick the box in `docs/FINISH_LINE.md` in the PR that finishes it, plus one
  Changelog line.
- End every session with a handoff prompt ("Act as...", state, next task,
  acceptance criteria) as the PR's last comment.

## Things only Ziah can do

Merge PRs, Apple Developer membership, App Store Connect, signing, tax and
banking, the price, a contact email, the copyright line, the age-rating
answers, playtests, device checks, and pressing Submit. When a task needs one,
stop and list exactly what to click.
