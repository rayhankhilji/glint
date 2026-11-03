import AppKit
import GlintCore
import SwiftUI
import Testing
@testable import GlintUI

@Suite("Custom icons")
struct IconTests {
    @Test(
        "Every icon has a title, parts, and stays inside its grid including stroke width",
        arguments: GlintIconName.allCases
    )
    func iconGeometry(name: GlintIconName) {
        let art = name.artwork
        #expect(!name.title.isEmpty)
        #expect(!art.parts.isEmpty)
        #expect(art.grid == 24)
        #expect(Set(art.parts.map(\.id)).count == art.parts.count, "duplicate part ids")
        let inset = art.strokeWidth / 2
        for part in art.parts {
            let b = part.gridBounds
            #expect(b.minX >= 1 - inset && b.minY >= 1 - inset, "\(name.rawValue).\(part.id) leaves the 1 pt margin")
            #expect(b.maxX <= 23 + inset && b.maxY <= 23 + inset, "\(name.rawValue).\(part.id) leaves the 1 pt margin")
        }
    }

    @Test("Menu bar glyphs exist for every state on an 18 pt grid", arguments: MenuBarGlyphState.allCases)
    func menuBarGlyph(state: MenuBarGlyphState) {
        #expect(state.artwork.grid == 18)
        let image = MenuBarGlyph.image(for: state)
        #expect(image.isTemplate)
        #expect(image.size == MenuBarGlyph.size)
        #expect(!(image.accessibilityDescription ?? "").isEmpty)
    }

    @Test("Animated parts the motion code relies on exist")
    func animatedParts() {
        let mark = GlintIconName.eyeGlint.artwork
        #expect(mark.part("sparkle") != nil)
        #expect(mark.part("outline") != nil)
        #expect(mark.part("iris") != nil)
        #expect(GlintIconName.check.artwork.part("tick") != nil)
    }

    @Test("Settings tabs use custom icons")
    func settingsTabIcons() {
        #expect(Set(SettingsTab.allCases.map(\.icon)).count == SettingsTab.allCases.count)
    }
}

@MainActor
@Suite("Icon snapshots")
struct IconSnapshotTests {
    @Test("Icon sheet at 16 and 24 pt")
    func iconSheet() {
        let sheet = VStack(alignment: .leading, spacing: GlintSpacing.m) {
            ForEach([16.0, 24.0], id: \.self) { size in
                HStack(spacing: GlintSpacing.m) {
                    ForEach(GlintIconName.allCases, id: \.self) { GlintIcon($0, size: size) }
                }
            }
        }
        .foregroundStyle(GlintColor.text)
        .padding(GlintSpacing.l)
        .background(GlintColor.background)
        assertGlintSnapshot(sheet, size: CGSize(width: 1100, height: 110), named: "icons")
    }

    @Test("Glint mark, still")
    func mark() {
        let view = GlintMark(size: 64, motion: .still).padding(GlintSpacing.l).background(GlintColor.background)
        assertGlintSnapshot(view, size: CGSize(width: 96, height: 96), named: "mark")
    }
}
