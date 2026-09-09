import AppKit
import BannerHitherCore
import UserNotifications

/// Posts a local notification after a delay so the user can watch where the banner lands.
///
/// Uses `UNUserNotificationCenter` when running as an app bundle and falls back to
/// AppleScript's `display notification` (which posts on behalf of Script Editor) when the
/// framework is unavailable or the user declined notification permission for BannerHither.
@MainActor
final class TestNotificationSender: NSObject, UNUserNotificationCenterDelegate {
    private let log = AppLog.logger(category: "test-notification")

    func send(after delay: TimeInterval) {
        guard AppInfo.isBundled else {
            sendViaAppleScript(after: delay)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        Task { @MainActor in
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                guard granted else {
                    log.notice("Notification permission not granted; falling back to AppleScript")
                    sendViaAppleScript(after: delay)
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = L10n.testNotificationTitle
                content.body = L10n.testNotificationBody(Self.timestamp())
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
                try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
                log.info("Scheduled test notification in \(delay, privacy: .public)s")
            } catch {
                log.error("Scheduling failed: \(String(describing: error), privacy: .public); falling back to AppleScript")
                sendViaAppleScript(after: delay)
            }
        }
    }

    // Show the banner even if BannerHither happens to be the active app (its menu is open).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func sendViaAppleScript(after delay: TimeInterval) {
        let title = Self.escaped(L10n.testNotificationTitle)
        let body = Self.escaped(L10n.testNotificationBody(Self.timestamp()))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e", "delay \(Int(delay.rounded()))",
            "-e", "display notification \"\(body)\" with title \"\(title)\"",
        ]
        do {
            try process.run()
            log.info("Scheduled AppleScript test notification in \(delay, privacy: .public)s")
        } catch {
            log.error("osascript failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func timestamp() -> String {
        Date().formatted(date: .omitted, time: .standard)
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
