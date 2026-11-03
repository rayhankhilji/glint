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

    public var symbol: String {
        switch self {
        case .general: "gearshape"
        case .gestures: "eye"
        case .scrolling: "arrow.down.to.line"
        case .apps: "square.grid.2x2"
        case .privacy: "hand.raised"
        case .advanced: "wrench.and.screwdriver"
        case .about: "info.circle"
        }
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
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
                    .accessibilityIdentifier("glint.settings.\(tab.rawValue)")
            }
        }
        .frame(minWidth: GlintLayout.settingsMinSize.width, minHeight: GlintLayout.settingsMinSize.height)
    }

    @ViewBuilder
    private func content(for tab: SettingsTab) -> some View {
        if tab == .about {
            EmptyState(
                symbol: "sparkle",
                title: String(localized: "Glint", bundle: .module),
                message: String(localized: "Version \(version)", bundle: .module)
            )
        } else {
            EmptyState(
                symbol: tab.symbol,
                title: tab.title,
                message: String(localized: "Nothing to change here yet.", bundle: .module)
            )
        }
    }
}

#Preview { SettingsRootView(version: "0.1.0 (1)") }
