import Foundation
import Testing

@testable import NetScannerKit

@Suite("Host sorting")
struct HostSortingTests {
    let named = DiscoveredHost(ip: IPv4(10, 0, 0, 9), source: .tcp, hostname: "nas")
    let unnamedLow = DiscoveredHost(ip: IPv4(10, 0, 0, 2), source: .arp)
    let unnamedHigh = DiscoveredHost(ip: IPv4(10, 0, 0, 10), source: .tcp)
    let other = DiscoveredHost(ip: IPv4(10, 0, 0, 3), source: .mdns, hostname: "Apple-TV")

    var hosts: [DiscoveredHost] { [unnamedHigh, named, unnamedLow, other] }

    @Test func sortsByIPNumerically() {
        let sorted = hosts.sorted(using: HostComparator(.ip))
        #expect(sorted.map(\.ip.description) == ["10.0.0.2", "10.0.0.3", "10.0.0.9", "10.0.0.10"])
        let reversed = hosts.sorted(using: HostComparator(.ip, order: .reverse))
        #expect(reversed.map(\.ip.description) == ["10.0.0.10", "10.0.0.9", "10.0.0.3", "10.0.0.2"])
    }

    @Test func keepsBlanksLastInBothDirectionsInAddressOrder() {
        let forward = hosts.sorted(using: HostComparator(.name))
        #expect(forward.map(\.ip.description) == ["10.0.0.3", "10.0.0.9", "10.0.0.2", "10.0.0.10"])
        let reverse = hosts.sorted(using: HostComparator(.name, order: .reverse))
        #expect(reverse.map(\.ip.description) == ["10.0.0.9", "10.0.0.3", "10.0.0.2", "10.0.0.10"])
    }

    @Test func sortsUnscannedHostsLast() {
        var scanned = unnamedHigh
        scanned.openPorts = []
        let sorted = [named, scanned].sorted(using: HostComparator(.openPorts, order: .reverse))
        #expect(sorted.first == scanned)
    }
}

@Suite("Open ports")
struct OpenPortTests {
    @Test func hidesDescriptionsThatRepeatTheName() {
        #expect(OpenPort(port: 80, service: "HTTP", iana: "http", description: "http").distinctDescription == nil)
        #expect(OpenPort(port: 22, service: "SSH", description: "Secure Shell").distinctDescription == "Secure Shell")
    }

    @Test func picksTheWebScheme() {
        #expect(OpenPort(port: 443, category: .web).webURL(host: IPv4(10, 0, 0, 1))?.absoluteString == "https://10.0.0.1:443")
        #expect(OpenPort(port: 8080, service: "HTTP alt", category: .web).webScheme == "http")
        #expect(OpenPort(port: 9443, iana: "tungsten-https", category: .web).webScheme == "https")
    }

    @Test func summarizes() {
        let ports = [OpenPort(port: 80, service: "HTTP"), OpenPort(port: 22, service: "SSH"), OpenPort(port: 443), OpenPort(port: 8123)]
        #expect(ports.summary() == "22 SSH, 80 HTTP, 443, +1 more")
        #expect([OpenPort]().summary() == "None open")
    }

    @Test func labelsUnknownCategories() {
        #expect(PortCategory(engineValue: "gaming")?.label == "Gaming")
        #expect(PortCategory(engineValue: nil) == nil)
    }
}

@Suite("Progress")
struct ProgressTests {
    @Test func clampsAndFormats() {
        let progress = ScanProgress(phase: .sweep, done: 127, total: 254)
        #expect(progress.fraction == 0.5)
        #expect(ScanProgress(phase: .identify, done: 12, total: 9).done == 9)
        #expect(ScanProgress(phase: .identify, done: 3, total: 9).countText == "3 of 9")
    }
}

@Suite("Export")
struct ExportTests {
    @Test func quotesCSVFields() {
        let csv = ResultExport.csv(headers: ["A", "B"], rows: [["x,y", "say \"hi\""], ["plain", ""]])
        #expect(csv == "A,B\r\n\"x,y\",\"say \"\"hi\"\"\"\r\nplain,\r\n")
    }

    @Test func flattensTabsInTSV() {
        #expect(ResultExport.tabSeparated(headers: ["A"], rows: [["a\tb\nc"]]) == "A\na b c\n")
    }
}
