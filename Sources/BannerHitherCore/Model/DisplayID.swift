import Foundation

/// Stable identity of a physical display.
///
/// Backed by the CoreGraphics display UUID string, which survives reboots and
/// re-plugging. `CGDirectDisplayID` is deliberately not used because macOS may
/// hand out a different number for the same monitor after reconnecting it.
public struct DisplayID: Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension DisplayID: CustomStringConvertible {
    public var description: String { rawValue }
}
