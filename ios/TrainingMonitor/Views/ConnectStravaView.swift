import SwiftUI

struct ConnectStravaView: View {
    @EnvironmentObject private var authManager: StravaAuthManager

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
                Text("Connect your Strava account to see your training load and trends.")
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

            Spacer()
            Spacer()
        }
    }
}
