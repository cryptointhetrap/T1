import Combine
import Foundation

/// Backs the launch splash (`RootView`/`MotivationSplashView`) — not a
/// tab, just the one-line daily quote shown briefly while the app opens.
/// Cached so Claude is only called once per calendar day per device.
@MainActor
final class MotivationViewModel: ObservableObject {
    @Published private(set) var quote: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private static let cacheKey = "com.trainingmonitor.app.motivation-cache"

    private struct CachedQuote: Codable {
        let day: String
        let quote: String
    }

    init() {
        quote = Self.cachedQuoteForToday()
    }

    /// Uses today's cached line if there is one; otherwise fetches and
    /// caches a fresh one. Safe to call from multiple views — a second
    /// call while the first is still loading, or after a quote is
    /// already loaded, is a no-op.
    func loadIfNeeded() async {
        guard quote == nil, !isLoading else { return }
        await refresh()
    }

    /// Always fetches a new line, bypassing the daily cache.
    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await MotivationClient.fetchQuote()
            quote = fetched
            Self.cache(fetched)
        } catch {
            errorMessage = "Couldn't reach your coach for today's line: \(error.localizedDescription)"
        }
    }

    private static func cachedQuoteForToday() -> String? {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let cached = try? JSONDecoder().decode(CachedQuote.self, from: data),
            cached.day == dayFormatter.string(from: Date())
        else { return nil }
        return cached.quote
    }

    private static func cache(_ quote: String) {
        let cached = CachedQuote(day: dayFormatter.string(from: Date()), quote: quote)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
