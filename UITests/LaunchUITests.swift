import XCTest

/// Smoke test: Saccade launches as a menu-bar-only app with an isolated storage root (TESTING_GUIDE §5.5).
final class LaunchUITests: XCTestCase {
    private let storageRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("saccade-uitest-\(UUID().uuidString)", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storageRoot)
    }

    @MainActor
    func testLaunchesWithoutWindowsOrDockIcon() {
        let app = XCUIApplication()
        app.launchArguments = ["-SaccadeUITestMode", "YES"]
        app.launchEnvironment["SACCADE_STORAGE_ROOT"] = storageRoot.path
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10) || app.state == .runningBackground)
        XCTAssertEqual(app.windows.count, 0, "Saccade has no windows until the popover or Settings is opened")
        app.terminate()
    }
}
