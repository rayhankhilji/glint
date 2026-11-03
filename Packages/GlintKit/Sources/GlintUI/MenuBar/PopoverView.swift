import GlintCore
import SwiftUI

/// The menu bar popover (DESIGN_SYSTEM §9.1).
public struct PopoverView: View {
    @Bindable private var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: GlintSpacing.s) {
            if let banner = StatusCopy.banner(for: model.status) {
                StatusBanner(kind: .danger, message: banner.message, actionTitle: banner.action) {
                    if case let .needsAttention(attention) = model.status {
                        model.actions.fixProblem(attention)
                    }
                }
                .accessibilityIdentifier("glint.popover.banner")
            }
            header
            Text(StatusCopy.statusLine(for: model.status))
                .glintText(.callout)
                .foregroundStyle(statusLineColor)
                .accessibilityIdentifier("glint.popover.status")
            accuracyRow
            Divider().padding(.vertical, GlintSpacing.xs)
            pauseRow
            menuRow(String(localized: "Settings…", bundle: .module), shortcut: "⌘,", id: "settings") {
                model.actions.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            menuRow(String(localized: "Quit Glint", bundle: .module), shortcut: "⌘Q", id: "quit") {
                model.actions.quit()
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(GlintSpacing.l)
        .frame(width: GlintLayout.popoverWidth, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: GlintSpacing.s) {
            Image(systemName: "sparkle")
                .foregroundStyle(GlintColor.accentText)
                .accessibilityHidden(true)
            Text("Glint", bundle: .module)
                .glintText(.title2)
                .foregroundStyle(GlintColor.text)
            Spacer()
            Toggle(isOn: Binding(get: { model.isEnabled }, set: { model.setEnabled($0) })) {
                Text("Glint", bundle: .module)
            }
            .toggleStyle(.switch)
            .tint(GlintColor.accent)
            .labelsHidden()
            .disabled(!model.canToggle)
            .accessibilityLabel(Text("Glint on or off", bundle: .module))
            .accessibilityIdentifier("glint.popover.toggle")
        }
    }

    private var accuracyRow: some View {
        HStack(spacing: GlintSpacing.s) {
            Text("Accuracy", bundle: .module)
                .glintText(.body)
                .foregroundStyle(GlintColor.textMuted)
            AccuracyChip(reading: model.accuracy)
            Spacer()
            if model.accuracy == nil {
                Button(String(localized: "Calibrate", bundle: .module)) { model.actions.recalibrate() }
                    .buttonStyle(.borderedProminent)
                    .tint(GlintColor.accent)
                    .foregroundStyle(GlintColor.onAccent)
                    .accessibilityIdentifier("glint.popover.calibrate")
            } else {
                Button(String(localized: "Recalibrate", bundle: .module)) { model.actions.recalibrate() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(GlintColor.accentText)
                    .accessibilityIdentifier("glint.popover.recalibrate")
            }
        }
    }

    @ViewBuilder private var pauseRow: some View {
        if case .paused = model.status {
            menuRow(String(localized: "Resume", bundle: .module), shortcut: nil, id: "resume") {
                model.actions.resume()
            }
        } else {
            Menu {
                ForEach(PauseDuration.allCases, id: \.self) { duration in
                    Button(Self.title(for: duration)) { model.actions.pause(duration) }
                }
            } label: {
                Text("Pause", bundle: .module)
                    .glintText(.body)
                    .foregroundStyle(GlintColor.text)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.visible)
            .disabled(!model.status.allowsActions)
            .accessibilityIdentifier("glint.popover.pause")
        }
    }

    private func menuRow(_ title: String, shortcut: String?, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .glintText(.body)
                    .foregroundStyle(GlintColor.text)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .glintText(.body)
                        .foregroundStyle(GlintColor.textMuted)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: GlintLayout.minHitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("glint.popover.\(id)")
    }

    private var statusLineColor: Color {
        if case .needsAttention(.lowLight) = model.status {
            return GlintColor.warning
        }
        return GlintColor.textMuted
    }

    static func title(for duration: PauseDuration) -> String {
        switch duration {
        case .fifteenMinutes: String(localized: "For 15 minutes", bundle: .module)
        case .oneHour: String(localized: "For 1 hour", bundle: .module)
        case .untilResumed: String(localized: "Until I resume", bundle: .module)
        }
    }
}

public extension AppModel {
    /// Fixtures for previews and snapshot tests, one per popover state (DESIGN_SYSTEM §9.1).
    static func fixture(_ status: GlintStatus, accuracy: AccuracyReading? = AccuracyReading(medianErrorDegrees: 2.1))
        -> AppModel {
        AppModel(status: status, accuracy: accuracy)
    }
}

#Preview("Tracking") { PopoverView(model: .fixture(.tracking(fps: 30))) }
#Preview("Off") { PopoverView(model: .fixture(.off)) }
#Preview("Not calibrated") { PopoverView(model: .fixture(.needsAttention(.notCalibrated), accuracy: nil)) }
#Preview("Accessibility missing") { PopoverView(model: .fixture(.needsAttention(.accessibilityPermissionMissing))) }
