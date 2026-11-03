import AppKit
import GlintCore
import SwiftUI
import Testing
@testable import GlintUI

@MainActor
@Suite("Design system snapshots")
struct DesignSystemSnapshotTests {
    @Test("Chrome color swatches (DESIGN_SYSTEM §2.2)")
    func colorSwatches() {
        let swatches = VStack(alignment: .leading, spacing: GlintSpacing.xs) {
            ForEach(GlintColor.chromeTokenNames, id: \.self) { name in
                HStack {
                    RoundedRectangle(cornerRadius: GlintRadius.s).fill(GlintColor.chrome(name))
                        .frame(width: 40, height: 20)
                    Text(name).glintText(.mono).foregroundStyle(GlintColor.text)
                }
            }
        }
        .padding(GlintSpacing.l)
        .background(GlintColor.background)
        assertGlintSnapshot(swatches, size: CGSize(width: 240, height: 420), named: "swatches")
    }

    @Test("Type scale (DESIGN_SYSTEM §3)")
    func typeScale() {
        let scale = VStack(alignment: .leading, spacing: GlintSpacing.xs) {
            ForEach(Array(GlintTextStyle.allCases.enumerated()), id: \.offset) { _, style in
                Text(verbatim: "Your Mac, at a glance 1.8°").glintText(style).foregroundStyle(GlintColor.text)
            }
        }
        .padding(GlintSpacing.l)
        .background(GlintColor.background)
        assertGlintSnapshot(scale, size: CGSize(width: 560, height: 420), named: "type-scale")
    }

    @Test("Every chrome token resolves from the asset catalog in both appearances")
    func tokensResolve() throws {
        for name in GlintColor.chromeTokenNames {
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                let color = try #require(
                    NSColor(named: name, bundle: GlintColor.resourceBundle),
                    "missing colorset \(name)"
                )
                var resolved: NSColor?
                NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
                    resolved = color.usingColorSpace(.sRGB)
                }
                #expect(resolved != nil, "\(name) did not resolve in \(appearance.rawValue)")
            }
        }
    }

    @Test("Glint ring radius follows DESIGN_SYSTEM §4")
    func ringRadius() {
        #expect(GlintRadius.glintRing(forTargetHeight: 10) == 10)
        #expect(GlintRadius.glintRing(forTargetHeight: 32) == 32 * 0.28 + 4)
        #expect(GlintRadius.glintRing(forTargetHeight: 200) == 18)
    }

    @Test("Reduced motion collapses animations to ≤ 150 ms fades")
    func reducedMotion() {
        #expect(GlintMotion.reducedMax == 0.150)
        #expect(GlintMotion.respecting(reduceMotion: true, GlintMotion.springFollow) == .easeOut(duration: 0.150))
        #expect(GlintMotion.respecting(reduceMotion: false, GlintMotion.springFollow) == GlintMotion.springFollow)
    }
}
