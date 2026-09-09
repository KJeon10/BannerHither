import AppKit
import BannerHitherCore

/// Converts `NSScreen`s into `ScreenDescriptor`s (CoreGraphics coordinates, stable UUIDs).
///
/// Nothing is cached: `NSScreen.screens` is cheap and always reflects the current arrangement,
/// which keeps display hot-plugging free of special cases.
@MainActor
enum DisplayCatalog {
    /// The display at the AppKit origin, i.e. the one with the menu bar in a single-space layout.
    static var primaryScreen: NSScreen? {
        NSScreen.screens.first
    }

    static var primaryHeight: CGFloat {
        primaryScreen?.frame.height ?? 0
    }

    static func screens() -> [ScreenDescriptor] {
        NSScreen.screens.compactMap(descriptor(for:))
    }

    static func descriptor(for screen: NSScreen) -> ScreenDescriptor? {
        guard let id = displayID(of: screen) else { return nil }
        return ScreenDescriptor(
            id: id,
            name: screen.localizedName,
            frame: ScreenGeometry.cgFrame(appKitFrame: screen.frame, primaryHeight: primaryHeight),
            isPrimary: screen == primaryScreen
        )
    }

    static func screen(withID id: DisplayID) -> ScreenDescriptor? {
        screens().first { $0.id == id }
    }

    /// The screen containing a CoreGraphics point, if any.
    static func screen(containingCGPoint point: CGPoint) -> ScreenDescriptor? {
        screens().first { $0.frame.contains(point) }
    }

    /// The screen containing an AppKit point such as `NSEvent.mouseLocation`.
    static func screen(containingAppKitPoint point: CGPoint) -> ScreenDescriptor? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }.flatMap(descriptor(for:))
    }

    static func directDisplayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    static func displayID(of screen: NSScreen) -> DisplayID? {
        guard let number = directDisplayID(of: screen),
              let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue() else { return nil }
        return DisplayID(rawValue: CFUUIDCreateString(nil, uuid) as String)
    }
}
