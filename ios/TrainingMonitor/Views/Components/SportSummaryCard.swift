import SwiftUI

/// Shows weekly/monthly/yearly totals for one sport. Run, Bike, and Swim
/// show mileage and elevation gain; Weight Training shows duration and
/// session count instead, since Strava never reports a distance for it —
/// see `SportCategory.tracksDistance`.
struct SportSummaryCard: View {
    let category: SportCategory
    let totals: SportTotals

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(category.rawValue, systemImage: category.systemImage)
                .font(.headline)

            row(label: "This week", totals: totals.weekly)
            Divider()
            row(label: "This month", totals: totals.monthly)
            Divider()
            row(label: "This year", totals: totals.yearly)
            Divider()
            row(label: "Avg/week (year)", totals: totals.weeklyAverageForYear)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func row(label: String, totals: PeriodTotals) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if category.tracksDistance {
                    Text(Units.formattedMiles(totals.distanceMeters))
                        .font(.subheadline.bold())
                    Text("\(Units.formattedFeet(totals.elevationGainMeters)) gain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(format: "%.1f h", totals.movingTimeHours))
                        .font(.subheadline.bold())
                    Text("\(totals.activityCount) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
