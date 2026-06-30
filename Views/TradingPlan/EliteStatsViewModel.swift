import Combine
import Foundation

@MainActor
final class EliteStatsViewModel: ObservableObject {
    private let engine = EliteStatsEngine()

    func snapshot(for trades: [Trade]) -> EliteStatsSnapshot {
        engine.snapshot(for: trades)
    }

    func riskProjection(summary: EliteStatsSummary, riskPerTrade: Double) -> EliteRiskProjection {
        engine.riskProjection(summary: summary, riskPerTrade: riskPerTrade)
    }
}
