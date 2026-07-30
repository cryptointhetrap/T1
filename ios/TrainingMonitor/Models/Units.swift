import Foundation

/// The app displays imperial units (miles/feet); Strava's API returns
/// everything in meters, so conversions happen at the display edge and raw
/// SI values stay the source of truth in models/view models.
enum Units {
    static func miles(fromMeters meters: Double) -> Double { meters / 1609.344 }
    static func feet(fromMeters meters: Double) -> Double { meters * 3.28084 }

    static func formattedMiles(_ meters: Double) -> String {
        String(format: "%.1f mi", miles(fromMeters: meters))
    }

    static func formattedFeet(_ meters: Double) -> String {
        String(format: "%.0f ft", feet(fromMeters: meters))
    }
}
