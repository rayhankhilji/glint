import Foundation
import GlintCoreTestSupport
import Testing
@testable import GlintCore

@Suite("Settings migrator")
struct SettingsMigratorTests {
    @Test("T-F11-AC1 (core) encode → decode round-trips every field")
    func roundTrip() throws {
        let original = Fixtures.settings {
            $0.isEnabled = false
            $0.onboarding = .calibrate
            $0.gazeDisplayUUID = "37D8832A-2D66-02CA-B9F7-8F30A301B230"
            $0.cameraUniqueID = "0x1420000005ac8600"
            $0.activeProfileKey = ProfileKey(cameraUniqueID: "cam", displayUUID: "disp")
            $0.click.sensitivity = 0.7
            $0.scroll.dwellMs = 450
            $0.focusFollowsGaze.enabled = false
            $0.appRules.append(AppRule(bundleID: "com.example.notes", mode: .scrollOnly))
            $0.metricsConsent = MetricsConsent(
                state: .optedIn,
                changedAt: Fixtures.referenceDate,
                installID: Fixtures.installID
            )
            $0.pausedUntil = Fixtures.referenceDate.addingTimeInterval(900)
        }
        let data = try SettingsMigrator.encode(original)
        let decoded = try SettingsMigrator.decode(data)
        #expect(decoded == original)
    }

    @Test("Missing keys take defaults; unknown keys are ignored")
    func lenientDecoding() throws {
        let json = #"{"schemaVersion": 1, "isEnabled": false, "futureFeature": {"x": 1}, "scroll": {"dwellMs": 250}}"#
        let s = try SettingsMigrator.decode(Data(json.utf8))
        #expect(!s.isEnabled)
        #expect(s.scroll.dwellMs == 250)
        #expect(s.scroll.downZoneFraction == 0.15)
        #expect(s.appRules == AppRule.defaults)
        #expect(s.metricsConsent.state == .neverAsked)
    }

    @Test("A file from a newer schema still loads (rollback safety)")
    func newerSchema() throws {
        let json = #"{"schemaVersion": 9, "isEnabled": false}"#
        let s = try SettingsMigrator.decode(Data(json.utf8))
        #expect(!s.isEnabled)
        #expect(s.schemaVersion == Settings.currentSchemaVersion)
    }

    @Test("Loaded values are validated")
    func validatesOnLoad() throws {
        let json = #"{"schemaVersion": 1, "scroll": {"dwellMs": 99999}}"#
        #expect(try SettingsMigrator.decode(Data(json.utf8)).scroll.dwellMs == 600)
    }

    @Test(
        "Garbage, non-objects, mistyped values and bad versions are SETTINGS_CORRUPT",
        arguments: [
            "not json",
            "[1, 2, 3]",
            #"{"schemaVersion": 1, "isEnabled": "yes"}"#,
            #"{"schemaVersion": 0}"#,
            #"{"schemaVersion": 1, "onboarding": "launchpad"}"#,
        ]
    )
    func corrupt(json: String) {
        #expect(throws: GlintError.settingsCorrupt) {
            try SettingsMigrator.decode(Data(json.utf8))
        }
    }

    @Test("Encoded JSON uses sorted keys and ISO-8601 dates")
    func encodingFormat() throws {
        let s = Fixtures.settings { $0.pausedUntil = Fixtures.referenceDate }
        let text = try #require(String(bytes: SettingsMigrator.encode(s), encoding: .utf8))
        #expect(text.contains(#""pausedUntil" : "2026-01-01T00:00:00Z""#))
        let keys = text.split(separator: "\n").filter { $0.hasPrefix("  \"") }.map { $0.split(separator: "\"")[1] }
        #expect(keys == keys.sorted())
    }
}
