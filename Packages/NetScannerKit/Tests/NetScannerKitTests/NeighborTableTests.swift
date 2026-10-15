import Darwin
import Foundation
import Testing

@testable import NetScannerKit

@Suite("ARP table")
struct NeighborTableTests {
    @Test func readsResolvedEntriesFromARouteDump() {
        var dump = Data()
        dump += routeMessage(ip: (192, 168, 1, 1), interface: "en0", mac: [0xAA, 0xBB, 0xCC, 0x0D, 0x0E, 0x0F])
        // Asked about, nobody answered: no link-layer address.
        dump += routeMessage(ip: (192, 168, 1, 7), interface: "en0", mac: [])
        dump += routeMessage(ip: (10, 0, 0, 2), interface: "", mac: [0, 1, 2, 3, 4, 5])
        let entries = dump.withUnsafeBytes { NeighborTable.entries(inRouteDump: $0) }
        #expect(
            entries == [
                NeighborEntry(ip: IPv4(192, 168, 1, 1), macAddress: "aa:bb:cc:0d:0e:0f"),
                NeighborEntry(ip: IPv4(10, 0, 0, 2), macAddress: "00:01:02:03:04:05"),
            ])
    }

    @Test func stopsAtTruncatedOrEmptyMessages() {
        let message = routeMessage(ip: (192, 168, 1, 1), interface: "en0", mac: [1, 2, 3, 4, 5, 6])
        let truncated = message.dropLast(4)
        #expect(Data(truncated).withUnsafeBytes { NeighborTable.entries(inRouteDump: $0) }.isEmpty)
        let zeroLength = Data(count: MemoryLayout<rt_msghdr>.size) + message
        #expect(zeroLength.withUnsafeBytes { NeighborTable.entries(inRouteDump: $0) }.isEmpty)
    }

    @Test func readsThisMacsTable() throws {
        // The content depends on the network; reading it must not fail.
        _ = try NeighborTable.read()
    }

    @Test func encodesTheReply() {
        let table = [NeighborEntry(ip: IPv4(192, 168, 1, 1), macAddress: "aa:bb:cc:dd:ee:ff")]
        #expect(
            line(NeighborsReply(id: 1, table: .success(table)))
                == #"{"entries":[{"ip":"192.168.1.1","mac":"aa:bb:cc:dd:ee:ff","state":"stale"}],"id":1,"type":"neighbors"}"# + "\n")
        #expect(
            line(NeighborsReply(id: 2, table: .success([])))
                == #"{"entries":[],"id":2,"type":"neighbors"}"# + "\n")
        #expect(
            line(NeighborsReply(id: 3, table: .failure(NeighborTableError(code: EPERM))))
                == #"{"error":"Operation not permitted","id":3,"type":"neighbors"}"# + "\n")
    }

    // MARK: - Helpers

    private func line(_ reply: NeighborsReply) -> String {
        String(decoding: reply.line, as: UTF8.self)
    }

    /// One `RTM_GET` message as the kernel lays it out: header, then the
    /// destination `sockaddr_in`, then the `sockaddr_dl` with the
    /// interface name and the MAC address in `sdl_data`.
    private func routeMessage(
        ip: (UInt8, UInt8, UInt8, UInt8), interface: String, mac: [UInt8]
    ) -> Data {
        var inet = sockaddr_in()
        inet.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        inet.sin_family = sa_family_t(AF_INET)
        withUnsafeMutableBytes(of: &inet.sin_addr) { $0.copyBytes(from: [ip.0, ip.1, ip.2, ip.3]) }

        var link = sockaddr_dl()
        link.sdl_len = UInt8(MemoryLayout<sockaddr_dl>.size)
        link.sdl_family = sa_family_t(AF_LINK)
        link.sdl_nlen = UInt8(interface.utf8.count)
        link.sdl_alen = UInt8(mac.count)
        withUnsafeMutableBytes(of: &link.sdl_data) { $0.copyBytes(from: Array(interface.utf8) + mac) }

        var header = rt_msghdr()
        header.rtm_msglen = UInt16(
            MemoryLayout<rt_msghdr>.size + MemoryLayout<sockaddr_in>.size + MemoryLayout<sockaddr_dl>.size)
        return bytes(of: header) + bytes(of: inet) + bytes(of: link)
    }

    private func bytes<T>(of value: T) -> Data {
        withUnsafeBytes(of: value) { Data($0) }
    }
}
