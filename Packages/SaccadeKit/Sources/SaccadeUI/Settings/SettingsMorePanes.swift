import AppKit
import SaccadeCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: Panes (apps, privacy, advanced, about)

struct AppsPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                if model.settings.appRules.isEmpty {
                    Text(String(localized: "Saccade works everywhere.")).foregroundStyle(SaccadeColor.textMuted)
                }
                ForEach(model.settings.appRules, id: \.bundleID) { rule in
                    HStack(spacing: SaccadeSpacing.s) {
                        VStack(alignment: .leading, spacing: SaccadeSpacing.xxs) {
                            Text(AppName.display(for: rule.bundleID)).foregroundStyle(SaccadeColor.text)
                            Text(rule.bundleID).saccadeText(.caption).foregroundStyle(SaccadeColor.textMuted)
                                .textSelection(.enabled)
                        }
                        Spacer(minLength: SaccadeSpacing.m)
                        Picker(String(localized: "Mode"), selection: Binding(
                            get: { rule.mode },
                            set: { model.setMode($0, for: rule.bundleID) }
                        )) {
                            Text(String(localized: "Off")).tag(AppRuleMode.off)
                            Text(String(localized: "Scroll only")).tag(AppRuleMode.scrollOnly)
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button {
                            model.removeRule(bundleID: rule.bundleID)
                        } label: {
                            SaccadeSymbolImage(.remove, size: 13, weight: .regular)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(String(localized: "Remove \(AppName.display(for: rule.bundleID))"))
                    }
                }
            } header: {
                Text(String(localized: "Rules"))
            } footer: {
                FormFooter(String(localized: "Password managers and System Settings are off by default."))
            }
            Section {
                HStack {
                    Button(String(localized: "Add App…")) { chooseApp() }
                    Spacer()
                    Button(String(localized: "Restore Defaults")) { model.restoreDefaultRules() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier {
                model.addRule(bundleID: id)
            }
        }
    }
}

struct PrivacyPane: View {
    @Bindable var model: SettingsModel
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section {
                LabeledContent(String(localized: "Camera")) {
                    Text(String(localized: "Processed on this Mac, never stored"))
                        .foregroundStyle(SaccadeColor.textMuted)
                }
                Toggle(String(localized: "Learn from my clicks"), isOn: $model.settings.silentLearningEnabled)
            } footer: {
                FormFooter(
                    String(
                        localized: """
                        Each frame is reduced to a few eye measurements in memory and discarded. \
                        Learning keeps only gaze offsets, never images.
                        """
                    )
                )
            }
            Section {
                Toggle(String(localized: "Share anonymous usage metrics"), isOn: $model.metricsOptIn)
            } footer: {
                FormFooter(
                    String(localized: "Counts and timings only. No screen content, gaze positions or app names.")
                )
            }
            Section {
                LabeledContent(String(localized: "Calibration data")) {
                    Button(String(localized: "Delete…"), role: .destructive) { confirmDelete = true }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            String(localized: "Delete calibration?"),
            isPresented: $confirmDelete
        ) {
            Button(String(localized: "Delete"), role: .destructive) { model.actions.deleteCalibration() }
        } message: {
            Text(
                String(localized: """
                Saccade forgets your calibration and everything it learned. You'll calibrate again.
                """)
            )
        }
    }
}

struct AdvancedPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Only click real controls"), isOn: $model.settings.preciseTargetsOnly)
            } footer: {
                FormFooter(String(localized: "When off, a double blink over empty space clicks at your gaze point."))
            }
            Section {
                Toggle(String(localized: "Show gaze point"), isOn: $model.settings.debugGazeDot)
            } footer: {
                FormFooter(String(localized: "Always draws the estimated gaze point, even over a target."))
            }
            Section {
                LabeledContent(String(localized: "Setup")) {
                    Button(String(localized: "Show Welcome…")) { model.actions.openOnboarding() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutPane: View {
    let version: String

    var body: some View {
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
            Text(String(localized: "Control your Mac with your eyes."))
                .saccadeText(.callout)
                .foregroundStyle(SaccadeColor.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SaccadeColor.background)
    }
}

// MARK: Pieces

struct FormFooter: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text).saccadeText(.callout).foregroundStyle(SaccadeColor.textMuted)
    }
}

struct PercentSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: SaccadeSpacing.s) {
            Slider(value: $value, in: range, step: 0.01).frame(maxWidth: 200)
            Text(value.formatted(.percent.precision(.fractionLength(0))))
                .saccadeText(.body).monospacedDigit().foregroundStyle(SaccadeColor.textMuted)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

struct MillisecondSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: SaccadeSpacing.s) {
            Slider(value: $value, in: Double(range.lowerBound) ... Double(range.upperBound), step: 50)
                .frame(maxWidth: 200)
            Text(String(localized: "\(Int(value)) ms"))
                .saccadeText(.body).monospacedDigit().foregroundStyle(SaccadeColor.textMuted)
                .frame(width: 64, alignment: .trailing)
        }
    }
}

/// Human-readable app names for bundle IDs, falling back to the ID for apps that aren't installed.
enum AppName {
    @MainActor
    static func display(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
