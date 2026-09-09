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
    static var menuCheckForUpdates: String { string("menu.checkForUpdates", "Check for Updates…") }
    static var menuCheckingForUpdates: String { string("menu.checkingForUpdates", "Checking for Updates…") }
    static var menuAutomaticUpdateChecks: String { string("menu.automaticUpdateChecks", "Check for Updates Automatically") }
    static func menuUpdateAvailable(_ version: String) -> String {
        String(format: string("menu.updateAvailable", "Update available: BannerHither %@…"), version)
    }
    static var menuAbout: String { string("menu.about", "About BannerHither") }
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

    // MARK: Updates

    static var updateConsentTitle: String { string("update.consent.title", "Check for updates automatically?") }
    static var updateConsentBody: String {
        string("update.consent.body", "Once a day, BannerHither can ask GitHub whether a newer version has been released. Only the version number is fetched; nothing about you or your Mac is sent. You can change this at any time from the menu.")
    }
    static var updateConsentAllow: String { string("update.consent.allow", "Check Automatically") }
    static var updateConsentDeny: String { string("update.consent.deny", "Don’t Check") }
    static func updateAvailableTitle(_ version: String) -> String {
        String(format: string("update.available.title", "BannerHither %@ is available"), version)
    }
    static func updateAvailableBody(_ currentVersion: String) -> String {
        String(format: string("update.available.body", "You have %@. Download the new version from GitHub, or skip this version until the next one is released.\n\nInstalled with Homebrew? Run: brew upgrade --cask bannerhither"), currentVersion)
    }
    static var updateDownload: String { string("update.download", "Download") }
    static var updateLater: String { string("update.later", "Later") }
    static var updateSkip: String { string("update.skip", "Skip This Version") }
    static var updateUpToDateTitle: String { string("update.upToDate.title", "BannerHither is up to date") }
    static func updateUpToDateBody(_ version: String) -> String {
        String(format: string("update.upToDate.body", "BannerHither %@ is the latest version."), version)
    }
    static var updateFailedTitle: String { string("update.failed.title", "Could not check for updates") }
    static func updateFailedBody(_ reason: String) -> String {
        String(format: string("update.failed.body", "Check your internet connection and try again.\n\n%@"), reason)
    }

    // MARK: About

    static var aboutTagline: String { string("about.tagline", "Notification banners on the display you are looking at.") }
    static var aboutLicense: String { string("about.license", "MIT License") }
}
