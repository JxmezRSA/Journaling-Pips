import SwiftUI

struct ReplayStatisticsView: View {
    let stats: [ReplayStudioStat]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Replay Statistics", subtitle: "Execution data behind the film")

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(stats) { stat in
                    GlassCard(padding: 14, cornerRadius: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: stat.icon)
                                .font(.caption.weight(.black))
                                .foregroundStyle(stat.tint)
                                .frame(width: 36, height: 36)
                                .background(stat.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            Text(stat.value)
                                .font(.system(size: 21, weight: .black, design: .rounded))
                                .foregroundStyle(stat.tint)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                            Text(stat.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.secondaryText)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                    }
                }
            }
        }
    }
}
