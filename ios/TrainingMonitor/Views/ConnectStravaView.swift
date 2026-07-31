import SwiftUI

struct ConnectStravaView: View {
    @EnvironmentObject private var authManager: StravaAuthManager
    @ObservedObject var healthViewModel: HealthViewModel
    @ObservedObject var activitySourceStore: ActivitySourceStore
    @State private var isConnectingAppleHealth = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 8) {
                Text("Go Harder Ai Training")
                    .font(.title.bold())
                Text("Connect Strava, or use Apple Health Workouts instead, to see your training load and trends.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let error = authManager.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            if let error = healthViewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                authManager.connect()
            } label: {
                Label("Connect with Strava", systemImage: "link")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(Color.orange)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)

            Button {
                Task {
                    isConnectingAppleHealth = true
                    await healthViewModel.requestAccess()
                    isConnectingAppleHealth = false
                    if healthViewModel.isAuthorized {
                        activitySourceStore.source = .appleHealth
                    }
                }
            } label: {
                if isConnectingAppleHealth {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Label("Use Apple Health Workouts Instead", systemImage: "heart.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .disabled(isConnectingAppleHealth)
            .background(Color.ghGreen)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)

            Text("No Strava account? Track weekly volume, training load, and your calendar straight from workouts logged in the Health app — from your Apple Watch or iPhone. A few Strava-only features (all-time PRs, power data, Compare, Longest Efforts) won't be available this way.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}
