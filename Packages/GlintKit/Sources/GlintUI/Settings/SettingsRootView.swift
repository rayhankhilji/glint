import AppKit
import SwiftUI

/// Settings window tabs (DESIGN_SYSTEM §9.4).
public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general, gestures, scrolling, apps, privacy, advanced, about

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: String(localized: "General", bundle: .module)
        case .gestures: String(localized: "Gestures", bundle: .module)
        case .scrolling: String(localized: "Scrolling", bundle: .module)
        case .apps: String(localized: "Apps", bundle: .module)
        case .privacy: String(localized: "Privacy", bundle: .module)
        case .advanced: String(localized: "Advanced", bundle: .module)
        case .about: String(localized: "About", bundle: .module)
        }
    }

    /// Custom tab icon (DESIGN_SYSTEM §7).
    public var icon: GlintIconName {
        switch self {
        case .general: .tune
        case .gestures: .eye
        case .scrolling: .scrollGlide
        case .apps: .grid
        case .privacy: .shield
        case .advanced: .gauge
        case .about: .glint
        }
    }

    /// Template image for the Settings toolbar (which only accepts images, not custom views).
    var tabImage: NSImage {
        icon.artwork.templateImage(side: 20, accessibilityDescription: title)
    }
}

/// The Settings scene root. P0 skeleton: every tab exists and is navigable; its controls arrive in
/// ROADMAP P4.T5–P4.T7.
public struct SettingsRootView: View {
    @State private var selection: SettingsTab = .general
    private let version: String

    public init(version: String) {
        self.version = version
    }

    public var body: some View {
        TabView(selection: $selection) {
            ForEach(SettingsTab.allCases) { tab in
                content(for: tab)
                    .tabItem { Label { Text(tab.title) } icon: { Image(nsImage: tab.tabImage) } }
                    .tag(tab)
                    .accessibilityIdentifier("glint.settings.\(tab.rawValue)")
            }
        }
        .frame(minWidth: GlintLayout.settingsMinSize.width, minHeight: GlintLayout.settingsMinSize.height)
    }

    @ViewBuilder
    private func content(for tab: SettingsTab) -> some View {
        if tab == .about {
            VStack(spacing: GlintSpacing.m) {
                GlintMark(size: 56, motion: .twinkle)
                Text("Glint", bundle: .module)
                    .glintText(.title1)
                    .foregroundStyle(GlintColor.text)
                Text(String(localized: "Version \(version)", bundle: .module))
                    .glintText(.body)
                    .monospacedDigit()
                    .foregroundStyle(GlintColor.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyState(
                icon: tab.icon,
                title: tab.title,
                message: String(localized: "Nothing to change here yet.", bundle: .module)
            )
        }
    }
}

#Preview { SettingsRootView(version: "0.1.0 (1)") }
