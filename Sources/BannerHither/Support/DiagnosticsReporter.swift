import AppKit
import ApplicationServices
import BannerHitherCore

/// Produces the plain-text report behind "Copy Diagnostics": enough for a bug report to show
/// what this machine's NotificationCenter window looks like after an OS update.
@MainActor
final class DiagnosticsReporter {
    private let engine: Engine
    private let settings: SettingsStore
    private let permission: AccessibilityPermission
    private let probe: NotificationCenterProbe
    private let resolver: ScreenResolver
    private let loginItem: LoginItemController
    private let updates: UpdateCoordinator
    private let log = AppLog.logger(category: "diagnostics")

    init(
        engine: Engine,
        settings: SettingsStore,
        permission: AccessibilityPermission,
        probe: NotificationCenterProbe,
        resolver: ScreenResolver,
        loginItem: LoginItemController,
        updates: UpdateCoordinator
    ) {
        self.engine = engine
        self.settings = settings
        self.permission = permission
        self.probe = probe
        self.resolver = resolver
        self.loginItem = loginItem
        self.updates = updates
    }

    func copyToPasteboard() {
        let report = makeReport()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(report, forType: .string)
        log.info("Diagnostics copied to the pasteboard")
    }

    func makeReport() -> String {
        var lines: [String] = []
        let os = ProcessInfo.processInfo.operatingSystemVersion
        lines.append("\(AppInfo.versionDescription) — macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
        lines.append("Bundle: \(AppInfo.bundleIdentifier) at \(Bundle.main.bundleURL.path)")
        lines.append("Accessibility trusted: \(permission.isTrusted)")
        lines.append("Engine: \(engine.state), mode: \(format(mode: settings.placementMode)), enabled: \(settings.isEnabled), relocations: \(engine.relocationCount), lastOrigin: \(engine.lastOrigin.map { format(point: $0) } ?? "none")")
        lines.append("Settings: pollIntervalMilliseconds=\(settings.pollIntervalMilliseconds) resizeToTargetScreen=\(settings.resizeToTargetScreen) launchAtLogin=\(loginItem.isEnabled)")
        lines.append("Updates: automatic=\(settings.automaticUpdateChecks) consentAsked=\(settings.updateConsentAsked) lastCheck=\(settings.lastUpdateCheck.map { $0.formatted(.iso8601) } ?? "never") skipped=\(settings.skippedUpdateVersion ?? "none") available=\(updates.availableRelease?.tag ?? "none") feed=\(updates.feedURL.absoluteString)")

        lines.append("")
        lines.append("Screens (AppKit frame → CoreGraphics frame):")
        for screen in NSScreen.screens {
            let descriptor = DisplayCatalog.descriptor(for: screen)
            let primary = screen == DisplayCatalog.primaryScreen ? " [primary]" : ""
            lines.append("  \(screen.localizedName)\(primary) id=\(descriptor?.id.rawValue ?? "?") appkit=\(format(rect: screen.frame)) cg=\(descriptor.map { format(rect: $0.frame) } ?? "?") scale=\(screen.backingScaleFactor)")
        }
        let mouse = NSEvent.mouseLocation
        lines.append("Mouse: appkit=\(format(point: mouse)) → \(resolver.mouseScreen()?.name ?? "none")")
        lines.append("Active window screen: \(resolver.activeWindowScreen()?.name ?? "none") (frontmost: \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"))")

        lines.append("")
        lines.append(contentsOf: notificationCenterLines())
        return lines.joined(separator: "\n")
    }

    private func notificationCenterLines() -> [String] {
        guard let app = probe.runningApplication else { return ["NotificationCenter: not running"] }
        var lines = ["NotificationCenter: pid \(app.processIdentifier)"]
        guard permission.isTrusted else {
            lines.append("  (Accessibility permission missing; windows cannot be inspected)")
            return lines
        }
        let application = AXElement(pid: app.processIdentifier)
        do {
            let windows = try application.elements(for: kAXWindowsAttribute)
            lines.append("  focusedWindow: \(try application.element(for: kAXFocusedWindowAttribute) != nil)")
            lines.append("  windows: \(windows.count)")
            for window in windows {
                let role = window.role ?? "?"
                let subrole = window.subrole ?? "?"
                let title = window.title ?? ""
                let position = (try? window.point(for: kAXPositionAttribute)).map { format(point: $0) } ?? "?"
                let size = (try? window.size(for: kAXSizeAttribute)).map { format(size: $0) } ?? "?"
                let banner = NotificationCenterProbe.isBannerWindow(window) ? " ← banner window" : ""
                lines.append("    \(role)/\(subrole) \"\(title)\" pos=\(position) size=\(size) settable(pos)=\(window.isSettable(kAXPositionAttribute)) settable(size)=\(window.isSettable(kAXSizeAttribute))\(banner)")
            }
        } catch {
            lines.append("  error: \(error)")
        }
        return lines
    }

    // MARK: Formatting

    private func format(mode: PlacementMode) -> String {
        switch mode {
        case .fixedDisplay(let id): return "fixedDisplay(\(id.rawValue))"
        default: return mode.kind.rawValue
        }
    }

    private func format(point: CGPoint) -> String {
        "(\(Int(point.x)), \(Int(point.y)))"
    }

    private func format(size: CGSize) -> String {
        "\(Int(size.width))×\(Int(size.height))"
    }

    private func format(rect: CGRect) -> String {
        "(\(Int(rect.minX)), \(Int(rect.minY)), \(Int(rect.width))×\(Int(rect.height)))"
    }
}
