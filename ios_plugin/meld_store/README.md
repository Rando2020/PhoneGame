# MeldStore (iOS plugin for Godot 4.3): the full-game unlock

StoreKit 2 behind an Engine singleton "MeldStore" that the game's
`Entitlement` and end card use (`godot/engine/entitlement.gd`,
`godot/ui/run_flow.gd`). The game side is tested with a stand-in
(`godot/tests/entitlement_test.gd`).

**Status: compiles, never run on a device.** Built on every push by
`.github/workflows/ios-plugins.yml` (debug and release, device arm64 and
simulator arm64 + x86_64, warnings are errors) and linked into the real app
by `ios-build.yml`. `tools/ios/build_plugins.sh` does the build; no Mac
needed. Whether it behaves right on an iPhone is unverified until TestFlight.

StoreKit 2 is Swift-only, so `MeldStoreKit.swift` does the store work and
`meld_store.mm` (Objective-C++) bridges it to Godot. What the first compile
found (2026-10-31): three data races (state captured across threads; Swift 6
makes them errors), fixed by putting `MeldStoreKit` on the main actor; and a
link failure (`__swift_FORCE_LOAD_$_swiftCompatibility56`) because Godot's
Xcode project has no Swift of its own, fixed by the Swift library paths and
the `/usr/lib/swift` rpath in `meld_store.gdip`'s `linker_flags`. The bridging
header name (`meld_store-Swift.h`) was right.

## Build (on a Mac)

As `ios_plugin/meld_access/README.md`: build against Godot 4.3's headers in
the `godot-ios-plugins` layout, as an xcframework, with `MeldStoreKit.swift`
in the target (Swift 5.5 or later; iOS 15 or later for StoreKit 2). Copy
`meld_store.gdip` and the xcframework to `godot/ios/plugins/meld_store/`,
tick Plugins > MeldStore in the iOS export preset, export again.

StoreKit 2 needs iOS 15: the preset's minimum is 15.0 (`application/min_ios_version`).

## Test in Xcode without App Store Connect

Add a StoreKit Configuration file (File > New > StoreKit Configuration File)
with one non-consumable, id `com.meldlings.full`, and select it in the
scheme (Run > Options > StoreKit Configuration). Purchases then run locally:
buy, cancel, Ask to Buy and refunds can all be tried from Xcode's
Debug > StoreKit > Manage Transactions.
