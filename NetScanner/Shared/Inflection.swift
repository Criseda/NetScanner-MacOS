import Foundation

extension String {
    /// A count with its noun in the right grammatical form ("1 host",
    /// "2 hosts"), using Foundation's automatic grammar agreement so
    /// every language gets its own plural rules without per-string
    /// plural variants.
    static func inflected(_ resource: LocalizedStringResource) -> String {
        String(AttributedString(localized: resource).characters)
    }
}
