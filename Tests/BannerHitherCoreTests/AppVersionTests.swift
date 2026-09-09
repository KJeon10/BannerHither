import XCTest
@testable import BannerHitherCore

final class AppVersionTests: XCTestCase {
    func testParsesTagsAndPlainVersions() {
        XCTAssertEqual(AppVersion("v0.1.0"), AppVersion([0, 1, 0]))
        XCTAssertEqual(AppVersion("0.2"), AppVersion([0, 2]))
        XCTAssertEqual(AppVersion(" V1.2.3 "), AppVersion([1, 2, 3]))
    }

    func testIgnoresPreReleaseAndBuildSuffixes() {
        XCTAssertEqual(AppVersion("1.2.0-beta.1"), AppVersion([1, 2, 0]))
        XCTAssertEqual(AppVersion("1.2.0+45"), AppVersion([1, 2, 0]))
    }

    func testRejectsNonNumericText() {
        XCTAssertNil(AppVersion("latest"))
        XCTAssertNil(AppVersion("1.x"))
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("1..2"))
        XCTAssertNil(AppVersion("-1"))
    }

    func testOrdering() {
        XCTAssertLessThan(AppVersion("0.1.0")!, AppVersion("0.2.0")!)
        XCTAssertLessThan(AppVersion("0.9.9")!, AppVersion("1.0")!)
        XCTAssertLessThan(AppVersion("1.2")!, AppVersion("1.2.1")!)
        XCTAssertFalse(AppVersion("1.2.0")! < AppVersion("1.2")!)
        XCTAssertFalse(AppVersion("1.2")! < AppVersion("1.2.0")!)
    }

    func testTrailingZerosDoNotMatterButAreKeptForDisplay() {
        XCTAssertEqual(AppVersion("1.2")!, AppVersion("1.2.0")!)
        XCTAssertEqual(AppVersion("1.2")!.hashValue, AppVersion("1.2.0")!.hashValue)
        XCTAssertEqual(AppVersion("1.2.0")!.description, "1.2.0")
        XCTAssertEqual(AppVersion("v0.1.0")!.description, "0.1.0")
    }
}
