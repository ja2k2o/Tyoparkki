import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var snapshot: ParkingSnapshot? = SnapshotCache.load()
    @State private var errorMessage: String?
    @State private var isLoading = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let snapshot {
                        ForEach(snapshot.areas) { AreaRow(area: $0) }
                    } else if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        ContentUnavailableView("No data yet", systemImage: "parkingsign.circle")
                    }
                } footer: {
                    if let snapshot {
                        Text("Updated \(snapshot.fetchedAt, style: .time)")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Link(destination: ParkingConfig.pageURL) {
                        Label("Open parkkimaksu.fi", systemImage: "safari")
                    }
                }
            }
            .navigationTitle("Free spaces")
            .refreshable { await refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            // Refresh when opened and every minute while the app is in the foreground.
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                while !Task.isCancelled {
                    await refresh()
                    try? await Task.sleep(for: .seconds(60))
                }
            }
        }
    }

    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // The plate may have been changed in the Settings app while we were away.
        let plateChanged = PlateSettings.syncFromSettingsApp()
        if plateChanged {
            snapshot = SnapshotCache.load()
        }

        do {
            let new = try await ParkingService.fetchAndCache()
            let changed = plateChanged || new.areas != snapshot?.areas
            withAnimation { snapshot = new }
            errorMessage = nil
            if changed { WidgetCenter.shared.reloadAllTimelines() }
        } catch let error as URLError where error.code == .cancelled {
            // View went away; ignore.
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
            if plateChanged { WidgetCenter.shared.reloadAllTimelines() }
        }
    }
}

private struct AreaRow: View {
    let area: AreaStatus

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(area.title)
                .font(.title3.weight(.medium))
            Spacer()
            Text(area.freeText)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(area.tint)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ContentView()
}
