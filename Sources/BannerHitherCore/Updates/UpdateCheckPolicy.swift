import Foundation

/// The verdict of comparing a published release with the running version.
public enum UpdateEvaluation: Equatable, Sendable {
    /// The running version is the newest one (or newer than anything published).
    case upToDate(latest: ReleaseInfo)
    /// A newer release exists and should be offered.
    case available(ReleaseInfo)
    /// A newer release exists but the user chose to skip exactly this version.
    case skipped(ReleaseInfo)
}

/// Pure decisions behind update checks: when an automatic check is due and what a result means.
public struct UpdateCheckPolicy: Sendable {
    public static let defaultInterval: TimeInterval = 24 * 60 * 60

    /// Minimum time between two automatic checks.
    public let interval: TimeInterval

    public init(interval: TimeInterval = UpdateCheckPolicy.defaultInterval) {
        self.interval = interval
    }

    /// An automatic check is due when none has ever completed or the last one is older than
    /// `interval`. A last check that lies in the future (the clock was set back) counts as due,
    /// so a wrong clock can never silence checks for good.
    public func isDue(lastCheck: Date?, now: Date = Date()) -> Bool {
        guard let lastCheck else { return true }
        return lastCheck > now || now.timeIntervalSince(lastCheck) >= interval
    }

    /// Compares `latest` with `current`. A skipped version stays hidden only while it is the
    /// newest release; anything newer than the skipped version is offered again.
    public func evaluate(latest: ReleaseInfo, current: AppVersion, skipped: AppVersion?) -> UpdateEvaluation {
        guard latest.version > current else { return .upToDate(latest: latest) }
        if let skipped, latest.version == skipped {
            return .skipped(latest)
        }
        return .available(latest)
    }
}
