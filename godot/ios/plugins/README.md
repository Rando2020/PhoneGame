# Prebuilt iOS plugins

Built by `.github/workflows/ios-plugins.yml` (run 41188339970, 2026-10-31,
Xcode 16.4, Godot 4.3-stable headers, 0 warnings) from `ios_plugin/`. Each
folder holds `<name>.debug.xcframework`, `<name>.release.xcframework` and the
`.gdip` (copied from `ios_plugin/<name>/`). The iOS preset turns all three on.

Do not edit these by hand. After changing `ios_plugin/`, take the new
`ios-plugins` artifact from that workflow (or run `tools/ios/build_plugins.sh`
on a Mac) and replace them. `ios-build.yml` always rebuilds them fresh before
it exports, so CI never builds against stale copies.
