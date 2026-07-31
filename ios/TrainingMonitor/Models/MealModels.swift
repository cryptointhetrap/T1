import Foundation

enum MealSlot: String, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    var id: String { rawValue }
}

struct MealOption: Codable, Identifiable, Equatable {
    let name: String
    let description: String
    let carbLevel: CarbLevel

    var id: String { name }

    enum CarbLevel: String, Codable {
        case low
        case high
    }
}

struct DailyMeals: Codable {
    let breakfast: [MealOption]
    let lunch: [MealOption]
    let dinner: [MealOption]

    subscript(slot: MealSlot) -> [MealOption] {
        switch slot {
        case .breakfast: return breakfast
        case .lunch: return lunch
        case .dinner: return dinner
        }
    }
}

extension MealOption {
    /// A recipe search, not a specific recipe URL — Claude can't guarantee a
    /// real working page for an arbitrary dish name, so this always resolves
    /// to a valid results page instead of risking a broken/hallucinated link.
    var recipeSearchURL: URL {
        Self.googleSearchURL(query: "how to make \(name) recipe")
    }

    /// Likewise a search rather than a guessed DoorDash deep link — surfaces
    /// delivery options (DoorDash and others) for this dish without betting
    /// on an undocumented, possibly-unstable URL scheme.
    var deliverySearchURL: URL {
        Self.googleSearchURL(query: "order \(name) doordash delivery")
    }

    private static func googleSearchURL(query: String) -> URL {
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url!
    }
}
