import SwiftUI

struct PerformanceScorecardView: View {
    let snapshot: EliteStatsSnapshot
    @State private var reveal = false

    private var scoreProgress: Double {
        Double(snapshot.rating.score) / 100
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(JPColors.graphite.opacity(0.9), lineWidth: 14)

                        Circle()
                            .trim(from: 0, to: reveal ? scoreProgress : 0)
                            .stroke(
                                AngularGradient(
                                    colors: [JPColors.accent, JPColors.warning, tint, JPColors.accent],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .shadow(color: tint.opacity(0.28), radius: 18, x: 0, y: 8)

                        VStack(spacing: 2) {
                            Text("\(snapshot.rating.score)")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(tint)
                                .contentTransition(.numericText())
                            Text("Score")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(JPColors.secondaryText)
                        }
                    }
                    .frame(width: 128, height: 128)
                    .accessibilityLabel("Elite trader score \(snapshot.rating.score) out of 100")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Performance Scorecard")
                            .font(.caption.weight(.black))
                            .foregroundStyle(JPColors.secondaryText)
                            .textCase(.uppercase)

                        Text(snapshot.rating.grade)
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                            .lineLimit(1)

                        Text(snapshot.rating.label)
                            .font(.title3.weight(.black))
                            .foregroundStyle(JPColors.primaryText)

                        Text("Built from profitability, drawdown control, consistency, psychology, journal quality, and risk discipline.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    scorePill("Risk", "\(snapshot.summary.riskConsistency)%", JPColors.warning)
                    scorePill("Journal", "\(snapshot.summary.journalCompletion)%", JPColors.purple)
                    scorePill("Plan", "\(snapshot.summary.checklistCompletion)%", JPColors.blue)
                    scorePill("Visuals", "\(snapshot.summary.screenshotCompletion)%", JPColors.accent)
                }
            }
        }
        .onAppear {
            withAnimation(JPDesign.slowSpring.delay(0.08)) {
                reveal = true
            }
        }
    }

    private var tint: Color {
        switch snapshot.rating.score {
        case 85...:
            return JPColors.profit
        case 70..<85:
            return JPColors.warning
        case 55..<70:
            return JPColors.blue
        default:
            return JPColors.loss
        }
    }

    private func scorePill(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .shadow(color: color.opacity(0.35), radius: 8, x: 0, y: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(JPColors.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}
