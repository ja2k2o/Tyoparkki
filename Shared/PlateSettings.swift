import Foundation

/// The register plate used to look up parking spaces.
///
/// The user edits it in Settings → Apps → Työparkki (Tyoparkki/Settings.bundle).
/// The Settings app stores those values in the *app's own* UserDefaults, which the
/// widget can't read, so the app copies them into the shared App Group whenever it
/// runs (on launch, when it comes to the foreground, and when Siri asks).
/// The widget reads only the App Group copy.
enum PlateSettings {
    static let appGroupID = "group.com.github.ja2k2o.Tyoparkki"

    /// No default plate: the user enters their own in the Settings app.
    static let defaultPlate = ""
    static let defaultCountry = "FIN"

    // Same keys as in Settings.bundle/Root.plist.
    private static let plateKey = "plateText"
    private static let countryKey = "plateCountry"

    private static var shared: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Plate as the API expects it, e.g. "ABC-123" → "ABC123".
    static var plate: String {
        normalize(shared.string(forKey: plateKey) ?? defaultPlate)
    }

    /// Country code as the API expects it, e.g. "FIN".
    static var country: String {
        let value = normalize(shared.string(forKey: countryKey) ?? defaultCountry)
        return value.isEmpty ? defaultCountry : value
    }

    /// Copies the values entered in the Settings app to the App Group.
    /// Call from the app only. Returns true if the plate or country changed.
    @discardableResult
    static func syncFromSettingsApp() -> Bool {
        let standard = UserDefaults.standard
        // Settings.bundle defaults aren't stored until the user opens Settings.
        standard.register(defaults: [plateKey: defaultPlate, countryKey: defaultCountry])

        let newPlate = standard.string(forKey: plateKey) ?? defaultPlate
        let newCountry = standard.string(forKey: countryKey) ?? defaultCountry

        let changed = shared.string(forKey: plateKey) != newPlate
            || shared.string(forKey: countryKey) != newCountry
        if changed {
            shared.set(newPlate, forKey: plateKey)
            shared.set(newCountry, forKey: countryKey)
        }
        return changed
    }

    private static func normalize(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }
}
