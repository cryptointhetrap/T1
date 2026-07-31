import SwiftUI

/// Shown once per app launch, on top of everything else — see `RootView`.
/// Opens on the logo alone for 2s, then crossfades into the quote, which
/// auto-dismisses after a few more seconds — or tap at any point to skip.
struct MotivationSplashView: View {
    @ObservedObject var viewModel: MotivationViewModel
    let onDismiss: () -> Void
    @State private var showLogo = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showLogo {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .transition(.opacity)
            } else {
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
                .transition(.opacity)
            }
        }
        .animation(.easeIn(duration: 0.4), value: showLogo)
        .animation(.easeIn(duration: 0.4), value: viewModel.quote)
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .task { await viewModel.loadIfNeeded() }
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showLogo = false
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            onDismiss()
        }
    }
}
