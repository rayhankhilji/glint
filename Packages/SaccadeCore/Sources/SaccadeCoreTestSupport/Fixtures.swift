import Foundation
import SaccadeCore

/// Test factories (TESTING_GUIDE §4.1). Deterministic: fixed install ID, no wall-clock reads.
public enum Fixtures {
    public static let installID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xC0, 0xDE))

    /// Default settings with optional overrides.
    public static func settings(_ configure: (inout Settings) -> Void = { _ in }) -> Settings {
        var settings = Settings.defaults(installID: installID)
        configure(&settings)
        return settings
    }

    /// A fixed reference date (2026-01-01T00:00:00Z) for persisted timestamps.
    public static let referenceDate = Date(timeIntervalSince1970: 1_767_225_600)
}

/// Temporary directories for store tests. Each call returns a fresh, empty directory.
public enum TestSupport {
    public static func makeTempRoot(function: String = #function) throws -> URL {
        let name = "saccade-test-\(function.filter(\.isLetter).prefix(40))-\(UUID().uuidString)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func removeTempRoot(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
