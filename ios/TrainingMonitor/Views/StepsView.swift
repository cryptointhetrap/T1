import SwiftUI

struct StepsView: View {
    @ObservedObject var viewModel: StepsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if viewModel.isAuthorized {
                        VStack(spacing: 0) {
                            row(label: "This week", totals: viewModel.weekly)
                            Divider()
                            row(label: "This month", totals: viewModel.monthly)
                            Divider()
                            row(label: "This year", totals: viewModel.yearly)
                            Divider()
                            row(label: "Avg/day (rolling year)", totals: viewModel.dailyAverageRollingYear)
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                        if !viewModel.recentDailySteps.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last 30 days")
                                    .font(.headline)
                                DailyStepsChart(days: viewModel.recentDailySteps)
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Text("Connect Apple Health to see your steps and walking/running mileage.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button {
                                Task { await viewModel.requestAccess() }
                            } label: {
                                Label("Connect Apple Health", systemImage: "figure.walk")
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding()
            }
            .navigationTitle("Steps")
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.refresh() }
            .overlay {
                if viewModel.isLoading && viewModel.weekly == nil {
                    ProgressView()
                }
            }
            .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func row(label: String, totals: StepPeriodTotals?) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(totals.map { "\($0.steps.formatted()) steps" } ?? "—")
                    .font(.subheadline.bold())
                Text(totals.map { Units.formattedMiles($0.distanceMeters) } ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
