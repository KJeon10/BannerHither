import AppKit
import ServiceManagement

/// "Launch at Login" through `SMAppService`. The state lives in the system, not in our settings.
@MainActor
final class LoginItemController {
    private let service = SMAppService.mainApp

    /// Login items need a real `.app` bundle; a bare SwiftPM executable cannot register.
    var isAvailable: Bool {
        AppInfo.isBundled
    }

    var isEnabled: Bool {
        service.status == .enabled
    }

    /// The user must approve the item in System Settings before it takes effect.
    var requiresApproval: Bool {
        service.status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
