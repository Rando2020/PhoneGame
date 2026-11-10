#!/usr/bin/env bash
# Build the three iOS plugins (MeldAccess, MeldShare, MeldStore) as Godot 4.3
# xcframeworks, debug and release, device (arm64) and simulator (arm64 + x86_64).
#
# Needs macOS with Xcode. Usage:
#   tools/ios/build_plugins.sh <path to godot 4.3 source with generated headers> <out dir>
#
# The flags follow godotengine/godot-ios-plugins (the official plugin repo):
# Objective-C++ with ARC, C++17, IOS_ENABLED/UNIX_ENABLED, and DEBUG_ENABLED
# only in the debug variant (export templates are built that way; an ABI
# mismatch here crashes at bind time, not at link time).
set -euo pipefail

GODOT="$(cd "$1" && pwd)"
OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIN_IOS=15.0
PLUGINS=(meld_access meld_share meld_store)

SDK_DEV="$(xcrun --sdk iphoneos --show-sdk-path)"
SDK_SIM="$(xcrun --sdk iphonesimulator --show-sdk-path)"

# slice name -> "sdk|clang target triple" (no associative arrays: macOS bash is 3.2)
slice_info() {
	case "$1" in
	dev_arm64) echo "$SDK_DEV|arm64-apple-ios$MIN_IOS" ;;
	sim_arm64) echo "$SDK_SIM|arm64-apple-ios$MIN_IOS-simulator" ;;
	sim_x86_64) echo "$SDK_SIM|x86_64-apple-ios$MIN_IOS-simulator" ;;
	esac
}

COMMON=(
	-std=gnu++17 -fobjc-arc -fblocks -fno-exceptions -fvisibility=hidden
	-fno-strict-aliasing -Wall -Werror -Wno-ambiguous-macro
	-DIOS_ENABLED -DUNIX_ENABLED -DCOREAUDIO_ENABLED -DPTRCALL_ENABLED
	-I"$GODOT" -I"$GODOT/platform/ios"
)

fail=0
for p in "${PLUGINS[@]}"; do
	src="$ROOT/ios_plugin/$p"
	for variant in debug release; do
		if [ "$variant" = debug ]; then vflags=(-O0 -g -DDEBUG_ENABLED); else vflags=(-O2 -DNDEBUG); fi
		libs_dev=()
		libs_sim=()
		for slice in dev_arm64 sim_arm64 sim_x86_64; do
			IFS='|' read -r sdk triple <<<"$(slice_info "$slice")"
			obj="$OUT/obj/$p/$variant/$slice"
			mkdir -p "$obj"
			objs=()
			slice_ok=1
			# Swift first: it writes the <module>-Swift.h header the .mm imports.
			for s in "$src"/*.swift; do
				[ -e "$s" ] || continue
				echo "== swiftc $p $variant $slice $(basename "$s")"
				sopt=-Onone
				[ "$variant" = release ] && sopt=-O
				xcrun swiftc -parse-as-library -module-name "$p" -warnings-as-errors \
					-target "$triple" -sdk "$sdk" "$sopt" \
					-emit-objc-header -emit-objc-header-path "$obj/$p-Swift.h" \
					-c "$s" -o "$obj/$(basename "$s" .swift).o" || { fail=1; slice_ok=0; continue; }
				objs+=("$obj/$(basename "$s" .swift).o")
			done
			for m in "$src"/*.mm; do
				echo "== clang++ $p $variant $slice $(basename "$m")"
				xcrun clang++ -target "$triple" -isysroot "$sdk" "${COMMON[@]}" "${vflags[@]}" \
					-I"$obj" -c "$m" -o "$obj/$(basename "$m" .mm).o" || { fail=1; slice_ok=0; continue; }
				objs+=("$obj/$(basename "$m" .mm).o")
			done
			# A slice with any failed source gets no library, so no partial xcframework.
			[ "$slice_ok" = 1 ] && [ "${#objs[@]}" -gt 0 ] || continue
			xcrun libtool -static -o "$obj/$p.a" "${objs[@]}"
			if [ "$slice" = dev_arm64 ]; then libs_dev+=("$obj/$p.a"); else libs_sim+=("$obj/$p.a"); fi
		done
		if [ "${#libs_dev[@]}" -eq 1 ] && [ "${#libs_sim[@]}" -eq 2 ]; then
			fat="$OUT/obj/$p/$variant/sim_fat"
			mkdir -p "$fat"
			xcrun lipo -create "${libs_sim[@]}" -output "$fat/$p.a"
			rm -rf "$OUT/$p/$p.$variant.xcframework"
			mkdir -p "$OUT/$p"
			xcodebuild -create-xcframework -library "${libs_dev[0]}" -library "$fat/$p.a" \
				-output "$OUT/$p/$p.$variant.xcframework"
		else
			echo "!! $p $variant: missing slices, no xcframework"
			fail=1
		fi
	done
	cp "$src/$p.gdip" "$OUT/$p/" 2>/dev/null || true
done

echo
echo "== built:"
find "$OUT" -maxdepth 2 -name '*.xcframework' | sort
exit "$fail"
