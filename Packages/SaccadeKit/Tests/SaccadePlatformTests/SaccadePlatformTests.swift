import Foundation
import SaccadeCore
import Testing
@testable import SaccadePlatform

@Suite("SaccadePlatform")
struct SaccadePlatformTests {
    @Test("Logged error text contains only the stable code and category (G-SEC-03)")
    func logMessageIsCodeOnly() {
        for error in SaccadeError.catalogue {
            let message = SaccadeLog.message(for: error)
            #expect(message == "error code=\(error.code) category=\(error.category.rawValue)")
        }
    }

    @Test("Associated values never reach the log text")
    func associatedValuesNotLogged() {
        let message = SaccadeLog.message(for: .calibrationInsufficient(anchorsOK: 4))
        #expect(!message.contains("4"))
    }

    @Test("SystemClock is monotonic")
    func systemClockMonotonic() {
        let clock = SystemClock()
        let a = clock.now()
        let b = clock.now()
        #expect(b >= a)
        #expect(a >= 0)
    }

    @Test("SACCADE_STORAGE_ROOT overrides the storage location")
    func storageOverride() {
        let paths = AppPaths.live(environment: ["SACCADE_STORAGE_ROOT": "/tmp/saccade-x"])
        #expect(paths.root.path == "/tmp/saccade-x")
        #expect(paths.settingsFile.path == "/tmp/saccade-x/settings.json")
        #expect(paths.profilesDirectory.lastPathComponent == "profiles")
    }

    @Test("Default storage is Application Support/Saccade")
    func defaultStorage() {
        let paths = AppPaths.live(environment: [:])
        #expect(paths.root.lastPathComponent == "Saccade")
        #expect(paths.root.deletingLastPathComponent().lastPathComponent == "Application Support")
    }
}
