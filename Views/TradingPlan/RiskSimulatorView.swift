import SwiftUI

struct RiskSimulatorView: View {
    let summary: EliteStatsSummary
    @ObservedObject var viewModel: EliteStatsViewModel
    @State private var riskPerTrade = 1.0
    @State private var reveal = false

    private var projection: EliteRiskProjection {
        viewModel.riskProjection(summary: summary, riskPerTrade: riskPerTrade)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Risk Simulator", subtitle: "Model position risk using your current edge")

            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Risk Per Trade")
                                .font(.headline.weight(.black))
                                .foregroundStyle(JPColors.primaryText)
                            Text("Estimate returns and drawdown pressure from local stats.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)
                        }
                        Spacer()
                        Text(String(format: "%.1f%%", riskPerTrade))
                            .font(.title3.weight(.black))
                            .foregroundStyle(riskTint)
                            .contentTransition(.numericText())
                    }

                    Slider(value: $riskPerTrade, in: 0.25...5, step: 0.25) {
                        Text("Risk Per Trade")
                    }
                    .tint(riskTint)
                    .accessibilityLabel("Risk per trade")
                    .accessibilityValue(String(format: "%.1f percent", riskPerTrade))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        simulatorMetric("Monthly", signedPercent(projection.expectedMonthlyReturn), "Expected return", projection.expectedMonthlyReturn >= 0 ? JPColors.profit : JPColors.loss)
                        simulatorMetric("Yearly", signedPercent(projection.expectedYearlyReturn), "Projected compounding", projection.expectedYearlyReturn >= 0 ? JPColors.profit : JPColors.loss)
                        simulatorMetric("Max DD", percent(projection.estimatedMaxDrawdown), "Estimated drawdown", JPColors.loss)
                        simulatorMetric("Ruin Risk", percent(projection.riskOfRuin), "Stress estimate", projection.riskOfRuin > 20 ? JPColors.loss : JPColors.warning)
                        simulatorMetric("Break-even WR", percent(projection.requiredWinRate), "At current RR", JPColors.blue)
                        simulatorMetric("Required RR", String(format: "%.2fR", projection.requiredRR), "At current win rate", JPColors.accent)
                    }
                }
            }
        }
        .premiumEntrance(active: reveal)
        .onAppear {
            withAnimation(JPDesign.smoothSpring.delay(0.12)) {
                reveal = true
            }
        }
        .onChange(of: riskPerTrade) { _, _ in
            JPHaptics.selection()
        }
    }

    private var riskTint: Color {
        switch riskPerTrade {
        case ..<1:
            return JPColors.blue
        case 1...2:
            return JPColors.accent
        case 2...3:
            return JPColors.warning
        default:
            return JPColors.loss
        }
    }

    private func simulatorMetric(_ title: String, _ value: String, _ subtitle: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .contentTransition(.numericText())
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.primaryText)
            Text(subtitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(JPColors.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(JPDesign.quickSpring, value: riskPerTrade)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(subtitle)")
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func signedPercent(_ value: Double) -> String {
        "\(value >= 0 ? "+" : "-")\(Int(abs(value).rounded()))%"
    }
}
