#!/bin/bash
# Installs the ns scan engine that the app bundles, into Engine/ns.
#
# The app is only a frontend: scanning lives in Criseda/NetScanner.
# Rather than committing a binary, this downloads the release pinned in
# Config/Version.xcconfig for both Mac architectures, verifies each
# against its pinned SHA-256, and joins them into one universal binary.
#
# Usage:
#   Scripts/fetch-engine.sh                  # pinned release (skips if present)
#   Scripts/fetch-engine.sh --force          # re-download even if present
#   Scripts/fetch-engine.sh --local PATH     # use a locally built ns instead,
#                                            # e.g. ../NetScanner/zig-out/bin/ns
#
# Output: Engine/ns (gitignored) and Engine/ns.version.
#
# The binary is ad-hoc signed here with a reverse-DNS identifier and the
# hardened runtime. macOS hides the kernel ARP table (MAC addresses,
# manufacturers, quiet hosts) from binaries without a real code
# identity. Xcode's Code Sign On Copy re-signs it with the app's
# identity when embedding it, and preserves the identifier and flags.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
config="$repo_root/Config/Version.xcconfig"
engine_dir="$repo_root/Engine"
engine="$engine_dir/ns"
version_file="$engine_dir/ns.version"

force=false
local_engine=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) force=true ;;
        --local)
            [[ $# -ge 2 ]] || { echo "error: --local needs a path to an ns binary" >&2; exit 1; }
            local_engine="$2"
            shift
            ;;
        -h | --help) sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "error: unknown option $1" >&2; exit 1 ;;
    esac
    shift
done

# Reads `KEY = value` from the xcconfig.
setting() {
    local value
    value="$(sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\([^[:space:]]*\).*/\1/p" "$config")"
    [[ -n "$value" ]] || { echo "error: $1 is not set in $config" >&2; exit 1; }
    printf '%s' "$value"
}

mkdir -p "$engine_dir"

sign() {
    codesign --force --sign - --identifier io.github.criseda.netscanner --options runtime "$engine" 2>/dev/null
}

if [[ -n "$local_engine" ]]; then
    [[ -x "$local_engine" ]] || { echo "error: $local_engine is not an executable" >&2; exit 1; }
    cp "$local_engine" "$engine"
    sign
    printf 'local %s\n' "$("$engine" --version)" > "$version_file"
    echo "Installed local engine $("$engine" --version) to $engine"
    exit 0
fi

version="$(setting NETSCANNER_ENGINE_VERSION)"
if [[ "$force" == false && -x "$engine" && "$(cat "$version_file" 2>/dev/null)" == "$version" ]]; then
    echo "ns $version already present at $engine"
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Downloads and verifies one architecture's release zip, and prints the
# path of the ns binary inside it.
fetch_arch() {
    local asset="$1" expected="$2"
    local url="https://github.com/Criseda/NetScanner/releases/download/$version/$asset.zip"
    local zip="$work/$asset.zip"

    # Fail closed: nothing is unpacked or run without a hash to check.
    [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { echo "error: no valid SHA-256 pinned for $asset" >&2; exit 1; }

    echo "Downloading $url" >&2
    curl --fail --silent --show-error --location --proto '=https' --output "$zip" "$url"

    local actual
    actual="$(shasum -a 256 "$zip" | cut -d' ' -f1)"
    if [[ "$actual" != "$expected" ]]; then
        echo "error: SHA-256 mismatch for $asset.zip: expected $expected, got $actual" >&2
        exit 1
    fi

    mkdir -p "$work/$asset"
    unzip -q "$zip" -d "$work/$asset"
    local binary
    binary="$(find "$work/$asset" -type f -name ns | head -n 1)"
    [[ -n "$binary" ]] || { echo "error: $asset.zip contains no ns binary" >&2; exit 1; }
    printf '%s' "$binary"
}

arm64="$(fetch_arch macos-arm64 "$(setting NETSCANNER_ENGINE_SHA256_ARM64)")"
x86_64="$(fetch_arch macos-x86_64 "$(setting NETSCANNER_ENGINE_SHA256_X86_64)")"

lipo -create "$arm64" "$x86_64" -output "$engine"
chmod 755 "$engine"
sign
printf '%s\n' "$version" > "$version_file"

echo "Installed ns $("$engine" --version) ($(lipo -archs "$engine")) to $engine"
