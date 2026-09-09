import CoreGraphics

/// Events a probe reports to the engine. The engine re-evaluates on every event; the
/// probe does not need to know what changed, only that something might have.
public enum BannerProbeEvent: Sendable {
    /// An Accessibility notification suggests the banner window appeared, moved or vanished.
    case windowChanged
    /// NotificationCenter was relaunched; any cached window state is stale.
    case notificationCenterRelaunched
}

public enum BannerProbeError: Error, Equatable, Sendable {
    /// The Accessibility API refused the call; the user revoked the permission.
    case accessibilityDenied
    case notificationCenterNotRunning
    /// Any other `AXError`, with the operation that produced it for diagnostics.
    case accessibilityFailure(code: Int32, operation: String)
}

/// Reads and moves NotificationCenter's banner window.
@MainActor
public protocol BannerWindowProbing: AnyObject {
    var eventHandler: ((BannerProbeEvent) -> Void)? { get set }

    /// Starts delivering `eventHandler` callbacks. Throws only for `.accessibilityDenied`.
    func startObserving() throws
    func stopObserving()

    /// The banner window's current state, or `nil` when no banner window is on screen.
    func snapshot() throws -> BannerWindowSnapshot?

    /// Moves (and optionally resizes) the banner window and returns its origin re-read afterwards.
    func moveBanner(to origin: CGPoint, resizingTo size: CGSize?) throws -> CGPoint
}

/// Turns a placement mode into a concrete display.
@MainActor
public protocol TargetScreenResolving: AnyObject {
    /// CoreGraphics frame of the primary display.
    var primaryFrame: CGRect { get }

    /// The display banners should go to, or `nil` when the mode yields none right now.
    func targetScreen(for mode: PlacementMode) -> ScreenDescriptor?
}

/// The Accessibility ("Assistive access") permission, which is the only permission the app needs.
@MainActor
public protocol AccessibilityAuthorizing: AnyObject {
    var isTrusted: Bool { get }
    var trustChangeHandler: ((Bool) -> Void)? { get set }

    /// Shows the system prompt that sends the user to System Settings.
    func requestAccess()
    /// Polls the permission state and reports changes through `trustChangeHandler`.
    func startMonitoring()
    func stopMonitoring()
}
