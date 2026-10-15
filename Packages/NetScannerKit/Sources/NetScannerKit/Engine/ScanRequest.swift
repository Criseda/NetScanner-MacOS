/// What to ask the engine for. Each case maps to one `ns` command line.
public enum ScanRequest: Hashable, Sendable {
    case discovery(DiscoveryOptions)
    case portScan(PortScanOptions)

    /// The `ns` arguments, always with `--json`.
    public var arguments: [String] {
        switch self {
        case .discovery(let options):
            var arguments = ["-s", options.subnet.description]
            if options.method == .ping { arguments.append("--ping") }
            if options.identifyDevices { arguments.append("--resolve") }
            return arguments + ["--json"]

        case .portScan(let options):
            var arguments = ["-p", options.host.description, options.ports.engineArgument]
            if let timeout = options.timeout {
                arguments += ["--timeout", String(timeout.milliseconds)]
            }
            return arguments + ["--json"]
        }
    }
}

public struct DiscoveryOptions: Hashable, Sendable {
    public enum Method: String, CaseIterable, Hashable, Sendable {
        /// TCP probes plus mDNS, SSDP and the ARP table: finds quiet
        /// phones, printers and TVs too. The engine's default.
        case standard
        /// One ICMP ping per host, for networks that filter TCP probes.
        case ping
    }

    public var subnet: Subnet
    public var method: Method
    /// Resolve hostnames, MAC addresses and manufacturers (`--resolve`).
    public var identifyDevices: Bool

    public init(subnet: Subnet, method: Method = .standard, identifyDevices: Bool = true) {
        self.subnet = subnet
        self.method = method
        self.identifyDevices = identifyDevices
    }
}

public struct PortScanOptions: Hashable, Sendable {
    public var host: IPv4
    public var ports: PortRange
    /// Nil lets the engine learn the wait from the host's answers.
    public var timeout: ProbeTimeout?

    public init(host: IPv4, ports: PortRange, timeout: ProbeTimeout? = nil) {
        self.host = host
        self.ports = ports
        self.timeout = timeout
    }
}
