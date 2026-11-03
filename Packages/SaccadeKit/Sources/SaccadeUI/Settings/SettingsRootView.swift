import SwiftUI

/// Settings window tabs (DESIGN_SYSTEM §9.4).
public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general, gestures, scrolling, apps, privacy, advanced, about

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: String(localized: "General")
        case .gestures: String(localized: "Gestures")
        case .scrolling: String(localized: "Scrolling")
        case .apps: String(localized: "Apps")
        case .privacy: String(localized: "Privacy")
        case .advanced: String(localized: "Advanced")
        case .about: String(localized: "About")
        }
    }

    public var symbol: SaccadeSymbol {
        switch self {
        case .general: .general
        case .gestures: .gestures
        case .scrolling: .scrolling
        case .apps: .apps
        case .privacy: .privacy
        case .advanced: .advanced
        case .about: .about
        }
    }
}

/// The Settings scene root. P0 skeleton: every tab exists and is navigable; controls arrive in P4.T5–P4.T7.
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
                    .background(SaccadeColor.background)
                    .tabItem { Label(tab.title, systemImage: tab.symbol.rawValue) }
                    .tag(tab)
                    .accessibilityIdentifier("saccade.settings.\(tab.rawValue)")
            }
        }
        .frame(minWidth: SaccadeLayout.settingsMinSize.width, minHeight: SaccadeLayout.settingsMinSize.height)
    }

    @ViewBuilder
    private func content(for tab: SettingsTab) -> some View {
        if tab == .about {
            VStack(spacing: SaccadeSpacing.m) {
                SaccadeMark(size: 48, motion: .live)
                VStack(spacing: SaccadeSpacing.xxs) {
                    Text("Saccade")
                        .saccadeText(.title2)
                        .foregroundStyle(SaccadeColor.text)
                    Text(String(localized: "Version \(version)"))
                        .saccadeText(.callout)
                        .monospacedDigit()
                        .foregroundStyle(SaccadeColor.textMuted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyState(
                symbol: tab.symbol,
                title: tab.title,
                message: String(localized: "These settings arrive with the features they control.")
            )
        }
    }
}

#Preview { SettingsRootView(version: "0.1.0 (1)") }
