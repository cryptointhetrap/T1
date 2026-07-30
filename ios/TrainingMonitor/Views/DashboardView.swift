import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @ObservedObject private var healthViewModel: HealthViewModel
    @ObservedObject private var calendarViewModel: GoogleCalendarViewModel
    @EnvironmentObject private var authManager: StravaAuthManager

    init(viewModel: DashboardViewModel, healthViewModel: HealthViewModel, calendarViewModel: GoogleCalendarViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.healthViewModel = healthViewModel
        self.calendarViewModel = calendarViewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let status = viewModel.trainingStatus, let ratio = viewModel.acuteChronicRatio {
                        trainingStatusBanner(status: status, ratio: ratio)
                    }

                    section(title: "Recovery") {
                        recoverySection
                    }

                    statGrid

                    section(title: "Bike & Run") {
                        VStack(spacing: 12) {
                            ForEach(SportCategory.allCases) { category in
                                if let totals = viewModel.sportTotals[category] {
                                    SportSummaryCard(category: category, totals: totals)
                                }
                            }
                        }
                    }

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
                        if !healthViewModel.isAuthorized {
                            Button("Connect Apple Health") {
                                Task { await healthViewModel.requestAccess() }
                            }
                        }
                        if calendarViewModel.isConnected {
                            Button("Disconnect Google Calendar", role: .destructive) {
                                calendarViewModel.disconnect()
                            }
                        } else {
                            Button("Connect Google Calendar") {
                                calendarViewModel.connect()
                            }
                        }
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
                value: Units.formattedMiles(last7?.distanceMeters ?? 0),
                systemImage: "figure.run"
            )
            StatCard(
                title: "Time",
                value: String(format: "%.1f h", last7?.movingTimeHours ?? 0),
                systemImage: "clock"
            )
            StatCard(
                title: "Elevation",
                value: Units.formattedFeet(last7?.elevationGainMeters ?? 0),
                systemImage: "mountain.2"
            )
            StatCard(
                title: "Activities",
                value: "\(last7?.activityCount ?? 0)",
                systemImage: "checkmark.circle"
            )
        }
    }

    @ViewBuilder
    private var recoverySection: some View {
        if healthViewModel.isAuthorized {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Sleep",
                    value: healthViewModel.sleepHours.map { String(format: "%.1f h", $0) } ?? "—",
                    systemImage: "bed.double"
                )
                StatCard(
                    title: "Resting HR",
                    value: healthViewModel.restingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "—",
                    systemImage: "heart"
                )
                StatCard(
                    title: "HRV",
                    value: healthViewModel.heartRateVariability.map { String(format: "%.0f ms", $0) } ?? "—",
                    systemImage: "waveform.path.ecg"
                )
            }
        } else {
            Button {
                Task { await healthViewModel.requestAccess() }
            } label: {
                Label("Connect Apple Health", systemImage: "heart.text.square")
            }
            .buttonStyle(.bordered)
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
