import Foundation

/// A dotted numeric version such as `0.1.0`, compared component by component.
///
/// Accepts an optional leading `v` (release tags are `v0.1.0`) and ignores a pre-release or
/// build suffix after `-` or `+`. Missing components count as zero, so `1.2` equals `1.2.0`.
public struct AppVersion: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let components: [Int]

    public init(_ components: [Int]) {
        self.components = components.isEmpty ? [0] : components
    }

    public init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") {
            text.removeFirst()
        }
        if let suffix = text.firstIndex(where: { $0 == "-" || $0 == "+" }) {
            text = String(text[..<suffix])
        }
        guard !text.isEmpty else { return nil }

        var parsed: [Int] = []
        for part in text.split(separator: ".", omittingEmptySubsequences: false) {
            guard let value = Int(part), value >= 0 else { return nil }
            parsed.append(value)
        }
        self.init(parsed)
    }

    /// The version as written, e.g. `0.1.0`.
    public var description: String {
        components.map(String.init).joined(separator: ".")
    }

    /// Components with trailing zeros removed, so `1.2.0` and `1.2` hash and compare alike.
    private var normalized: [Int] {
        var trimmed = components
        while trimmed.count > 1, trimmed.last == 0 {
            trimmed.removeLast()
        }
        return trimmed
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.normalized == rhs.normalized
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(normalized)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}
