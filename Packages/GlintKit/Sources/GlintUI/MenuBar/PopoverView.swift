import GlintCore
import SwiftUI

/// The menu bar popover (DESIGN_SYSTEM §9.1): the live mark and switch, one status line, accuracy as plain
/// text, then a short list of actions with custom icons. No cards, chips or gradients.
public struct PopoverView: View {
    @Bindable private var model: AppModel
    @Environment(\.openSettings) private var openSettings

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: GlintSpacing.m) {
            header
            if let banner = StatusCopy.banner(for: model.status) {
                StatusBanner(kind: .danger, message: banner.message, actionTitle: banner.action) {
                    if case let .needsAttention(attention) = model.status {
                        model.actions.fixProblem(attention)
                    }
                }
                .accessibilityIdentifier("glint.popover.banner")
            }
            accuracyRow
            Rectangle()
                .fill(GlintColor.border)
                .frame(height: GlintLayout.hairline)
            VStack(spacing: GlintSpacing.xxs) {
                pauseRow
                PopoverRow(
                    icon: .recalibrate,
                    title: model.accuracy == nil
                        ? String(localized: "Calibrate", bundle: .module)
                        : String(localized: "Recalibrate", bundle: .module),
                    id: "recalibrate"
                ) {
                    model.actions.recalibrate()
                }
                PopoverRow(
                    icon: .tune,
                    title: String(localized: "Settings…", bundle: .module),
                    shortcut: "⌘,",
                    id: "settings"
                ) {
                    model.actions.openSettings()
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
                PopoverRow(
                    icon: .quit,
                    title: String(localized: "Quit Glint", bundle: .module),
                    shortcut: "⌘Q",
                    id: "quit"
                ) {
                    model.actions.quit()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(GlintSpacing.l)
        .frame(width: GlintLayout.popoverWidth, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: GlintSpacing.m) {
            GlintMark(size: 28, motion: model.status.allowsActions ? .twinkle : .still)
                .opacity(model.isEnabled ? 1 : 0.45)
            VStack(alignment: .leading, spacing: GlintSpacing.xxs) {
                Text("Glint", bundle: .module)
                    .glintText(.title2)
                    .foregroundStyle(GlintColor.text)
                Text(StatusCopy.statusLine(for: model.status))
                    .glintText(.callout)
                    .foregroundStyle(statusLineColor)
                    .contentTransition(.opacity)
                    .accessibilityIdentifier("glint.popover.status")
            }
            Spacer(minLength: GlintSpacing.s)
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
        .animation(GlintMotion.springSnappy, value: model.status)
    }

    private var accuracyRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Accuracy", bundle: .module)
                .glintText(.body)
                .foregroundStyle(GlintColor.textMuted)
            Spacer()
            AccuracyReadout(reading: model.accuracy)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var pauseRow: some View {
        if case .paused = model.status {
            PopoverRow(icon: .play, title: String(localized: "Resume", bundle: .module), id: "resume") {
                model.actions.resume()
            }
        } else {
            Menu {
                ForEach(PauseDuration.allCases, id: \.self) { duration in
                    Button(Self.title(for: duration)) { model.actions.pause(duration) }
                }
            } label: {
                PopoverRowLabel(icon: .pause, title: String(localized: "Pause", bundle: .module), trailing: .chevron)
            }
            .menuStyle(.button)
            .buttonStyle(PopoverRowButtonStyle())
            .menuIndicator(.hidden)
            .disabled(!model.status.allowsActions)
            .accessibilityIdentifier("glint.popover.pause")
        }
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

/// One action row: icon, title, optional shortcut or chevron.
struct PopoverRow: View {
    let icon: GlintIconName
    let title: String
    var shortcut: String?
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PopoverRowLabel(icon: icon, title: title, trailing: shortcut.map { .shortcut($0) } ?? .none)
        }
        .buttonStyle(PopoverRowButtonStyle())
        .accessibilityIdentifier("glint.popover.\(id)")
    }
}

struct PopoverRowLabel: View {
    enum Trailing { case none, chevron, shortcut(String) }

    let icon: GlintIconName
    let title: String
    let trailing: Trailing

    var body: some View {
        HStack(spacing: GlintSpacing.m) {
            GlintIcon(icon, size: 16)
                .foregroundStyle(GlintColor.textMuted)
            Text(title)
                .glintText(.body)
                .foregroundStyle(GlintColor.text)
            Spacer(minLength: GlintSpacing.s)
            switch trailing {
            case .none:
                EmptyView()
            case .chevron:
                GlintIcon(.chevronRight, size: 12)
                    .foregroundStyle(GlintColor.textMuted)
            case let .shortcut(keys):
                Text(keys)
                    .glintText(.body)
                    .foregroundStyle(GlintColor.textMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, GlintSpacing.s)
        .frame(minHeight: GlintLayout.minHitTarget)
        .contentShape(Rectangle())
    }
}

/// Flat hover and press feedback for popover rows: a quiet fill, no scaling, no color shift.
struct PopoverRowButtonStyle: ButtonStyle {
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: GlintRadius.s, style: .continuous)
                    .fill(GlintColor.border.opacity(configuration.isPressed ? 1 : (hovering ? 0.6 : 0)))
            )
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: GlintMotion.instant), value: hovering)
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
