import AppKit
import BannerHitherCore

/// Everything the status item needs to render: derived from engine, permission and settings.
struct StatusPresentation {
    let symbolName: String
    let statusText: String
    /// Adds a dot to the icon while a newer release is waiting in the menu.
    let hasUpdateBadge: Bool

    @MainActor
    init(engineState: Engine.State, isTrusted: Bool, mode: PlacementMode, fixedDisplayName: String?, hasUpdateBadge: Bool = false) {
        self.hasUpdateBadge = hasUpdateBadge
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
        let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: statusText)
            ?? NSImage(systemSymbolName: "bell", accessibilityDescription: statusText)
        guard let symbol else { return nil }
        return hasUpdateBadge ? Self.badged(symbol) : symbol
    }

    /// Draws a small dot in the lower-right corner, separated from the symbol by a cleared ring.
    /// The result stays a template image so it follows the menu bar's appearance.
    static func badged(_ symbol: NSImage) -> NSImage {
        let image = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            let diameter = (rect.height * 0.36).rounded()
            let dot = CGRect(x: rect.maxX - diameter, y: rect.minY, width: diameter, height: diameter)
            guard let context = NSGraphicsContext.current?.cgContext else { return true }

            context.saveGState()
            context.setBlendMode(.destinationOut)
            NSColor.black.setFill()
            NSBezierPath(ovalIn: dot.insetBy(dx: -1.25, dy: -1.25)).fill()
            context.restoreGState()

            NSColor.black.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = symbol.accessibilityDescription
        return image
    }
}
