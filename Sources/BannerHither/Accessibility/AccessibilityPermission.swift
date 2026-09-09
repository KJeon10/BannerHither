import AppKit
import ApplicationServices
import BannerHitherCore

/// The "Accessibility" privacy permission, checked through `AXIsProcessTrusted`.
///
/// macOS offers no change notification for it, so `startMonitoring` polls once a second.
@MainActor
final class AccessibilityPermission: AccessibilityAuthorizing {
    static let systemSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    var trustChangeHandler: ((Bool) -> Void)?

    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var lastKnownTrust: Bool
    private let log = AppLog.logger(category: "permission")

    init(pollInterval: TimeInterval = 1) {
        self.pollInterval = pollInterval
        self.lastKnownTrust = AXIsProcessTrusted()
    }

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccess() {
        // Same value as `kAXTrustedCheckOptionPrompt`, which Swift 6 cannot reference safely (a global `var`).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        log.info("Requested Accessibility access (currently trusted: \(trusted, privacy: .public))")
    }

    func startMonitoring() {
        guard timer == nil else { return }
        lastKnownTrust = isTrusted
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    static func openSystemSettings() {
        NSWorkspace.shared.open(systemSettingsURL)
    }

    private func poll() {
        let trusted = isTrusted
        guard trusted != lastKnownTrust else { return }
        lastKnownTrust = trusted
        log.info("Accessibility trust changed: \(trusted, privacy: .public)")
        trustChangeHandler?(trusted)
    }
}
