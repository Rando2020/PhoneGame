# Release checklist

Every gate before a build goes to the Mac (then `docs/MAC_HANDOFF.md`). Run
from the repo root. "Today" is 2026-10-20, on the Linux build machine.

| # | gate | command | pass when | today |
|---|---|---|---|---|
| 1 | all test suites (32) | `cd godot && for t in $(grep -l "^extends SceneTree" tests/*_test*.gd \| grep -v soak_test); do godot --headless --path . --script res://$t >/dev/null 2>&1 \|\| echo "FAIL $t"; done` | no FAIL lines | **pass** (32 of 32) |
| 2 | web parity (inside 1) | `godot --headless --path godot --script res://tests/parity_test.gd` | exit 0 | **pass** |
| 3 | soak, 200 runs | `tools/soak.sh 200` | `0 fails`, `errors: 0` | **pass** (pass 11: 2,445 saves round-tripped, no growth in nodes) |
| 4 | deep soak, 50 strong runs | `SOAK_STRONG=1 tools/soak.sh 50` | `0 fails`, `errors: 0`, half the runs reach act 3 | **pass** (27 of 50 reached act 3+, 4 reached act 5, 1 won; 194 Spoiler rounds; 1,887 saves round-tripped; 18 min) |
| 5 | listing within Apple's limits | `godot --headless --path godot --script res://tests/listing_counts.gd && python3 tools/check_listing.py --counts /tmp/listing_counts.json` | `listing: 0 fails` | **pass** |
| 6 | app preview within Apple's spec | `tools/make_preview.sh` (records, encodes, checks) | `preview: 0 fails` | **pass** (21.0 s, 886x1920, 30 fps, 26.8 MB) |
| 7 | store screenshots current | `python3 tools/make_store_shots.py store/screenshots` after re-rendering the six states at the three sizes | 18 files, looked at by eye | **pass** (no visible change this pass; shop identical to the pixel, Gallery differs only by the idle bob) |
| 8 | iOS export dry run | `godot --headless --path godot --export-release "iOS" ../build/ios/Meldlings.ipa` | exit 0; `build/ios/` has the .xcodeproj, .pck, PrivacyInfo.xcprivacy | **pass** (Info.plist carries ITSAppUsesNonExemptEncryption = NO) |
| 9 | frame time (report, not a gate) | `godot --headless --path godot --script res://tests/frame_time_test.gd` | read the OVER lines | see `docs/AUDIT.md`; this machine varies 2x run to run |

## Not gates here (need a Mac or Ziah)

- Real Team ID and bundle id in `godot/export_presets.cfg` (placeholders now).
- Support and privacy pages live: turn on GitHub Pages for `docs/`, add the
  email where the pages say NEEDS ZIAH. URLs in `store/listing.md`.
- Copyright line and the "simulated gambling" age-rating answer.
- Price of the full-game unlock (the in-app purchase isn't built yet).
- Simulator and device checks, including safe areas (audit #18): MAC_HANDOFF.md step 5.
