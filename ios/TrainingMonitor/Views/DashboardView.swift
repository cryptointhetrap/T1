import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @ObservedObject private var healthViewModel: HealthViewModel
    @ObservedObject private var calendarViewModel: GoogleCalendarViewModel
    @ObservedObject private var intervalsICUViewModel: IntervalsICUViewModel
    @ObservedObject private var goalsStore: GoalsStore
    @ObservedObject private var pushManager: PushNotificationManager
    @StateObject private var groupCompareViewModel: GroupCompareViewModel
    /// `nil` when backed by Apple Health Workouts instead of Strava (see
    /// `ActivitySourceStore`) — only needed for the Longest Efforts page.
    let apiClient: StravaAPIClient?
    let activitySource: ActivitySource
    var onDisconnectAppleHealth: (() -> Void)?
    @EnvironmentObject private var authManager: StravaAuthManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showIntervalsSettings = false
    @State private var showGoalsSettings = false

    init(
        viewModel: DashboardViewModel,
        healthViewModel: HealthViewModel,
        calendarViewModel: GoogleCalendarViewModel,
        intervalsICUViewModel: IntervalsICUViewModel,
        goalsStore: GoalsStore,
        pushManager: PushNotificationManager,
        apiClient: StravaAPIClient?,
        activitySource: ActivitySource,
        onDisconnectAppleHealth: (() -> Void)? = nil,
        athleteID: Int?
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.healthViewModel = healthViewModel
        self.calendarViewModel = calendarViewModel
        self.intervalsICUViewModel = intervalsICUViewModel
        self.goalsStore = goalsStore
        self.pushManager = pushManager
        self.apiClient = apiClient
        self.activitySource = activitySource
        self.onDisconnectAppleHealth = onDisconnectAppleHealth
        _groupCompareViewModel = StateObject(wrappedValue: GroupCompareViewModel(athleteID: athleteID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let status = viewModel.trainingStatus, let ratio = viewModel.acuteChronicRatio {
                        trainingStatusBanner(status: status, ratio: ratio)
                    }

                    section(title: "Weekly Goal") {
                        weeklyGoalSection
                    }

                    section(title: "Recovery") {
                        recoverySection
                    }

                    statGrid

                    section(title: "By Sport") {
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

                    if !viewModel.efficiencyTrend.isEmpty {
                        section(title: "Aerobic efficiency trend") {
                            EfficiencyTrendChart(trend: viewModel.efficiencyTrend)
                        }
                    }

                    if !viewModel.recentPersonalRecords.isEmpty {
                        section(title: "Recent PRs") {
                            PersonalRecordsList(records: viewModel.recentPersonalRecords)
                        }
                    }

                    if activitySource == .strava, let apiClient {
                        NavigationLink {
                            LongestEffortsView(apiClient: apiClient)
                        } label: {
                            recordsRowLabel(title: "Longest Efforts", systemImage: "ruler")
                        }

                        NavigationLink {
                            GroupCompareView(viewModel: groupCompareViewModel)
                        } label: {
                            recordsRowLabel(title: "Compare", systemImage: "person.2")
                        }
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
            .navigationTitle("Stats")
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
                        if intervalsICUViewModel.isConnected {
                            Button("Disconnect Intervals.icu", role: .destructive) {
                                intervalsICUViewModel.disconnect()
                            }
                        } else {
                            Button("Connect Intervals.icu") {
                                showIntervalsSettings = true
                            }
                        }
                        if activitySource == .strava {
                            if pushManager.isEnabled {
                                Button("Disable Workout Reviews", role: .destructive) {
                                    pushManager.disable()
                                }
                            } else {
                                Button("Enable Workout Reviews") {
                                    Task { await pushManager.enable() }
                                }
                            }
                        }
                        switch activitySource {
                        case .strava:
                            Button("Disconnect Strava", role: .destructive) {
                                authManager.disconnect()
                            }
                        case .appleHealth:
                            Button("Stop Using Apple Health Workouts", role: .destructive) {
                                onDisconnectAppleHealth?()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showIntervalsSettings) {
                IntervalsICUSettingsView(viewModel: intervalsICUViewModel)
            }
            .sheet(isPresented: $showGoalsSettings) {
                GoalsSettingsView(store: goalsStore)
            }
            .refreshable {
                await viewModel.refresh()
                await intervalsICUViewModel.refresh()
            }
            .task {
                await viewModel.refresh()
                await intervalsICUViewModel.refresh()
            }
            .onChange(of: scenePhase) { newPhase in
                guard newPhase == .active, let athleteID = authManager.session?.athleteID else { return }
                Task { await viewModel.refreshIfNewActivity(athleteID: athleteID) }
            }
            .onChange(of: viewModel.currentMonthGroupStats) { stats in
                guard let stats else { return }
                groupCompareViewModel.updateStats(stats)
            }
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
            .alert("Push notifications", isPresented: .constant(pushManager.errorMessage != nil)) {
                Button("OK") { pushManager.errorMessage = nil }
            } message: {
                Text(pushManager.errorMessage ?? "")
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
    private var weeklyGoalSection: some View {
        if goalsStore.goals.isEmpty {
            Button {
                showGoalsSettings = true
            } label: {
                Label("Set weekly goals", systemImage: "flag.checkered")
            }
            .buttonStyle(.bordered)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                WeeklyGoalRings(goals: goalsStore.goals, week: viewModel.weeklySummaries.last)
                Button("Edit goals") { showGoalsSettings = true }
                    .font(.caption)
                    .foregroundStyle(Color.ghGreen)
            }
        }
    }

    @ViewBuilder
    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            if let wellness = intervalsICUViewModel.latestWellness, let ctl = wellness.ctl, let atl = wellness.atl {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "Fitness (CTL)", value: String(format: "%.0f", ctl), systemImage: "chart.line.uptrend.xyaxis")
                    StatCard(title: "Fatigue (ATL)", value: String(format: "%.0f", atl), systemImage: "battery.25")
                    StatCard(title: "Form", value: String(format: "%.0f", ctl - atl), systemImage: "figure.run.circle")
                }
            } else if !intervalsICUViewModel.isConnected {
                Button {
                    showIntervalsSettings = true
                } label: {
                    Label("Connect Intervals.icu", systemImage: "waveform.path.ecg.rectangle")
                }
                .buttonStyle(.bordered)
            }
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
        .background(color(for: status).opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
    }

    private func color(for status: TrainingStatus) -> Color {
        switch status {
        case .optimal: return .ghGreen
        case .rampingUp: return .red
        case .highRisk: return .primary
        case .detraining: return .secondary
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

    private func recordsRowLabel(title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
