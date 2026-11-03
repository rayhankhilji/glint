import AppKit
import SaccadeCore
import SwiftUI
import Testing
@testable import SaccadeUI

@Suite("Brand artwork and symbols")
struct IconTests {
    @Test("The mark has the ring and catchlight parts the motion code animates")
    func markParts() {
        let art = SaccadeIconName.mark.artwork
        #expect(art.grid == 24)
        #expect(art.part("ring") != nil)
        #expect(art.part("catchlight") != nil)
    }

    @Test("Menu bar glyphs exist for every state on an 18 pt grid", arguments: MenuBarGlyphState.allCases)
    func menuBarGlyph(state: MenuBarGlyphState) {
        #expect(state.artwork.grid == 18)
        #expect(state.artwork.part("ring") != nil)
        let image = MenuBarGlyph.image(for: state)
        #expect(image.isTemplate)
        #expect(image.size == MenuBarGlyph.size)
        #expect(!(image.accessibilityDescription ?? "").isEmpty)
    }

    @Test("Every UI symbol exists in SF Symbols on this macOS", arguments: SaccadeSymbol.allCases)
    func symbolExists(symbol: SaccadeSymbol) {
        #expect(NSImage(systemSymbolName: symbol.rawValue, accessibilityDescription: nil) != nil, "\(symbol.rawValue)")
    }

    @Test("Settings tabs use distinct symbols")
    func settingsTabSymbols() {
        #expect(Set(SettingsTab.allCases.map(\.symbol)).count == SettingsTab.allCases.count)
    }
}

@MainActor
@Suite("Brand snapshots")
struct IconSnapshotTests {
    @Test("Mark and menu bar glyphs")
    func brandSheet() {
        let sheet = HStack(spacing: SaccadeSpacing.l) {
            SaccadeMark(size: 48, motion: .still)
            ForEach(MenuBarGlyphState.allCases, id: \.self) { state in
                Image(nsImage: MenuBarGlyph.image(for: state)).resizable().frame(width: 36, height: 36)
            }
        }
        .foregroundStyle(SaccadeColor.text)
        .padding(SaccadeSpacing.l)
        .background(SaccadeColor.background)
        assertSaccadeSnapshot(sheet, size: CGSize(width: 420, height: 90), named: "brand")
    }
}
