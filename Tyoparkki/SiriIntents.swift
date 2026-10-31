import AppIntents
import WidgetKit

// MARK: - Intents
//
// Three small intents instead of one with a parameter: fixed phrases are matched
// far more reliably by Siri (especially in Finnish) than spoken parameter values.

struct CheckParkingSpacesIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Parking Spaces"
    static let description = IntentDescription("Tells how many free spaces there are in K1/K2 and Hiekkaparkki.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = try await ParkingSpeech.answer(for: nil)
        return .result(dialog: "\(answer)")
    }
}

struct CheckK1K2Intent: AppIntent {
    static let title: LocalizedStringResource = "Check K1/K2"
    static let description = IntentDescription("Tells how many free spaces there are in K1/K2.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = try await ParkingSpeech.answer(for: "k1k2")
        return .result(dialog: "\(answer)")
    }
}

struct CheckHiekkaparkkiIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Hiekkaparkki"
    static let description = IntentDescription("Tells how many free spaces there are in Hiekkaparkki.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = try await ParkingSpeech.answer(for: "hiekka")
        return .result(dialog: "\(answer)")
    }
}

// MARK: - Siri phrases
//
// Every phrase must contain the app name. Finnish versions are in
// AppShortcuts.xcstrings; they keep "Työparkki" in its base form because Siri
// matches the name literally (an inflected form like "Työparkista" won't match).

struct TyoparkkiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckParkingSpacesIntent(),
            phrases: [
                "How many free spaces in \(.applicationName)",
                "Check \(.applicationName)",
                "Show \(.applicationName)",
                "\(.applicationName) free spaces",
            ],
            shortTitle: "Free spaces",
            systemImageName: "parkingsign.circle"
        )
        AppShortcut(
            intent: CheckK1K2Intent(),
            phrases: [
                "\(.applicationName) K1 and K2",
                "Check K1 and K2 in \(.applicationName)",
            ],
            shortTitle: "K1/K2",
            systemImageName: "parkingsign"
        )
        AppShortcut(
            intent: CheckHiekkaparkkiIntent(),
            phrases: [
                "\(.applicationName) Hiekkaparkki",
                "Check Hiekkaparkki in \(.applicationName)",
            ],
            shortTitle: "Hiekkaparkki",
            systemImageName: "parkingsign"
        )
    }
}

// MARK: - Spoken answer

enum ParkingSpeech {
    /// Fetches fresh numbers and builds the sentence Siri reads, e.g.
    /// "K1 ja K2: 6 vapaata paikkaa. Hiekkaparkki: 78 vapaata paikkaa."
    /// Pass an area id to answer about one area only, or nil for all.
    static func answer(for areaID: String?) async throws -> String {
        PlateSettings.syncFromSettingsApp()
        let snapshot = try await ParkingService.fetchAndCache()
        WidgetCenter.shared.reloadAllTimelines()

        let statuses = snapshot.areas.filter { areaID == nil || $0.id == areaID }
        return statuses.map { sentence(for: $0) }.joined(separator: " ")
    }

    private static func sentence(for status: AreaStatus) -> String {
        let name = ParkingConfig.area(id: status.id).map { String(localized: $0.spokenTitle) } ?? status.title
        let count: String
        if let free = status.free {
            count = String(localized: "\(free) free spaces")
        } else {
            count = String(localized: "no data")
        }
        return "\(name): \(count)."
    }
}
