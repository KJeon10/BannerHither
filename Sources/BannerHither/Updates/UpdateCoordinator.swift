import AppKit
import BannerHitherCore

/// Drives update checks: the one-time consent question, the daily automatic check, the manual
/// "Check for Updates…" flow and the alerts that present results.
///
/// An automatic check never interrupts the user: a newer release only adds a menu item and a
/// badge on the status icon. The alert with Download / Later / Skip This Version appears when
/// the user opens that item or checks by hand.
@MainActor
final class UpdateCoordinator {
    /// How often the coordinator re-evaluates whether a daily check is due. Together with the
    /// wake-from-sleep notification this keeps the schedule alive on a Mac that never restarts.
    private static let scheduleInterval: TimeInterval = 60 * 60
    private static let launchDelay: TimeInterval = 5
    private static let consentDelay: TimeInterval = 1.5

    let checker: UpdateChecker
    let feedURL: URL
    private let settings: SettingsStore
    private var scheduleTimer: Timer?
    private var wakeObserver: (any NSObjectProtocol)?
    private var consentScheduled = false
    private let log = AppLog.logger(category: "updates")

    /// Called whenever the menu or the status icon should be refreshed.
    var changeHandler: (() -> Void)?

    init(settings: SettingsStore) {
        self.settings = settings
        feedURL = settings.updateFeedURL ?? GitHubReleaseFeed.latestReleaseURL(repository: AppInfo.repository)
        let feed = GitHubReleaseFeed(url: feedURL, userAgent: AppInfo.userAgent)
        checker = UpdateChecker(currentVersion: AppInfo.currentVersion, feed: feed, settings: settings)
        checker.changeHandler = { [weak self] in self?.changeHandler?() }
    }

    var availableRelease: ReleaseInfo? {
        checker.availableRelease
    }

    var isChecking: Bool {
        checker.isChecking
    }

    func start() {
        let timer = Timer(timeInterval: Self.scheduleInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        RunLoop.main.add(timer, forMode: .common)
        scheduleTimer = timer

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }

        // Let the app settle after launch before touching the network.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.launchDelay))
            self?.checkIfDue()
        }
    }

    /// The consent question waits until the Accessibility prompt is out of the way, i.e. until
    /// the engine runs for the first time, so the two dialogs never stack.
    func engineDidStart() {
        guard !settings.updateConsentAsked, !consentScheduled else { return }
        consentScheduled = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.consentDelay))
            self?.askForConsent()
        }
    }

    /// Runs an automatic check when the user allowed them and the last one is a day old.
    func checkIfDue() {
        guard checker.isAutomaticCheckDue, !checker.isChecking else { return }
        Task { await checker.check(trigger: .automatic) }
    }

    /// "Check for Updates…": always ends in an alert, whatever the outcome.
    func checkNow() {
        Task {
            let outcome = await checker.check(trigger: .manual)
            present(outcome)
        }
    }

    /// The menu item shown while a newer release is known.
    func presentAvailableRelease() {
        guard let release = checker.availableRelease else { return }
        presentAvailable(release)
    }

    /// The menu toggle. Using it answers the consent question as well.
    func setAutomaticChecks(_ enabled: Bool) {
        settings.automaticUpdateChecks = enabled
        settings.updateConsentAsked = true
        if enabled {
            checkIfDue()
        }
    }

    // MARK: Dialogs

    private func askForConsent() {
        guard !settings.updateConsentAsked else { return }
        let alert = NSAlert()
        alert.messageText = L10n.updateConsentTitle
        alert.informativeText = L10n.updateConsentBody
        alert.addButton(withTitle: L10n.updateConsentAllow)
        alert.addButton(withTitle: L10n.updateConsentDeny)

        let allowed = runModal(alert) == .alertFirstButtonReturn
        settings.updateConsentAsked = true
        settings.automaticUpdateChecks = allowed
        log.info("Automatic update checks \(allowed ? "allowed" : "declined", privacy: .public)")
        if allowed {
            checkIfDue()
        }
    }

    private func present(_ outcome: UpdateChecker.Outcome) {
        switch outcome {
        case .available(let release), .skipped(let release):
            presentAvailable(release)
        case .upToDate:
            let alert = NSAlert()
            alert.messageText = L10n.updateUpToDateTitle
            alert.informativeText = L10n.updateUpToDateBody(AppInfo.version)
            alert.addButton(withTitle: L10n.alertOK)
            runModal(alert)
        case .failed(let reason):
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L10n.updateFailedTitle
            alert.informativeText = L10n.updateFailedBody(reason)
            alert.addButton(withTitle: L10n.alertOK)
            runModal(alert)
        }
    }

    private func presentAvailable(_ release: ReleaseInfo) {
        let alert = NSAlert()
        alert.messageText = L10n.updateAvailableTitle(release.version.description)
        alert.informativeText = L10n.updateAvailableBody(AppInfo.version)
        alert.addButton(withTitle: L10n.updateDownload)
        alert.addButton(withTitle: L10n.updateLater)
        alert.addButton(withTitle: L10n.updateSkip)

        switch runModal(alert) {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(release.downloadURL ?? release.pageURL)
        case .alertThirdButtonReturn:
            checker.skip(release)
        default:
            break
        }
    }

    @discardableResult
    private func runModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate()
        return alert.runModal()
    }
}
