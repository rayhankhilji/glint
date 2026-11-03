import AppKit
import SaccadeCore
import SwiftUI

// MARK: Panes

struct GeneralPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Saccade is on"), isOn: $model.settings.isEnabled)
                Toggle(String(localized: "Open at login"), isOn: $model.settings.launchAtLogin)
                LabeledContent(String(localized: "Turn on or off")) {
                    Text(model.hotKeyDisplay).saccadeText(.mono).foregroundStyle(SaccadeColor.textMuted)
                }
            }
            Section {
                LabeledContent(String(localized: "Calibration")) { AccuracyReadout(reading: model.accuracy) }
                LabeledContent(String(localized: "From your clicks")) {
                    if let live = model.liveAccuracy {
                        AccuracyReadout(reading: live)
                    } else {
                        Text(String(localized: "After a few clicks")).foregroundStyle(SaccadeColor.textMuted)
                    }
                }
                HStack {
                    Spacer()
                    Button(String(localized: "Recalibrate…")) { model.actions.recalibrate() }
                }
            } footer: {
                FormFooter(
                    String(
                        localized: """
                        Saccade also learns from every click you make, so accuracy keeps improving \
                        after calibration.
                        """
                    )
                )
            }
            Section {
                LabeledContent(String(localized: "Accessibility")) {
                    if model.accessibilityGranted {
                        Text(String(localized: "Allowed")).foregroundStyle(SaccadeColor.textMuted)
                    } else {
                        Button(String(localized: "Allow…")) { model.actions.openAccessibilitySettings() }
                    }
                }
            } footer: {
                FormFooter(String(localized: """
                Needed to find buttons under your gaze and to click and scroll for you.
                """))
            }
        }
        .formStyle(.grouped)
    }
}

struct GesturesPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Double blink to click"), isOn: $model.settings.click.enabled)
                Toggle(
                    String(localized: "Blink, then hold, to right-click"),
                    isOn: $model.settings.click.rightClickEnabled
                )
                .disabled(!model.settings.click.enabled)
                Toggle(String(localized: "Click sound"), isOn: $model.settings.clickSound)
                    .disabled(!model.settings.click.enabled)
                LabeledContent(String(localized: "Blink sensitivity")) {
                    Slider(value: $model.settings.click.sensitivity, in: ClickSettings.sensitivityRange) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text(String(localized: "Firm"))
                    } maximumValueLabel: {
                        Text(String(localized: "Light"))
                    }
                    .frame(maxWidth: 240)
                }
                .disabled(!model.settings.click.enabled)
            } footer: {
                FormFooter(
                    String(
                        localized: """
                        Clicks only fire after your gaze has rested on one target. Natural blinks \
                        never click.
                        """
                    )
                )
            }
            Section {
                Toggle(String(localized: "Focus follows gaze"), isOn: $model.settings.focusFollowsGaze.enabled)
                LabeledContent(String(localized: "Look for")) {
                    MillisecondSlider(value: $model.focusDwell, range: FocusSettings.dwellMsRange)
                }
                .disabled(!model.settings.focusFollowsGaze.enabled)
            } footer: {
                FormFooter(String(localized: "Look at another window to bring it forward. Paused while you type."))
            }
            Section {
                Toggle(String(localized: "Mark where I was reading"), isOn: $model.settings.readingMarkerEnabled)
            } footer: {
                FormFooter(
                    String(localized: """
                    When you look back after a break, the line you were on is briefly highlighted.
                    """)
                )
            }
        }
        .formStyle(.grouped)
    }
}

struct ScrollingPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Scroll by looking"), isOn: $model.settings.scroll.enabled)
            } footer: {
                FormFooter(
                    String(
                        localized: """
                        Rest your eyes near the bottom of a page to glide down, near the top to glide \
                        back.
                        """
                    )
                )
            }
            Section {
                LabeledContent(String(localized: "Bottom zone")) {
                    PercentSlider(value: $model.settings.scroll.downZoneFraction, range: ScrollSettings.downZoneRange)
                }
                LabeledContent(String(localized: "Top zone")) {
                    PercentSlider(value: $model.settings.scroll.upZoneFraction, range: ScrollSettings.upZoneRange)
                }
                LabeledContent(String(localized: "Glide distance")) {
                    PercentSlider(value: $model.settings.scroll.glideFraction, range: ScrollSettings.glideRange)
                }
                LabeledContent(String(localized: "Rest for")) {
                    MillisecondSlider(value: $model.scrollDwell, range: ScrollSettings.dwellMsRange)
                }
            }
            .disabled(!model.settings.scroll.enabled)
        }
        .formStyle(.grouped)
    }
}
