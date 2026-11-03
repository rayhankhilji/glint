import AppKit
import SaccadeCore
import SwiftUI
import Testing
@testable import SaccadeUI

@MainActor
@Suite("Popover and menu bar snapshots")
struct PopoverSnapshotTests {
    static let states: [(String, SaccadeStatus, AccuracyReading?)] = [
        ("tracking", .tracking(fps: 30), AccuracyReading(medianErrorDegrees: 2.1)),
        ("starting", .starting, AccuracyReading(medianErrorDegrees: 1.4)),
        ("off", .off, AccuracyReading(medianErrorDegrees: 2.1)),
        ("paused", .paused(until: nil), AccuracyReading(medianErrorDegrees: 2.1)),
        ("away", .away, AccuracyReading(medianErrorDegrees: 2.1)),
        ("not-calibrated", .needsAttention(.notCalibrated), nil),
        ("camera-permission", .needsAttention(.cameraPermissionMissing), AccuracyReading(medianErrorDegrees: 2.1)),
        ("ax-permission", .needsAttention(.accessibilityPermissionMissing), AccuracyReading(medianErrorDegrees: 2.1)),
        ("camera-missing", .needsAttention(.cameraMissing), AccuracyReading(medianErrorDegrees: 3.2)),
        ("low-light", .needsAttention(.lowLight), AccuracyReading(medianErrorDegrees: 4.0)),
    ]

    @Test("Popover state", arguments: states.map(\.0))
    func popover(name: String) throws {
        let state = try #require(Self.states.first { $0.0 == name })
        let view = PopoverView(model: AppModel(status: state.1, accuracy: state.2))
            .background(SaccadeColor.background)
        assertSaccadeSnapshot(view, size: CGSize(width: 320, height: 280), named: "popover-\(name)")
    }

    @Test("Menu bar glyphs", arguments: MenuBarGlyphState.allCases)
    func glyph(state: MenuBarGlyphState) {
        let view = Image(nsImage: MenuBarGlyph.image(for: state))
            .resizable()
            .frame(width: 72, height: 72)
            .padding(SaccadeSpacing.s)
            .background(SaccadeColor.background)
        assertSaccadeSnapshot(view, size: CGSize(width: 88, height: 88), named: "glyph-\(state.rawValue)")
    }

    @Test("Glyphs are template images with accessibility descriptions")
    func glyphMetadata() {
        for state in MenuBarGlyphState.allCases {
            let image = MenuBarGlyph.image(for: state)
            #expect(image.isTemplate)
            #expect(image.size == MenuBarGlyph.size)
            #expect(!(image.accessibilityDescription ?? "").isEmpty)
        }
    }

    @Test("Banners appear only for blocking problems")
    func banners() {
        #expect(StatusCopy.banner(for: .tracking(fps: 30)) == nil)
        #expect(StatusCopy.banner(for: .needsAttention(.notCalibrated)) == nil)
        #expect(StatusCopy.banner(for: .needsAttention(.lowLight)) == nil)
        #expect(StatusCopy.banner(for: .needsAttention(.accessibilityPermissionMissing))?.message
            == "Saccade can't act — Accessibility is off")
    }

    @Test("The switch is locked while a permission is missing")
    func toggleLock() {
        #expect(!AppModel(status: .needsAttention(.cameraPermissionMissing), accuracy: nil).canToggle)
        #expect(AppModel(status: .off, accuracy: nil).canToggle)
        #expect(!AppModel(status: .off, accuracy: nil).isEnabled)
    }

    @Test("Accuracy shows one decimal with a degree sign")
    func degreesFormat() {
        #expect(AccuracyReadout.degrees(2.14) == "2.1°")
        #expect(AccuracyReadout.degrees(1) == "1.0°")
    }

    @Test("Settings has the seven documented tabs in order")
    func settingsTabs() {
        #expect(SettingsTab.allCases.map(\.rawValue)
            == ["general", "gestures", "scrolling", "apps", "privacy", "advanced", "about"])
    }

    @Test("Settings window snapshot")
    func settingsWindow() {
        assertSaccadeSnapshot(
            SettingsRootView(version: "0.1.0 (1)"),
            size: CGSize(width: 640, height: 480),
            named: "settings"
        )
    }
}
