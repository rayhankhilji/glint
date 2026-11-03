import AppKit
import SwiftUI

extension GlintColor {
    /// An appearance-aware color: resolves to `dark` under any dark appearance (including vibrant and
    /// high-contrast variants), otherwise `light`. Replaces an asset catalog so the package has no resources.
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    /// An sRGB color from 8-bit channels.
    static func rgba(_ red: UInt8, _ green: UInt8, _ blue: UInt8, _ alpha: Double) -> NSColor {
        NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: alpha)
    }
}
