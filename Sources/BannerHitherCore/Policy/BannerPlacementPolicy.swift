import CoreGraphics

/// What the probe observed about NotificationCenter's banner window at one instant.
public struct BannerWindowSnapshot: Equatable, Sendable {
    /// Window origin in CoreGraphics coordinates.
    public var origin: CGPoint
    public var size: CGSize
    /// Whether the Notification Center panel, as opposed to a transient banner, is open.
    public var isPanelOpen: Bool

    public init(origin: CGPoint, size: CGSize, isPanelOpen: Bool) {
        self.origin = origin
        self.size = size
        self.isPanelOpen = isPanelOpen
    }
}

public enum PlacementDecision: Equatable, Sendable {
    case skip(SkipReason)
    /// Move the window to `origin`; when `size` is non-nil the window is resized to it first.
    case move(origin: CGPoint, size: CGSize?)
}

public enum SkipReason: String, Sendable {
    /// The Notification Center panel is open; NotificationCenter positions it itself.
    case panelOpen
    /// The window has not moved since the last observation.
    case noTransition
    /// NotificationCenter did not place the window at its default position (primary display origin).
    case notAtSystemDefaultOrigin
    /// The current mode yields no target (e.g. a fixed display that is not connected).
    case noTargetScreen
    /// The window is already where the target requires.
    case alreadyOnTarget
}

/// Decides whether and where to move NotificationCenter's banner window.
///
/// The policy is deliberately conservative. It acts only at *transitions* — the window just
/// appeared, or NotificationCenter just repositioned it — and only while the window sits at the
/// position NotificationCenter uses by default. Consequently banners are never dragged around
/// after they are on screen, and the Notification Center panel, which NotificationCenter places
/// on the display whose clock was clicked, is left alone.
public struct BannerPlacementPolicy: Sendable {
    /// Maximum per-axis distance (in points) for two positions to count as equal.
    public var tolerance: CGFloat
    /// Resize the window to the target display before moving it, so a display narrower than the
    /// one the window was sized for does not end up with the window overhanging its neighbour.
    public var resizeToTargetScreen: Bool

    public init(tolerance: CGFloat = 1, resizeToTargetScreen: Bool = false) {
        self.tolerance = tolerance
        self.resizeToTargetScreen = resizeToTargetScreen
    }

    /// - Parameters:
    ///   - snapshot: Current state of the banner window.
    ///   - previousOrigin: Origin observed on the previous evaluation, `nil` if the window was absent.
    ///   - primaryFrame: CoreGraphics frame of the primary display (its origin is where
    ///     NotificationCenter puts the window by default).
    ///   - targetScreen: Resolves the desired display; called only when a move is being considered
    ///     because resolving may be comparatively expensive (Accessibility calls into other apps).
    public func decide(
        snapshot: BannerWindowSnapshot,
        previousOrigin: CGPoint?,
        primaryFrame: CGRect,
        targetScreen: () -> ScreenDescriptor?
    ) -> PlacementDecision {
        guard !snapshot.isPanelOpen else { return .skip(.panelOpen) }

        let isTransition = previousOrigin.map { !ScreenGeometry.isNear(snapshot.origin, $0, tolerance: tolerance) } ?? true
        guard isTransition else { return .skip(.noTransition) }

        guard ScreenGeometry.isNear(snapshot.origin, primaryFrame.origin, tolerance: tolerance) else {
            return .skip(.notAtSystemDefaultOrigin)
        }

        guard let screen = targetScreen() else { return .skip(.noTargetScreen) }

        let newSize: CGSize? = (resizeToTargetScreen && snapshot.size != screen.frame.size) ? screen.frame.size : nil
        let origin = ScreenGeometry.topRightAlignedOrigin(windowSize: newSize ?? snapshot.size, in: screen.frame)

        if newSize == nil, ScreenGeometry.isNear(origin, snapshot.origin, tolerance: tolerance) {
            return .skip(.alreadyOnTarget)
        }
        return .move(origin: origin, size: newSize)
    }
}
