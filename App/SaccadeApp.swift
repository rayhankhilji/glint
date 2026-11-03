import SaccadeUI
import SwiftUI

/// Saccade's entry point: a menu-bar-only app (LSUIElement) with a popover and a Settings scene.
@main
struct SaccadeApp: App {
    @State private var environment = AppEnvironment.makeLive()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: environment.appModel)
        } label: {
            MenuBarLabel(state: environment.appModel.glyph)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView(model: environment.settingsModel, version: environment.versionString)
        }
    }
}
