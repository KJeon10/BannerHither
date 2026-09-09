import XCTest
@testable import BannerHitherCore

@MainActor
final class EngineTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var settings: SettingsStore!
    private var probe: FakeProbe!
    private var resolver: FakeResolver!
    private var permission: FakePermission!
    private var engine: Engine!

    private let primary = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let external = ScreenDescriptor(
        id: DisplayID(rawValue: "EXTERNAL"),
        name: "External",
        frame: CGRect(x: -3840, y: 37, width: 1920, height: 1080),
        isPrimary: false
    )
    private let windowSize = CGSize(width: 1728, height: 1117)
    private let movedOrigin = CGPoint(x: -3648, y: 37)

    override func setUp() async throws {
        suiteName = "io.github.kjeon10.BannerHither.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settings = SettingsStore(defaults: defaults)
        settings.pollIntervalMilliseconds = 0 // keep the run loop out of the tests
        probe = FakeProbe()
        resolver = FakeResolver(primaryFrame: primary)
        resolver.target = external
        permission = FakePermission(isTrusted: true)
        engine = Engine(probe: probe, resolver: resolver, permission: permission, settings: settings)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func banner(at origin: CGPoint, panelOpen: Bool = false) -> BannerWindowSnapshot {
        BannerWindowSnapshot(origin: origin, size: windowSize, isPanelOpen: panelOpen)
    }

    // MARK: Lifecycle

    func testStartWithPermissionRunsAndObserves() {
        engine.start()
        XCTAssertEqual(engine.state, .running)
        XCTAssertTrue(probe.isObserving)
        XCTAssertEqual(permission.requestCount, 0)
    }

    func testStartWithoutPermissionPromptsAndWaits() {
        permission.isTrusted = false
        engine.start()
        XCTAssertEqual(engine.state, .waitingForPermission)
        XCTAssertEqual(permission.requestCount, 1)
        XCTAssertTrue(permission.isMonitoring)
        XCTAssertFalse(probe.isObserving)

        permission.grant()
        XCTAssertEqual(engine.state, .running)
        XCTAssertTrue(probe.isObserving)
    }

    func testStopReleasesObservationAndKeepsTheBannerWhereItIs() {
        probe.snapshotResult = .success(banner(at: .zero))
        engine.start()
        XCTAssertEqual(probe.moves.count, 1)

        engine.stop()
        XCTAssertEqual(engine.state, .stopped)
        XCTAssertFalse(probe.isObserving)
        XCTAssertNil(engine.lastOrigin)
        XCTAssertEqual(probe.moves.count, 1)
    }

    func testSystemDefaultModeDoesNotObserve() {
        settings.placementMode = .systemDefault
        engine.start()
        XCTAssertEqual(engine.state, .running)
        XCTAssertFalse(probe.isObserving)

        settings.placementMode = .followMouse
        XCTAssertTrue(probe.isObserving)

        settings.placementMode = .systemDefault
        XCTAssertFalse(probe.isObserving)
    }

    // MARK: Evaluation

    func testNoWindowIsANoOp() {
        probe.snapshotResult = .success(nil)
        engine.start()
        XCTAssertTrue(probe.moves.isEmpty)
        XCTAssertNil(engine.lastOrigin)
    }

    func testBannerAppearingAtTheDefaultOriginIsMovedOnce() {
        engine.start()
        probe.snapshotResult = .success(banner(at: .zero))
        probe.emit(.windowChanged)
        XCTAssertEqual(probe.moves, [FakeProbe.Move(origin: movedOrigin, size: nil)])
        XCTAssertEqual(engine.lastOrigin, movedOrigin)
        XCTAssertEqual(engine.relocationCount, 1)

        // The AXWindowMoved notification caused by our own move must not trigger another move.
        probe.snapshotResult = .success(banner(at: movedOrigin))
        probe.emit(.windowChanged)
        XCTAssertEqual(probe.moves.count, 1)
    }

    func testRepositionedBannerIsMovedAgain() {
        engine.start()
        probe.snapshotResult = .success(banner(at: .zero))
        probe.emit(.windowChanged)
        probe.snapshotResult = .success(banner(at: movedOrigin))
        probe.emit(.windowChanged)

        // NotificationCenter puts the window back on the primary display when a new banner arrives.
        probe.snapshotResult = .success(banner(at: .zero))
        probe.emit(.windowChanged)
        XCTAssertEqual(probe.moves.count, 2)
    }

    func testOpenPanelIsIgnored() {
        engine.start()
        probe.snapshotResult = .success(banner(at: CGPoint(x: -3840, y: 37), panelOpen: true))
        probe.emit(.windowChanged)
        XCTAssertTrue(probe.moves.isEmpty)
        XCTAssertNil(engine.lastOrigin)
    }

    func testDisconnectedFixedDisplayLeavesTheBannerAlone() {
        settings.placementMode = .fixedDisplay(DisplayID(rawValue: "MISSING"))
        resolver.target = nil
        engine.start()
        probe.snapshotResult = .success(banner(at: .zero))
        probe.emit(.windowChanged)
        XCTAssertTrue(probe.moves.isEmpty)
        XCTAssertEqual(engine.lastOrigin, .zero)
    }

    func testWindowGoingAwayResetsTransitionMemory() {
        engine.start()
        probe.snapshotResult = .success(banner(at: .zero))
        probe.emit(.windowChanged)
        probe.snapshotResult = .success(nil)
        probe.emit(.windowChanged)
        XCTAssertNil(engine.lastOrigin)

        probe.snapshotResult = .success(banner(at: .zero))
        probe.emit(.windowChanged)
        XCTAssertEqual(probe.moves.count, 2)
    }

    func testResizeOptionIsPassedThrough() {
        settings.resizeToTargetScreen = true
        engine.start()
        probe.snapshotResult = .success(banner(at: .zero))
        probe.emit(.windowChanged)
        XCTAssertEqual(probe.moves, [FakeProbe.Move(origin: CGPoint(x: -3840, y: 37), size: external.frame.size)])
    }

    // MARK: Failure handling

    func testRevokedPermissionMovesBackToWaiting() {
        engine.start()
        probe.snapshotResult = .failure(.accessibilityDenied)
        probe.emit(.windowChanged)
        XCTAssertEqual(engine.state, .waitingForPermission)
        XCTAssertFalse(probe.isObserving)

        probe.snapshotResult = .success(nil)
        permission.grant()
        XCTAssertEqual(engine.state, .running)
        XCTAssertTrue(probe.isObserving)
    }

    func testNotificationCenterNotRunningIsTolerated() {
        engine.start()
        probe.snapshotResult = .failure(.notificationCenterNotRunning)
        probe.emit(.windowChanged)
        XCTAssertEqual(engine.state, .running)
        XCTAssertNil(engine.lastOrigin)
    }

    func testRelaunchResetsMemoryAndReevaluates() {
        engine.start()
        probe.snapshotResult = .success(banner(at: .zero))
        probe.emit(.windowChanged)
        XCTAssertEqual(probe.moves.count, 1)

        probe.snapshotResult = .success(banner(at: .zero))
        probe.emit(.notificationCenterRelaunched)
        XCTAssertEqual(probe.moves.count, 2)
    }
}

