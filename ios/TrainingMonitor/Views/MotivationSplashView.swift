import SwiftUI

/// Shown once per app launch, on top of everything else — see `RootView`.
/// Auto-dismisses after a few seconds, or immediately on tap.
struct MotivationSplashView: View {
    @ObservedObject var viewModel: MotivationViewModel
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "flame.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.mdGold)

                if let quote = viewModel.quote {
                    Text(quote)
                        .font(.system(.title, design: .serif).bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                } else {
                    ProgressView()
                        .tint(.white)
                }

                Spacer()

                Text("Tap to continue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
            .animation(.easeIn(duration: 0.4), value: viewModel.quote)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .task { await viewModel.loadIfNeeded() }
        .task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            onDismiss()
        }
    }
}
