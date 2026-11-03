import Foundation
import SaccadeCoreTestSupport
import Testing
@testable import SaccadeCore

@Suite("Settings defaults")
struct SettingsDefaultsTests {
    @Test("Factory defaults match ARCHITECTURE §4")
    func defaultsMatchSpec() {
        let s = Fixtures.settings()
        #expect(s.schemaVersion == 1)
        #expect(s.isEnabled)
        #expect(s.onboarding == .notStarted)
        #expect(!s.launchAtLogin)
        #expect(s.click == ClickSettings(enabled: true, sensitivity: 0.5, rightClickEnabled: true))
        #expect(s.scroll == ScrollSettings(
            enabled: true, downZoneFraction: 0.15, upZoneFraction: 0.10, glideFraction: 0.40, dwellMs: 300
        ))
        #expect(s.focusFollowsGaze == FocusSettings(enabled: true, dwellMs: 900))
        #expect(s.readingMarkerEnabled)
        #expect(s.silentLearningEnabled)
        #expect(s.preciseTargetsOnly)
        #expect(!s.clickSound)
        #expect(!s.debugGazeDot)
        #expect(s.pausedUntil == nil)
    }

    @Test("Metrics are not opted in by default (F-12, G-SEC-05)")
    func metricsOffByDefault() {
        let s = Fixtures.settings()
        #expect(s.metricsConsent.state == .neverAsked)
        #expect(!s.metricsConsent.allowsSending)
    }

    @Test("Default app rules turn Saccade off in security-sensitive apps (G-SEC-11)")
    func defaultAppRules() {
        let rules = Fixtures.settings().appRules
        #expect(rules.count == 7)
        #expect(rules.allSatisfy { $0.mode == .off && $0.isDefault })
        for id in [
            "com.1password.1password",
            "com.bitwarden.desktop",
            "com.apple.keychainaccess",
            "com.apple.loginwindow",
            "com.apple.systempreferences",
        ] {
            #expect(Fixtures.settings().rule(for: id)?.mode == .off, "\(id)")
        }
    }

    @Test("Reset to defaults restores removed default rules and keeps user rules")
    func restoringDefaults() {
        let user = AppRule(bundleID: "com.example.game", mode: .scrollOnly)
        let trimmed = [user] + AppRule.defaults.dropFirst(3)
        let restored = AppRule.restoringDefaults(in: trimmed)
        #expect(restored.first == user)
        #expect(Set(restored.map(\.bundleID)) == Set(AppRule.defaultBundleIDs + ["com.example.game"]))
    }

    @Test("Opting back in after opting out rotates the install ID")
    func consentRotation() throws {
        let first = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let second = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let consent = MetricsConsent(installID: first)
        let optedIn = consent.updated(to: .optedIn, at: Fixtures.referenceDate) { second }
        #expect(optedIn.installID == first)
        #expect(optedIn.allowsSending)
        let optedOut = optedIn.updated(to: .optedOut, at: Fixtures.referenceDate) { second }
        #expect(optedOut.installID == first)
        let back = optedOut.updated(to: .optedIn, at: Fixtures.referenceDate) { second }
        #expect(back.installID == second)
        #expect(back.changedAt == Fixtures.referenceDate)
    }

    @Test("Onboarding steps are ordered")
    func onboardingOrder() {
        #expect(OnboardingProgress.notStarted < .camera)
        #expect(OnboardingProgress.playground < .completed)
        #expect(!(OnboardingProgress.completed < .calibrate))
    }
}

@Suite("Settings validation")
struct SettingsValidationTests {
    @Test("Out-of-range values are clamped to documented ranges")
    func clamping() {
        let s = Fixtures.settings {
            $0.click.sensitivity = 7
            $0.scroll.downZoneFraction = 0.9
            $0.scroll.upZoneFraction = -1
            $0.scroll.glideFraction = 0.1
            $0.scroll.dwellMs = 5000
            $0.focusFollowsGaze.dwellMs = 10
        }.validated()
        #expect(s.click.sensitivity == 1)
        #expect(s.scroll.downZoneFraction == 0.25)
        #expect(s.scroll.upZoneFraction == 0.05)
        #expect(s.scroll.glideFraction == 0.25)
        #expect(s.scroll.dwellMs == 600)
        #expect(s.focusFollowsGaze.dwellMs == 600)
    }

    @Test("Non-finite values fall back to defaults")
    func nonFinite() {
        let s = Fixtures.settings {
            $0.click.sensitivity = .nan
            $0.scroll.glideFraction = .infinity
        }.validated()
        #expect(s.click.sensitivity == 0.5)
        #expect(s.scroll.glideFraction == 0.40)
    }

    @Test("Duplicate and empty app rules are dropped, first wins")
    func ruleCleanup() {
        let s = Fixtures.settings {
            $0.appRules = [
                AppRule(bundleID: "com.a", mode: .scrollOnly),
                AppRule(bundleID: "com.a", mode: .off),
                AppRule(bundleID: "  ", mode: .off),
            ]
        }.validated()
        #expect(s.appRules == [AppRule(bundleID: "com.a", mode: .scrollOnly)])
    }

    @Test("Valid settings are unchanged by validation")
    func idempotent() {
        let s = Fixtures.settings()
        #expect(s.validated() == s)
        #expect(s.validated().validated() == s.validated())
    }
}
