# MeldStore (iOS plugin for Godot 4.3): the full-game unlock

StoreKit 2 behind an Engine singleton "MeldStore" that the game's
`Entitlement` and end card use (`godot/engine/entitlement.gd`,
`godot/ui/run_flow.gd`). The game side is tested with a stand-in
(`godot/tests/entitlement_test.gd`).

**Status: unverified.** Written on Linux without Xcode, never compiled.
StoreKit 2 is Swift-only, so `MeldStoreKit.swift` does the store work and
`meld_store.mm` (Objective-C++) bridges it to Godot. Expect fixes on the
first build, mostly around the Swift bridging header name.

## Build (on a Mac)

As `ios_plugin/meld_access/README.md`: build against Godot 4.3's headers in
the `godot-ios-plugins` layout, as an xcframework, with `MeldStoreKit.swift`
in the target (Swift 5.5 or later; iOS 15 or later for StoreKit 2). Copy
`meld_store.gdip` and the xcframework to `godot/ios/plugins/meld_store/`,
tick Plugins > MeldStore in the iOS export preset, export again.

Note: StoreKit 2 needs iOS 15. The preset's minimum is iOS 14.0; raise it to
15.0 when this plugin goes in (`application/min_ios_version`).

## Test in Xcode without App Store Connect

Add a StoreKit Configuration file (File > New > StoreKit Configuration File)
with one non-consumable, id `com.meldlings.full`, and select it in the
scheme (Run > Options > StoreKit Configuration). Purchases then run locally:
buy, cancel, Ask to Buy and refunds can all be tried from Xcode's
Debug > StoreKit > Manage Transactions.
