/// Where notification banners should appear while the engine is running.
public enum PlacementMode: Equatable, Sendable {
    /// Leave NotificationCenter alone; banners stay wherever macOS puts them.
    case systemDefault
    /// Move banners to the screen that currently contains the mouse pointer.
    case followMouse
    /// Move banners to the screen containing the focused window of the frontmost app.
    case followActiveWindow
    /// Always move banners to one specific display.
    case fixedDisplay(DisplayID)
}

extension PlacementMode {
    /// The mode family without its associated display; used for persistence, menus and logs.
    public enum Kind: String, CaseIterable, Sendable {
        case systemDefault
        case followMouse
        case followActiveWindow
        case fixedDisplay
    }

    public var kind: Kind {
        switch self {
        case .systemDefault: return .systemDefault
        case .followMouse: return .followMouse
        case .followActiveWindow: return .followActiveWindow
        case .fixedDisplay: return .fixedDisplay
        }
    }

    public var fixedDisplayID: DisplayID? {
        if case .fixedDisplay(let id) = self { return id }
        return nil
    }

    /// `false` only for `.systemDefault`, where the engine stays idle.
    public var relocatesBanners: Bool {
        self != .systemDefault
    }
}
