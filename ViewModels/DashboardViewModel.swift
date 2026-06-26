import Combine
import SwiftUI

struct DashboardMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color
}

@MainActor
final class DashboardViewModel: ObservableObject {
    let greeting = "Good evening"
    let subtitle = "Stay patient. Let the best setups come to you."
    let quote: String

    init() {
        quote = Self.tradingQuotes.randomElement() ?? "Trade your plan."
    }

    private static let tradingQuotes = [
        "Protect capital first.",
        "The best trade is patience.",
        "Discipline compounds.",
        "Trade your plan.",
        "Risk small. Think long.",
        "Wait for your price.",
        "Process before profit.",
        "Cut losses without debate.",
        "Consistency beats intensity.",
        "Your edge needs patience.",
        "No setup, no trade.",
        "Let winners breathe.",
        "Journal the lesson.",
        "Clarity creates confidence.",
        "One good trade at a time.",
        "Respect your stop.",
        "Quality over frequency.",
        "Calm is an edge.",
        "Plan the trade. Trade the plan.",
        "Capital is opportunity."
    ]

    func metrics(for trades: TradeViewModel) -> [DashboardMetric] {
        [
            DashboardMetric(title: "Total Net P/L", value: currency(trades.totalNetProfitLoss), detail: "All saved trades", icon: "chart.line.uptrend.xyaxis", tint: tint(for: trades.totalNetProfitLoss)),
            DashboardMetric(title: "Today's P/L", value: currency(trades.dailyProfitLoss), detail: "Current day", icon: "sun.max.fill", tint: tint(for: trades.dailyProfitLoss)),
            DashboardMetric(title: "Weekly P/L", value: currency(trades.weeklyProfitLoss), detail: "Current week", icon: "calendar.badge.clock", tint: tint(for: trades.weeklyProfitLoss)),
            DashboardMetric(title: "Monthly P/L", value: currency(trades.monthlyProfitLoss), detail: "Current month", icon: "calendar", tint: tint(for: trades.monthlyProfitLoss)),
            DashboardMetric(title: "Win Rate", value: "\(Int(trades.winRate.rounded()))%", detail: "Wins vs losses", icon: "target", tint: JPColors.warning),
            DashboardMetric(title: "Total Trades", value: "\(trades.trades.count)", detail: "Saved journal entries", icon: "number", tint: JPColors.blue),
            DashboardMetric(title: "Avg Risk:Reward", value: riskReward(averageRiskReward(for: trades.trades)), detail: "Average planned R:R", icon: "scale.3d", tint: JPColors.accent),
            DashboardMetric(title: "Current Streak", value: currentStreak(for: trades.trades), detail: "Latest resolved run", icon: "flame.fill", tint: JPColors.warning),
            DashboardMetric(title: "Largest Win", value: currency(largestWin(for: trades.trades)), detail: "Best saved result", icon: "arrow.up.right", tint: JPColors.profit),
            DashboardMetric(title: "Largest Loss", value: currency(largestLoss(for: trades.trades)), detail: "Worst saved result", icon: "arrow.down.right", tint: JPColors.loss),
            DashboardMetric(title: "Average Win", value: currency(averageWin(for: trades.trades)), detail: "Winning trades", icon: "plus.forwardslash.minus", tint: JPColors.profit),
            DashboardMetric(title: "Average Loss", value: currency(averageLoss(for: trades.trades)), detail: "Losing trades", icon: "minus.forwardslash.plus", tint: JPColors.loss)
        ]
    }

    func equitySeries(for trades: [Trade]) -> [Double] {
        guard !trades.isEmpty else {
            return []
        }

        let orderedTrades = trades.sorted { $0.date < $1.date }
        var runningTotal = 0.0
        return orderedTrades.map { trade in
            runningTotal += trade.profitLoss
            return runningTotal
        }
    }

    func equityPoints(for trades: [Trade]) -> [CGFloat] {
        let cumulativeValues = equitySeries(for: trades)

        guard !cumulativeValues.isEmpty else {
            return []
        }

        guard let minValue = cumulativeValues.min(), let maxValue = cumulativeValues.max(), minValue != maxValue else {
            return Array(repeating: 0.5, count: max(cumulativeValues.count, 2))
        }

        return cumulativeValues.map { value in
            CGFloat((value - minValue) / (maxValue - minValue)) * 0.72 + 0.14
        }
    }

    func finalEquity(for trades: [Trade]) -> Double {
        equitySeries(for: trades).last ?? 0
    }

    private func averageRiskReward(for trades: [Trade]) -> Double {
        let values = trades.map(\.riskReward).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }

        return values.reduce(0, +) / Double(values.count)
    }

    private func largestWin(for trades: [Trade]) -> Double {
        trades.map(\.profitLoss).filter { $0 > 0 }.max() ?? 0
    }

    private func largestLoss(for trades: [Trade]) -> Double {
        trades.map(\.profitLoss).filter { $0 < 0 }.min() ?? 0
    }

    private func averageWin(for trades: [Trade]) -> Double {
        let wins = trades.map(\.profitLoss).filter { $0 > 0 }
        guard !wins.isEmpty else { return 0 }

        return wins.reduce(0, +) / Double(wins.count)
    }

    private func averageLoss(for trades: [Trade]) -> Double {
        let losses = trades.map(\.profitLoss).filter { $0 < 0 }
        guard !losses.isEmpty else { return 0 }

        return losses.reduce(0, +) / Double(losses.count)
    }

    private func currentStreak(for trades: [Trade]) -> String {
        let resolvedTrades = trades
            .filter { $0.status == .win || $0.status == .loss }
            .sorted { $0.date > $1.date }

        guard let latestStatus = resolvedTrades.first?.status else {
            return "0"
        }

        let count = resolvedTrades.prefix { $0.status == latestStatus }.count
        let label = latestStatus == .win ? "W" : "L"

        return "\(count)\(label)"
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func riskReward(_ value: Double) -> String {
        guard value > 0 else {
            return "--"
        }

        return "1:\(String(format: "%.2f", value))"
    }

    private func tint(for value: Double) -> Color {
        if value > 0 {
            return JPColors.profit
        }

        if value < 0 {
            return JPColors.loss
        }

        return JPColors.secondaryText
    }
}
