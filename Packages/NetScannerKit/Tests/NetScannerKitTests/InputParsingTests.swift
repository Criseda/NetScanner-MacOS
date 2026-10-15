import Testing

@testable import NetScannerKit

@Suite("IPv4")
struct IPv4Tests {
    @Test(arguments: ["0.0.0.0", "192.168.1.10", "255.255.255.255"])
    func parsesDottedQuads(_ text: String) {
        #expect(IPv4(text)?.description == text)
    }

    @Test(arguments: [
        "", "192.168.1", "192.168.1.1.1", "256.1.1.1", "1..1.1", "0x1.1.1.1", " 1.1.1.1",
        "1.1.1.1/24", "١.١.١.١", "1234.1.1.1",
    ])
    func rejectsAnythingElse(_ text: String) {
        #expect(IPv4(text) == nil)
    }

    @Test func sortsNumerically() {
        #expect(IPv4(192, 168, 1, 9) < IPv4(192, 168, 1, 10))
    }

    @Test func recognizesSpecialRanges() {
        #expect(IPv4(169, 254, 3, 4).isLinkLocal)
        #expect(IPv4(127, 0, 0, 1).isLoopback)
        #expect(!IPv4(192, 168, 1, 1).isLinkLocal)
    }
}

@Suite("Subnet")
struct SubnetTests {
    @Test func parsesCIDR() throws {
        let subnet = try Subnet(validating: " 192.168.1.7/24 ")
        #expect(subnet.description == "192.168.1.7/24")
        #expect(subnet.networkAddress == IPv4(192, 168, 1, 0))
        #expect(subnet.broadcastAddress == IPv4(192, 168, 1, 255))
        #expect(subnet.contains(IPv4(192, 168, 1, 200)))
        #expect(!subnet.contains(IPv4(192, 168, 2, 1)))
    }

    @Test(arguments: [(24, 254), (16, 65_534), (30, 2), (31, 2), (32, 1)])
    func countsUsableHostsLikeTheEngine(prefix: Int, expected: Int) {
        #expect(Subnet(address: IPv4(10, 0, 0, 0), prefixLength: prefix).usableHostCount == expected)
    }

    @Test func rejectsBadInput() {
        #expect(throws: InputError.invalidSubnet) { try Subnet(validating: "192.168.1.0") }
        #expect(throws: InputError.invalidSubnet) { try Subnet(validating: "192.168.1/24") }
        #expect(throws: InputError.invalidPrefixLength) { try Subnet(validating: "10.0.0.0/33") }
        #expect(throws: InputError.invalidPrefixLength) { try Subnet(validating: "10.0.0.0/-1") }
        #expect(throws: InputError.subnetTooLarge(hostCount: 131_070)) {
            try Subnet(validating: "10.0.0.0/15")
        }
    }
}

@Suite("Port range and timeout")
struct PortRangeTests {
    @Test func parsesRangesAndSinglePorts() throws {
        #expect(try PortRange(validating: "1-1024") == .wellKnown)
        #expect(try PortRange(validating: "1024 - 1") == .wellKnown)
        #expect(try PortRange(validating: "80").count == 1)
        #expect(try PortRange(validating: "80").engineArgument == "80-80")
    }

    @Test func rejectsBadRanges() {
        #expect(throws: InputError.invalidPortRange) { try PortRange(validating: "") }
        #expect(throws: InputError.invalidPortRange) { try PortRange(validating: "1-2-3") }
        #expect(throws: InputError.invalidPortRange) { try PortRange(validating: "a-b") }
        #expect(throws: InputError.portOutOfRange) { try PortRange(validating: "0-10") }
        #expect(throws: InputError.portOutOfRange) { try PortRange(validating: "1-70000") }
        #expect(throws: InputError.portOutOfRange) { try PortRange(validating: "99999999999") }
    }

    @Test func parsesTimeouts() throws {
        #expect(try ProbeTimeout.parse("") == nil)
        #expect(try ProbeTimeout.parse(" 500 ")?.milliseconds == 500)
        #expect(throws: InputError.invalidTimeout) { try ProbeTimeout.parse("0") }
        #expect(throws: InputError.invalidTimeout) { try ProbeTimeout.parse("60001") }
        #expect(throws: InputError.invalidTimeout) { try ProbeTimeout.parse("fast") }
    }
}

@Suite("Pasted input")
struct PastedInputTests {
    @Test func toleratesSurroundingNewlines() throws {
        #expect(try Subnet(validating: "10.0.0.0/24\n").prefixLength == 24)
        #expect(try PortRange(validating: "1-1024\n") == .wellKnown)
        #expect(try ProbeTimeout.parse("500\n")?.milliseconds == 500)
    }
}
