import SwiftUI

/// A dedicated page (pushed from the Stats tab) ranking the athlete's
/// own longest-distance runs and rides across their entire Strava history
/// — separate from the Dashboard, which only looks back ~370 days.
struct LongestEffortsView: View {
    @StateObject private var viewModel: LongestEffortsViewModel

    init(apiClient: StravaAPIClient) {
        _viewModel = StateObject(wrappedValue: LongestEffortsViewModel(apiClient: apiClient))
    }

    var body: some View {
        List {
            Section("Longest Runs") {
                if viewModel.topRuns.isEmpty {
                    Text("No runs found yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.topRuns.enumerated()), id: \.element.id) { index, activity in
                        LongestEffortRow(rank: index + 1, activity: activity)
                    }
                }
            }

            Section("Longest Rides") {
                if viewModel.topRides.isEmpty {
                    Text("No rides found yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.topRides.enumerated()), id: \.element.id) { index, activity in
                        LongestEffortRow(rank: index + 1, activity: activity)
                    }
                }
            }
        }
        .navigationTitle("Longest Efforts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.load() }
        .overlay {
            if viewModel.isLoading && viewModel.topRuns.isEmpty && viewModel.topRides.isEmpty {
                ProgressView("Loading your full history…")
            }
        }
        .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

private struct LongestEffortRow: View {
    let rank: Int
    let activity: StravaActivity

    var body: some View {
        HStack {
            Text("\(rank)")
                .font(.headline)
                .foregroundStyle(rank == 1 ? Color.ghGreen : Color.secondary)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.subheadline.bold())
                Text(activity.startDateLocal.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Units.formattedMiles(activity.distance))
                .font(.subheadline.bold())
        }
        .padding(.vertical, 4)
    }
}
