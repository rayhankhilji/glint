import Foundation
import GlintCore
import Testing
@testable import GlintPlatform

@Suite("GlintPlatform")
struct GlintPlatformTests {
    @Test("Logged error text contains only the stable code and category (G-SEC-03)")
    func logMessageIsCodeOnly() {
        for error in GlintError.catalogue {
            let message = GlintLog.message(for: error)
            #expect(message == "error code=\(error.code) category=\(error.category.rawValue)")
        }
    }

    @Test("Associated values never reach the log text")
    func associatedValuesNotLogged() {
        let message = GlintLog.message(for: .calibrationInsufficient(anchorsOK: 4))
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

    @Test("GLINT_STORAGE_ROOT overrides the storage location")
    func storageOverride() {
        let paths = AppPaths.live(environment: ["GLINT_STORAGE_ROOT": "/tmp/glint-x"])
        #expect(paths.root.path == "/tmp/glint-x")
        #expect(paths.settingsFile.path == "/tmp/glint-x/settings.json")
        #expect(paths.profilesDirectory.lastPathComponent == "profiles")
    }

    @Test("Default storage is Application Support/Glint")
    func defaultStorage() {
        let paths = AppPaths.live(environment: [:])
        #expect(paths.root.lastPathComponent == "Glint")
        #expect(paths.root.deletingLastPathComponent().lastPathComponent == "Application Support")
    }
}
