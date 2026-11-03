import XCTest

/// Smoke test: Glint launches as a menu-bar-only app with an isolated storage root (TESTING_GUIDE §5.5).
final class LaunchUITests: XCTestCase {
    private let storageRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("glint-uitest-\(UUID().uuidString)", isDirectory: true)

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
        app.launchArguments = ["-GlintUITestMode", "YES"]
        app.launchEnvironment["GLINT_STORAGE_ROOT"] = storageRoot.path
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10) || app.state == .runningBackground)
        XCTAssertEqual(app.windows.count, 0, "Glint has no windows until the popover or Settings is opened")
        app.terminate()
    }
}
