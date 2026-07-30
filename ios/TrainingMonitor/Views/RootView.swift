import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: StravaAuthManager

    var body: some View {
        Group {
            if authManager.isConnected {
                let apiClient = StravaAPIClient(authManager: authManager)
                let dashboardViewModel = DashboardViewModel(apiClient: apiClient)
                TabView {
                    DashboardView(viewModel: dashboardViewModel)
                        .tabItem { Label("Training", systemImage: "chart.bar") }
                    CalendarView(viewModel: CalendarViewModel(apiClient: apiClient))
                        .tabItem { Label("Calendar", systemImage: "calendar") }
                    CoachChatView(viewModel: CoachChatViewModel(dashboardViewModel: dashboardViewModel))
                        .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right") }
                }
            } else {
                ConnectStravaView()
            }
        }
    }
}
