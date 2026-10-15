#!/bin/bash
# Builds the Release app and packs it into the zip that GitHub Releases
# and the Homebrew cask (Criseda/homebrew-tap) serve.
#
# Usage:
#   Scripts/package-release.sh            # writes build/release/NetScanner-<version>.zip
#
# Run Scripts/fetch-engine.sh first. The app is ad-hoc signed ("Sign to
# Run Locally"), not Developer ID signed or notarized, so Gatekeeper
# asks the user to allow it on first launch. The cask's caveats say how.
#
# Prints the zip's path and SHA-256 last, for the cask.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
config="$repo_root/Config/Version.xcconfig"
build_dir="$repo_root/build/release"

version="$(sed -n 's/^[[:space:]]*MARKETING_VERSION[[:space:]]*=[[:space:]]*\([^[:space:]]*\).*/\1/p' "$config")"
[[ -n "$version" ]] || { echo "error: MARKETING_VERSION is not set in $config" >&2; exit 1; }

[[ -x "$repo_root/Engine/ns" ]] || { echo "error: Engine/ns is missing; run Scripts/fetch-engine.sh" >&2; exit 1; }

rm -rf "$build_dir"
xcodebuild build \
    -project "$repo_root/NetScanner.xcodeproj" \
    -scheme NetScanner \
    -configuration Release \
    -derivedDataPath "$build_dir/DerivedData" \
    -quiet

app="$build_dir/DerivedData/Build/Products/Release/NetScanner.app"
[[ -d "$app" ]] || { echo "error: the build produced no $app" >&2; exit 1; }

# Both the app and the embedded engine must carry a valid signature, or
# Apple silicon refuses to run them and macOS hides the ARP table.
codesign --verify --deep --strict "$app"
codesign --verify --strict "$app/Contents/Helpers/ns"

# ditto keeps the bundle's symlinks, extended attributes and signature
# intact, which zip(1) does not.
zip="$build_dir/NetScanner-$version.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"

echo "$zip"
shasum -a 256 "$zip" | cut -d' ' -f1
