import Charts
import SwiftUI

struct DailyStepsChart: View {
    let days: [DailyStepPoint]

    var body: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Steps", day.steps)
            )
            .foregroundStyle(Color.accentColor)
            .cornerRadius(3)
        }
        .frame(height: 160)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}
