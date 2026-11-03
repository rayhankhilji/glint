import SaccadeCore
import SwiftUI

/// The menu bar popover (DESIGN_SYSTEM §9.1). Linear-style: compact 13 pt rows, hairline sections, a status dot,
/// SF Symbols, and the accent only where it means something.
public struct PopoverView: View {
    @Bindable private var model: AppModel
    @Environment(\.openSettings) private var openSettings

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, SaccadeSpacing.m)
                .padding(.top, SaccadeSpacing.m)
                .padding(.bottom, SaccadeSpacing.m)
            if let banner = StatusCopy.banner(for: model.status) {
                StatusBanner(kind: .danger, message: banner.message, actionTitle: banner.action) {
                    if case let .needsAttention(attention) = model.status {
                        model.actions.fixProblem(attention)
                    }
                }
                .padding(.horizontal, SaccadeSpacing.s)
                .padding(.bottom, SaccadeSpacing.s)
                .accessibilityIdentifier("saccade.popover.banner")
            }
            Hairline()
            accuracyRow
                .padding(.horizontal, SaccadeSpacing.m)
                .frame(height: 36)
            Hairline()
            VStack(spacing: 0) {
                pauseRow
                PopoverRow(
                    symbol: .recalibrate,
                    title: model.accuracy == nil
                        ? String(localized: "Calibrate")
                        : String(localized: "Recalibrate"),
                    id: "recalibrate"
                ) {
                    model.actions.recalibrate()
                }
                PopoverRow(symbol: .settings, title: String(localized: "Settings…"), shortcut: "⌘,", id: "settings") {
                    model.actions.openSettings()
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            .padding(SaccadeSpacing.xs)
            Hairline()
            PopoverRow(symbol: .quit, title: String(localized: "Quit Saccade"), shortcut: "⌘Q", id: "quit") {
                model.actions.quit()
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(SaccadeSpacing.xs)
        }
        .frame(width: SaccadeLayout.popoverWidth, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: SaccadeSpacing.m) {
            SaccadeMark(size: 22, motion: model.status.allowsActions ? .live : .still)
                .opacity(model.isEnabled ? 1 : 0.4)
            VStack(alignment: .leading, spacing: 2) {
                Text("Saccade")
                    .saccadeText(.headline)
                    .foregroundStyle(SaccadeColor.text)
                HStack(spacing: 6) {
                    StatusDot(statusColor)
                    Text(StatusCopy.statusLine(for: model.status))
                        .saccadeText(.callout)
                        .foregroundStyle(SaccadeColor.textMuted)
                        .contentTransition(.opacity)
                        .accessibilityIdentifier("saccade.popover.status")
                }
            }
            Spacer(minLength: SaccadeSpacing.s)
            Toggle(isOn: Binding(get: { model.isEnabled }, set: { model.setEnabled($0) })) {
                Text("Saccade")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(SaccadeColor.accent)
            .labelsHidden()
            .disabled(!model.canToggle)
            .accessibilityLabel(Text("Saccade on or off"))
            .accessibilityIdentifier("saccade.popover.toggle")
        }
        .animation(SaccadeMotion.springSnappy, value: model.status)
    }

    private var accuracyRow: some View {
        HStack {
            Text("Accuracy")
                .saccadeText(.body)
                .foregroundStyle(SaccadeColor.textMuted)
            Spacer()
            AccuracyReadout(reading: model.accuracy)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var pauseRow: some View {
        if case .paused = model.status {
            PopoverRow(symbol: .resume, title: String(localized: "Resume"), id: "resume") {
                model.actions.resume()
            }
        } else {
            Menu {
                ForEach(PauseDuration.allCases, id: \.self) { duration in
                    Button(Self.title(for: duration)) { model.actions.pause(duration) }
                }
            } label: {
                PopoverRowLabel(symbol: .pause, title: String(localized: "Pause"), trailing: .chevron)
            }
            .menuStyle(.button)
            .buttonStyle(PopoverRowButtonStyle())
            .menuIndicator(.hidden)
            .disabled(!model.status.allowsActions)
            .accessibilityIdentifier("saccade.popover.pause")
        }
    }

    /// Status dot: green while tracking, amber when paused or away, red when blocked, faint when off.
    private var statusColor: Color {
        switch model.status {
        case .tracking: SaccadeColor.success
        case .starting: SaccadeColor.accent
        case .paused, .away, .needsAttention(.lowLight), .needsAttention(.notCalibrated): SaccadeColor.warning
        case .needsAttention: SaccadeColor.danger
        case .off: SaccadeColor.textFaint
        }
    }

    static func title(for duration: PauseDuration) -> String {
        switch duration {
        case .fifteenMinutes: String(localized: "For 15 minutes")
        case .oneHour: String(localized: "For 1 hour")
        case .untilResumed: String(localized: "Until I resume")
        }
    }
}

/// A full-width 1 px hairline.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(SaccadeColor.border).frame(height: 1)
    }
}

/// One action row: symbol, title, optional shortcut or chevron.
struct PopoverRow: View {
    let symbol: SaccadeSymbol
    let title: String
    var shortcut: String?
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PopoverRowLabel(symbol: symbol, title: title, trailing: shortcut.map { .shortcut($0) } ?? .none)
        }
        .buttonStyle(PopoverRowButtonStyle())
        .accessibilityIdentifier("saccade.popover.\(id)")
    }
}

struct PopoverRowLabel: View {
    enum Trailing { case none, chevron, shortcut(String) }

    let symbol: SaccadeSymbol
    let title: String
    let trailing: Trailing

    var body: some View {
        HStack(spacing: SaccadeSpacing.s) {
            SaccadeSymbolImage(symbol, size: 12)
                .foregroundStyle(SaccadeColor.textMuted)
            Text(title)
                .saccadeText(.body)
                .foregroundStyle(SaccadeColor.text)
            Spacer(minLength: SaccadeSpacing.s)
            switch trailing {
            case .none:
                EmptyView()
            case .chevron:
                SaccadeSymbolImage(.chevron, size: 10, weight: .semibold)
                    .foregroundStyle(SaccadeColor.textFaint)
            case let .shortcut(keys):
                Text(keys)
                    .saccadeText(.callout)
                    .foregroundStyle(SaccadeColor.textFaint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, SaccadeSpacing.s)
        .frame(height: SaccadeLayout.rowHeight)
        .contentShape(Rectangle())
    }
}

/// Flat hover and press feedback: a subtle fill with 6 pt corners. No scaling, no color shift.
struct PopoverRowButtonStyle: ButtonStyle {
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: SaccadeRadius.s, style: .continuous)
                    .fill(hovering || configuration.isPressed ? SaccadeColor.subtle : .clear)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { hovering = $0 }
    }
}

public extension AppModel {
    /// Fixtures for previews and snapshot tests, one per popover state (DESIGN_SYSTEM §9.1).
    static func fixture(_ status: SaccadeStatus, accuracy: AccuracyReading? = AccuracyReading(medianErrorDegrees: 2.1))
        -> AppModel {
        AppModel(status: status, accuracy: accuracy)
    }
}

#Preview("Tracking") { PopoverView(model: .fixture(.tracking(fps: 30))) }
#Preview("Off") { PopoverView(model: .fixture(.off)) }
#Preview("Not calibrated") { PopoverView(model: .fixture(.needsAttention(.notCalibrated), accuracy: nil)) }
#Preview("Accessibility missing") { PopoverView(model: .fixture(.needsAttention(.accessibilityPermissionMissing))) }
