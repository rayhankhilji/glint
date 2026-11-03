import Foundation

/// A per-app override (F-10). Apps without a rule get full Saccade behavior.
public struct AppRule: Hashable, Sendable, Codable {
    public var bundleID: String
    public var mode: AppRuleMode
    /// Rules shipped by Saccade (G-SEC-11). Users may remove them; "Reset to defaults" restores them.
    public var isDefault: Bool

    public init(bundleID: String, mode: AppRuleMode = .off, isDefault: Bool = false) {
        self.bundleID = bundleID
        self.mode = mode
        self.isDefault = isDefault
    }

    /// Security-sensitive apps where Saccade is off by default (ARCHITECTURE §4, G-SEC-11).
    public static let defaultBundleIDs: [String] = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.apple.keychainaccess",
        "com.apple.loginwindow",
        "com.apple.ScreenSaver.Engine",
        "com.apple.systempreferences",
    ]

    public static let defaults: [AppRule] = defaultBundleIDs.map { AppRule(bundleID: $0, mode: .off, isDefault: true) }

    /// Drops rules with empty bundle IDs and keeps only the first rule per bundle ID.
    public static func deduplicated(_ rules: [AppRule]) -> [AppRule] {
        var seen = Set<String>()
        return rules.filter { rule in
            let id = rule.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !seen.contains(id) else { return false }
            seen.insert(id)
            return true
        }
    }

    /// `rules` with every default rule present again (user rules kept, defaults appended if missing).
    public static func restoringDefaults(in rules: [AppRule]) -> [AppRule] {
        let existing = Set(rules.map(\.bundleID))
        return rules + defaults.filter { !existing.contains($0.bundleID) }
    }
}

/// What Saccade may do in an app.
public enum AppRuleMode: String, Sendable, Codable, CaseIterable {
    /// No saccade and no actions at all.
    case off
    /// Only glide scroll; no saccade, clicks or focus switching.
    case scrollOnly
}
