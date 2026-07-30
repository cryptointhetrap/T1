import Charts
import SwiftUI

struct TrainingLoadChart: View {
    let points: [DailyLoadPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Acute (7d)", point.acuteLoad)
            )
            .foregroundStyle(.orange)
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Date", point.date),
                y: .value("Chronic (28d)", point.chronicLoad)
            )
            .foregroundStyle(.secondary)
            .interpolationMethod(.catmullRom)
        }
        .chartForegroundStyleScale([
            "Acute (7d)": Color.orange,
            "Chronic (28d)": Color.secondary,
        ])
        .chartLegend(position: .bottom)
        .frame(height: 180)
    }
}
