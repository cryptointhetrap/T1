import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: StravaAuthManager
    @StateObject private var scheduledWorkoutStore = ScheduledWorkoutStore()

    var body: some View {
        Group {
            if authManager.isConnected {
                let apiClient = StravaAPIClient(authManager: authManager)
                let dashboardViewModel = DashboardViewModel(apiClient: apiClient)
                TabView {
                    DashboardView(viewModel: dashboardViewModel)
                        .tabItem { Label("Training", systemImage: "chart.bar") }
                    CalendarView(viewModel: CalendarViewModel(apiClient: apiClient), scheduledWorkoutStore: scheduledWorkoutStore)
                        .tabItem { Label("Calendar", systemImage: "calendar") }
                    CoachChatView(viewModel: CoachChatViewModel(dashboardViewModel: dashboardViewModel, scheduledWorkoutStore: scheduledWorkoutStore))
                        .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
                }
            } else {
                ConnectStravaView()
            }
        }
    }
}
