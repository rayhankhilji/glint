import Foundation

/// Where Saccade stores its files: `~/Library/Application Support/Saccade/` (ARCHITECTURE §4).
/// `SACCADE_STORAGE_ROOT` overrides the root for tests and UI tests (TESTING_GUIDE §2).
public struct AppPaths: Sendable, Equatable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static func live(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppPaths {
        if let override = environment["SACCADE_STORAGE_ROOT"], !override.isEmpty {
            return AppPaths(root: URL(fileURLWithPath: override, isDirectory: true))
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return AppPaths(root: support.appendingPathComponent("Saccade", isDirectory: true))
    }

    public var settingsFile: URL { root.appendingPathComponent("settings.json") }
    public var profilesDirectory: URL { root.appendingPathComponent("profiles", isDirectory: true) }
    public var metricsDirectory: URL { root.appendingPathComponent("metrics", isDirectory: true) }
}
