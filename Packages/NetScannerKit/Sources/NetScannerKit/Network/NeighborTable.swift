import Darwin

/// One resolved entry of the kernel's ARP table.
public struct NeighborEntry: Hashable, Sendable {
    public let ip: IPv4
    /// Six bytes, as `aa:bb:cc:dd:ee:ff`.
    public let macAddress: String

    public init(ip: IPv4, macAddress: String) {
        self.ip = ip
        self.macAddress = macAddress
    }
}

/// Why the ARP table could not be read: the `errno` of the failed
/// `sysctl`.
public struct NeighborTableError: Error, Hashable, Sendable {
    public let code: Int32

    public var message: String { String(cString: strerror(code)) }
}

/// The kernel's ARP table, read in this process.
///
/// On macOS 27 the kernel hides the table from programs that an ad-hoc
/// signed app starts, `ns` among them, while the app itself can always
/// read it. So the app reads it here and hands it to the engine
/// (`--neighbor-table=parent`), which keeps all the logic of what an
/// entry means. This mirrors `macos_dump` in the engine's
/// `src/c/neighbors.c` and adds nothing to it: no filtering, no
/// manufacturer lookup.
public enum NeighborTable {
    /// The table as the kernel reports it. Unresolved entries (nobody
    /// answered, so no MAC address) are left out.
    public static func read() throws(NeighborTableError) -> [NeighborEntry] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO]
        // The table can grow between sizing and reading, so retry with
        // slack, as the engine does.
        for attempt in 0..<3 {
            var needed = 0
            guard sysctl(&mib, UInt32(mib.count), nil, &needed, nil, 0) == 0 else {
                throw NeighborTableError(code: errno)
            }
            var length = needed + needed / 2 + MemoryLayout<rt_msghdr>.size
            var buffer = [UInt8](repeating: 0, count: length)
            let status = buffer.withUnsafeMutableBytes { bytes in
                sysctl(&mib, UInt32(mib.count), bytes.baseAddress, &length, nil, 0)
            }
            if status == 0 {
                return buffer.withUnsafeBytes { entries(inRouteDump: UnsafeRawBufferPointer(rebasing: $0[..<length])) }
            }
            if errno != ENOMEM || attempt == 2 { throw NeighborTableError(code: errno) }
        }
        return []
    }

    /// Walks a `sysctl(NET_RT_FLAGS, RTF_LLINFO)` dump: a run of route
    /// messages, each an `rt_msghdr` followed by the destination
    /// `sockaddr_in` and the gateway `sockaddr_dl` holding the MAC
    /// address. Separate from ``read()`` so it can be tested on a
    /// buffer built by hand. Malformed or truncated messages end the
    /// walk instead of reading past the buffer.
    static func entries(inRouteDump dump: UnsafeRawBufferPointer) -> [NeighborEntry] {
        var entries: [NeighborEntry] = []
        var offset = 0
        while offset + MemoryLayout<rt_msghdr>.size <= dump.count {
            let header = dump.loadUnaligned(fromByteOffset: offset, as: rt_msghdr.self)
            let length = Int(header.rtm_msglen)
            guard length > 0, offset + length <= dump.count else { break }
            let message = UnsafeRawBufferPointer(rebasing: dump[offset..<offset + length])
            offset += length
            if let entry = entry(inRouteMessage: message) { entries.append(entry) }
        }
        return entries
    }

    private static func entry(inRouteMessage message: UnsafeRawBufferPointer) -> NeighborEntry? {
        let inetOffset = MemoryLayout<rt_msghdr>.size
        guard inetOffset + MemoryLayout<sockaddr_in>.size <= message.count else { return nil }
        let inet = message.loadUnaligned(fromByteOffset: inetOffset, as: sockaddr_in.self)
        guard inet.sin_family == AF_INET else { return nil }

        let linkOffset = inetOffset + roundedUp(Int(inet.sin_len))
        guard linkOffset + MemoryLayout<sockaddr_dl>.size <= message.count else { return nil }
        let link = message.loadUnaligned(fromByteOffset: linkOffset, as: sockaddr_dl.self)
        // Unresolved entries carry no link-layer address: nobody answered.
        guard link.sdl_family == AF_LINK, link.sdl_alen == 6 else { return nil }

        // LLADDR: the address follows the interface name in `sdl_data`.
        let macOffset = linkOffset + linkDataOffset + Int(link.sdl_nlen)
        guard macOffset + 6 <= message.count else { return nil }
        let mac = message[macOffset..<macOffset + 6]

        // `sin_addr` is in network byte order: its bytes are a.b.c.d.
        let address = withUnsafeBytes(of: inet.sin_addr) { Array($0) }
        return NeighborEntry(
            ip: IPv4(address[0], address[1], address[2], address[3]),
            macAddress: mac.map { hex($0) }.joined(separator: ":"))
    }

    /// Route-message socket addresses are padded to 4-byte boundaries
    /// (Apple's `arp.c` rounds the same way); an empty one still takes 4.
    private static func roundedUp(_ length: Int) -> Int {
        length > 0 ? (length + 3) & ~3 : 4
    }

    /// Where `sdl_data` starts in a `sockaddr_dl` (8 bytes in every SDK).
    private static let linkDataOffset = MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data) ?? 8

    private static func hex(_ byte: UInt8) -> String {
        let digits = String(byte, radix: 16)
        return byte < 0x10 ? "0" + digits : digits
    }
}
