import Charts
import SwiftUI

/// Monthly aerobic-efficiency trend per sport — see `EfficiencyPoint`'s doc
/// comment for what the number means. The y-axis is intentionally hidden:
/// the raw m/s-per-bpm value isn't meaningful on its own, only its
/// direction over time is.
struct EfficiencyTrendChart: View {
    let trend: [SportCategory: [EfficiencyPoint]]

    var body: some View {
        Chart {
            ForEach(SportCategory.allCases) { category in
                if let points = trend[category] {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Month", point.monthStart, unit: .month),
                            y: .value(category.rawValue, point.efficiencyFactor)
                        )
                        .foregroundStyle(by: .value("Sport", category.rawValue))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
        }
        .chartForegroundStyleScale([
            SportCategory.run.rawValue: Color.ghGreen,
            SportCategory.ride.rawValue: Color.ghSilver,
        ])
        .chartLegend(position: .bottom)
        .chartYAxis(.hidden)
        .frame(height: 160)
    }
}
