import SaccadeCore
import Testing
@testable import SaccadeRuntime

@Suite("IntentCoordinator (P0 skeleton)")
struct IntentCoordinatorTests {
    @Test("Settings updates are validated and applied")
    func appliesValidatedSettings() async {
        var initial = Settings.defaults(installID: .init(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)))
        let coordinator = IntentCoordinator(settings: initial)
        initial.scroll.dwellMs = 10000
        await coordinator.update(settings: initial)
        #expect(await coordinator.settings.scroll.dwellMs == 600)
    }
}
