import Foundation

/// Persists user preferences in `UserDefaults` and tells observers what changed.
///
/// All keys are plain `defaults(1)`-friendly values so advanced options can be adjusted
/// from the command line, e.g. `defaults write io.github.kjeon10.BannerHither pollIntervalMilliseconds -int 500`.
@MainActor
public final class SettingsStore {
    public enum Key {
        public static let placementMode = "placementMode"
        public static let fixedDisplayID = "fixedDisplayID"
        public static let fixedDisplayName = "fixedDisplayName"
        public static let isEnabled = "isEnabled"
        public static let pollIntervalMilliseconds = "pollIntervalMilliseconds"
        public static let resizeToTargetScreen = "resizeToTargetScreen"
    }

    public enum Change: Sendable {
        case placementMode
        case isEnabled
        case pollInterval
        case resizeToTargetScreen
    }

    public static let defaultPollIntervalMilliseconds = 1_000
    /// Polling below this interval buys nothing and only burns CPU on Accessibility round trips.
    public static let minimumPollIntervalMilliseconds = 50
    public static let maximumPollIntervalMilliseconds = 5_000

    private let defaults: UserDefaults
    private var observers: [@MainActor (Change) -> Void] = []

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.placementMode: PlacementMode.Kind.followMouse.rawValue,
            Key.isEnabled: true,
            Key.pollIntervalMilliseconds: Self.defaultPollIntervalMilliseconds,
            Key.resizeToTargetScreen: false,
        ])
    }

    // MARK: Placement

    public var placementMode: PlacementMode {
        get {
            let kind = defaults.string(forKey: Key.placementMode).flatMap(PlacementMode.Kind.init(rawValue:)) ?? .followMouse
            switch kind {
            case .systemDefault: return .systemDefault
            case .followMouse: return .followMouse
            case .followActiveWindow: return .followActiveWindow
            case .fixedDisplay:
                // A fixed mode without a display is meaningless; fall back to doing nothing.
                guard let raw = defaults.string(forKey: Key.fixedDisplayID) else { return .systemDefault }
                return .fixedDisplay(DisplayID(rawValue: raw))
            }
        }
        set {
            defaults.set(newValue.kind.rawValue, forKey: Key.placementMode)
            if let id = newValue.fixedDisplayID {
                defaults.set(id.rawValue, forKey: Key.fixedDisplayID)
            }
            notify(.placementMode)
        }
    }

    /// Last known name of the fixed display, shown in the menu while that display is disconnected.
    public var fixedDisplayName: String? {
        get { defaults.string(forKey: Key.fixedDisplayName) }
        set { defaults.set(newValue, forKey: Key.fixedDisplayName) }
    }

    // MARK: Engine

    /// Whether the engine should run (the Start/Stop menu item).
    public var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled) }
        set {
            defaults.set(newValue, forKey: Key.isEnabled)
            notify(.isEnabled)
        }
    }

    /// Safety-net polling interval in seconds; `0` disables polling and relies on Accessibility events alone.
    public var pollInterval: TimeInterval {
        get { TimeInterval(pollIntervalMilliseconds) / 1_000 }
    }

    public var pollIntervalMilliseconds: Int {
        get {
            let stored = defaults.integer(forKey: Key.pollIntervalMilliseconds)
            return stored <= 0 ? 0 : min(max(stored, Self.minimumPollIntervalMilliseconds), Self.maximumPollIntervalMilliseconds)
        }
        set {
            defaults.set(newValue, forKey: Key.pollIntervalMilliseconds)
            notify(.pollInterval)
        }
    }

    public var resizeToTargetScreen: Bool {
        get { defaults.bool(forKey: Key.resizeToTargetScreen) }
        set {
            defaults.set(newValue, forKey: Key.resizeToTargetScreen)
            notify(.resizeToTargetScreen)
        }
    }

    // MARK: Observation

    /// Registers a change handler for the lifetime of the store.
    public func addObserver(_ handler: @escaping @MainActor (Change) -> Void) {
        observers.append(handler)
    }

    private func notify(_ change: Change) {
        for observer in observers {
            observer(change)
        }
    }
}
