import Foundation

/// Turns `settings.json` bytes into valid `Settings`, upgrading older schemas step by step
/// (ARCHITECTURE §4). Shipped steps are never edited; a schema change adds a new step.
public enum SettingsMigrator {
    /// Decodes, migrates and validates settings data.
    /// - Throws: `GlintError.settingsCorrupt` if the data isn't a JSON object or has mistyped values.
    public static func decode(_ data: Data) throws(GlintError) -> Settings {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            var json = object as? [String: Any]
        else { throw .settingsCorrupt }

        let version = json["schemaVersion"] as? Int ?? Settings.currentSchemaVersion
        guard version >= 1 else { throw .settingsCorrupt }
        if version < Settings.currentSchemaVersion {
            for from in version ..< Settings.currentSchemaVersion {
                migrate(&json, from: from)
            }
        }
        // Files from newer builds (after a rollback) decode leniently: unknown keys are ignored.

        do {
            let migrated = try JSONSerialization.data(withJSONObject: json)
            return try GlintJSON.decoder.decode(Settings.self, from: migrated).validated()
        } catch {
            throw .settingsCorrupt
        }
    }

    /// Encodes settings for disk (stable key order so diffs and diagnostics are readable).
    public static func encode(_ settings: Settings) throws(GlintError) -> Data {
        do {
            return try GlintJSON.encoder.encode(settings)
        } catch {
            throw .persistenceFailed
        }
    }

    /// Applies the single step `from → from + 1`. Schema v1 is the first version, so no steps exist yet.
    static func migrate(_ json: inout [String: Any], from version: Int) {
        switch version {
        default:
            json["schemaVersion"] = version + 1
        }
    }
}

/// Shared JSON coders for every persisted Glint file: ISO-8601 dates, sorted keys.
public enum GlintJSON {
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
