import AppKit
import BannerHitherCore

/// Composition root: builds every long-lived object once and wires them together.
@MainActor
final class AppContainer {
    let settings: SettingsStore
    let permission: AccessibilityPermission
    let probe: NotificationCenterProbe
    let resolver: ScreenResolver
    let engine: Engine
    let loginItem: LoginItemController
    let testNotifications: TestNotificationSender
    let updates: UpdateCoordinator
    let diagnostics: DiagnosticsReporter
    let statusBar: StatusBarController

    init() {
        settings = SettingsStore()
        permission = AccessibilityPermission()
        probe = NotificationCenterProbe()
        resolver = ScreenResolver(ignoredBundleIdentifiers: [NotificationCenterProbe.Constants.bundleIdentifier])
        engine = Engine(probe: probe, resolver: resolver, permission: permission, settings: settings)
        loginItem = LoginItemController()
        testNotifications = TestNotificationSender()
        updates = UpdateCoordinator(settings: settings)
        diagnostics = DiagnosticsReporter(
            engine: engine,
            settings: settings,
            permission: permission,
            probe: probe,
            resolver: resolver,
            loginItem: loginItem,
            updates: updates
        )
        statusBar = StatusBarController(
            engine: engine,
            settings: settings,
            permission: permission,
            loginItem: loginItem,
            testNotifications: testNotifications,
            diagnostics: diagnostics,
            updates: updates
        )
    }

    func start() {
        settings.addObserver { [weak self] change in
            guard let self else { return }
            if change == .isEnabled { self.applyEnabledState() }
            self.statusBar.refresh()
        }
        engine.stateChangeHandler = { [weak self] state in
            guard let self else { return }
            self.statusBar.refresh()
            if state == .running {
                self.updates.engineDidStart()
            }
        }
        updates.changeHandler = { [weak self] in
            self?.statusBar.refresh()
        }
        applyEnabledState()
        updates.start()
    }

    func screenParametersDidChange() {
        engine.screenConfigurationDidChange()
        statusBar.refresh()
    }

    private func applyEnabledState() {
        if settings.isEnabled {
            engine.start()
        } else {
            engine.stop()
        }
    }
}
