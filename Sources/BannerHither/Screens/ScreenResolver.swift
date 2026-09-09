import AppKit
import ApplicationServices
import BannerHitherCore

/// Resolves a `PlacementMode` to the display banners should be moved to.
@MainActor
final class ScreenResolver: TargetScreenResolving {
    /// Bundle identifiers whose "focused window" must not be used as the active window.
    private let ignoredBundleIdentifiers: Set<String>
    private let log = AppLog.logger(category: "resolver")

    init(ignoredBundleIdentifiers: Set<String>) {
        self.ignoredBundleIdentifiers = ignoredBundleIdentifiers
    }

    var primaryFrame: CGRect {
        DisplayCatalog.primaryScreen.flatMap(DisplayCatalog.descriptor(for:))?.frame ?? .zero
    }

    func targetScreen(for mode: PlacementMode) -> ScreenDescriptor? {
        switch mode {
        case .systemDefault:
            return nil
        case .followMouse:
            return mouseScreen()
        case .followActiveWindow:
            // Fallback chain: focused window's screen → mouse screen → nothing.
            return activeWindowScreen() ?? mouseScreen()
        case .fixedDisplay(let id):
            return DisplayCatalog.screen(withID: id)
        }
    }

    // MARK: Strategies

    func mouseScreen() -> ScreenDescriptor? {
        DisplayCatalog.screen(containingAppKitPoint: NSEvent.mouseLocation)
    }

    /// Screen containing the centre of the frontmost application's focused window.
    func activeWindowScreen() -> ScreenDescriptor? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !(app.bundleIdentifier.map(ignoredBundleIdentifiers.contains) ?? false) else {
            return nil
        }
        do {
            let application = AXElement(pid: app.processIdentifier)
            guard let window = try application.element(for: kAXFocusedWindowAttribute),
                  let origin = try window.point(for: kAXPositionAttribute),
                  let size = try window.size(for: kAXSizeAttribute) else {
                return nil
            }
            let centre = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
            return DisplayCatalog.screen(containingCGPoint: centre)
        } catch {
            log.debug("Focused window of \(app.bundleIdentifier ?? "?", privacy: .public) unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
