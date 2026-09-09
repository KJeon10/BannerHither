import XCTest
@testable import BannerHitherCore

@MainActor
final class UpdateCheckerTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var settings: SettingsStore!
    private var feed: FakeReleaseFeed!
    private var checker: UpdateChecker!
    private var now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() async throws {
        suiteName = "io.github.kjeon10.BannerHither.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settings = SettingsStore(defaults: defaults)
        feed = FakeReleaseFeed()
        checker = UpdateChecker(
            currentVersion: AppVersion("0.1.0")!,
            feed: feed,
            settings: settings,
            policy: UpdateCheckPolicy(interval: 3_600),
            now: { [unowned self] in self.now }
        )
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func release(_ version: String) -> ReleaseInfo {
        ReleaseInfo(version: AppVersion(version)!, tag: "v\(version)", pageURL: URL(string: "https://example.com/\(version)")!)
    }

    func testNewerReleaseBecomesAvailable() async {
        feed.result = .success(release("0.2.0"))
        let outcome = await checker.check(trigger: .automatic)
        XCTAssertEqual(outcome, .available(release("0.2.0")))
        XCTAssertEqual(checker.availableRelease, release("0.2.0"))
        XCTAssertEqual(checker.lastOutcome, outcome)
        XCTAssertEqual(settings.lastUpdateCheck, now)
    }

    func testUpToDateClearsAvailableReleaseAndAnObsoleteSkip() async {
        settings.skippedUpdateVersion = "0.1.0"
        feed.result = .success(release("0.1.0"))
        let outcome = await checker.check(trigger: .automatic)
        XCTAssertEqual(outcome, .upToDate(release("0.1.0")))
        XCTAssertNil(checker.availableRelease)
        XCTAssertNil(settings.skippedUpdateVersion)
    }

    func testSkippedVersionIsHiddenFromAutomaticChecksButReportedToManualOnes() async {
        feed.result = .success(release("0.2.0"))
        await checker.check(trigger: .automatic)

        checker.skip(release("0.2.0"))
        XCTAssertNil(checker.availableRelease)
        XCTAssertEqual(settings.skippedUpdateVersion, "0.2.0")

        let automatic = await checker.check(trigger: .automatic)
        XCTAssertEqual(automatic, .skipped(release("0.2.0")))
        XCTAssertNil(checker.availableRelease)

        let manual = await checker.check(trigger: .manual)
        XCTAssertEqual(manual, .available(release("0.2.0")))
        XCTAssertNil(checker.availableRelease, "looking at a skipped version by hand does not re-advertise it")
    }

    func testReleaseNewerThanTheSkippedOneIsOfferedAgain() async {
        checker.skip(release("0.2.0"))
        feed.result = .success(release("0.3.0"))
        let outcome = await checker.check(trigger: .automatic)
        XCTAssertEqual(outcome, .available(release("0.3.0")))
        XCTAssertEqual(checker.availableRelease, release("0.3.0"))
    }

    func testFailureKeepsThePreviousResultAndRecordsNoCheck() async {
        feed.result = .success(release("0.2.0"))
        await checker.check(trigger: .automatic)
        let recorded = settings.lastUpdateCheck

        feed.result = .failure(UpdateCheckError.httpStatus(503))
        now = now.addingTimeInterval(7_200)
        let outcome = await checker.check(trigger: .automatic)
        guard case .failed(let reason) = outcome else {
            return XCTFail("expected a failure, got \(outcome)")
        }
        XCTAssertTrue(reason.contains("503"), reason)
        XCTAssertEqual(checker.availableRelease, release("0.2.0"))
        XCTAssertEqual(settings.lastUpdateCheck, recorded)
    }

    func testAutomaticCheckIsDueOnlyWithConsentAndAfterTheInterval() async {
        XCTAssertFalse(checker.isAutomaticCheckDue)
        settings.automaticUpdateChecks = true
        XCTAssertTrue(checker.isAutomaticCheckDue)

        feed.result = .success(release("0.1.0"))
        await checker.check(trigger: .automatic)
        XCTAssertFalse(checker.isAutomaticCheckDue)

        now = now.addingTimeInterval(3_600)
        XCTAssertTrue(checker.isAutomaticCheckDue)
    }

    func testChangeHandlerReportsProgressAndAvailability() async {
        var events = 0
        checker.changeHandler = { events += 1 }
        feed.result = .success(release("0.2.0"))
        await checker.check(trigger: .automatic)
        XCTAssertEqual(events, 3, "checking started, release became available, checking finished")
    }

    func testOverlappingChecksShareOneFetch() async {
        feed.result = .success(release("0.2.0"))
        let first = Task { @MainActor in await self.checker.check(trigger: .automatic) }
        let second = Task { @MainActor in await self.checker.check(trigger: .manual) }
        let outcomes = await (first.value, second.value)
        XCTAssertEqual(outcomes.0, .available(release("0.2.0")))
        XCTAssertEqual(outcomes.1, .available(release("0.2.0")))
        XCTAssertEqual(feed.calls, 1)
    }
}

/// A feed whose answer the test controls. It suspends briefly so overlapping checks really overlap.
final class FakeReleaseFeed: ReleaseFeedFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var storedResult: Result<ReleaseInfo, Error> = .failure(UpdateCheckError.httpStatus(0))
    private var storedCalls = 0

    var result: Result<ReleaseInfo, Error> {
        get { lock.withLock { storedResult } }
        set { lock.withLock { storedResult = newValue } }
    }

    var calls: Int {
        lock.withLock { storedCalls }
    }

    func latestRelease() async throws -> ReleaseInfo {
        lock.withLock { storedCalls += 1 }
        try? await Task.sleep(for: .milliseconds(20))
        return try result.get()
    }
}
