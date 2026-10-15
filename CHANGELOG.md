# Changelog

## Unreleased

First version of the native macOS app:

- Discovery (`ns -s`) of a subnet with TCP, multicast and ARP, or ICMP
  ping, optionally identifying devices; this Mac's networks are offered
  as targets, and sweeps above 4,096 hosts ask first.
- Port scans (`ns -p`) with service names, categories and IANA names;
  web ports open in the browser.
- Sortable, searchable tables with customizable columns, a host
  inspector, copy as text and CSV export.
- Scan menu with shortcuts, a Settings window for port scan defaults,
  and an About tab showing the bundled engine version.
- Asks for Local Network access at launch, so the first scan no longer
  finds only this Mac while the permission prompt is pending. Scans wait
  for the answer, and if access is denied, Discovery explains how to
  turn it on.
- Shows MAC addresses, manufacturers and quiet hosts found in the ARP
  table however the app is signed: macOS 27 hides that table from the
  engine but not from the app, so the app reads it and hands it to the
  engine (`--neighbor-table=parent`).
- Bundles NetScanner v1.7.0 as a universal binary.
- Released as `NetScanner-<version>.zip` on GitHub and as the
  `netscanner-app` cask in `criseda/tap` for Homebrew. Not notarized
  yet, so macOS asks to allow the first launch.
