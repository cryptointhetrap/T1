import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: StravaAuthManager
    @StateObject private var scheduledWorkoutStore = ScheduledWorkoutStore()
    @StateObject private var healthViewModel = HealthViewModel()
    @StateObject private var googleAuthManager = GoogleAuthManager()
    @StateObject private var intervalsICUViewModel = IntervalsICUViewModel()
    @StateObject private var preferencesStore = PreferencesStore()

    private let calendarFeedClient = CalendarFeedClient(token: FeedTokenStore.token())

    var body: some View {
        Group {
            if authManager.isConnected {
                let apiClient = StravaAPIClient(authManager: authManager)
                let dashboardViewModel = DashboardViewModel(apiClient: apiClient)
                let googleCalendarAPIClient = GoogleCalendarAPIClient(authManager: googleAuthManager)
                let calendarViewModel = GoogleCalendarViewModel(authManager: googleAuthManager, apiClient: googleCalendarAPIClient)

                TabView {
                    DashboardView(
                        viewModel: dashboardViewModel,
                        healthViewModel: healthViewModel,
                        calendarViewModel: calendarViewModel,
                        intervalsICUViewModel: intervalsICUViewModel,
                        apiClient: apiClient
                    )
                    .tabItem { Label("Training", systemImage: "chart.bar") }
                    CalendarView(
                        viewModel: CalendarViewModel(apiClient: apiClient),
                        scheduledWorkoutStore: scheduledWorkoutStore,
                        calendarFeedClient: calendarFeedClient
                    )
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                    CoachChatView(
                        viewModel: CoachChatViewModel(
                            dashboardViewModel: dashboardViewModel,
                            scheduledWorkoutStore: scheduledWorkoutStore,
                            healthViewModel: healthViewModel,
                            calendarViewModel: calendarViewModel,
                            intervalsICUViewModel: intervalsICUViewModel,
                            preferencesStore: preferencesStore
                        )
                    )
                    .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
                }
                .onAppear {
                    scheduledWorkoutStore.googleCalendarClient = googleCalendarAPIClient
                    scheduledWorkoutStore.intervalsICUClient = intervalsICUViewModel.client
                    scheduledWorkoutStore.calendarFeedClient = calendarFeedClient
                }
                .onChange(of: intervalsICUViewModel.isConnected) { _ in
                    scheduledWorkoutStore.intervalsICUClient = intervalsICUViewModel.client
                }
            } else {
                ConnectStravaView()
            }
        }
    }
}
