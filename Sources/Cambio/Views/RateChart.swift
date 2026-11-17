import CambioCore
import Charts
import SwiftUI

/// The 30-day sparkline: a soft gradient area under a smooth line, no axes.
struct RateChart: View {
    let points: [DailyPoint]

    var body: some View {
        let values = points.map(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let padding = max((high - low) * 0.18, high * 0.0005)

        Chart(points) { point in
            AreaMark(
                x: .value("Day", point.date),
                yStart: .value("Floor", low - padding),
                yEnd: .value("Rate", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(x: .value("Day", point.date), y: .value("Rate", point.value))
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: (low - padding)...(high + padding))
        .frame(height: 58)
        .accessibilityLabel(Text("30 days"))
    }
}
