import AppKit
import BannerHitherCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?
    private var screenObserver: (any NSObjectProtocol)?
    private let log = AppLog.logger(category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.terminateIfAlreadyRunning() else { return }

        let container = AppContainer()
        self.container = container

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak container] _ in
            MainActor.assumeIsolated { container?.screenParametersDidChange() }
        }

        container.start()
        log.info("Launched \(AppInfo.versionDescription, privacy: .public)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        container?.engine.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    /// A second copy (e.g. one launched at login plus one from a build directory) would fight over
    /// the same window, so it hands over to the running instance and quits.
    private static func terminateIfAlreadyRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let current = NSRunningApplication.current
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != current.processIdentifier }
        guard !others.isEmpty else { return false }
        NSApp.terminate(nil)
        return true
    }
}
