import AppKit
import ApplicationServices
import BannerHitherCore

/// Finds NotificationCenter's banner window through the Accessibility API and reports changes to it.
///
/// Behaviour this relies on (observed on macOS 26.6; see the README for details):
/// - `NotificationCenter.app` draws every banner, and the Notification Center panel, in one
///   display-sized window whose subrole is `AXSystemDialog` and whose title is "Notification Center".
/// - The window is listed in `AXWindows` only while a banner or the panel is showing. Its AX element
///   is destroyed at dismissal and a new one is created for the next banner, so elements are never
///   trusted across banners.
/// - `AXWindowCreated` fires on the application element for every appearance, re-appearances included.
///   A notification arriving while a banner is already showing produces only `AXLayoutChanged`.
/// - While the panel is open the application reports an `AXFocusedWindow`; a plain banner does not.
@MainActor
final class NotificationCenterProbe: BannerWindowProbing {
    enum Constants {
        static let bundleIdentifier = "com.apple.notificationcenterui"
        static let windowTitle = "Notification Center"
        static let windowSubrole = "AXSystemDialog"
    }

    var eventHandler: ((BannerProbeEvent) -> Void)?

    private let workspace = NSWorkspace.shared
    private var workspaceObservers: [any NSObjectProtocol] = []
    private var observer: AXObserverHandle?
    /// The banner window element that currently carries window-level subscriptions.
    private var observedWindow: AXElement?
    /// The banner window element seen most recently; the target of `moveBanner`.
    private var currentWindow: AXElement?
    private let log = AppLog.logger(category: "probe")

