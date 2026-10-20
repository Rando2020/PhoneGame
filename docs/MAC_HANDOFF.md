# Mac handoff: from this repo to the App Store

Everything left needs a Mac. In order, with time estimates. **Every time
estimate is a guess** for someone new to Xcode; nothing here was timed.

Before you start: an Apple Developer Program membership (paid, yearly), a Mac
with the current Xcode, and an iPhone if you have one (the simulator covers
most of it).

## 1. Accounts and IDs (about 30 min, guess)

1. developer.apple.com > Account > Membership: note your **Team ID** (10 characters).
2. Certificates, Identifiers & Profiles > Identifiers > +: an App ID with your
   real **bundle id** (for example `com.yourname.meldlings`). No capabilities
   are needed (no push, no iCloud, no Game Center).
3. App Store Connect > Apps > +: a new iOS app with that bundle id, the name
   `Meldlings: Cribbage Roguelite` (from `store/listing.md`) and a SKU of your choosing.

## 2. Put the IDs in the project (5 min, guess)

In `godot/export_presets.cfg` replace the placeholders:
- `application/app_store_team_id="ABCDE12345"` with your Team ID
- `application/bundle_identifier="com.example.meldlings"` with your bundle id

Keep `export_project_only=true`: Godot writes the Xcode project and Xcode
does the build.

## 3. Build the MeldAccess plugin (1 to 3 h, guess; the least certain step)

Optional for a first submission. Without it, the game's own Text size and
Reduce Motion settings still work; with it, the game also follows the
phone's settings. Steps: `ios_plugin/meld_access/README.md`. The source has
never been compiled, so expect small fixes. If it fights you, skip it and
ship without it.

## 3b. The in-app purchase (2 to 4 h, guess)

The game is free to try; one non-consumable unlocks it (`docs/MONETIZATION.md`).

1. App Store Connect > your app > Monetization > In-App Purchases > +:
   Non-Consumable, Product ID **com.meldlings.full** (must match
   `Entitlement.FULL_ID`), reference name and display name "Full game",
   description from `store/listing.md`, a price (suggested $2.99), and a
   review screenshot (the end card: `godot/tests/free_end_shot.gd` renders it).
2. Agreements, Tax, and Banking: the Paid Apps agreement must be active, or
   no purchase works (not even in TestFlight).
3. Build the MeldStore plugin: `ios_plugin/meld_store/README.md` (StoreKit 2;
   raise the preset's minimum iOS to 15.0). **Without it the shipped game is
   free-only and can't sell.**
4. Test in Xcode with a StoreKit Configuration file first (the README says
   how): buy, cancel, Restore, Ask to Buy.
5. Then in TestFlight with a Sandbox account (Settings > App Store > Sandbox
   Account on the iPhone): buy, delete the app, reinstall, Restore.
6. Submit the in-app purchase together with the build for review.

## 4. Export and open in Xcode (15 min, guess)

```
godot --headless --path godot --export-release "iOS" ../build/ios/Meldlings.ipa
open build/ios/Meldlings.xcodeproj
```

You need Godot 4.3 and its iOS export template (Editor > Manage Export Templates).

In Xcode, select the target > Signing & Capabilities: tick
"Automatically manage signing" and pick your team.

## 5. Simulator checks (1 h, guess)

Run it (Product > Run) on these three simulators:
- iPhone 16 Pro Max (Dynamic Island, the store screenshots' size)
- iPhone SE (3rd generation) (home button, the shortest screen)
- iPhone 16 (Dynamic Island, standard size)

On each, go through: title, the road, a street, the Meldling picker, Peddler,
Deeds, Record, every Gallery tab, How to play (all 7 steps), Settings, a deal,
the count, The Play, the shop, a round end.

- **Safe areas (audit #18):** nothing under the Dynamic Island, the status
  bar or the home bar; every button tappable. `tests/reach_test.gd` checks
  this against an iPhone 16 Pro Max's insets in software. Only the
  simulator proves it.
- Rotate the simulator: the game should stay portrait.
- Settings > Accessibility > Display & Text Size > Larger Text, and Motion >
  Reduce Motion (only if you built the plugin): the game should follow both.
- Quit mid-run (swipe it away), reopen: Continue resumes where you were.

## 6. A real iPhone, once (30 min, guess)

Plug it in, pick it as the run destination, Run. Check what a simulator
can't: haptics on a big count and on 31, sound with the ring switch on and
off, and the frame rate (it should feel smooth; the headless numbers are in
`docs/AUDIT.md`).

## 7. Archive and upload (30 min, guess)

1. Run destination: "Any iOS Device (arm64)".
2. Product > Archive. The Organizer opens.
3. Distribute App > App Store Connect > Upload. Accept the defaults.
4. Wait for processing (often 10 to 30 min; Apple's queue, a guess).

## 8. App Store Connect (1 h, guess)

Paste from `store/listing.md` (every field is within Apple's limits, checked
by `tools/check_listing.py`):
- Name, subtitle, promotional text, description, keywords, what's new.
- **Support URL and privacy policy URL: yours to make** (a one-page site is
  enough; the policy can say the app collects no data).
- Copyright line.
- Category: Games > Card, secondary Games > Strategy.
- Age rating: the answers in `store/listing.md`. Decide on "simulated gambling"
  yourself; the listing explains the Wager rounds.
- App privacy: "Data not collected" (matches `godot/ios/PrivacyInfo.xcprivacy`).
- Screenshots: `store/screenshots/6.9in/` (and `6.5in/` if asked; `5.5in/` for older devices).
- App preview (optional): `store/preview/preview_886x1920.mp4`, 21 s,
  checked against Apple's spec by `tools/check_preview.py`.

## 9. TestFlight, then review (a day or more, guess)

1. TestFlight tab: add yourself as an internal tester, install TestFlight on
   your iPhone, play a full run.
2. App Store tab: pick the build, Add for Review, Submit.
3. Review notes worth adding: "Native Godot app; no web view; plays offline;
   no account or data collection." The first submission was rejected under
   4.2 as a web wrapper. This build is native (see `docs/AUDIT.md`).

## If something fails

- Signing errors: Xcode > Settings > Accounts, sign in, then re-tick
  automatic signing.
- Export compliance: the preset already sets `ITSAppUsesNonExemptEncryption`
  to NO in the Info.plist (the game has no networking), so upload shouldn't
  ask. If you add networking later, revisit it.
- Rejection: send the message back here; the audit history is in `docs/AUDIT.md`.
