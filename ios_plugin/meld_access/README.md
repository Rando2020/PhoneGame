# MeldAccess (iOS plugin for Godot 4.3)

Lets the game follow the phone's Reduce Motion and text size (Dynamic Type).
Godot 4.3 can't read either. The game side is already wired and tested with
a stand-in (`godot/tests/os_access_test.gd`).

**Status: unverified.** Written on Linux without Xcode. It has never been
compiled or run. Expect small fixes on the first build.

## Build (on a Mac)

These steps follow the layout of Godot's official plugin repo
(github.com/godotengine/godot-ios-plugins, which builds plugins against the
engine's headers with SCons).

1. Clone that repo. Check out the branch or tag that matches Godot 4.3, and
   fetch the engine headers it asks for (its README: `./scripts/generate_headers.sh`).
2. Copy this folder in as `plugins/meld_access/`.
3. Add an SConstruct target for it, the same way as the repo's other plugins:
   sources `meld_access.mm` and `meld_access_module.mm`, framework UIKit.
4. Build release and debug for device (arm64) and simulator, then make the
   xcframework: `./scripts/release_xcframework.sh meld_access 4.0`. Adjust
   the script name and arguments to the repo's README.
5. Copy `meld_access.gdip` and `meld_access.xcframework` into
   `godot/ios/plugins/meld_access/` in this project.
6. In the iOS export preset, tick Plugins > MeldAccess, then export again.

## Check on a simulator

- Settings > Accessibility > Motion > Reduce Motion on: a new game should
  start with Reduce Motion on (Meldlings Settings shows On).
- Change Larger Text while a screen is up: it re-lays out at once.
- Settings > Accessibility > Display & Text Size > Larger Text, set to the
  XL or XXL step: Meldlings Settings shows Text size "Large". Above that step,
  or with accessibility sizes, it shows "Larger".
- Pick a value in Meldlings Settings: from then on the game keeps the
  player's choice over the phone's.
