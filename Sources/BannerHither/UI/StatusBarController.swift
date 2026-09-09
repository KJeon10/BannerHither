import AppKit
import BannerHitherCore

/// Owns the `NSStatusItem`, renders its icon, and handles menu actions.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let engine: Engine
    private let settings: SettingsStore
    private let permission: AccessibilityPermission
    private let loginItem: LoginItemController
    private let testNotifications: TestNotificationSender
    private let diagnostics: DiagnosticsReporter
    private let updates: UpdateCoordinator
    private lazy var menuBuilder = StatusMenuBuilder(target: self)
    private let log = AppLog.logger(category: "ui")

    init(
        engine: Engine,
        settings: SettingsStore,
        permission: AccessibilityPermission,
        loginItem: LoginItemController,
        testNotifications: TestNotificationSender,
        diagnostics: DiagnosticsReporter,
        updates: UpdateCoordinator
    ) {
        self.engine = engine
        self.settings = settings
        self.permission = permission
        self.loginItem = loginItem
        self.testNotifications = testNotifications
        self.diagnostics = diagnostics
        self.updates = updates
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refresh()
    }

    /// Re-renders the icon and tooltip from the current state.
    func refresh() {
        let presentation = StatusPresentation(
            engineState: engine.state,
            isTrusted: permission.isTrusted,
            mode: settings.placementMode,
            fixedDisplayName: settings.fixedDisplayName,
            hasUpdateBadge: updates.availableRelease != nil
        )
        statusItem.button?.image = presentation.image
        statusItem.button?.toolTip = "\(AppInfo.name) — \(presentation.statusText)"
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        let state = StatusMenuState(
            engineState: engine.state,
            isTrusted: permission.isTrusted,
            placementMode: settings.placementMode,
            fixedDisplayName: settings.fixedDisplayName,
            screens: DisplayCatalog.screens(),
            isLaunchAtLoginEnabled: loginItem.isEnabled,
            canToggleLaunchAtLogin: loginItem.isAvailable,
            availableUpdate: updates.availableRelease,
            isAutomaticUpdateCheckEnabled: settings.automaticUpdateChecks,
            isCheckingForUpdates: updates.isChecking
        )
        menuBuilder.populate(menu, with: state)
    }

    // MARK: Actions

    @objc func toggleEnabled(_ sender: Any?) {
        settings.isEnabled.toggle()
    }

    @objc func selectPlacementMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let kind = PlacementMode.Kind(rawValue: raw) else { return }
        switch kind {
        case .systemDefault: settings.placementMode = .systemDefault
        case .followMouse: settings.placementMode = .followMouse
        case .followActiveWindow: settings.placementMode = .followActiveWindow
        case .fixedDisplay: break // chosen through the submenu
        }
    }

    @objc func selectFixedDisplay(_ sender: NSMenuItem) {
        guard let screen = sender.representedObject as? ScreenDescriptor else { return }
        settings.fixedDisplayName = screen.name
        settings.placementMode = .fixedDisplay(screen.id)
    }

    @objc func toggleLaunchAtLogin(_ sender: Any?) {
        do {
            try loginItem.setEnabled(!loginItem.isEnabled)
            if loginItem.requiresApproval {
                presentLoginItemApprovalAlert()
            }
        } catch {
            log.error("Login item change failed: \(String(describing: error), privacy: .public)")
            let alert = NSAlert()
            alert.messageText = L10n.alertLoginItemFailed
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: L10n.alertOK)
            alert.runModal()
        }
    }

    @objc func toggleAutomaticUpdateChecks(_ sender: Any?) {
        updates.setAutomaticChecks(!settings.automaticUpdateChecks)
    }

    @objc func checkForUpdates(_ sender: Any?) {
        updates.checkNow()
    }

    @objc func showAvailableUpdate(_ sender: Any?) {
        updates.presentAvailableRelease()
    }

    @objc func showAbout(_ sender: Any?) {
        AboutPanel.show()
    }

    @objc func openAccessibilitySettings(_ sender: Any?) {
        AccessibilityPermission.openSystemSettings()
    }

    @objc func sendTestNotification(_ sender: Any?) {
        testNotifications.send(after: 3)
    }

    @objc func copyDiagnostics(_ sender: Any?) {
        diagnostics.copyToPasteboard()
    }

    @objc func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    private func presentLoginItemApprovalAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.alertLoginItemRequiresApproval
        alert.addButton(withTitle: L10n.alertOpenLoginItems)
        alert.addButton(withTitle: L10n.alertOK)
        if alert.runModal() == .alertFirstButtonReturn {
            LoginItemController.openSystemSettings()
        }
    }
}
