# Working in this repo (notes for humans and agents)

NetScanner for macOS is a native SwiftUI frontend for
[NetScanner](https://github.com/Criseda/NetScanner), the Zig LAN
scanner (`ns`). It is the macOS sibling of
[NetScannerDesktop](https://github.com/Criseda/NetScannerDesktop) (WinUI 3
on Windows): same engine, same features, but written to feel like an
app Apple could have shipped.

The goals, in order:

1. **Clean, maintainable code.** Someone new should understand any file
   in one read. This matters more than cleverness or brevity.
2. **Performance.** Scans take about a second; the UI must never be the
   slow part, even with thousands of hosts or open ports.
3. **A real Mac app.** Follows the Human Interface Guidelines and the
   macOS 26+ design language (Liquid Glass), and is shippable as a
   Homebrew cask and, later, on the Mac App Store.

## The engine is the source of truth

No scanning logic lives here. The app runs the bundled `ns` binary with
`--json`, reads its NDJSON event stream, and shows the results. If a
feature needs new scanning behavior, it belongs in the NetScanner repo
first (with its tests and CHANGELOG entry), and reaches this app as a
new pinned engine version.

The event protocol is documented in NetScanner's `docs/README.md`
("Machine-readable output"). Key rules the parser must keep honoring:

- One JSON object per line, each with a `type`: `start`, `host`,
  `host_detail`, `port`, `progress`, `summary`, `error`.
- Unknown `type`s and unknown `host.source` / `port.category` values are
  normal (the engine adds them over time): ignore unknown types, show
  unknown sources and categories by their own name. Never crash or drop
  the host.
- `progress` is per phase (`sweep`, `arp`, `identify`, `ports`), may
  skip counts, and `done` only increases within a phase. Show the
  latest event, never count them.
- Input errors come as `{"type":"error"}` with exit status 1;
  diagnostics stay on stderr as plain text.

The app only ever runs the `ns` it ships with (in
`NetScanner.app/Contents/Helpers/ns`). It never downloads code, so a new
engine reaches users as a new app release, which is also what the App
Store requires. Debug builds alone honor `NETSCANNER_ENGINE=/path/to/ns`
to try an unreleased engine.

### macOS specifics that bite

- **Code identity.** macOS hides the kernel ARP table from binaries
  without a real code identity. `Scripts/fetch-engine.sh` ad-hoc signs
  `Engine/ns` with the identifier `io.github.criseda.netscanner` and the
  hardened runtime; the target's "Embed Scan Engine" Copy Files phase
  (Code Sign On Copy) re-signs it with the app's identity and preserves
  that identifier. Do not drop the pre-signing.
- **Local Network privacy.** The app is the responsible process for
  `ns`, so `NSLocalNetworkUsageDescription` in `Config/Info.plist` is
  what makes the system ask the user once. Until they answer, local
  traffic fails silently, so a scan that is the app's first network use
  finds only this Mac. To avoid that, `LocalNetworkPermission` (in
  NetScannerKit) runs at launch and whenever the app becomes active
  without access: it advertises and browses a private Bonjour service
  (`_netscanner._tcp`, listed under `NSBonjourServices`), which shows
  the prompt and reports granted, denied or undetermined. Scans wait
  for that answer (the status capsule says so); a denial blocks
  Discovery with a screen that links to Privacy & Security. Port scans
  still run, since the host may be off the local network. The grant
  belongs to the app's code signature, so a build signed differently
  (ad-hoc vs. a team certificate) is a new app to macOS and is asked
  again.
- **The app reads the ARP table for the engine.** On macOS 27 the
  kernel hides the ARP table from the `sysctl(NET_RT_FLAGS,
  RTF_LLINFO)` dump (it returns 0 bytes, with no error and nothing
  logged) unless the process chain is trusted. Measured with a test app
  and the bundled `ns` (October 2026):
  - The app's **own process** can always read the table, even when it
    is ad-hoc signed.
  - **Children of an ad-hoc signed app** (Xcode's "Sign to Run
    Locally", which is what `CODE_SIGN_IDENTITY = "-"` gives) always
    get an empty table. That holds for every child: `ns` with any
    signature, Apple's own `/usr/sbin/arp`, children started through
    `/bin/sh` or `/usr/bin/env`, and children that disclaim
    responsibility. An Apple Development certificate (free personal
    team) does not help either.
  - **Children of a Developer ID signed, notarized app** that
    LaunchServices started can read it; a non-Apple binary between the
    app and `ns` hides it again.

  So discovery scans run `ns` with `--neighbor-table=parent` (the first
  engine release after v1.6.0; see "Neighbor table from the parent" in NetScanner's
  `docs/README.md`). Each time `ns` needs the table it prints
  `{"type":"neighbors_request","id":N}` and waits up to 2 seconds for
  one line on stdin. `EngineRun` answers from the stdout handler (off
  the main actor) with `NeighborTable.read()`, a pure Swift port of the
  engine's `macos_dump` in `src/c/neighbors.c`: the raw table, every
  entry `stale`, no filtering. Everything an entry means (which hosts
  it proves, the confirming pings, the manufacturer lookup) stays in
  the engine. If the read fails the reply carries an `error` and `ns`
  reads the table itself. This works with any signature, so MAC
  addresses, manufacturers and ARP-found quiet hosts show in ad-hoc
  Debug builds too. Keep `ns` spawned directly by the app, keep its
  stdin a pipe the app owns, and keep `ns` signed with a reverse-DNS
  identifier (`io.github.criseda.netscanner`) as before.
- **Script sandboxing.** `ENABLE_USER_SCRIPT_SANDBOXING` is on. Build
  phases must declare their inputs and outputs, and tools that write
  temporary files next to outputs (codesign) fail inside it, which is
  why the engine is signed by the fetch script rather than a build
  phase.

## Layout

```
NetScanner.xcodeproj         Xcode project (folders are synchronized: add
                             files on disk, no project edits needed)
NetScanner/                  The app target: SwiftUI only
  App/                       App entry, scenes, commands, app-wide state
  Features/Discovery/        Host discovery (ns -s)
  Features/PortScan/         Port scan (ns -p)
  Features/Settings/         Settings scene (⌘,) and About
  Shared/                    Small reusable views and view helpers
  Resources/                 Asset catalog
Packages/NetScannerKit/      Swift package: everything that is not UI
  Sources/NetScannerKit/
    Engine/                  Process runner, NDJSON line splitter, parser
    Models/                  Host, OpenPort, ScanProgress, ...
    Network/                 IPv4/CIDR types, validation, local subnets
    Export/                  CSV and plain-text table formatting
  Tests/NetScannerKitTests/  Swift Testing suites
Config/                      Info.plist (merged into the generated one), Version.xcconfig
Engine/                      ns, installed by fetch-engine.sh (gitignored)
Scripts/                     fetch-engine.sh
```

The split is deliberate: `NetScannerKit` has no SwiftUI or AppKit
imports, so its logic is tested with plain `swift test` in seconds,
and the app target stays thin views plus `@Observable` models.

## Commands

```sh
Scripts/fetch-engine.sh                    # download the pinned ns (universal), checksum-verified
swift test --package-path Packages/NetScannerKit
xcodebuild -project NetScanner.xcodeproj -scheme NetScanner -configuration Debug build
```

`fetch-engine.sh --local ../NetScanner/zig-out/bin/ns` installs a locally
built engine instead (build it with `zig build -Doptimize=ReleaseFast`
in the NetScanner repo). The Xcode build does not download anything:
run `fetch-engine.sh` once after cloning and after changing the pinned
version, or the build stops with a missing-input error for `Engine/ns`.

Tests must be green and the app must build without warnings before any
PR.

## Versions

Every version lives in `Config/Version.xcconfig`, and nothing else
restates them:

- `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`: the app.
- `NETSCANNER_ENGINE_VERSION` plus `NETSCANNER_ENGINE_SHA256_ARM64` and
  `NETSCANNER_ENGINE_SHA256_X86_64`: the bundled engine and the SHA-256
  of its `macos-arm64.zip` / `macos-x86_64.zip` release assets. The
  fetch script refuses a download that does not match.

## Changelog per change

Like the engine repo, every user-facing change gets an entry under
`## Unreleased` in `CHANGELOG.md` in the same commit or PR.

## Swift style

- Swift 6 language mode with complete strict concurrency. The app target
  defaults to `MainActor` isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION`);
  `NetScannerKit` does not, and its types are explicitly `Sendable`. No
  `@unchecked Sendable`, `nonisolated(unsafe)` or `@preconcurrency`
  unless a comment explains why it is sound.
- UI state is `@Observable` and `@MainActor`. Engine work (process I/O,
  JSON decoding) runs off the main actor; the main actor only receives
  finished, typed events.
- Value types for data (`struct`, `enum`). Classes only for identity
  and observation.
- No force unwraps or `try!` outside tests. Errors are typed enough to
  show the user a sentence, not a stack.
- No third-party dependencies. Foundation, SwiftUI, AppKit (only where
  SwiftUI has no equivalent), Network, SystemConfiguration.
- Human-readable first. Doc comments explain *why*, not *what*. One
  type per file when the type is more than a few lines.
- User-facing strings are written for `String(localized:)` /
  `LocalizedStringKey` so the app can be localized later; counts use
  `String.inflected` (automatic grammar agreement), never a hand-rolled
  plural.
- Format with `swift format` (Xcode: Editor ▸ Structure ▸ Format File)
  on the files you touch.

## UI and UX

- Native components first: `NavigationSplitView`, `Table`, `.inspector`,
  `.searchable`, `ContentUnavailableView`, `Settings` scene, menu
  `Commands`, SF Symbols. A custom control needs a reason.
- Liquid Glass (macOS 26+): toolbars and sidebars get it from the
  system; don't paint over them. Use `.glassEffect` sparingly, for
  floating chrome over content (the scan status capsule), and
  `.buttonStyle(.glassProminent)` for the one primary action per
  window. Content (tables, text) is never glass.
- Every action is reachable from the keyboard and the menu bar
  (⌘R scan, ⌘. stop, ⌘F search, ⌘C copy rows) and has an accessibility
  label. Respect Reduce Motion, Reduce Transparency, Increase Contrast,
  Dynamic Type sizes and Dark Mode; test each when touching visuals.
- Plain language. Explain what a scan does and why something failed in
  a sentence a non-network-engineer understands.

## Performance

- Parse lines as they arrive; never wait for the process to exit to
  show results.
- Hosts and ports are keyed by stable IDs (IPv4 as `UInt32`, port
  number) so `Table` diffing stays cheap. Sorting and filtering happen
  once per change of sort/filter/results, not per row render.
- Batch UI updates: coalesce engine events into one main-actor update
  per frame-ish interval rather than one per line. The engine can emit
  hundreds of lines in a burst.
- Measure before optimizing (Instruments: SwiftUI, Time Profiler), and
  say in the PR what was measured.

## Distribution

- **Homebrew cask** (first target): Developer ID signed, hardened
  runtime, notarized and stapled `.dmg` or `.zip`. Homebrew requires
  signed and notarized apps for new casks.
- **Mac App Store** (later, needs a paid developer account): requires
  App Sandbox. Open questions to verify before committing to it:
  whether a sandboxed child can read the ARP table via `sysctl`, open
  unprivileged ICMP sockets, and send multicast. The engine (and this
  app) are GPL-3.0; the copyright holder can publish on the App Store,
  but outside contributions would need a CLA or license grant for that.

## Git

Branch per change, PR to `main`. Commit messages say why, in the
imperative.
