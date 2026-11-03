import AppKit
import SaccadeCore
import SwiftUI
import Testing
@testable import SaccadeUI

@MainActor
@Suite("Design system snapshots")
struct DesignSystemSnapshotTests {
    @Test("Chrome color swatches (DESIGN_SYSTEM §2.2)")
    func colorSwatches() {
        let swatches = VStack(alignment: .leading, spacing: SaccadeSpacing.xs) {
            ForEach(SaccadeColor.chromeTokenNames, id: \.self) { name in
                HStack {
                    RoundedRectangle(cornerRadius: SaccadeRadius.s).fill(SaccadeColor.chrome(name))
                        .frame(width: 40, height: 20)
                    Text(name).saccadeText(.mono).foregroundStyle(SaccadeColor.text)
                }
            }
        }
        .padding(SaccadeSpacing.l)
        .background(SaccadeColor.background)
        assertSaccadeSnapshot(swatches, size: CGSize(width: 240, height: 420), named: "swatches")
    }

    @Test("Type scale (DESIGN_SYSTEM §3)")
    func typeScale() {
        let scale = VStack(alignment: .leading, spacing: SaccadeSpacing.xs) {
            ForEach(Array(SaccadeTextStyle.allCases.enumerated()), id: \.offset) { _, style in
                Text(verbatim: "Your Mac, at a glance 1.8°").saccadeText(style).foregroundStyle(SaccadeColor.text)
            }
        }
        .padding(SaccadeSpacing.l)
        .background(SaccadeColor.background)
        assertSaccadeSnapshot(scale, size: CGSize(width: 560, height: 420), named: "type-scale")
    }

    @Test("Chrome tokens resolve differently in light and dark appearance")
    func tokensAdapt() {
        func resolve(_ color: Color, _ name: NSAppearance.Name) -> NSColor? {
            var out: NSColor?
            NSAppearance(named: name)?.performAsCurrentDrawingAppearance {
                out = NSColor(color).usingColorSpace(.sRGB)
            }
            return out
        }
        for name in ["background", "text", "accent", "surface"] {
            let light = resolve(SaccadeColor.chrome(name), .aqua)
            let dark = resolve(SaccadeColor.chrome(name), .darkAqua)
            #expect(light != nil && dark != nil)
            #expect(light != dark, "\(name) should differ between appearances")
        }
    }

    @Test("Saccade ring radius follows DESIGN_SYSTEM §4")
    func ringRadius() {
        #expect(SaccadeRadius.saccadeRing(forTargetHeight: 10) == 10)
        #expect(SaccadeRadius.saccadeRing(forTargetHeight: 32) == 32 * 0.28 + 4)
        #expect(SaccadeRadius.saccadeRing(forTargetHeight: 200) == 18)
    }

    @Test("Reduced motion collapses animations to ≤ 150 ms fades")
    func reducedMotion() {
        #expect(SaccadeMotion.reducedMax == 0.150)
        #expect(SaccadeMotion.respecting(reduceMotion: true, SaccadeMotion.springFollow) == .easeOut(duration: 0.150))
        #expect(SaccadeMotion.respecting(reduceMotion: false, SaccadeMotion.springFollow) == SaccadeMotion.springFollow)
    }
}
