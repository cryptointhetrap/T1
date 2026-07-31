import SwiftUI

/// Three concentric progress rings — distance, time, elevation — showing
/// the current calendar week's actual totals against the athlete's own
/// weekly targets (`GoalsStore`). A target left unset draws as an empty
/// track with no arc rather than being hidden, so the ring count stays
/// fixed. Reuses the app's two accent colors plus plain white rather than
/// introducing a third accent just for this.
struct WeeklyGoalRings: View {
    let goals: WeeklyGoals
    let week: WeekSummary?

    private var metrics: [RingMetric] {
        [
            RingMetric(
                title: "Distance",
                color: .ghGreen,
                actual: Units.miles(fromMeters: week?.distanceMeters ?? 0),
                target: goals.distanceMiles,
                unit: "mi"
            ),
            RingMetric(
                title: "Time",
                color: .ghSilver,
                actual: week?.movingTimeHours ?? 0,
                target: goals.timeHours,
                unit: "h"
            ),
            RingMetric(
                title: "Elevation",
                color: .white,
                actual: Units.feet(fromMeters: week?.elevationGainMeters ?? 0),
                target: goals.elevationFeet,
                unit: "ft"
            ),
        ]
    }

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    ring(for: metric, inset: CGFloat(index) * 20)
                }
            }
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(metrics) { metric in
                    legendRow(for: metric)
                }
            }
        }
    }

    private func ring(for metric: RingMetric, inset: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(metric.color.opacity(0.15), lineWidth: 11)
            if let target = metric.target, target > 0 {
                Circle()
                    .trim(from: 0, to: min(metric.actual / target, 1))
                    .stroke(metric.color, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(inset)
    }

    private func legendRow(for metric: RingMetric) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(metric.color)
                .frame(width: 8, height: 8)
            Text(metric.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if let target = metric.target, target > 0 {
                Text("\(formatted(metric.actual)) / \(formatted(target)) \(metric.unit)")
                    .font(.caption.monospacedDigit())
            } else {
                Text("No target")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: value >= 100 ? "%.0f" : "%.1f", value)
    }
}

private struct RingMetric: Identifiable {
    let title: String
    let color: Color
    let actual: Double
    let target: Double?
    let unit: String
    var id: String { title }
}
