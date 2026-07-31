import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: StravaAuthManager
    @StateObject private var scheduledWorkoutStore = ScheduledWorkoutStore()
    @StateObject private var healthViewModel = HealthViewModel()
    @StateObject private var stepsViewModel = StepsViewModel()
    @StateObject private var mealsViewModel = MealsViewModel()
    @StateObject private var googleAuthManager = GoogleAuthManager()
    @StateObject private var intervalsICUViewModel = IntervalsICUViewModel()
    @StateObject private var preferencesStore = PreferencesStore()
    @StateObject private var goalsStore = GoalsStore()
    @StateObject private var pushManager = PushNotificationManager.shared
    @StateObject private var activitySourceStore = ActivitySourceStore()
    @StateObject private var motivationViewModel = MotivationViewModel()
    @State private var showLaunchSplash = true

    private let calendarFeedClient = CalendarFeedClient(token: FeedTokenStore.token())

    var body: some View {
        Group {
            if authManager.isConnected {
                let apiClient = StravaAPIClient(authManager: authManager)
                mainTabView(
                    activitySource: .strava,
                    activityProvider: apiClient,
                    prDetailClient: apiClient,
                    longestEffortsClient: apiClient,
                    athleteID: authManager.session?.athleteID,
                    onDisconnectAppleHealth: nil
                )
            } else if activitySourceStore.source == .appleHealth {
                mainTabView(
                    activitySource: .appleHealth,
                    activityProvider: HealthKitActivityProvider(),
                    prDetailClient: nil,
                    longestEffortsClient: nil,
                    athleteID: nil,
                    onDisconnectAppleHealth: { activitySourceStore.source = nil }
                )
            } else {
                ConnectStravaView(healthViewModel: healthViewModel, activitySourceStore: activitySourceStore)
            }
        }
        .overlay {
            if showLaunchSplash {
                MotivationSplashView(viewModel: motivationViewModel) {
                    withAnimation { showLaunchSplash = false }
                }
            }
        }
    }

    /// Shared Stats/Steps/Meals/Calendar/Coach tab set for both activity
    /// sources (see `ActivitySourceStore`) — everything except the
    /// Strava-specific bits threaded in as parameters (Longest Efforts,
    /// Compare, Recent PRs, and workout-review push all end up hidden or
    /// inert when `prDetailClient`/`longestEffortsClient`/`athleteID` are
    /// `nil`, handled inside `DashboardView`). Google Calendar,
    /// Intervals.icu, and the `.ics` feed are independent of Strava, so
    /// they work identically either way.
    @ViewBuilder
    private func mainTabView(
        activitySource: ActivitySource,
        activityProvider: ActivityProvider,
        prDetailClient: StravaAPIClient?,
        longestEffortsClient: StravaAPIClient?,
        athleteID: Int?,
        onDisconnectAppleHealth: (() -> Void)?
    ) -> some View {
        let dashboardViewModel = DashboardViewModel(activityProvider: activityProvider, prDetailClient: prDetailClient)
        let googleCalendarAPIClient = GoogleCalendarAPIClient(authManager: googleAuthManager)
        let calendarViewModel = GoogleCalendarViewModel(authManager: googleAuthManager, apiClient: googleCalendarAPIClient)

        TabView {
            DashboardView(
                viewModel: dashboardViewModel,
                healthViewModel: healthViewModel,
                calendarViewModel: calendarViewModel,
                intervalsICUViewModel: intervalsICUViewModel,
                goalsStore: goalsStore,
                pushManager: pushManager,
                apiClient: longestEffortsClient,
                activitySource: activitySource,
                onDisconnectAppleHealth: onDisconnectAppleHealth,
                athleteID: athleteID
            )
            .tabItem { Label("Stats", systemImage: "chart.bar") }
            StepsView(viewModel: stepsViewModel)
                .tabItem { Label("Steps", systemImage: "figure.walk") }
            MealsView(viewModel: mealsViewModel)
                .tabItem { Label("Meals", systemImage: "fork.knife") }
            CalendarView(
                viewModel: CalendarViewModel(activityProvider: activityProvider),
                scheduledWorkoutStore: scheduledWorkoutStore,
                calendarFeedClient: calendarFeedClient
            )
            .tabItem { Label("Calendar", systemImage: "calendar") }
            CoachChatView(
                viewModel: CoachChatViewModel(
                    dashboardViewModel: dashboardViewModel,
                    scheduledWorkoutStore: scheduledWorkoutStore,
                    healthViewModel: healthViewModel,
                    stepsViewModel: stepsViewModel,
                    calendarViewModel: calendarViewModel,
                    intervalsICUViewModel: intervalsICUViewModel,
                    preferencesStore: preferencesStore,
                    goalsStore: goalsStore
                )
            )
            .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
        }
        .onAppear {
            scheduledWorkoutStore.googleCalendarClient = googleCalendarAPIClient
            scheduledWorkoutStore.intervalsICUClient = intervalsICUViewModel.client
            scheduledWorkoutStore.calendarFeedClient = calendarFeedClient
            pushManager.setAthleteID(athleteID)
        }
        .onChange(of: intervalsICUViewModel.isConnected) { _ in
            scheduledWorkoutStore.intervalsICUClient = intervalsICUViewModel.client
        }
        .onChange(of: authManager.session?.athleteID) { newAthleteID in
            pushManager.setAthleteID(newAthleteID)
        }
    }
}
