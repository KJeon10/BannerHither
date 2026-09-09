import CoreGraphics

/// A connected display described in CoreGraphics coordinates.
///
/// CoreGraphics and the Accessibility API put the origin at the top-left corner of the
/// primary display with the y axis pointing down. That is the coordinate system in which
/// NotificationCenter's window position is read and written, so the engine works in it
/// exclusively; AppKit frames are converted once, at the edge, by `ScreenGeometry`.
public struct ScreenDescriptor: Equatable, Sendable {
    public let id: DisplayID
    /// Human-readable name, e.g. "Built-in Retina Display".
    public let name: String
    /// Full frame including the menu bar area (not the visible frame).
    public let frame: CGRect
    /// Whether this is the display whose top-left corner is the CoreGraphics origin.
    public let isPrimary: Bool

    public init(id: DisplayID, name: String, frame: CGRect, isPrimary: Bool) {
        self.id = id
        self.name = name
        self.frame = frame
        self.isPrimary = isPrimary
    }
}
