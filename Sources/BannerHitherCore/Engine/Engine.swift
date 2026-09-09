import CoreGraphics
import Foundation

/// Orchestrates permission, probing, resolving and the placement policy.
///
/// State machine:
///
///     stopped ──start()──▶ waitingForPermission ──granted──▶ running ──stop()──▶ stopped
///                                      ▲                        │
///                                      └──── permission lost ───┘
///
/// While `running`, the engine observes NotificationCenter through the probe (Accessibility
/// notifications plus an optional polling safety net) and, at each transition of the banner
/// window, asks `BannerPlacementPolicy` whether to move it. Everything happens on the main actor.
@MainActor
public final class Engine {
    public enum State: Equatable, Sendable {
        case stopped
        case waitingForPermission
        case running
    }

    /// What prompted an evaluation; only used for logging.
    public enum Trigger: String, Sendable {
        case start
        case accessibilityEvent
        case poll
        case screenConfigurationChanged
        case notificationCenterRelaunched
    }

    public private(set) var state: State = .stopped {
        didSet {
            guard oldValue != state else { return }
            log.info("State: \(oldValue.rawValue, privacy: .public) → \(self.state.rawValue, privacy: .public)")
            stateChangeHandler?(state)
        }
    }
    public var stateChangeHandler: ((State) -> Void)?

    /// Origin observed on the previous evaluation; `nil` while no banner window is visible.
    public private(set) var lastOrigin: CGPoint?
    /// Number of successful relocations since launch, surfaced in diagnostics.
    public private(set) var relocationCount = 0

    private let probe: any BannerWindowProbing
    private let resolver: any TargetScreenResolving
    private let permission: any AccessibilityAuthorizing
    private let settings: SettingsStore
    private var policy: BannerPlacementPolicy
    private var pollTimer: Timer?
    private var isObserving = false
    private let log = AppLog.logger(category: "engine")

    public init(
        probe: any BannerWindowProbing,
        resolver: any TargetScreenResolving,
        permission: any AccessibilityAuthorizing,
        settings: SettingsStore
    ) {
        self.probe = probe
        self.resolver = resolver
        self.permission = permission
        self.settings = settings
        self.policy = BannerPlacementPolicy(resizeToTargetScreen: settings.resizeToTargetScreen)

        settings.addObserver { [weak self] change in self?.settingsDidChange(change) }
        permission.trustChangeHandler = { [weak self] trusted in self?.trustDidChange(trusted) }
        probe.eventHandler = { [weak self] event in self?.probeDidReport(event) }
    }

    // MARK: Lifecycle

    public func start() {
        guard state == .stopped else { return }
        if permission.isTrusted {
            becomeRunning()
        } else {
            state = .waitingForPermission
            permission.requestAccess()
            permission.startMonitoring()
        }
    }

    /// Stops observing. A banner that is currently on screen is left where it is.
    public func stop() {
        guard state != .stopped else { return }
        permission.stopMonitoring()
        deactivateObservation()
        state = .stopped
    }

    /// Displays were added, removed or rearranged. Screens are looked up fresh on every
    /// evaluation, so only the transition memory needs resetting.
    public func screenConfigurationDidChange() {
        lastOrigin = nil
        evaluate(.screenConfigurationChanged)
    }

    // MARK: Evaluation

    /// Reads the banner window and applies the placement policy. Safe to call at any time.
    public func evaluate(_ trigger: Trigger) {
        guard state == .running, settings.placementMode.relocatesBanners else { return }

        do {
            guard let snapshot = try probe.snapshot() else {
                if lastOrigin != nil { log.debug("Banner window is gone") }
                lastOrigin = nil
                return
            }

            let mode = settings.placementMode
            let decision = policy.decide(
                snapshot: snapshot,
                previousOrigin: lastOrigin,
                primaryFrame: resolver.primaryFrame,
                targetScreen: { resolver.targetScreen(for: mode) }
            )
            // While the panel is open the window belongs to NotificationCenter; remembering its
            // position would only make the next banner look like a non-transition.
            if decision != .skip(.panelOpen) {
                lastOrigin = snapshot.origin
            }

            switch decision {
            case .skip(.noTransition):
                break
            case .skip(let reason):
                log.debug("Skip (\(reason.rawValue, privacy: .public)) at \(snapshot.origin.debugDescription, privacy: .public) via \(trigger.rawValue, privacy: .public)")
            case .move(let origin, let size):
                let actual = try probe.moveBanner(to: origin, resizingTo: size)
                // Re-read so the AXWindowMoved notification our own move produces is not mistaken for a transition.
                lastOrigin = actual
                relocationCount += 1
                log.info("Moved banner window \(snapshot.origin.debugDescription, privacy: .public) → \(actual.debugDescription, privacy: .public) via \(trigger.rawValue, privacy: .public)")
            }
        } catch BannerProbeError.accessibilityDenied {
            log.error("Accessibility permission was revoked; waiting until it is granted again")
            loseRunning()
        } catch BannerProbeError.notificationCenterNotRunning {
            lastOrigin = nil
        } catch {
            log.error("Evaluation failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: State transitions

    private func becomeRunning() {
        state = .running
        // Keep watching so a revoked permission is noticed even when no banner ever appears.
        permission.startMonitoring()
        refreshObservation()
    }

    private func loseRunning() {
        deactivateObservation()
        state = .waitingForPermission
        permission.startMonitoring()
    }

    private func trustDidChange(_ trusted: Bool) {
        switch (state, trusted) {
        case (.waitingForPermission, true):
            becomeRunning()
        case (.running, false):
            loseRunning()
        default:
            break
        }
    }

    // MARK: Observation

    /// Observing is worthwhile only while running in a mode that moves banners.
    private func refreshObservation() {
        let shouldObserve = state == .running && settings.placementMode.relocatesBanners
        if shouldObserve, !isObserving {
            activateObservation()
        } else if !shouldObserve, isObserving {
            deactivateObservation()
        }
    }

    private func activateObservation() {
        do {
            try probe.startObserving()
        } catch {
            log.error("Could not start observing NotificationCenter: \(String(describing: error), privacy: .public)")
            loseRunning()
            return
        }
        isObserving = true
        restartPolling()
        evaluate(.start)
    }

    private func deactivateObservation() {
        guard isObserving else { return }
        stopPolling()
        probe.stopObserving()
        isObserving = false
        lastOrigin = nil
    }

    private func restartPolling() {
        stopPolling()
        let interval = settings.pollInterval
        guard isObserving, interval > 0 else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate(.poll) }
        }
        timer.tolerance = interval * 0.2
        // `.common` keeps the timer firing while a menu (including our own) is being tracked.
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: Inputs

    private func settingsDidChange(_ change: SettingsStore.Change) {
        switch change {
        case .placementMode:
            // Applies from the next banner on; a banner already on screen is not moved back.
            log.info("Placement mode: \(self.settings.placementMode.kind.rawValue, privacy: .public)")
            refreshObservation()
        case .pollInterval:
            restartPolling()
        case .resizeToTargetScreen:
            policy.resizeToTargetScreen = settings.resizeToTargetScreen
        case .isEnabled, .automaticUpdateChecks:
            break
        }
    }

    private func probeDidReport(_ event: BannerProbeEvent) {
        switch event {
        case .windowChanged:
            evaluate(.accessibilityEvent)
        case .notificationCenterRelaunched:
            lastOrigin = nil
            evaluate(.notificationCenterRelaunched)
        }
    }
}

extension Engine.State {
    var rawValue: String {
        switch self {
        case .stopped: return "stopped"
        case .waitingForPermission: return "waitingForPermission"
        case .running: return "running"
        }
    }
}
