import ApplicationServices
import CoreGraphics

/// An `AXError` together with the operation that produced it.
struct AXAccessError: Error, CustomStringConvertible {
    let code: AXError
    let operation: String

    var description: String { "\(operation) failed with AXError \(code.rawValue)" }
}

/// Typed, error-reporting wrapper around `AXUIElement`.
///
/// Every accessor throws `AXAccessError` on failure except for "no value" and "unsupported
/// attribute", which map to `nil`. The wrapper is not thread-safe by itself; this app only
/// touches the Accessibility API from the main actor.
struct AXElement {
    let raw: AXUIElement

    init(raw: AXUIElement) {
        self.raw = raw
    }

    /// The application element of a running process.
    init(pid: pid_t) {
        self.init(raw: AXUIElementCreateApplication(pid))
    }

    // MARK: Reading

    func value(for attribute: String) throws -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(raw, attribute as CFString, &value)
        switch error {
        case .success:
            return value
        case .noValue, .attributeUnsupported:
            return nil
        default:
            throw AXAccessError(code: error, operation: "copy \(attribute)")
        }
    }

    func string(for attribute: String) throws -> String? {
        try value(for: attribute) as? String
    }

    func point(for attribute: String) throws -> CGPoint? {
        guard let value = try value(for: attribute), let axValue = Self.axValue(value), AXValueGetType(axValue) == .cgPoint else {
            return nil
        }
        var point = CGPoint.zero
        return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    func size(for attribute: String) throws -> CGSize? {
        guard let value = try value(for: attribute), let axValue = Self.axValue(value), AXValueGetType(axValue) == .cgSize else {
            return nil
        }
        var size = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }

    func element(for attribute: String) throws -> AXElement? {
        guard let value = try value(for: attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return AXElement(raw: unsafeDowncast(value, to: AXUIElement.self))
    }

    func elements(for attribute: String) throws -> [AXElement] {
        guard let value = try value(for: attribute), CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
        return ((value as! CFArray) as [AnyObject]).compactMap { item in
            CFGetTypeID(item) == AXUIElementGetTypeID() ? AXElement(raw: unsafeDowncast(item, to: AXUIElement.self)) : nil
        }
    }

    func isSettable(_ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(raw, attribute as CFString, &settable) == .success && settable.boolValue
    }

    // MARK: Writing

    func set(_ point: CGPoint, for attribute: String) throws {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else {
            throw AXAccessError(code: .failure, operation: "encode \(attribute)")
        }
        try set(value, for: attribute)
    }

    func set(_ size: CGSize, for attribute: String) throws {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else {
            throw AXAccessError(code: .failure, operation: "encode \(attribute)")
        }
        try set(value, for: attribute)
    }

    private func set(_ value: CFTypeRef, for attribute: String) throws {
        let error = AXUIElementSetAttributeValue(raw, attribute as CFString, value)
        guard error == .success else { throw AXAccessError(code: error, operation: "set \(attribute)") }
    }

    // MARK: Convenience

    var role: String? { try? string(for: kAXRoleAttribute) }
    var subrole: String? { try? string(for: kAXSubroleAttribute) }
    var title: String? { try? string(for: kAXTitleAttribute) }

    private static func axValue(_ value: CFTypeRef) -> AXValue? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXValue.self)
    }
}

extension AXElement: Equatable {
    static func == (lhs: AXElement, rhs: AXElement) -> Bool {
        CFEqual(lhs.raw, rhs.raw)
    }
}
