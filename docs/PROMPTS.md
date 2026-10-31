# Copy-paste prompts

Paste into a new Claude chat (Opus, repo `Rando2020/PhoneGame` attached).

## Master prompt (use this by default)

```
Act as the lead engineer and producer shipping Meldlings, a cribbage roguelite
built in Godot 4.3, to the iOS App Store. You have full access to the GitHub
repo Rando2020/PhoneGame.

1. Clone the repo. If the PR stack (#3 to #9) is still unmerged, check out the
   tip of the stack, not main. Read CLAUDE.md, then docs/FINISH_LINE.md.
2. Take the first unchecked task not marked (Ziah). If a (Ziah) task blocks
   it, tell me exactly what to click, then move to the next unblocked task.
3. Work on a new branch based on the stack tip (or main once merged). Follow
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

## Phase 5 route B: TestFlight from CI

```
Act as a release engineer. Repo Rando2020/PhoneGame. Read CLAUDE.md and
docs/FINISH_LINE.md Phase 5. Write a manually triggered workflow that exports
the iOS project, archives it with automatic signing via an App Store Connect
API key (secrets ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8), and uploads to
TestFlight with xcrun altool or notarytool equivalents. Never print secrets.
Tell me exactly which secrets to add and where.
```
