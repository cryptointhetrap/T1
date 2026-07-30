import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: StravaAuthManager

    var body: some View {
        Group {
            if authManager.isConnected {
                let apiClient = StravaAPIClient(authManager: authManager)
                TabView {
                    DashboardView(viewModel: DashboardViewModel(apiClient: apiClient))
                        .tabItem { Label("Training", systemImage: "chart.bar") }
                    CalendarView(viewModel: CalendarViewModel(apiClient: apiClient))
                        .tabItem { Label("Calendar", systemImage: "calendar") }
                }
            } else {
                ConnectStravaView()
            }
        }
    }
}
