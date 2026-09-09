import AppKit
import BannerHitherCore

/// A snapshot of everything the menu displays, captured when the menu opens.
struct StatusMenuState {
    var engineState: Engine.State
    var isTrusted: Bool
    var placementMode: PlacementMode
    var fixedDisplayName: String?
    var screens: [ScreenDescriptor]
    var isLaunchAtLoginEnabled: Bool
    var canToggleLaunchAtLogin: Bool
    var availableUpdate: ReleaseInfo?
    var isAutomaticUpdateCheckEnabled: Bool
    var isCheckingForUpdates: Bool
}

/// Builds the status item menu. Actions are selectors on `StatusBarController`; the builder
/// itself holds no state so the menu is simply rebuilt from a fresh `StatusMenuState` each time.
@MainActor
struct StatusMenuBuilder {
    let target: StatusBarController

    func populate(_ menu: NSMenu, with state: StatusMenuState) {
        menu.removeAllItems()

        let presentation = StatusPresentation(
            engineState: state.engineState,
            isTrusted: state.isTrusted,
            mode: state.placementMode,
            fixedDisplayName: state.fixedDisplayName
        )
        menu.addItem(label(presentation.statusText))
        if let update = state.availableUpdate {
            let item = item(L10n.menuUpdateAvailable(update.version.description), action: #selector(StatusBarController.showAvailableUpdate(_:)))
            item.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let toggleTitle = state.engineState == .stopped ? L10n.menuStart : L10n.menuStop
        menu.addItem(item(toggleTitle, action: #selector(StatusBarController.toggleEnabled(_:))))
        menu.addItem(.separator())

        menu.addItem(label(L10n.menuPlacementHeader))
        menu.addItem(modeItem(L10n.modeSystemDefault, kind: .systemDefault, current: state.placementMode))
        menu.addItem(modeItem(L10n.modeFollowMouse, kind: .followMouse, current: state.placementMode))
        menu.addItem(modeItem(L10n.modeFollowActiveWindow, kind: .followActiveWindow, current: state.placementMode))
        menu.addItem(fixedDisplayItem(state))
        menu.addItem(.separator())

        let loginItem = item(L10n.menuLaunchAtLogin, action: #selector(StatusBarController.toggleLaunchAtLogin(_:)))
        loginItem.state = state.isLaunchAtLoginEnabled ? .on : .off
        loginItem.isEnabled = state.canToggleLaunchAtLogin
        menu.addItem(loginItem)

        let automaticUpdates = item(L10n.menuAutomaticUpdateChecks, action: #selector(StatusBarController.toggleAutomaticUpdateChecks(_:)))
        automaticUpdates.state = state.isAutomaticUpdateCheckEnabled ? .on : .off
        menu.addItem(automaticUpdates)

        if !state.isTrusted {
            menu.addItem(item(L10n.menuOpenAccessibilitySettings, action: #selector(StatusBarController.openAccessibilitySettings(_:))))
        }
        menu.addItem(item(L10n.menuSendTestNotification, action: #selector(StatusBarController.sendTestNotification(_:))))
        menu.addItem(item(L10n.menuCopyDiagnostics, action: #selector(StatusBarController.copyDiagnostics(_:))))
        menu.addItem(.separator())

        let checkTitle = state.isCheckingForUpdates ? L10n.menuCheckingForUpdates : L10n.menuCheckForUpdates
        let check = item(checkTitle, action: #selector(StatusBarController.checkForUpdates(_:)))
        check.isEnabled = !state.isCheckingForUpdates
        menu.addItem(check)
        menu.addItem(item(L10n.menuAbout, action: #selector(StatusBarController.showAbout(_:))))
        menu.addItem(.separator())

        let quit = item(L10n.menuQuit, action: #selector(StatusBarController.quit(_:)))
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    // MARK: Items

    private func label(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func item(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        return item
    }

    private func modeItem(_ title: String, kind: PlacementMode.Kind, current: PlacementMode) -> NSMenuItem {
        let item = item(title, action: #selector(StatusBarController.selectPlacementMode(_:)))
        item.representedObject = kind.rawValue
        item.state = current.kind == kind ? .on : .off
        item.indentationLevel = 1
        return item
    }

    private func fixedDisplayItem(_ state: StatusMenuState) -> NSMenuItem {
        let parent = NSMenuItem(title: L10n.modeFixedDisplay, action: nil, keyEquivalent: "")
        parent.indentationLevel = 1
        parent.state = state.placementMode.kind == .fixedDisplay ? .on : .off

        let submenu = NSMenu(title: L10n.modeFixedDisplay)
        let selectedID = state.placementMode.fixedDisplayID
        for screen in state.screens {
            let item = item(screen.name, action: #selector(StatusBarController.selectFixedDisplay(_:)))
            item.representedObject = screen
            item.state = screen.id == selectedID ? .on : .off
            submenu.addItem(item)
        }
        if let selectedID, !state.screens.contains(where: { $0.id == selectedID }) {
            let missing = label(L10n.menuDisplayDisconnected(state.fixedDisplayName ?? selectedID.rawValue))
            missing.state = .on
            submenu.addItem(missing)
        }
        if submenu.items.isEmpty {
            submenu.addItem(label(L10n.menuNoDisplays))
        }
        parent.submenu = submenu
        return parent
    }
}
