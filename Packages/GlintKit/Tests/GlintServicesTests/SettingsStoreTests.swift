import Foundation
import GlintCore
import GlintCoreTestSupport
import GlintPlatform
import Testing
@testable import GlintServices

@Suite("SettingsStore")
struct SettingsStoreTests {
    private func makeStore(_ root: URL) -> SettingsStore {
        SettingsStore(
            paths: AppPaths(root: root),
            now: { Fixtures.referenceDate },
            makeInstallID: { Fixtures.installID }
        )
    }

    @Test("T-F11-AC1 (store) a saved setting survives a new store instance (relaunch)")
    func persistsAcrossRelaunch() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        var settings = makeStore(root).load()
        settings.scroll.dwellMs = 420
        settings.focusFollowsGaze.enabled = false
        try makeStore(root).save(settings)

        let reloaded = makeStore(root).load()
        #expect(reloaded.scroll.dwellMs == 420)
        #expect(!reloaded.focusFollowsGaze.enabled)
    }

    @Test("A missing file yields defaults without writing anything")
    func missingFile() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        let store = makeStore(root)
        #expect(store.load() == Fixtures.settings())
        #expect(!FileManager.default.fileExists(atPath: AppPaths(root: root).settingsFile.path))
        #expect(store.recoveredFromCorruption == nil)
    }

    @Test("A corrupt file is backed up, defaults load, and the backup keeps the original bytes")
    func corruptFile() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        let paths = AppPaths(root: root)
        let garbage = Data("{ definitely not settings".utf8)
        try garbage.write(to: paths.settingsFile)

        let store = makeStore(root)
        #expect(store.load() == Fixtures.settings())
        let backup = try #require(store.recoveredFromCorruption)
        #expect(backup.lastPathComponent == "settings.corrupt-2026-01-01T00-00-00Z.json")
        #expect(try Data(contentsOf: backup) == garbage)
        #expect(!FileManager.default.fileExists(atPath: paths.settingsFile.path))
    }

    @Test("Saved values are validated before they hit disk")
    func validatesOnSave() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        var settings = Fixtures.settings()
        settings.scroll.glideFraction = 3
        try makeStore(root).save(settings)
        #expect(makeStore(root).load().scroll.glideFraction == 0.60)
    }

    @Test("Saving leaves exactly one file (atomic write, no temp leftovers)")
    func atomicWrite() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        try makeStore(root).save(Fixtures.settings())
        let contents = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(contents == ["settings.json"])
    }

    @Test("Subscribers receive saved settings")
    func changesStream() async throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        let store = makeStore(root)
        let stream = store.changes()
        var settings = store.load()
        settings.isEnabled = false
        try store.save(settings)
        var iterator = stream.makeAsyncIterator()
        let received = await iterator.next()
        #expect(received?.isEnabled == false)
    }

    @Test("An unwritable location throws PERSISTENCE_FAILED")
    func unwritable() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        let blocker = root.appendingPathComponent("not-a-dir")
        try Data().write(to: blocker)
        let store = makeStore(blocker)
        #expect(throws: GlintError.persistenceFailed) {
            try store.save(Fixtures.settings())
        }
    }
}
