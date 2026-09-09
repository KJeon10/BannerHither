import XCTest
@testable import BannerHitherCore

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var store: SettingsStore!

    override func setUp() async throws {
        suiteName = "io.github.kjeon10.BannerHither.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = SettingsStore(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaults() {
        XCTAssertEqual(store.placementMode, .followMouse)
        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(store.pollIntervalMilliseconds, SettingsStore.defaultPollIntervalMilliseconds)
        XCTAssertEqual(store.pollInterval, 1.0)
        XCTAssertFalse(store.resizeToTargetScreen)
        XCTAssertNil(store.fixedDisplayName)
        XCTAssertFalse(store.automaticUpdateChecks)
        XCTAssertFalse(store.updateConsentAsked)
        XCTAssertNil(store.lastUpdateCheck)
        XCTAssertNil(store.skippedUpdateVersion)
        XCTAssertNil(store.updateFeedURL)
    }

    func testUpdateSettingsRoundTrip() {
        let checked = Date(timeIntervalSince1970: 1_800_000_000)
        store.automaticUpdateChecks = true
        store.updateConsentAsked = true
        store.lastUpdateCheck = checked
        store.skippedUpdateVersion = "0.2.0"
        store.updateFeedURL = URL(string: "file:///tmp/feed.json")

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertTrue(reloaded.automaticUpdateChecks)
        XCTAssertTrue(reloaded.updateConsentAsked)
        XCTAssertEqual(reloaded.lastUpdateCheck, checked)
        XCTAssertEqual(reloaded.skippedUpdateVersion, "0.2.0")
        XCTAssertEqual(reloaded.updateFeedURL?.absoluteString, "file:///tmp/feed.json")

        reloaded.skippedUpdateVersion = nil
        reloaded.lastUpdateCheck = nil
        XCTAssertNil(SettingsStore(defaults: defaults).skippedUpdateVersion)
        XCTAssertNil(SettingsStore(defaults: defaults).lastUpdateCheck)
    }

    func testFixedDisplayRoundTrips() {
        let id = DisplayID(rawValue: "9E27DD18-CF68-44C2-9518-EA25D328C6EA")
        store.fixedDisplayName = "MSI MP273A (2)"
        store.placementMode = .fixedDisplay(id)

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.placementMode, .fixedDisplay(id))
        XCTAssertEqual(reloaded.fixedDisplayName, "MSI MP273A (2)")
    }

    func testFixedDisplayWithoutAnIdentifierFallsBackToSystemDefault() {
        defaults.set(PlacementMode.Kind.fixedDisplay.rawValue, forKey: SettingsStore.Key.placementMode)
        XCTAssertEqual(store.placementMode, .systemDefault)
    }

    func testFixedDisplayIdentifierSurvivesSwitchingModes() {
        let id = DisplayID(rawValue: "X")
        store.placementMode = .fixedDisplay(id)
        store.placementMode = .followMouse
        store.placementMode = .fixedDisplay(id)
        XCTAssertEqual(store.placementMode, .fixedDisplay(id))
    }

    func testPollIntervalIsClampedAndZeroMeansOff() {
        store.pollIntervalMilliseconds = 10
        XCTAssertEqual(store.pollIntervalMilliseconds, SettingsStore.minimumPollIntervalMilliseconds)
        store.pollIntervalMilliseconds = 60_000
        XCTAssertEqual(store.pollIntervalMilliseconds, SettingsStore.maximumPollIntervalMilliseconds)
        store.pollIntervalMilliseconds = 0
        XCTAssertEqual(store.pollInterval, 0)
        store.pollIntervalMilliseconds = -5
        XCTAssertEqual(store.pollInterval, 0)
    }

    func testObserversAreToldWhatChanged() {
        var changes: [SettingsStore.Change] = []
        store.addObserver { changes.append($0) }

        store.isEnabled = false
        store.placementMode = .followActiveWindow
        store.pollIntervalMilliseconds = 500
        store.resizeToTargetScreen = true
        store.automaticUpdateChecks = true

        XCTAssertEqual(changes, [.isEnabled, .placementMode, .pollInterval, .resizeToTargetScreen, .automaticUpdateChecks])
    }
}
