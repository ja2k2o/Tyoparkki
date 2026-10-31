import Foundation
import SwiftUI

// MARK: - Configuration

enum ParkingConfig {
    // The plate comes from Settings → Apps → Työparkki (see PlateSettings).
    static var plateText: String { PlateSettings.plate }
    static var plateCountry: String { PlateSettings.country }

    /// The public status page (opened from the app).
    static var pageURL: URL {
        URL(string: "https://parkkimaksu.fi/tila/\(plateText)-\(plateCountry)")
            ?? URL(string: "https://parkkimaksu.fi")!
    }

    /// The JSON endpoint the status page loads its numbers from.
    static var dataURL: URL {
        var components = URLComponents(string: "https://parkkimaksu.fi/api/parkkimaksu/spaces")!
        components.queryItems = [
            URLQueryItem(name: "plateText", value: plateText),
            URLQueryItem(name: "plateCountry", value: plateCountry),
        ]
        return components.url!
    }

    /// The areas to show, in display order. An area matches every group in the
    /// response that has a hall whose name contains one of `hallNames` as a word
    /// (case-insensitive), e.g. "Hiekkaparkki" matches "Hiekkaparkki Keilaniemi".
    static let areas: [ParkingArea] = [
        ParkingArea(id: "k1k2", title: "K1/K2", spokenTitle: "K1 and K2", hallNames: ["K1", "K2"]),
        ParkingArea(id: "hiekka", title: "Hiekkaparkki", spokenTitle: "Hiekkaparkki", hallNames: ["Hiekkaparkki"]),
    ]

    static func area(id: String) -> ParkingArea? {
        areas.first { $0.id == id }
    }
}

// MARK: - Models

struct ParkingArea: Sendable {
    let id: String
    /// Shown on screen (not translated; it's the area's name).
    let title: String
    /// Used when Siri reads the result aloud ("K1 and K2" / "K1 ja K2").
    let spokenTitle: LocalizedStringResource
    let hallNames: [String]
}

struct AreaStatus: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let free: Int?

    var freeText: String { free.map(String.init) ?? "–" }

    var tint: Color {
        guard let free else { return .secondary }
        switch free {
        case 0: return .red
        case 1..<10: return .orange
        default: return .green
        }
    }
}

struct ParkingSnapshot: Codable, Hashable, Sendable {
    let areas: [AreaStatus]
    let fetchedAt: Date

    static let placeholder = ParkingSnapshot(
        areas: ParkingConfig.areas.map { AreaStatus(id: $0.id, title: $0.title, free: 42) },
        fetchedAt: .now
    )
}

// MARK: - Last-known-value cache

enum SnapshotCache {
    /// Per plate, so changing the plate never shows another vehicle's numbers.
    private static var key: String {
        "lastSnapshot.v2.\(ParkingConfig.plateText)-\(ParkingConfig.plateCountry)"
    }

    static func load() -> ParkingSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ParkingSnapshot.self, from: data)
    }

    static func save(_ snapshot: ParkingSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
