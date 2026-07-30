import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authManager: StravaAuthManager

    var body: some View {
        Group {
            if authManager.isConnected {
                DashboardView(viewModel: DashboardViewModel(apiClient: StravaAPIClient(authManager: authManager)))
            } else {
                ConnectStravaView()
            }
        }
    }
}
