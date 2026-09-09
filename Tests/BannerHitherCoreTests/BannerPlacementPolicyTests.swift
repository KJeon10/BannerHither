import XCTest
@testable import BannerHitherCore

final class BannerPlacementPolicyTests: XCTestCase {
    private let primary = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let external = ScreenDescriptor(
        id: DisplayID(rawValue: "EXTERNAL"),
        name: "External",
        frame: CGRect(x: -3840, y: 37, width: 1920, height: 1080),
        isPrimary: false
    )
    private let windowSize = CGSize(width: 1728, height: 1117)
    private let movedOrigin = CGPoint(x: -3648, y: 37)
    private let policy = BannerPlacementPolicy()

    private func snapshot(at origin: CGPoint, panelOpen: Bool = false) -> BannerWindowSnapshot {
        BannerWindowSnapshot(origin: origin, size: windowSize, isPanelOpen: panelOpen)
    }

    func testWindowAppearingAtTheDefaultOriginIsMovedToTheTargetScreen() {
        let decision = policy.decide(snapshot: snapshot(at: .zero), previousOrigin: nil, primaryFrame: primary) { external }
        XCTAssertEqual(decision, .move(origin: movedOrigin, size: nil))
    }

    func testUnchangedPositionIsNotATransition() {
        var resolved = false
        let decision = policy.decide(snapshot: snapshot(at: .zero), previousOrigin: .zero, primaryFrame: primary) {
            resolved = true
            return external
        }
        XCTAssertEqual(decision, .skip(.noTransition))
        XCTAssertFalse(resolved, "the target screen must not be resolved when nothing changed")
    }

    func testOpenPanelIsNeverTouched() {
        let decision = policy.decide(snapshot: snapshot(at: .zero, panelOpen: true), previousOrigin: nil, primaryFrame: primary) { external }
        XCTAssertEqual(decision, .skip(.panelOpen))
    }

    func testWindowPlacedElsewhereByNotificationCenterIsLeftAlone() {
        let panelOrigin = CGPoint(x: -3840, y: 37)
        let decision = policy.decide(snapshot: snapshot(at: panelOrigin), previousOrigin: nil, primaryFrame: primary) { external }
        XCTAssertEqual(decision, .skip(.notAtSystemDefaultOrigin))
    }

    func testOurOwnMoveIsNotATransition() {
        let decision = policy.decide(snapshot: snapshot(at: movedOrigin), previousOrigin: movedOrigin, primaryFrame: primary) { external }
        XCTAssertEqual(decision, .skip(.noTransition))
    }

    func testRepositioningBackToTheDefaultOriginTriggersAnotherMove() {
        let decision = policy.decide(snapshot: snapshot(at: .zero), previousOrigin: movedOrigin, primaryFrame: primary) { external }
        XCTAssertEqual(decision, .move(origin: movedOrigin, size: nil))
    }

    func testMissingTargetScreenSkips() {
        let decision = policy.decide(snapshot: snapshot(at: .zero), previousOrigin: nil, primaryFrame: primary) { nil }
        XCTAssertEqual(decision, .skip(.noTargetScreen))
    }

    func testTargetOnThePrimaryDisplayNeedsNoMove() {
        let primaryScreen = ScreenDescriptor(id: DisplayID(rawValue: "PRIMARY"), name: "Built-in", frame: primary, isPrimary: true)
        let decision = policy.decide(snapshot: snapshot(at: .zero), previousOrigin: nil, primaryFrame: primary) { primaryScreen }
        XCTAssertEqual(decision, .skip(.alreadyOnTarget))
    }

    func testToleranceAbsorbsSubpixelDrift() {
        let decision = policy.decide(snapshot: snapshot(at: CGPoint(x: 0.5, y: -0.5)), previousOrigin: nil, primaryFrame: primary) { external }
        XCTAssertEqual(decision, .move(origin: movedOrigin, size: nil))
    }

    func testResizingToTheTargetScreenAlignsTheResizedWindow() {
        let resizing = BannerPlacementPolicy(resizeToTargetScreen: true)
        let decision = resizing.decide(snapshot: snapshot(at: .zero), previousOrigin: nil, primaryFrame: primary) { external }
        XCTAssertEqual(decision, .move(origin: CGPoint(x: -3840, y: 37), size: external.frame.size))
    }

    func testResizingIsSkippedWhenSizesAlreadyMatch() {
        let resizing = BannerPlacementPolicy(resizeToTargetScreen: true)
        let sameSize = ScreenDescriptor(id: external.id, name: external.name, frame: CGRect(origin: external.frame.origin, size: windowSize), isPrimary: false)
        let decision = resizing.decide(snapshot: snapshot(at: .zero), previousOrigin: nil, primaryFrame: primary) { sameSize }
        XCTAssertEqual(decision, .move(origin: sameSize.frame.origin, size: nil))
    }
}
