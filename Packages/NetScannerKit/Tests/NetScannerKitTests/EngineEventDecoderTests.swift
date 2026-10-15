import Foundation
import Testing

@testable import NetScannerKit

/// Lines taken from NetScanner's `docs/README.md` ("Machine-readable
/// output"), so these tests double as a check on the documented protocol.
@Suite("Engine event decoding")
struct EngineEventDecoderTests {
    let decoder = EngineEventDecoder()

    func decode(_ line: String) -> EngineEvent? {
        decoder.decode(Data(line.utf8))
    }

    @Test func decodesStart() {
        let line = #"{"type":"start","mode":"subnet","cidr":"192.168.1.0/24","first":"192.168.1.0","last":"192.168.1.255"}"#
        #expect(decode(line) == .subnetStarted(first: IPv4(192, 168, 1, 0), last: IPv4(192, 168, 1, 255)))
    }

    @Test func decodesHostsWithEverySource() {
        #expect(decode(#"{"type":"host","ip":"192.168.1.10","source":"tcp"}"#) == .hostFound(IPv4(192, 168, 1, 10), .tcp))
        #expect(decode(#"{"type":"host","ip":"192.168.1.25","source":"arp"}"#) == .hostFound(IPv4(192, 168, 1, 25), .arp))
        #expect(decode(#"{"type":"host","ip":"10.0.0.2","source":"mdns"}"#) == .hostFound(IPv4(10, 0, 0, 2), .mdns))
        #expect(decode(#"{"type":"host","ip":"10.0.0.2"}"#) == .hostFound(IPv4(10, 0, 0, 2), .tcp))
    }

    @Test func keepsUnknownSourcesByName() {
        #expect(decode(#"{"type":"host","ip":"10.0.0.2","source":"llmnr"}"#) == .hostFound(IPv4(10, 0, 0, 2), .other("llmnr")))
        #expect(HostSource.other("llmnr").label == "LLMNR")
    }

    @Test func decodesHostDetailWithNulls() {
        let line = #"{"type":"host_detail","ip":"192.168.1.10","hostname":"nas-storage","mac":null,"vendor":"Synology Incorporated"}"#
        #expect(decode(line) == .hostDetail(HostDetail(ip: IPv4(192, 168, 1, 10), hostname: "nas-storage", macAddress: nil, vendor: "Synology Incorporated")))
    }

    @Test func decodesPorts() {
        let line = #"{"type":"port","port":3389,"service":"RDP","iana":"ms-wbt-server","description":"Remote Desktop Protocol (Windows)","category":"remote"}"#
        #expect(decode(line) == .portFound(OpenPort(port: 3389, service: "RDP", iana: "ms-wbt-server", description: "Remote Desktop Protocol (Windows)", category: .remote)))
        let unknown = #"{"type":"port","port":49152,"service":null,"iana":null,"description":null,"category":null}"#
        #expect(decode(unknown) == .portFound(OpenPort(port: 49152)))
        #expect(decode(#"{"type":"port","port":0}"#) == nil)
        #expect(decode(#"{"type":"port","port":65536}"#) == nil)
    }

    @Test func decodesProgress() {
        #expect(decode(#"{"type":"progress","phase":"sweep","done":120,"total":254}"#) == .progress(ScanProgress(phase: .sweep, done: 120, total: 254)))
        #expect(decode(#"{"type":"progress","phase":"sweep","done":1,"total":0}"#) == nil)
        #expect(decode(#"{"type":"progress","phase":"warp","done":1,"total":2}"#) == .progress(ScanProgress(phase: .other("warp"), done: 1, total: 2)))
    }

    @Test func decodesBothSummaries() {
        #expect(decode(#"{"type":"summary","hosts":2,"elapsed_ms":1843}"#) == .subnetFinished(hostCount: 2, elapsed: .milliseconds(1843)))
        #expect(decode(#"{"type":"summary","open_ports":[22,3389],"elapsed_ms":512}"#) == .portScanFinished(openPorts: [22, 3389], elapsed: .milliseconds(512)))
        #expect(decode(#"{"type":"summary","open_ports":[],"elapsed_ms":5}"#) == .portScanFinished(openPorts: [], elapsed: .milliseconds(5)))
    }

    @Test func decodesErrors() {
        #expect(decode(#"{"type":"error","message":"Invalid IP address"}"#) == .failure(message: "Invalid IP address"))
    }

    @Test func decodesNeighborsRequests() {
        #expect(decode(#"{"type":"neighbors_request","id":1}"#) == .neighborsRequest(id: 1))
        #expect(decode(#"{"type":"neighbors_request"}"#) == nil)
    }

    @Test(arguments: [
        "", "   ", "NetScanner: warning", "[1,2]", "{not json", #"{"type":"future_event","x":1}"#,
        #"{"type":"host","ip":"999.1.1.1"}"#, #"{"type":"summary"}"#, #"{"ip":"1.1.1.1"}"#,
    ])
    func ignoresWhatIsNotAnEvent(_ line: String) {
        #expect(decode(line) == nil)
    }
}

@Suite("Line splitting")
struct LineSplitterTests {
    @Test func joinsLinesAcrossChunks() {
        var splitter = LineSplitter()
        #expect(splitter.append(Data("{\"a\":1}\n{\"b\"".utf8)).map(string) == [#"{"a":1}"#])
        #expect(splitter.append(Data(":2}\r\n\n".utf8)).map(string) == [#"{"b":2}"#, ""])
        #expect(splitter.finish() == nil)
    }

    @Test func returnsAnUnterminatedLastLine() {
        var splitter = LineSplitter()
        #expect(splitter.append(Data("tail".utf8)).isEmpty)
        #expect(splitter.finish().map(string) == "tail")
        #expect(splitter.finish() == nil)
    }

    private func string(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }
}

@Suite("Scan requests")
struct ScanRequestTests {
    @Test func buildsDiscoveryArguments() throws {
        let subnet = try Subnet(validating: "192.168.1.0/24")
        #expect(ScanRequest.discovery(DiscoveryOptions(subnet: subnet)).arguments == ["-s", "192.168.1.0/24", "--resolve", "--json", "--neighbor-table=parent"])
        #expect(
            ScanRequest.discovery(DiscoveryOptions(subnet: subnet, method: .ping, identifyDevices: false)).arguments
                == ["-s", "192.168.1.0/24", "--ping", "--json", "--neighbor-table=parent"])
    }

    @Test func buildsPortScanArguments() {
        let host = IPv4(192, 168, 1, 1)
        #expect(ScanRequest.portScan(PortScanOptions(host: host, ports: .wellKnown)).arguments == ["-p", "192.168.1.1", "1-1024", "--json"])
        #expect(
            ScanRequest.portScan(PortScanOptions(host: host, ports: PortRange(22, 22), timeout: ProbeTimeout(milliseconds: 800))).arguments
                == ["-p", "192.168.1.1", "22-22", "--timeout", "800", "--json"])
    }
}
