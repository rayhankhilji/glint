import SaccadeCore
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

/// The Settings scene root: native grouped forms, monochrome, every control live.
public struct SettingsRootView: View {
    @Bindable private var model: SettingsModel
    @State private var selection: SettingsTab = .general
    private let version: String

    public init(model: SettingsModel, version: String) {
        self.model = model
        self.version = version
    }

    public var body: some View {
        TabView(selection: $selection) {
            ForEach(SettingsTab.allCases) { tab in
                content(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol.rawValue) }
                    .tag(tab)
                    .accessibilityIdentifier("saccade.settings.\(tab.rawValue)")
            }
        }
        .tint(SaccadeColor.accent)
        .frame(minWidth: SaccadeLayout.settingsMinSize.width, minHeight: SaccadeLayout.settingsMinSize.height)
        .onChange(of: model.settings) { _, settings in model.actions.commit(settings) }
    }

    @ViewBuilder
    private func content(for tab: SettingsTab) -> some View {
        switch tab {
        case .general: GeneralPane(model: model)
        case .gestures: GesturesPane(model: model)
        case .scrolling: ScrollingPane(model: model)
        case .apps: AppsPane(model: model)
        case .privacy: PrivacyPane(model: model)
        case .advanced: AdvancedPane(model: model)
        case .about: AboutPane(version: version)
        }
    }
}

#Preview { SettingsRootView(model: SettingsModel(settings: .defaults()), version: "0.1.0 (1)") }
