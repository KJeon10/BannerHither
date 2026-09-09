import XCTest
@testable import BannerHitherCore

final class UpdateCheckPolicyTests: XCTestCase {
    private let policy = UpdateCheckPolicy(interval: 3_600)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let current = AppVersion("0.1.0")!

    private func release(_ version: String) -> ReleaseInfo {
        ReleaseInfo(version: AppVersion(version)!, tag: "v\(version)", pageURL: URL(string: "https://example.com/\(version)")!)
    }

    // MARK: Scheduling

    func testFirstCheckIsAlwaysDue() {
        XCTAssertTrue(policy.isDue(lastCheck: nil, now: now))
    }

    func testRecentCheckIsNotDue() {
        XCTAssertFalse(policy.isDue(lastCheck: now.addingTimeInterval(-600), now: now))
    }

    func testCheckOlderThanTheIntervalIsDue() {
        XCTAssertTrue(policy.isDue(lastCheck: now.addingTimeInterval(-3_600), now: now))
    }

    func testCheckDatedInTheFutureIsDue() {
        XCTAssertTrue(policy.isDue(lastCheck: now.addingTimeInterval(600), now: now))
    }

    // MARK: Evaluation

    func testNewerReleaseIsAvailable() {
        XCTAssertEqual(policy.evaluate(latest: release("0.2.0"), current: current, skipped: nil), .available(release("0.2.0")))
    }

    func testSameOrOlderReleaseIsUpToDate() {
        XCTAssertEqual(policy.evaluate(latest: release("0.1.0"), current: current, skipped: nil), .upToDate(latest: release("0.1.0")))
        XCTAssertEqual(policy.evaluate(latest: release("0.0.9"), current: current, skipped: nil), .upToDate(latest: release("0.0.9")))
    }

    func testSkippedVersionStaysHidden() {
        XCTAssertEqual(policy.evaluate(latest: release("0.2.0"), current: current, skipped: AppVersion("0.2.0")), .skipped(release("0.2.0")))
    }

    func testReleaseNewerThanTheSkippedOneIsOfferedAgain() {
        XCTAssertEqual(policy.evaluate(latest: release("0.3.0"), current: current, skipped: AppVersion("0.2.0")), .available(release("0.3.0")))
    }
}
