import Foundation
import SaccadeCore
import SaccadePlatform

/// A saved calibration (F-03). One profile for now; per camera × display profiles come with multi-display support.
public struct StoredCalibration: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var createdAt: Date
    public var result: CalibrationResult
    public var medianErrorDegrees: Double

    public init(createdAt: Date, result: CalibrationResult, medianErrorDegrees: Double) {
        schemaVersion = Self.currentSchemaVersion
        self.createdAt = createdAt
        self.result = result
        self.medianErrorDegrees = medianErrorDegrees
    }
}

/// Reads and writes `profiles/default.json` atomically.
public final class ProfileStore: @unchecked Sendable {
    // @unchecked: every file access is serialized by `lock`.
    private let paths: AppPaths
    private let lock = NSLock()

    public init(paths: AppPaths) {
        self.paths = paths
    }

    private var file: URL { paths.profilesDirectory.appendingPathComponent("default.json") }

    /// The saved calibration, or `nil` if there is none or it can't be read (or was made by an older feature layout).
    public func load() -> StoredCalibration? {
        lock.withLock {
            guard let data = try? Data(contentsOf: file),
                  let stored = try? SaccadeJSON.decoder.decode(StoredCalibration.self, from: data),
                  stored.result.model.featureVersion == GazeFeatures.featureVersion
            else { return nil }
            return stored
        }
    }

    public func save(_ stored: StoredCalibration) throws(SaccadeError) {
        do {
            let data = try SaccadeJSON.encoder.encode(stored)
            try lock.withLock {
                try FileManager.default.createDirectory(at: paths.profilesDirectory, withIntermediateDirectories: true)
                try data.write(to: file, options: .atomic)
            }
        } catch {
            SaccadeLog.log(.persistenceFailed, in: .storage)
            throw .persistenceFailed
        }
    }

    public func delete() {
        lock.withLock { _ = try? FileManager.default.removeItem(at: file) }
    }
}
