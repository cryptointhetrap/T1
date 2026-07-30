import SwiftUI

@main
struct TrainingMonitorApp: App {
    @StateObject private var authManager = StravaAuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .preferredColorScheme(.dark)
        }
    }
}
