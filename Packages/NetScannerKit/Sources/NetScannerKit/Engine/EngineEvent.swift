/// Something the engine reported, decoded from one `--json` line.
public enum EngineEvent: Hashable, Sendable {
    /// A subnet scan began; `first`...`last` is the whole network range.
    case subnetStarted(first: IPv4, last: IPv4)
    case hostFound(IPv4, HostSource)
    case hostDetail(HostDetail)
    case portFound(OpenPort)
    case progress(ScanProgress)
    /// Closing line of `ns -s`.
    case subnetFinished(hostCount: Int, elapsed: Duration)
    /// Closing line of `ns -p`: every open port by number. Each one was
    /// already streamed, with its name, as `portFound`.
    case portScanFinished(openPorts: [UInt16], elapsed: Duration)
    /// An input error. The engine exits with status 1 right after.
    case failure(message: String)
    /// The engine waits for this app to send it the ARP table
    /// (`--neighbor-table=parent`). ``ScanEngine`` answers it, so it
    /// never reaches the scan's event stream.
    case neighborsRequest(id: Int)
}
