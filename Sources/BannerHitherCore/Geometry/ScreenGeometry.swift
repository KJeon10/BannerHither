import CoreGraphics

/// Pure coordinate helpers shared by the engine and the AppKit layer.
public enum ScreenGeometry {
    /// Converts an AppKit screen frame into CoreGraphics coordinates.
    ///
    /// AppKit's origin is the bottom-left corner of the primary display with y pointing up;
    /// CoreGraphics' origin is its top-left corner with y pointing down. Both share the x axis,
    /// so only y needs flipping, which requires the primary display's height.
    ///
    /// - Parameter primaryHeight: `NSScreen.screens[0].frame.height`.
    public static func cgFrame(appKitFrame frame: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    /// Converts an AppKit point (e.g. `NSEvent.mouseLocation`) into CoreGraphics coordinates.
    public static func cgPoint(appKitPoint point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Origin that puts the top-right corner of a `windowSize` window on the top-right corner of `screenFrame`.
    ///
    /// NotificationCenter draws banners in the top-right corner of a display-sized window, so aligning
    /// the window's top-right corner with the target display places the banner exactly where macOS
    /// would draw it natively on that display.
    public static func topRightAlignedOrigin(windowSize: CGSize, in screenFrame: CGRect) -> CGPoint {
        CGPoint(x: screenFrame.maxX - windowSize.width, y: screenFrame.minY)
    }

    /// Whether two points coincide within `tolerance` on both axes.
    public static func isNear(_ a: CGPoint, _ b: CGPoint, tolerance: CGFloat = 1) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance
    }
}
