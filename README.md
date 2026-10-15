# NetScanner for macOS

[![CI](https://github.com/Criseda/NetScanner-MacOS/actions/workflows/ci.yml/badge.svg)](https://github.com/Criseda/NetScanner-MacOS/actions/workflows/ci.yml)
![macOS](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange?logo=swift)
![License](https://img.shields.io/badge/License-GNU%20GPL--3.0-green)

A native macOS app for [NetScanner](https://github.com/Criseda/NetScanner),
the fast LAN scanner. Find every device on your network, then see which
services each one offers. No administrator rights needed.

No scanning logic lives here: the app runs the bundled `ns` engine and
shows its results in a SwiftUI interface built for macOS 26 and later
(Liquid Glass). It is the Mac sibling of
[NetScannerDesktop](https://github.com/Criseda/NetScannerDesktop) for
Windows.

## Features

- **Discovery**: TCP, mDNS, SSDP and ARP discovery of a subnet (or ICMP
  ping), with hostnames; this Mac's networks are one click away.
- **Port scan**: open TCP ports with service names, categories and IANA
  assignments, and one-click "Open in Browser" for web services.
- Sortable, searchable tables with customizable columns, an inspector
  for host details, copy as text, and CSV export.
- Every action in the menu bar with a shortcut: ⌘R scan, ⌘. stop,
  ⌘1 / ⌘2 switch screens, ⌘F search.

## Build

Requires Xcode 26 or later.

```sh
Scripts/fetch-engine.sh    # downloads the pinned ns engine, checksum-verified
open NetScanner.xcodeproj  # then Run
```

Tests for everything that is not UI:

```sh
swift test --package-path Packages/NetScannerKit
```

See [AGENTS.md](AGENTS.md) for the architecture, conventions and
release notes.

## License

GNU GPL-3.0, see [LICENSE](LICENSE).
