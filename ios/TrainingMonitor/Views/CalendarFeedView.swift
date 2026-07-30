import SwiftUI
import UIKit

/// Shows the athlete's `.ics` subscription URL so they can add it to
/// Apple Calendar, Google Calendar, or any other app that supports
/// URL-based calendar subscriptions — a read-only mirror of their
/// scheduled workouts that updates whenever the schedule changes.
struct CalendarFeedView: View {
    let feedClient: CalendarFeedClient
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(feedClient.subscriptionURL.absoluteString)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } header: {
                    Text("Subscription URL")
                } footer: {
                    Text("Add this as a URL-based calendar subscription in Apple Calendar, Google Calendar, or any app that supports .ics feeds. It updates automatically whenever your schedule changes.\n\nFor this link to work from other devices, backendBaseURL must point at a real deployed server, not localhost.")
                }

                Section {
                    Button {
                        UIPasteboard.general.string = feedClient.subscriptionURL.absoluteString
                        showCopiedConfirmation = true
                    } label: {
                        Label("Copy link", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: feedClient.subscriptionURL) {
                        Label("Share link", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Calendar Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Copied", isPresented: $showCopiedConfirmation) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}
