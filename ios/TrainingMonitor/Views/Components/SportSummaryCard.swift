import SwiftUI

/// Shows mileage and elevation gain for one sport (run or bike) across the
/// current calendar week, month, and year.
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
                Text(Units.formattedMiles(totals.distanceMeters))
                    .font(.subheadline.bold())
                Text("\(Units.formattedFeet(totals.elevationGainMeters)) gain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
