import SwiftUI
import WidgetKit

// MARK: - Timeline

struct ParkingEntry: TimelineEntry {
    let date: Date
    let snapshot: ParkingSnapshot?
    /// True when the latest fetch failed and we're showing the last known value.
    let isStale: Bool
    /// True when no register plate has been set in the Settings app.
    var needsPlate = false
}

struct ParkingProvider: TimelineProvider {
    func placeholder(in context: Context) -> ParkingEntry {
        ParkingEntry(date: .now, snapshot: .placeholder, isStale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (ParkingEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { completion(await makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ParkingEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            // iOS decides the actual refresh time within the widget's budget;
            // in practice expect roughly every 15–30 minutes.
            let next = Date.now.addingTimeInterval(entry.isStale ? 5 * 60 : 10 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func makeEntry() async -> ParkingEntry {
        do {
            let snapshot = try await ParkingService.fetchAndCache()
            return ParkingEntry(date: .now, snapshot: snapshot, isStale: false)
        } catch ParkingError.noPlate {
            return ParkingEntry(date: .now, snapshot: nil, isStale: false, needsPlate: true)
        } catch {
            return ParkingEntry(date: .now, snapshot: SnapshotCache.load(), isStale: true)
        }
    }
}

// MARK: - Views

struct ParkingWidgetView: View {
    let entry: ParkingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenView(entry: entry)
                .containerBackground(for: .widget) {}
        default:
            SmallView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

/// Home Screen and CarPlay.
private struct SmallView: View {
    let entry: ParkingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Free spaces", systemImage: "parkingsign.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let snapshot = entry.snapshot {
                ForEach(snapshot.areas) { area in
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(area.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: 2)
                        Text(area.freeText)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(area.tint)
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    if entry.isStale {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    Text(snapshot.fetchedAt, style: .time)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else {
                Spacer(minLength: 0)
                Text("No data")
                    .font(.headline)
                MissingDataHint(needsPlate: entry.needsPlate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Lock Screen. iOS draws it in a single tint, so the numbers carry no
/// colour meaning here; they're just bold.
private struct LockScreenView: View {
    let entry: ParkingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 3) {
                Image(systemName: "parkingsign.circle.fill")
                Text("Free spaces")
                if entry.isStale {
                    Spacer(minLength: 2)
                    Image(systemName: "exclamationmark.triangle.fill")
                }
            }
            .font(.caption2.weight(.semibold))
            .widgetAccentable()
            .lineLimit(1)

            if let snapshot = entry.snapshot {
                ForEach(snapshot.areas) { area in
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(area.title)
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 2)
                        Text(area.freeText)
                            .font(.headline.weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
            } else {
                MissingDataHint(needsPlate: entry.needsPlate)
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MissingDataHint: View {
    let needsPlate: Bool

    var body: some View {
        if needsPlate {
            Text("Set the register plate in Settings → Apps → Työparkki.")
        } else {
            Text("Open the app to check the setup.")
        }
    }
}

// MARK: - Widget

struct TyoparkkiWidget: Widget {
    let kind = "TyoparkkiWidget"

    var body: some WidgetConfiguration {
        // systemSmall: Home Screen and CarPlay (iOS 26). accessoryRectangular: Lock Screen.
        StaticConfiguration(kind: kind, provider: ParkingProvider()) { entry in
            ParkingWidgetView(entry: entry)
        }
        .configurationDisplayName("Parking spaces")
        .description("Free spaces in K1/K2 and Hiekkaparkki.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

@main
struct TyoparkkiWidgetBundle: WidgetBundle {
    var body: some Widget {
        TyoparkkiWidget()
    }
}

#Preview("Home Screen", as: .systemSmall) {
    TyoparkkiWidget()
} timeline: {
    ParkingEntry(date: .now, snapshot: .placeholder, isStale: false)
    ParkingEntry(date: .now, snapshot: nil, isStale: false, needsPlate: true)
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    TyoparkkiWidget()
} timeline: {
    ParkingEntry(date: .now, snapshot: .placeholder, isStale: false)
    ParkingEntry(date: .now, snapshot: nil, isStale: false, needsPlate: true)
}
