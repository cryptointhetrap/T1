import Charts
import SwiftUI

struct WeeklyVolumeChart: View {
    let weeks: [WeekSummary]

    var body: some View {
        Chart(weeks) { week in
            BarMark(
                x: .value("Week", week.weekStart, unit: .weekOfYear),
                y: .value("Distance (mi)", Units.miles(fromMeters: week.distanceMeters))
            )
            .foregroundStyle(Color.accentColor)
            .cornerRadius(4)
        }
        .frame(height: 180)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }
}
