import XCTest
@testable import BannerHitherCore

/// Values come from a real three-display setup: a 1728×1117 built-in (primary) display and
/// two 1920×1080 externals arranged to its left.
final class ScreenGeometryTests: XCTestCase {
    private let primaryHeight: CGFloat = 1117
    private let builtIn = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let external = CGRect(x: -3840, y: 0, width: 1920, height: 1080)

    func testPrimaryDisplayKeepsItsOriginInCoreGraphicsCoordinates() {
        XCTAssertEqual(ScreenGeometry.cgFrame(appKitFrame: builtIn, primaryHeight: primaryHeight), builtIn)
    }

    func testShorterExternalDisplayIsOffsetByTheHeightDifference() {
        let frame = ScreenGeometry.cgFrame(appKitFrame: external, primaryHeight: primaryHeight)
        XCTAssertEqual(frame, CGRect(x: -3840, y: 37, width: 1920, height: 1080))
    }

    func testMousePointConversionFlipsY() {
        let point = ScreenGeometry.cgPoint(appKitPoint: CGPoint(x: 100, y: 1117), primaryHeight: primaryHeight)
        XCTAssertEqual(point, CGPoint(x: 100, y: 0))
    }

    func testTopRightAlignmentOnAnExternalDisplay() {
        let screen = ScreenGeometry.cgFrame(appKitFrame: external, primaryHeight: primaryHeight)
        let origin = ScreenGeometry.topRightAlignedOrigin(windowSize: CGSize(width: 1728, height: 1117), in: screen)
        XCTAssertEqual(origin, CGPoint(x: -3648, y: 37))
    }

    func testTopRightAlignmentOnThePrimaryDisplayIsItsOrigin() {
        let origin = ScreenGeometry.topRightAlignedOrigin(windowSize: builtIn.size, in: builtIn)
        XCTAssertEqual(origin, .zero)
    }

    func testIsNearUsesPerAxisTolerance() {
        XCTAssertTrue(ScreenGeometry.isNear(CGPoint(x: 0, y: 0), CGPoint(x: 1, y: -1)))
        XCTAssertFalse(ScreenGeometry.isNear(CGPoint(x: 0, y: 0), CGPoint(x: 1.5, y: 0)))
        XCTAssertTrue(ScreenGeometry.isNear(CGPoint(x: 0, y: 0), CGPoint(x: 1.5, y: 0), tolerance: 2))
    }
}
