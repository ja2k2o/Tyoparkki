import Foundation

enum ParkingError: LocalizedError, CustomLocalizedStringResourceConvertible {
    case noPlate
    case badResponse(Int)
    case noMatchingAreas

    /// Used by Siri / App Intents.
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noPlate:
            return "Set the register plate in Settings → Apps → Työparkki."
        case .badResponse(let code):
            return "Server responded with HTTP \(code)."
        case .noMatchingAreas:
            return "Couldn't find K1/K2 or Hiekkaparkki in the data."
        }
    }

    /// Used by the app's own UI.
    var errorDescription: String? { String(localized: localizedStringResource) }
}

// MARK: - API response

/// Response of GET /api/parkkimaksu/spaces:
/// { "spaces": [ { "spaces": 78, "targets": [ { "hallName": "...", "laneName": "" } ] } ], "countries": ["FIN"] }
struct SpacesResponse: Decodable, Sendable {
    let spaces: [SpaceGroup]

    struct SpaceGroup: Decodable, Sendable {
        /// Number of free spaces shared by all `targets` in this group.
        let spaces: Int
        let targets: [Target]
    }

    struct Target: Decodable, Sendable {
        let hallName: String
    }
}

// MARK: - Service

enum ParkingService {

    /// Fetches the current numbers and stores them as the last known value.
    static func fetchAndCache() async throws -> ParkingSnapshot {
        let snapshot = try await fetch()
        SnapshotCache.save(snapshot)
        return snapshot
    }

    static func fetch() async throws -> ParkingSnapshot {
        guard !ParkingConfig.plateText.isEmpty else { throw ParkingError.noPlate }

        var request = URLRequest(url: ParkingConfig.dataURL,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ParkingError.badResponse(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(SpacesResponse.self, from: data)
        let areas = ParkingConfig.areas.map { status(for: $0, in: decoded.spaces) }
        guard areas.contains(where: { $0.free != nil }) else { throw ParkingError.noMatchingAreas }
        return ParkingSnapshot(areas: areas, fetchedAt: .now)
    }

    /// Sums the free spaces of every group that contains one of the area's halls.
    /// (K1 and K2 currently come back as a single shared group, so this is just that group's count.)
    static func status(for area: ParkingArea, in groups: [SpacesResponse.SpaceGroup]) -> AreaStatus {
        let matching = groups.filter { group in
            group.targets.contains { target in
                area.hallNames.contains { containsWord($0, in: target.hallName) }
            }
        }
        let free = matching.isEmpty ? nil : matching.reduce(0) { $0 + max(0, $1.spaces) }
        return AreaStatus(id: area.id, title: area.title, free: free)
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        let pattern = "(?<![A-Za-z0-9])" + NSRegularExpression.escapedPattern(for: word) + "(?![A-Za-z0-9])"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
