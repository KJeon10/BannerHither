import Foundation

/// Runs update checks against a release feed and remembers the result.
///
/// The checker owns no timers and shows no UI: the app decides when to call `check(trigger:)`
/// and how to present the outcome. `availableRelease` is what the UI should advertise; it is
/// `nil` while the app is up to date, while the newest release is one the user skipped, and
/// until the first check has completed.
@MainActor
public final class UpdateChecker {
    public enum Trigger: Sendable {
        /// Scheduled in the background; respects "Skip This Version".
        case automatic
        /// Requested by the user; always reports a newer release, even a skipped one.
        case manual
    }

    public enum Outcome: Equatable, Sendable {
        case upToDate(ReleaseInfo)
        case available(ReleaseInfo)
        case skipped(ReleaseInfo)
        case failed(String)
    }

    public let currentVersion: AppVersion
    public private(set) var availableRelease: ReleaseInfo? {
        didSet { if availableRelease != oldValue { changeHandler?() } }
    }
    public private(set) var isChecking = false {
        didSet { if isChecking != oldValue { changeHandler?() } }
    }
    public private(set) var lastOutcome: Outcome?

    /// Called whenever `availableRelease` or `isChecking` changes.
    public var changeHandler: (() -> Void)?

    private let feed: any ReleaseFeedFetching
    private let settings: SettingsStore
    private let policy: UpdateCheckPolicy
    private let now: () -> Date
    private var inFlight: Task<Outcome, Never>?
    private let log = AppLog.logger(category: "updates")

    public init(
        currentVersion: AppVersion,
        feed: any ReleaseFeedFetching,
        settings: SettingsStore,
        policy: UpdateCheckPolicy = UpdateCheckPolicy(),
        now: @escaping () -> Date = Date.init
    ) {
        self.currentVersion = currentVersion
        self.feed = feed
        self.settings = settings
        self.policy = policy
        self.now = now
    }

    /// `true` when the user allowed automatic checks and the last one is old enough.
    public var isAutomaticCheckDue: Bool {
        settings.automaticUpdateChecks && policy.isDue(lastCheck: settings.lastUpdateCheck, now: now())
    }

    /// Fetches the newest release and evaluates it. Calls made while a check is in flight
    /// share that check's outcome.
    @discardableResult
    public func check(trigger: Trigger) async -> Outcome {
        if let inFlight {
            return await inFlight.value
        }
        let task = Task { @MainActor in
            await self.performCheck(trigger: trigger)
        }
        inFlight = task
        let outcome = await task.value
        inFlight = nil
        return outcome
    }

    /// Hides `release` until a newer version is published.
    public func skip(_ release: ReleaseInfo) {
        settings.skippedUpdateVersion = release.version.description
        if availableRelease?.version == release.version {
            availableRelease = nil
        }
        log.info("Skipping version \(release.version.description, privacy: .public)")
    }

    private func performCheck(trigger: Trigger) async -> Outcome {
        isChecking = true
        defer { isChecking = false }

        let outcome: Outcome
        do {
            let latest = try await feed.latestRelease()
            settings.lastUpdateCheck = now()

            let skipped = settings.skippedUpdateVersion.flatMap(AppVersion.init)
            switch policy.evaluate(latest: latest, current: currentVersion, skipped: skipped) {
            case .upToDate(let latest):
                // A skip only makes sense for a version newer than the running one.
                settings.skippedUpdateVersion = nil
                availableRelease = nil
                outcome = .upToDate(latest)
            case .available(let release):
                availableRelease = release
                outcome = .available(release)
            case .skipped(let release):
                availableRelease = nil
                // The user asked explicitly, so tell them even about a skipped version.
                outcome = trigger == .manual ? .available(release) : .skipped(release)
            }
            log.info("Update check (\(String(describing: trigger), privacy: .public)): latest \(latest.tag, privacy: .public), running \(self.currentVersion.description, privacy: .public)")
        } catch {
            let reason = error.localizedDescription
            outcome = .failed(reason)
            log.notice("Update check failed: \(reason, privacy: .public)")
        }
        lastOutcome = outcome
        return outcome
    }
}
