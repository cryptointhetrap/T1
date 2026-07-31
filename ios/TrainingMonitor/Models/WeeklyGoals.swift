import Foundation

/// Weekly distance/time/elevation targets the athlete sets themselves, each
/// independently optional — set only the ones you want tracked. Stored
/// already in the app's display units (miles/hours/feet), same as
/// everywhere else in the UI, so no conversion is needed to show or edit
/// them.
struct WeeklyGoals: Codable, Equatable {
    var distanceMiles: Double?
    var timeHours: Double?
    var elevationFeet: Double?

    var isEmpty: Bool {
        distanceMiles == nil && timeHours == nil && elevationFeet == nil
    }
}
