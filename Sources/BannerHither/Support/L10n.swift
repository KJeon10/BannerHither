import Foundation

/// User-facing strings. Each accessor carries its English text as the fallback so the app
/// remains readable even when the resource bundle is missing (e.g. `swift run`).
enum L10n {
    /// The SwiftPM resource bundle, looked up next to the executable inside the app bundle
    /// first (where `scripts/build-app.sh` copies it) and in the build directory otherwise.
    static let bundle: Bundle = {
        let name = "BannerHither_BannerHither.bundle"
        if let url = Bundle.main.resourceURL?.appendingPathComponent(name), let bundle = Bundle(url: url) {
            return bundle
        }
        return Bundle.module
    }()

    static func string(_ key: String, _ fallback: String) -> String {
        bundle.localizedString(forKey: key, value: fallback, table: nil)
    }

    // MARK: Status line

    static var statusStopped: String { string("status.stopped", "Stopped") }
    static var statusNeedsPermission: String { string("status.needsPermission", "Accessibility permission required") }
    static var statusSystemDefault: String { string("status.running.systemDefault", "Running — system default (banners are not moved)") }
    static var statusFollowMouse: String { string("status.running.followMouse", "Running — screen under the mouse pointer") }
    static var statusFollowActiveWindow: String { string("status.running.followActiveWindow", "Running — screen of the active window") }
    static func statusFixedDisplay(_ name: String) -> String {
        String(format: string("status.running.fixedDisplay", "Running — fixed to %@"), name)
    }
    static func statusFixedDisplayDisconnected(_ name: String) -> String {
        String(format: string("status.running.fixedDisplayDisconnected", "Running — %@ is not connected"), name)
    }

    // MARK: Menu

    static var menuStart: String { string("menu.start", "Start") }
    static var menuStop: String { string("menu.stop", "Stop") }
    static var menuPlacementHeader: String { string("menu.placementHeader", "Show banners on") }
    static var modeSystemDefault: String { string("mode.systemDefault", "System default (primary display)") }
    static var modeFollowMouse: String { string("mode.followMouse", "Screen under the mouse pointer") }
    static var modeFollowActiveWindow: String { string("mode.followActiveWindow", "Screen of the active window") }
    static var modeFixedDisplay: String { string("mode.fixedDisplay", "Fixed display") }
    static var menuNoDisplays: String { string("menu.fixedDisplay.none", "No displays found") }
    static func menuDisplayDisconnected(_ name: String) -> String {
        String(format: string("menu.fixedDisplay.disconnected", "%@ (not connected)"), name)
    }
    static var menuLaunchAtLogin: String { string("menu.launchAtLogin", "Launch at Login") }
    static var menuOpenAccessibilitySettings: String { string("menu.openAccessibilitySettings", "Open Accessibility Settings…") }
    static var menuSendTestNotification: String { string("menu.sendTestNotification", "Send Test Notification (3 s delay)") }
    static var menuCopyDiagnostics: String { string("menu.copyDiagnostics", "Copy Diagnostics") }
    static var menuQuit: String { string("menu.quit", "Quit BannerHither") }

    // MARK: Alerts and notifications

    static var alertLoginItemFailed: String { string("alert.loginItemFailed", "Could not change the login item.") }
    static var alertLoginItemRequiresApproval: String {
        string("alert.loginItemRequiresApproval", "macOS needs your approval before BannerHither can launch at login. Open Login Items settings to allow it.")
    }
    static var alertOpenLoginItems: String { string("alert.openLoginItems", "Open Login Items") }
    static var alertOK: String { string("alert.ok", "OK") }
    static var testNotificationTitle: String { string("test.title", "BannerHither test") }
    static func testNotificationBody(_ time: String) -> String {
        String(format: string("test.body", "Sent at %@. Move the mouse to another screen before it arrives."), time)
    }
}
