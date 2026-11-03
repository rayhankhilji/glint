import AppKit
import Foundation
import SaccadeCore
import SaccadeCoreTestSupport
import SwiftUI
import Testing
@testable import SaccadeUI

@MainActor
@Suite("Overlay, onboarding and settings models")
struct OverlayAndOnboardingTests {
    @Test("Onboarding steps map to persisted progress and back")
    func onboardingResume() {
        for step in OnboardingModel.Step.allCases {
            #expect(OnboardingModel.Step(resuming: step.progress) == step)
        }
        #expect(OnboardingModel.Step(resuming: .completed) == .done)
    }

    @Test("Advancing onboarding reports every step for persistence")
    func onboardingAdvance() {
        let seen = StepRecorder()
        var actions = OnboardingActions.noop
        actions.stepChanged = { seen.steps.append($0) }
        let model = OnboardingModel(actions: actions)
        model.advance()
        model.advance()
        #expect(model.step == .accessibility)
        #expect(seen.steps == [.camera, .accessibility])
    }

    @Test("App rules: add once, change mode, remove, restore defaults")
    func appRules() {
        let model = SettingsModel(settings: Fixtures.settings())
        let count = model.settings.appRules.count
        model.addRule(bundleID: "com.example.editor")
        model.addRule(bundleID: "com.example.editor")
        #expect(model.settings.appRules.count == count + 1)
        model.setMode(.scrollOnly, for: "com.example.editor")
        #expect(model.settings.rule(for: "com.example.editor")?.mode == .scrollOnly)
        model.removeRule(bundleID: AppRule.defaultBundleIDs[0])
        model.restoreDefaultRules()
        #expect(model.settings.appRules.count == count + 1)
    }

    @Test("Slider views round-trip integer milliseconds and consent")
    func sliderViews() {
        let model = SettingsModel(settings: Fixtures.settings())
        model.scrollDwell = 349.6
        #expect(model.settings.scroll.dwellMs == 350)
        model.focusDwell = 1200
        #expect(model.settings.focusFollowsGaze.dwellMs == 1200)
        model.metricsOptIn = true
        #expect(model.settings.metricsConsent.allowsSending)
    }

    @Test("The lock corner follows the element: capsule for small controls, at most 8 pt")
    func lockCorner() {
        #expect(GazeOverlayView.corner(CGRect(x: 0, y: 0, width: 80, height: 10)) == 5)
        #expect(GazeOverlayView.corner(CGRect(x: 0, y: 0, width: 400, height: 300)) == 8)
    }

    @Test("Overlay marks: lock, uncertain pair, dot, scroll bar, line marker")
    func overlaySnapshot() {
        let model = GazeOverlayModel()
        model.visible = true
        var state = OverlayState()
        state.lock = Rect(x: 40, y: 40, width: 96, height: 24)
        state.uncertain = [Rect(x: 180, y: 40, width: 60, height: 24), Rect(x: 250, y: 40, width: 60, height: 24)]
        state.lineMarker = Rect(x: 24, y: 120, width: 300, height: 22)
        state.scrollProgress = (Rect(x: 16, y: 100, width: 320, height: 100), 0.6, false)
        model.state = state
        let view = ZStack {
            SaccadeColor.background
            GazeOverlayView(model: model)
        }
        assertSaccadeSnapshot(view, size: CGSize(width: 360, height: 220), named: "overlay")
    }

    @Test("Onboarding steps", arguments: OnboardingModel.Step.allCases.map(\.rawValue))
    func onboardingSnapshot(raw: Int) throws {
        let step = try #require(OnboardingModel.Step(rawValue: raw))
        let model = OnboardingModel(step: step)
        model.accuracy = step == .calibrate ? AccuracyReading(medianErrorDegrees: 1.2) : nil
        assertSaccadeSnapshot(
            OnboardingView(model: model), size: SaccadeLayout.onboardingSize, named: "onboarding-\(raw)"
        )
    }
}

@MainActor
private final class StepRecorder {
    var steps: [OnboardingModel.Step] = []
}
