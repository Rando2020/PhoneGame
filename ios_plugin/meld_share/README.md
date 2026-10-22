# MeldShare (iOS plugin for Godot 4.3): share a run card

The iOS share sheet (`UIActivityViewController`) for one PNG, behind an Engine
singleton "MeldShare". The game's Share button on a run's end draws the run
card (`godot/ui/fx/run_card.gd`), saves it to `user://`, then calls
`MeldShare.share_image(absolute_path)` when the singleton exists. Without the
plugin (desktop, editor, a build without it) the card is only saved and the
game says so; nothing else changes.

**Status: unverified.** Written on Linux without Xcode, never compiled.
Objective-C++ only (no Swift), so it should be the simplest of the three
plugins to build.

## Build (on a Mac)

As `ios_plugin/meld_access/README.md`: build against Godot 4.3's headers in
the `godot-ios-plugins` layout, as an xcframework (`meld_share.xcframework`)
from `meld_share.mm` and `meld_share_module.mm`. Copy `meld_share.gdip` and
the xcframework to `godot/ios/plugins/meld_share/`, tick Plugins > MeldShare
in the iOS export preset, export again.

## Check on a device

1. Play a run to its end (or lose one quickly), tap Share.
2. The share sheet opens with the card image: Save Image, Messages, AirDrop.
3. iPad: the sheet opens as a popover above the bottom edge (it needs an
   anchor; the plugin sets one). A missing anchor crashes on iPad.
4. Cancel: the game stays on the run's end; nothing else happens.

No permission prompt is needed to share. "Save Image" may ask for Photos
add-only access the first time: add `NSPhotoLibraryAddUsageDescription`
("Save your run card to Photos.") to the Info.plist via the export preset's
additional plist content, or Save Image is missing from the sheet.
