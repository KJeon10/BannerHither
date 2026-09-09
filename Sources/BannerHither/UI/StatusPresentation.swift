import AppKit
import BannerHitherCore

/// Everything the status item needs to render: derived from engine, permission and settings.
struct StatusPresentation {
    let symbolName: String
    let statusText: String

    @MainActor
    init(engineState: Engine.State, isTrusted: Bool, mode: PlacementMode, fixedDisplayName: String?) {
        switch engineState {
        case .stopped:
            symbolName = "bell.slash"
            statusText = L10n.statusStopped
        case .waitingForPermission:
            symbolName = "bell.badge.slash"
            statusText = L10n.statusNeedsPermission
        case .running:
            symbolName = "bell.badge.fill"
            switch mode {
            case .systemDefault:
                statusText = L10n.statusSystemDefault
            case .followMouse:
                statusText = L10n.statusFollowMouse
            case .followActiveWindow:
                statusText = L10n.statusFollowActiveWindow
            case .fixedDisplay(let id):
                if let screen = DisplayCatalog.screen(withID: id) {
                    statusText = L10n.statusFixedDisplay(screen.name)
                } else {
                    statusText = L10n.statusFixedDisplayDisconnected(fixedDisplayName ?? id.rawValue)
                }
            }
        }
    }

    /// The menu bar image; falls back to a plain bell when a symbol is unavailable on this OS.
    var image: NSImage? {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: statusText)
            ?? NSImage(systemSymbolName: "bell", accessibilityDescription: statusText)
    }
}
