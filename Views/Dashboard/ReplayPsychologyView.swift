import SwiftUI

struct ReplayPsychologyView: View {
    let metrics: [ReplayPsychologyMetric]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Psychology Replay", subtitle: "Mental game signals from the journal")

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(metrics) { metric in
                    GlassCard(padding: 14, cornerRadius: 22) {
                        HStack(spacing: 12) {
                            ring(metric)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(metric.title)
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(JPColors.primaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Image(systemName: metric.icon)
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(metric.tint)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private func ring(_ metric: ReplayPsychologyMetric) -> some View {
        ZStack {
            Circle()
                .stroke(JPColors.graphite, lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(metric.value) / 100)
                .stroke(metric.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: metric.tint.opacity(0.22), radius: 8, x: 0, y: 4)
            Text("\(metric.value)")
                .font(.caption.weight(.black))
                .foregroundStyle(JPColors.primaryText)
        }
        .frame(width: 58, height: 58)
        .animation(JPDesign.smoothSpring, value: metric.value)
    }
}