    var runningApplication: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: Constants.bundleIdentifier).first
    }

    private var isObservingWorkspace: Bool { !workspaceObservers.isEmpty }

    // MARK: BannerWindowProbing

    func startObserving() throws {
        guard !isObservingWorkspace else { return }
        let center = workspace.notificationCenter
        workspaceObservers = [
            center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
                guard Self.isNotificationCenter(note) else { return }
                MainActor.assumeIsolated { self?.notificationCenterDidLaunch() }
            },
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                guard Self.isNotificationCenter(note) else { return }
                MainActor.assumeIsolated { self?.notificationCenterDidTerminate() }
            },
        ]
        try attachObserver()
    }

    func stopObserving() {
        for observer in workspaceObservers {
            workspace.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        observer = nil
        observedWindow = nil
        currentWindow = nil
    }

    func snapshot() throws -> BannerWindowSnapshot? {
        guard let app = runningApplication else {
            currentWindow = nil
            throw BannerProbeError.notificationCenterNotRunning
        }
        // Self-heal: NotificationCenter may have been restarted without a workspace notification.
        if isObservingWorkspace, observer?.pid != app.processIdentifier {
            try attachObserver()
        }
        do {
            let application = AXElement(pid: app.processIdentifier)
            guard let window = try bannerWindow(in: application) else {
                currentWindow = nil
                return nil
            }
            currentWindow = window
            observeWindowIfNeeded(window)
            guard let origin = try window.point(for: kAXPositionAttribute),
                  let size = try window.size(for: kAXSizeAttribute) else {
                return nil
            }
            let isPanelOpen = try application.element(for: kAXFocusedWindowAttribute) != nil
            return BannerWindowSnapshot(origin: origin, size: size, isPanelOpen: isPanelOpen)
        } catch let error as AXAccessError {
            throw Self.probeError(from: error)
        }
    }

    func moveBanner(to origin: CGPoint, resizingTo size: CGSize?) throws -> CGPoint {
        guard let window = currentWindow else {
            throw BannerProbeError.accessibilityFailure(code: AXError.invalidUIElement.rawValue, operation: "move banner window (none observed)")
        }
        do {
            if let size {
                // Best effort: NotificationCenter may refuse a resize, and the move is still worthwhile.
                do {
                    try window.set(size, for: kAXSizeAttribute)
                } catch {
                    log.notice("Could not resize banner window: \(String(describing: error), privacy: .public)")
                }
            }
            try window.set(origin, for: kAXPositionAttribute)
            return try window.point(for: kAXPositionAttribute) ?? origin
        } catch let error as AXAccessError {
            throw Self.probeError(from: error)
        }
    }

    // MARK: Window lookup

    /// The banner window among the application's windows. Desktop widgets are separate
    /// NotificationCenter windows with other subroles and titles, so they never match.
    func bannerWindow(in application: AXElement) throws -> AXElement? {
        try application.elements(for: kAXWindowsAttribute).first(where: Self.isBannerWindow)
    }

    static func isBannerWindow(_ element: AXElement) -> Bool {
        element.subrole == Constants.windowSubrole && element.title == Constants.windowTitle
    }

    static func probeError(from error: AXAccessError) -> BannerProbeError {
        switch error.code {
        case .apiDisabled:
            return .accessibilityDenied
        default:
            return .accessibilityFailure(code: error.code.rawValue, operation: error.operation)
        }
    }

    // MARK: Accessibility observation

    private func attachObserver() throws {
        observer = nil
        observedWindow = nil
        guard let app = runningApplication else {
            log.notice("NotificationCenter is not running; waiting for it to launch")
            return
        }
        do {
            let handle = try AXObserverHandle(pid: app.processIdentifier) { [weak self] notification, element in
                self?.handle(notification, element: element)
            }
            let application = AXElement(pid: app.processIdentifier)
            try handle.add(kAXWindowCreatedNotification, to: application)
            try handle.add(kAXLayoutChangedNotification, to: application)
            observer = handle
            log.info("Observing NotificationCenter (pid \(app.processIdentifier, privacy: .public))")
        } catch let error as AXAccessError where error.code == .cannotComplete {
            // A freshly launched NotificationCenter is not serving Accessibility requests yet;
            // the next poll or workspace notification retries.
            log.notice("NotificationCenter (pid \(app.processIdentifier, privacy: .public)) is not ready for observation yet")
        } catch let error as AXAccessError {
            throw Self.probeError(from: error)
        }
    }

    private func observeWindowIfNeeded(_ window: AXElement) {
        guard let observer, observedWindow != window else { return }
        do {
            try observer.add(kAXWindowMovedNotification, to: window)
            try observer.add(kAXWindowResizedNotification, to: window)
            try observer.add(kAXUIElementDestroyedNotification, to: window)
            observedWindow = window
        } catch {
            log.error("Could not observe banner window: \(String(describing: error), privacy: .public)")
        }
    }

    private func handle(_ notification: String, element: AXElement) {
        switch notification {
        case kAXWindowCreatedNotification:
            guard Self.isBannerWindow(element) else { return }
            log.debug("Banner window created")
            currentWindow = element
            observeWindowIfNeeded(element)
            eventHandler?(.windowChanged)
        case kAXUIElementDestroyedNotification:
            log.debug("Banner window destroyed")
            if element == observedWindow { observedWindow = nil }
            currentWindow = nil
            eventHandler?(.windowChanged)
        case kAXWindowMovedNotification, kAXWindowResizedNotification:
            eventHandler?(.windowChanged)
        case kAXLayoutChangedNotification:
            // Layout changes are frequent (desktop widgets) and only matter while a banner is showing.
            if currentWindow != nil { eventHandler?(.windowChanged) }
        default:
            break
        }
    }

    // MARK: NotificationCenter lifecycle

    private func notificationCenterDidLaunch() {
        log.info("NotificationCenter launched; re-attaching observer")
        do {
            try attachObserver()
        } catch {
            log.error("Re-attaching observer failed: \(String(describing: error), privacy: .public)")
        }
        eventHandler?(.notificationCenterRelaunched)
    }

    private func notificationCenterDidTerminate() {
        log.info("NotificationCenter terminated")
        observer = nil
        observedWindow = nil
        currentWindow = nil
        eventHandler?(.windowChanged)
    }

    private nonisolated static func isNotificationCenter(_ note: Notification) -> Bool {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        return app?.bundleIdentifier == Constants.bundleIdentifier
    }
}
