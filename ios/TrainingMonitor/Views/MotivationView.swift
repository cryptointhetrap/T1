import SwiftUI

/// One Claude-written, Goggins/Kobe-vibe line, refreshed daily (or on
/// demand). Not literal quotes attributed to either of them — see
/// `backend/src/routes/chat.ts`'s `MOTIVATION_SYSTEM_PROMPT` for why.
struct MotivationView: View {
    @ObservedObject var viewModel: MotivationViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.ghGreen)

                    if let quote = viewModel.quote {
                        Text(quote)
                            .font(.system(.title2, design: .serif).bold())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }

                    Spacer()

                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Label("New line", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ghGreen)
                    .foregroundStyle(.black)
                    .disabled(viewModel.isLoading)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Motivation")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.loadIfNeeded() }
            .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
