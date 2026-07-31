import SwiftUI

/// Lets the athlete paste in a self-serve intervals.icu athlete ID + API
/// key (from intervals.icu → Settings → Developer) — no OAuth screen,
/// since intervals.icu doesn't offer one for third-party apps.
struct IntervalsICUSettingsView: View {
    @ObservedObject var viewModel: IntervalsICUViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var athleteID = ""
    @State private var apiKey = ""
    @State private var isConnecting = false

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isConnected {
                    Section("Status") {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.ghGreen)
                        if let wellness = viewModel.latestWellness, let ctl = wellness.ctl, let atl = wellness.atl {
                            LabeledContent("Fitness (CTL)", value: String(format: "%.0f", ctl))
                            LabeledContent("Fatigue (ATL)", value: String(format: "%.0f", atl))
                            LabeledContent("Form", value: String(format: "%.0f", ctl - atl))
                        }
                        Button("Disconnect", role: .destructive) {
                            viewModel.disconnect()
                        }
                    }
                } else {
                    Section {
                        TextField("Athlete ID (e.g. i123456)", text: $athleteID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("API key", text: $apiKey)
                    } header: {
                        Text("Connect intervals.icu")
                    } footer: {
                        Text("Find both at intervals.icu → Settings → Developer. This pulls their computed fitness/fatigue (CTL/ATL) numbers into your coach's context and pushes scheduled workouts there as planned events.")
                    }

                    Section {
                        Link("Open intervals.icu settings", destination: URL(string: "https://intervals.icu/settings")!)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(Color.red)
                        }
                    }

                    Section {
                        Button {
                            Task {
                                isConnecting = true
                                let success = await viewModel.connect(athleteID: athleteID, apiKey: apiKey)
                                isConnecting = false
                                if success { dismiss() }
                            }
                        } label: {
                            if isConnecting {
                                ProgressView()
                            } else {
                                Text("Connect")
                            }
                        }
                        .disabled(isConnecting || athleteID.trimmingCharacters(in: .whitespaces).isEmpty || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Intervals.icu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
