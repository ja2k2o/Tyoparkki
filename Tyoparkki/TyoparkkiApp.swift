import SwiftUI

@main
struct TyoparkkiApp: App {
    init() {
        // Pick up the plate from Settings → Apps → Työparkki before anything loads.
        PlateSettings.syncFromSettingsApp()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
