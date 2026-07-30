import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @EnvironmentObject private var authManager: StravaAuthManager

    init(viewModel: DashboardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let status = viewModel.trainingStatus, let ratio = viewModel.acuteChronicRatio {
                        trainingStatusBanner(status: status, ratio: ratio)
                    }

                    statGrid

                    section(title: "Weekly volume") {
                        WeeklyVolumeChart(weeks: viewModel.weeklySummaries)
                    }

                    section(title: "Training load trend") {
                        TrainingLoadChart(points: viewModel.loadSeries)
                    }

                    section(title: "Recent activities") {
                        VStack(spacing: 0) {
                            ForEach(viewModel.recentActivities.prefix(10)) { activity in
                                ActivityRow(activity: activity)
                                Divider()
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Training")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Disconnect Strava", role: .destructive) {
                            authManager.disconnect()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.refresh() }
            .overlay {
                if viewModel.isLoading && viewModel.recentActivities.isEmpty {
                    ProgressView()
                }
            }
            .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var statGrid: some View {
        let last7 = viewModel.weeklySummaries.last

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "This week",
                value: String(format: "%.1f km", last7?.distanceKm ?? 0),
                systemImage: "figure.run"
            )
            StatCard(
                title: "Time",
                value: String(format: "%.1f h", last7?.movingTimeHours ?? 0),
                systemImage: "clock"
            )
            StatCard(
                title: "Elevation",
                value: String(format: "%.0f m", last7?.elevationGainM ?? 0),
                systemImage: "mountain.2"
            )
            StatCard(
                title: "Activities",
                value: "\(last7?.activityCount ?? 0)",
                systemImage: "checkmark.circle"
            )
        }
    }

    private func trainingStatusBanner(status: TrainingStatus, ratio: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(status.rawValue)
                    .font(.headline)
                Text("Acute:chronic ratio \(String(format: "%.2f", ratio))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(color(for: status).opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
    }

    private func color(for status: TrainingStatus) -> Color {
        switch status {
        case .optimal: return .green
        case .rampingUp: return .yellow
        case .highRisk: return .red
        case .detraining: return .blue
        }
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

private struct ActivityRow: View {
    let activity: StravaActivity

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.subheadline.bold())
                Text("\(activity.type) · \(String(format: "%.1f km", activity.distance / 1000)) · \(activity.movingTime / 60) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
