import Foundation

/// Why a scan form value was rejected, phrased for the person typing it.
///
/// Parsing never throws anything else, so views can show
/// `localizedDescription` directly under the field.
public enum InputError: LocalizedError, Equatable, Sendable {
    case invalidAddress
    case invalidSubnet
    case invalidPrefixLength
    case subnetTooLarge(hostCount: Int)
    case invalidPortRange
    case portOutOfRange
    case invalidTimeout

    public var errorDescription: String? {
        switch self {
        case .invalidAddress:
            String(localized: "Enter an IPv4 address like 192.168.1.1.", bundle: .module)
        case .invalidSubnet:
            String(localized: "Use CIDR notation, like 192.168.1.0/24.", bundle: .module)
        case .invalidPrefixLength:
            String(localized: "The prefix length must be between /0 and /32.", bundle: .module)
        case .subnetTooLarge(let hostCount):
            String(
                localized: "Too large (\(hostCount.formatted()) hosts). Use a /16 or smaller.",
                bundle: .module)
        case .invalidPortRange:
            String(localized: "Use a port or a range, like 80 or 1-1024.", bundle: .module)
        case .portOutOfRange:
            String(localized: "Ports must be between 1 and 65535.", bundle: .module)
        case .invalidTimeout:
            String(localized: "The timeout must be between 1 and 60000 ms.", bundle: .module)
        }
    }
}
