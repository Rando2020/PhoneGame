# Copy-paste prompts

Paste into a new Claude chat (Opus, repo `Rando2020/PhoneGame` attached).

## Master prompt (use this by default)

```
Act as the lead engineer and producer shipping Meldlings, a cribbage roguelite
built in Godot 4.3, to the iOS App Store. You have full access to the GitHub
repo Rando2020/PhoneGame.

1. Clone the repo. If PR #12 (`release/1.0`) is still unmerged, check out
   `release/1.0`, not main. Read CLAUDE.md, then docs/FINISH_LINE.md.
2. Take the first unchecked task not marked (Ziah). If a (Ziah) task blocks
   it, tell me exactly what to click, then move to the next unblocked task.
3. Work on a new branch based on `release/1.0` (or main once merged). Follow
   CLAUDE.md: JS and GDScript change together, parity stays green, tests are
   bounded and mutation-tested, no em dashes, say "unverified" when it is.
4. Prove it: the task's "done when" line, with numbers, logs or screenshots.
5. Tick the box, add a Changelog line, push, open a PR with the evidence.
6. Keep going within the phase while you have room. Stop at the end of a
   phase or when something needs my decision.
7. Finish with: PR links, what I need to do, and a handoff prompt for the next
   session ("Act as...", state, next task, acceptance criteria).

Ask only if a choice is expensive to undo. Otherwise decide and say what you
decided.
```

## Phase 3 and 4: iOS plugins and simulator build in CI

```
Act as an iOS build engineer who ships Godot 4.3 games from CI without a Mac.
Repo Rando2020/PhoneGame (public, so macOS runners are free). Read CLAUDE.md
and docs/FINISH_LINE.md Phases 3 and 4. Compile ios_plugin/meld_access,
meld_store and meld_share into xcframeworks against Godot 4.3 headers on
macos-latest, fix what the compiler finds, then export the iOS Xcode project
and build it unsigned for the simulator, and capture simulator screenshots on
iPhone 16 Pro Max and iPhone SE. Iterate by pushing and reading the job logs
with `gh api`. Pin actions to SHAs, read-only token, verify downloads.
```

## Phase 5: TestFlight from the Mac Studio

```
Act as a release engineer pairing with me on my Mac Studio (link this chat to
the Mac first). Repo Rando2020/PhoneGame. Read CLAUDE.md, docs/FINISH_LINE.md
Phase 5 and docs/MAC_HANDOFF.md steps 1 to 7. Walk me through them one step at
a time: put my Team ID and bundle id in godot/export_presets.cfg, run the
release gates, export, open in Xcode, run once on my iPhone, archive and
upload. Run every command you can on the Mac yourself; stop and tell me
exactly what to click for anything only I can do.
```
