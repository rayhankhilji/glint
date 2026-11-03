import SaccadeCore
import SwiftUI

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
                Toggle(String(localized: "Record sessions for tuning"), isOn: $model.settings.recordTraces)
                HStack {
                    Spacer()
                    Button(String(localized: "Show Recordings")) { model.actions.revealTraces() }
                }
            } footer: {
                FormFooter(String(localized: """
                Saves eye measurements and click positions (never images) on this Mac, so `saccade-eval \
                --trace` can replay a session and compare settings.
                """))
            }
            Section {
                DiagnosticsRows(diagnostics: model.diagnostics)
            } header: {
                Text(String(localized: "Live"))
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

/// Live pipeline numbers in tabular digits; "—" until tracking runs.
struct DiagnosticsRows: View {
    let diagnostics: LiveDiagnostics?

    var body: some View {
        row(String(localized: "Frame rate"), diagnostics.map { "\($0.framesPerSecond) fps" })
        row(String(localized: "Gaze uncertainty"), diagnostics.map { String(format: "%.0f pt", $0.sigmaPoints) })
        row(
            String(localized: "Face confidence"),
            diagnostics.map { $0.confidence.formatted(.percent.precision(.fractionLength(0))) }
        )
        row(String(localized: "Clicks learned"), diagnostics.map { "\($0.learnedClicks)" })
        row(String(localized: "Accessibility lookup"), diagnostics.flatMap { d in
            d.accessibilityP50.map { p50 in
                String(format: "%.0f ms · p95 %.0f ms", p50, d.accessibilityP95 ?? p50)
            }
        })
    }

    private func row(_ label: String, _ value: String?) -> some View {
        LabeledContent(label) {
            Text(value ?? "—")
                .saccadeText(.body)
                .monospacedDigit()
                .foregroundStyle(SaccadeColor.textMuted)
        }
    }
}