// MARK: - Fakes

@MainActor
private final class FakeProbe: BannerWindowProbing {
    struct Move: Equatable {
        var origin: CGPoint
        var size: CGSize?
    }

    var eventHandler: ((BannerProbeEvent) -> Void)?
    var isObserving = false
    var snapshotResult: Result<BannerWindowSnapshot?, BannerProbeError> = .success(nil)
    var moves: [Move] = []

    func startObserving() throws { isObserving = true }
    func stopObserving() { isObserving = false }

    func snapshot() throws -> BannerWindowSnapshot? {
        try snapshotResult.get()
    }

    func moveBanner(to origin: CGPoint, resizingTo size: CGSize?) throws -> CGPoint {
        moves.append(Move(origin: origin, size: size))
        return origin
    }

    func emit(_ event: BannerProbeEvent) {
        eventHandler?(event)
    }
}

@MainActor
private final class FakeResolver: TargetScreenResolving {
    let primaryFrame: CGRect
    var target: ScreenDescriptor?

    init(primaryFrame: CGRect) {
        self.primaryFrame = primaryFrame
    }

    func targetScreen(for mode: PlacementMode) -> ScreenDescriptor? {
        mode.relocatesBanners ? target : nil
    }
}

@MainActor
private final class FakePermission: AccessibilityAuthorizing {
    var isTrusted: Bool
    var trustChangeHandler: ((Bool) -> Void)?
    var requestCount = 0
    var isMonitoring = false

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func requestAccess() { requestCount += 1 }
    func startMonitoring() { isMonitoring = true }
    func stopMonitoring() { isMonitoring = false }

    func grant() {
        isTrusted = true
        trustChangeHandler?(true)
    }
}
