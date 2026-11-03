import Foundation
import SaccadeCore
import SaccadePlatform

/// Reads and writes settings (ARCHITECTURE §5.1). Implementations must be safe to call from any thread.
public protocol SettingsStoring: Sendable {
    /// The current settings. Never fails: a missing file yields defaults and a corrupt file is backed up and
    /// replaced by defaults (`SETTINGS_CORRUPT` is reported through `recoveredFromCorruption`).
    func load() -> Settings
    /// Persists `settings` atomically and notifies `changes` subscribers.
    func save(_ settings: Settings) throws(SaccadeError)
    /// Emits every successfully saved value, starting with nothing (subscribe, then read `load()`).
    func changes() -> AsyncStream<Settings>
}

/// JSON-file settings store under `AppPaths.settingsFile`, written atomically (ARCHITECTURE §4).
public final class SettingsStore: SettingsStoring, @unchecked Sendable {
    // @unchecked: all mutable state (`cached`, `subscribers`, `corruptionBackup`) is guarded by `lock`.
    private let paths: AppPaths
    private let fileManager: FileManager
    private let now: @Sendable () -> Date
    private let makeInstallID: @Sendable () -> UUID
    private let lock = NSLock()
    private var cached: Settings?
    private var subscribers: [UUID: AsyncStream<Settings>.Continuation] = [:]
    private var corruptionBackup: URL?

    public init(
        paths: AppPaths,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = Date.init,
        makeInstallID: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.now = now
        self.makeInstallID = makeInstallID
    }

    /// Where the corrupt file was moved, if the last load recovered from corruption (shown once as a HUD).
    public var recoveredFromCorruption: URL? {
        lock.withLock { corruptionBackup }
    }

    public func load() -> Settings {
        lock.withLock {
            if let cached {
                return cached
            }
            let settings = readFromDisk()
            cached = settings
            return settings
        }
    }

    public func save(_ settings: Settings) throws(SaccadeError) {
        let valid = settings.validated()
        let data = try SettingsMigrator.encode(valid)
        let continuations: [AsyncStream<Settings>.Continuation]
        do {
            try lock.withLock {
                try fileManager.createDirectory(at: paths.root, withIntermediateDirectories: true)
                try data.write(to: paths.settingsFile, options: .atomic)
                cached = valid
            }
        } catch {
            SaccadeLog.log(.persistenceFailed, in: .storage)
            throw .persistenceFailed
        }
        continuations = lock.withLock { Array(subscribers.values) }
        for continuation in continuations {
            continuation.yield(valid)
        }
    }

    public func changes() -> AsyncStream<Settings> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Settings>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.onTermination = { [weak self] _ in
            self?.lock.withLock { _ = self?.subscribers.removeValue(forKey: id) }
        }
        lock.withLock { subscribers[id] = continuation }
        return stream
    }

    /// Must be called with `lock` held.
    private func readFromDisk() -> Settings {
        guard fileManager.fileExists(atPath: paths.settingsFile.path) else {
            return Settings.defaults(installID: makeInstallID())
        }
        do {
            let data = try Data(contentsOf: paths.settingsFile)
            return try SettingsMigrator.decode(data)
        } catch {
            SaccadeLog.log(.settingsCorrupt, in: .storage)
            corruptionBackup = backUpCorruptFile()
            return Settings.defaults(installID: makeInstallID())
        }
    }

    /// Renames the unreadable file to `settings.corrupt-<ISO date>.json` so nothing is lost.
    private func backUpCorruptFile() -> URL? {
        let stamp = ISO8601DateFormatter().string(from: now()).replacingOccurrences(of: ":", with: "-")
        let backup = paths.root.appendingPathComponent("settings.corrupt-\(stamp).json")
        do {
            if fileManager.fileExists(atPath: backup.path) {
                try fileManager.removeItem(at: backup)
            }
            try fileManager.moveItem(at: paths.settingsFile, to: backup)
            return backup
        } catch {
            SaccadeLog.log(.persistenceFailed, in: .storage)
            return nil
        }
    }
}
