import SwiftUI

struct InsightCard: View {
    let insight: Insight

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: insight.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(insight.category.rawValue)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(tint)
                            .textCase(.uppercase)

                        Text("\(Int((insight.confidence * 100).rounded()))% confidence")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(JPColors.mutedText)
                    }

                    Text(insight.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(insight.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .shadow(color: tint.opacity(0.10), radius: 18, x: 0, y: 10)
    }

    private var tint: Color {
        switch insight.category {
        case .performance:
            return JPColors.profit
        case .psychology:
            return JPColors.purple
        case .risk:
            return JPColors.warning
        case .discipline:
            return JPColors.accent
        case .execution:
            return JPColors.blue
        case .planning:
            return JPColors.warning
        case .replay:
            return JPColors.accent
        }
    }
}
