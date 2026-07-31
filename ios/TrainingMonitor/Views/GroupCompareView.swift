import SwiftUI

/// A separate page (pushed from the Stats tab) for comparing this
/// month's relative effort, hours, and mileage against specific people —
/// small invite-code groups, not a public Strava leaderboard. See
/// `GroupCompareViewModel`'s and `backend/src/routes/groups.ts`'s doc
/// comments for why: Strava's API has no athlete search and no way to
/// read a stranger's data, so this only works among people who separately
/// connect their own Strava account to this app and share a code.
struct GroupCompareView: View {
    /// Owned by `DashboardView` (not created here) so the background
    /// stats-push triggered by dashboard refreshes and the state shown on
    /// this page are the same instance, not two independently-fetching
    /// copies.
    @ObservedObject var viewModel: GroupCompareViewModel
    @State private var sortMetric: SortMetric = .effort

    enum SortMetric: String, CaseIterable, Identifiable {
        case effort = "Effort"
        case hours = "Hours"
        case miles = "Miles"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if viewModel.joinedCode != nil {
                joinedContent
            } else {
                setupContent
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
        .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var joinedContent: some View {
        if let group = viewModel.group {
            List {
                Section {
                    Picker("Sort by", selection: $sortMetric) {
                        ForEach(SortMetric.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("This month") {
                    ForEach(Array(sortedMembers(group).enumerated()), id: \.element.id) { index, member in
                        GroupMemberRow(rank: index + 1, member: member, metric: sortMetric, isMe: member.athleteID == viewModel.athleteID)
                    }
                }

                Section {
                    HStack {
                        Text("Group code")
                        Spacer()
                        Text(group.code)
                            .font(.body.monospaced().bold())
                    }
                    ShareLink(item: "Join my TrainingMonitor group — enter code \(group.code) on the Compare page.") {
                        Label("Share invite", systemImage: "square.and.arrow.up")
                    }
                    Button("Leave group", role: .destructive) {
                        Task { await viewModel.leaveGroup() }
                    }
                }
            }
        } else if viewModel.isLoading {
            ProgressView()
        } else {
            ContentUnavailableFallback()
        }
    }

    private var setupContent: some View {
        Form {
            Section {
                TextField("Your name", text: $viewModel.displayName)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Display name")
            } footer: {
                Text("Shown to whoever you compare with — not your Strava name, pick whatever you want.")
            }

            Section {
                Button {
                    Task { await viewModel.createGroup() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Create a new group")
                    }
                }
                .disabled(viewModel.isLoading || viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            } footer: {
                Text("Gets you a 6-character code to share with friends so they can join and compare with you.")
            }

            Section {
                TextField("Group code", text: $viewModel.codeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button {
                    Task { await viewModel.joinGroup() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Join group")
                    }
                }
                .disabled(
                    viewModel.isLoading ||
                    viewModel.codeInput.trimmingCharacters(in: .whitespaces).isEmpty ||
                    viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty
                )
            } header: {
                Text("Or join one")
            }
        }
    }

    private func sortedMembers(_ group: TrainingGroup) -> [GroupMember] {
        switch sortMetric {
        case .effort: return group.memberList.sorted { $0.relativeEffort > $1.relativeEffort }
        case .hours: return group.memberList.sorted { $0.hours > $1.hours }
        case .miles: return group.memberList.sorted { $0.miles > $1.miles }
        }
    }
}

private struct GroupMemberRow: View {
    let rank: Int
    let member: GroupMember
    let metric: GroupCompareView.SortMetric
    let isMe: Bool

    var body: some View {
        HStack {
            Text("\(rank)")
                .font(.headline)
                .foregroundStyle(rank == 1 ? Color.ghGreen : Color.secondary)
                .frame(width: 24, alignment: .leading)
            Text(member.displayName + (isMe ? " (you)" : ""))
                .font(.subheadline.bold())
            Spacer()
            Text(valueText)
                .font(.subheadline.bold())
        }
        .padding(.vertical, 4)
    }

    private var valueText: String {
        switch metric {
        case .effort: return String(format: "%.0f", member.relativeEffort)
        case .hours: return String(format: "%.1f h", member.hours)
        case .miles: return String(format: "%.1f mi", member.miles)
        }
    }
}

/// Shown only if a code is saved locally but the fetch hasn't returned
/// anything yet and isn't loading — e.g. the very first render before
/// `.task` fires. Deliberately minimal since it's a transient state.
private struct ContentUnavailableFallback: View {
    var body: some View {
        Text("Loading…")
            .foregroundStyle(.secondary)
    }
}
