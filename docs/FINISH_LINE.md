# Finish Line: Meldlings to the App Store

The single list of what is left. Work top to bottom. A task is done when its
"done when" line is true and the box is ticked in the PR that did it.

`(Ziah)` = needs Ziah's accounts, hands or decision. Everything else an AI
session can do.

What is already done (do not redo): the web game; the Godot 4.3 port with
every screen, audio, haptics, motion, save and resume; engine parity (78 runs,
4,000 hands, 1,800 pegging cases); the free-to-try end card and Entitlement;
store screenshots at three sizes; the 21 s preview; `store/listing.md`; privacy
and support pages in `docs/`; the playtest build and report tool; CI for the
port, parity and web checks. See `docs/PORT.md` and `docs/AUDIT.md`.

---

## Phase 0: Land the work on main

- [ ] **(Ziah)** Merge the stack in order on GitHub: #3, #4, #5, #6, #7, #8,
      then #9 (mark it Ready for review first), then this plan's PR. Each one's
      base is the one before, so merge oldest first and let GitHub retarget.
      Done when `main` has `godot/`, `store/` and this file, and CI on `main`
      is green.

## Phase 1: Answers only Ziah has (about 15 minutes)

- [ ] **(Ziah)** A contact email for `docs/privacy.html` and `docs/support.html`
      (search for NEEDS ZIAH). Reply with it and an AI session fills both.
- [ ] **(Ziah)** Copyright line, for example `2026 Josiah Parve`.
- [ ] **(Ziah)** Age rating: confirm the answers in `store/listing.md`,
      especially "simulated gambling" for the Wager rounds.
- [ ] **(Ziah)** Price of the unlock. Suggested $2.99 with a $0.99 launch week.
- [ ] **(Ziah)** Turn on GitHub Pages: repo Settings > Pages > Deploy from a
      branch > `main` / `docs`. Done when
      `https://rando2020.github.io/PhoneGame/privacy.html` loads.
- [ ] Fill the email and copyright into the pages and `store/listing.md`;
      `python3 tools/check_listing.py` passes. Done when no NEEDS ZIAH is left.

## Phase 2: One real playtest

- [ ] **(Ziah)** Play the 20-minute script in `docs/PLAYTEST.md` on the
      Windows playtest build and send back `playtest.log`.
- [ ] Run `tools/playtest_report.py` on the log, fill the six verdicts in
      PLAYTEST.md, and act only where two or more signals agree (sim first).
      Done when every verdict reads within, outside or unverified, with numbers.

## Phase 3: Compile the iOS plugins without a Mac

The repo is public, so GitHub's macOS runners (with Xcode) are free.

- [ ] Add a `ios-plugins` workflow on `macos-latest`: Godot 4.3 headers, build
      MeldAccess, MeldStore and MeldShare for device and simulator, package each
      as an xcframework, upload them as artifacts. Done when the job is green
      and all three `.xcframework` artifacts exist.
- [ ] Fix whatever the first compile finds in `ios_plugin/*` (expected: the
      Swift bridging header name in MeldStore). Note each fix in the plugin
      README and drop "never compiled" from its status.
- [ ] Commit the built plugins to `godot/ios/plugins/<name>/` with their
      `.gdip`, tick them in the iOS preset, raise `min_ios_version` to 15.0
      (StoreKit 2). Done when gate 8 (iOS export) still passes.

## Phase 4: Build and run on a simulator in CI

- [ ] Workflow `ios-build`: install Godot 4.3 and its iOS export template,
      export the Xcode project, `xcodebuild` it unsigned for the iOS
      Simulator. Done when the build step is green.
- [ ] Boot iPhone 16 Pro Max and iPhone SE simulators, install, launch, and
      save screenshots of the title and a deal with `xcrun simctl io
      screenshot`. Done when the shots are artifacts and nothing sits under
      the Dynamic Island or home bar (closes AUDIT #18 as far as a simulator
      can).

## Phase 5: Signing and upload

Pick one route. Ziah decides which (see the PR).

- [ ] **(Ziah)** Apple Developer Program membership. Note the Team ID.
- [ ] **(Ziah)** Create the App ID and the App Store Connect app
      (`docs/MAC_HANDOFF.md` step 1). Pick the real bundle id.
- [ ] Put the Team ID and bundle id in `godot/export_presets.cfg`.
- [ ] **Route A, Ziah has a Mac:** follow MAC_HANDOFF steps 4 to 7.
- [ ] **Route B, no Mac:** a `testflight` workflow that signs and uploads
      with an App Store Connect API key. **(Ziah)** creates the key (Users and
      Access > Integrations > App Store Connect API, role App Manager) and adds
      `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` as repo secrets. Done when a
      build appears in TestFlight.
- [ ] **(Ziah)** Create the in-app purchase `com.meldlings.full` and sign the
      Paid Apps agreement (MAC_HANDOFF step 3b).

## Phase 6: TestFlight and review

- [ ] **(Ziah)** Install from TestFlight on an iPhone. Check haptics, sound
      with the ring switch, a purchase with a Sandbox account, Restore, quit and
      Continue (MAC_HANDOFF steps 5, 6, 3b).
- [ ] Fix anything found; re-run the release gates.
- [ ] **(Ziah)** Paste `store/listing.md` into App Store Connect, upload
      `store/screenshots/6.9in/` and the preview, add the review note from
      MAC_HANDOFF step 9, submit.

## After launch (not blocking)

- Google Play: Godot Android export, $25 account, closed test with 12 testers
  for 14 days, then production.
- Game Center Daily leaderboard, iCloud save sync (both need new capabilities
  on the App ID).

---

## Changelog

- 2026-10-31: Plan created.
- 2026-10-31: Plan rewritten to match the repo. The first version was written
  from `main`, which is weeks behind the PR stack, and asked for work that was
  already done (the Godot port, store copy, screenshots). Removed
  `docs/STORE_LISTING.md`; `store/listing.md` is the listing.
