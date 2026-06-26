import Combine
import Foundation
import SwiftUI

struct AnalyticsMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color
}

struct AnalyticsChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let value: Double
}

struct SessionPerformance: Identifiable {
    let id = UUID()
    let session: Trade.Session
    let trades: Int
    let winRate: Double
    let averageRiskReward: Double
    let netProfit: Double
    let isStrongest: Bool
}

struct StrategyPerformance: Identifiable {
    let id = UUID()
    let strategy: Trade.Strategy
    let trades: Int
    let winRate: Double
    let netProfit: Double
    let averageRiskReward: Double
}

struct MistakePerformance: Identifiable {
    let id = UUID()
    let tag: Trade.MistakeTag
    let count: Int
    let percentage: Double
    let profitImpact: Double
}

struct PerformanceScore {
    let value: Int
    let rating: String
}

@MainActor
final class AnalyticsViewModel: ObservableObject {
    private let calendar = Calendar.current

    func performanceScore(for trades: [Trade]) -> PerformanceScore {
        guard !trades.isEmpty else {
            return PerformanceScore(value: 0, rating: "Poor")
        }

        let winRateScore = min(winRate(for: trades), 100) * 0.28
        let profitFactorValue = profitFactor(for: trades)
        let profitFactorScore = min(profitFactorValue.isInfinite ? 100 : profitFactorValue * 35, 100) * 0.24
        let rrScore = min(averageRiskReward(for: trades) / 2.5, 1) * 22
        let expectancyScore = expectancy(for: trades) > 0 ? 16.0 : 4.0
        let consistencyScore = currentStreakCount(for: trades) >= 3 ? 10.0 : 5.0
        let score = Int(min(max(winRateScore + profitFactorScore + rrScore + expectancyScore + consistencyScore, 0), 100).rounded())

        return PerformanceScore(value: score, rating: rating(for: score))
    }

    func metrics(for trades: [Trade]) -> [AnalyticsMetric] {
        [
            AnalyticsMetric(title: "Net Profit", value: currency(netProfit(for: trades)), detail: "All saved trades", icon: "chart.line.uptrend.xyaxis", tint: tint(for: netProfit(for: trades))),
            AnalyticsMetric(title: "Win Rate", value: percentage(winRate(for: trades)), detail: "Wins vs losses", icon: "target", tint: JPColors.warning),
            AnalyticsMetric(title: "Profit Factor", value: profitFactorText(for: trades), detail: "Gross wins / losses", icon: "divide.circle", tint: JPColors.accent),
            AnalyticsMetric(title: "Avg Risk:Reward", value: riskReward(averageRiskReward(for: trades)), detail: "Planned R:R", icon: "scale.3d", tint: JPColors.blue),
            AnalyticsMetric(title: "Expectancy", value: currency(expectancy(for: trades)), detail: "Average trade result", icon: "function", tint: tint(for: expectancy(for: trades))),
            AnalyticsMetric(title: "Current Streak", value: currentStreak(for: trades), detail: "Latest resolved run", icon: "flame.fill", tint: JPColors.warning),
            AnalyticsMetric(title: "Largest Win", value: currency(largestWin(for: trades)), detail: "Best result", icon: "arrow.up.right", tint: JPColors.profit),
            AnalyticsMetric(title: "Largest Loss", value: currency(largestLoss(for: trades)), detail: "Worst result", icon: "arrow.down.right", tint: JPColors.loss),
            AnalyticsMetric(title: "Average Win", value: currency(averageWin(for: trades)), detail: "Winning trades", icon: "plus.forwardslash.minus", tint: JPColors.profit),
            AnalyticsMetric(title: "Average Loss", value: currency(averageLoss(for: trades)), detail: "Losing trades", icon: "minus.forwardslash.plus", tint: JPColors.loss),
            AnalyticsMetric(title: "Total Trades", value: "\(trades.count)", detail: "Saved entries", icon: "number", tint: JPColors.purple),
            AnalyticsMetric(title: "Avg Duration", value: averageDuration(for: trades), detail: "Open to close", icon: "timer", tint: JPColors.secondaryText)
        ]
    }

    func equityCurve(for trades: [Trade]) -> [AnalyticsChartPoint] {
        var runningTotal = 0.0
        return trades.sorted { $0.date < $1.date }.map { trade in
            runningTotal += trade.profitLoss
            return AnalyticsChartPoint(label: trade.pair, date: trade.date, value: runningTotal)
        }
    }

    func monthlyProfit(for trades: [Trade]) -> [AnalyticsChartPoint] {
        groupedProfit(for: trades, components: [.year, .month], format: "MMM")
    }

    func weeklyProfit(for trades: [Trade]) -> [AnalyticsChartPoint] {
        groupedProfit(for: trades, components: [.yearForWeekOfYear, .weekOfYear], format: "'W'w")
    }

    func winRateTrend(for trades: [Trade]) -> [AnalyticsChartPoint] {
        let grouped = Dictionary(grouping: trades) { trade in
            calendar.date(from: calendar.dateComponents([.year, .month], from: trade.date)) ?? trade.date
        }

        return grouped.map { date, groupedTrades in
            AnalyticsChartPoint(label: monthFormatter.string(from: date), date: date, value: winRate(for: groupedTrades))
        }
        .sorted { $0.date < $1.date }
    }

    func sessionAnalysis(for trades: [Trade]) -> [SessionPerformance] {
        let grouped = Dictionary(grouping: trades, by: \.session)
        let raw = Trade.Session.allCases.map { session in
            let sessionTrades = grouped[session] ?? []
            return SessionPerformance(
                session: session,
                trades: sessionTrades.count,
                winRate: winRate(for: sessionTrades),
                averageRiskReward: averageRiskReward(for: sessionTrades),
                netProfit: netProfit(for: sessionTrades),
                isStrongest: false
            )
        }
        let strongest = raw.max { lhs, rhs in
            if lhs.netProfit == rhs.netProfit {
                return lhs.winRate < rhs.winRate
            }

            return lhs.netProfit < rhs.netProfit
        }?.session

        return raw.map { item in
            SessionPerformance(
                session: item.session,
                trades: item.trades,
                winRate: item.winRate,
                averageRiskReward: item.averageRiskReward,
                netProfit: item.netProfit,
                isStrongest: item.session == strongest && item.trades > 0
            )
        }
    }

    func strategyAnalysis(for trades: [Trade]) -> [StrategyPerformance] {
        Dictionary(grouping: trades, by: \.strategy)
            .map { strategy, strategyTrades in
                StrategyPerformance(
                    strategy: strategy,
                    trades: strategyTrades.count,
                    winRate: winRate(for: strategyTrades),
                    netProfit: netProfit(for: strategyTrades),
                    averageRiskReward: averageRiskReward(for: strategyTrades)
                )
            }
            .sorted { lhs, rhs in
                if lhs.netProfit == rhs.netProfit {
                    return lhs.winRate > rhs.winRate
                }

                return lhs.netProfit > rhs.netProfit
            }
    }

    func mistakeAnalysis(for trades: [Trade]) -> [MistakePerformance] {
        let allTags = trades.flatMap(\.mistakeTags)
        guard !allTags.isEmpty else {
            return []
        }

        return Trade.MistakeTag.allCases.compactMap { tag in
            let taggedTrades = trades.filter { $0.mistakeTags.contains(tag) }
            guard !taggedTrades.isEmpty else {
                return nil
            }

            return MistakePerformance(
                tag: tag,
                count: taggedTrades.count,
                percentage: (Double(taggedTrades.count) / Double(allTags.count)) * 100,
                profitImpact: netProfit(for: taggedTrades)
            )
        }
        .sorted { $0.count > $1.count }
    }

    func insights(for trades: [Trade]) -> [String] {
        guard !trades.isEmpty else {
            return []
        }

        var insights: [String] = []
        if let strongestSession = sessionAnalysis(for: trades).first(where: \.isStrongest) {
            insights.append("\(strongestSession.session.rawValue) session is your strongest session.")
        }

        let averageRR = averageRiskReward(for: trades)
        insights.append(averageRR >= 1.5 ? "Your average RR is supporting quality trade selection." : "Your average RR has room to improve.")

        let largestLossValue = abs(largestLoss(for: trades))
        let averageWinValue = averageWin(for: trades)
        if averageWinValue > 0, largestLossValue <= averageWinValue {
            insights.append("Your largest loss is within acceptable range.")
        } else if largestLossValue > 0 {
            insights.append("Your largest loss is larger than your average win.")
        }

        let losingTrades = trades.filter { $0.profitLoss < 0 }
        let losingMistakes = mistakeAnalysis(for: losingTrades)
        if let topMistake = losingMistakes.first {
            insights.append("\(topMistake.tag.rawValue) appears most often in losing trades.")
        }

        if winRate(for: trades) >= 55 {
            insights.append("Your win rate shows a positive execution baseline.")
        }

        return Array(insights.prefix(5))
    }

    private func groupedProfit(for trades: [Trade], components: Set<Calendar.Component>, format: String) -> [AnalyticsChartPoint] {
        let grouped = Dictionary(grouping: trades) { trade in
            calendar.date(from: calendar.dateComponents(components, from: trade.date)) ?? trade.date
        }

        let formatter = DateFormatter()
        formatter.dateFormat = format

        return grouped.map { date, groupedTrades in
            AnalyticsChartPoint(label: formatter.string(from: date), date: date, value: netProfit(for: groupedTrades))
        }
        .sorted { $0.date < $1.date }
    }

    private func netProfit(for trades: [Trade]) -> Double {
        trades.reduce(0) { $0 + $1.profitLoss }
    }

    private func winRate(for trades: [Trade]) -> Double {
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }
        guard !resolved.isEmpty else { return 0 }

        return (Double(resolved.filter { $0.status == .win }.count) / Double(resolved.count)) * 100
    }

    private func profitFactor(for trades: [Trade]) -> Double {
        let grossProfit = trades.map(\.profitLoss).filter { $0 > 0 }.reduce(0, +)
        let grossLoss = abs(trades.map(\.profitLoss).filter { $0 < 0 }.reduce(0, +))

        if grossLoss == 0 {
            return grossProfit > 0 ? .infinity : 0
        }

        return grossProfit / grossLoss
    }

    private func profitFactorText(for trades: [Trade]) -> String {
        let value = profitFactor(for: trades)
        return value.isInfinite ? "∞" : String(format: "%.2f", value)
    }

    private func averageRiskReward(for trades: [Trade]) -> Double {
        let values = trades.map(\.riskReward).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }

        return values.reduce(0, +) / Double(values.count)
    }

    private func expectancy(for trades: [Trade]) -> Double {
        guard !trades.isEmpty else { return 0 }
        return netProfit(for: trades) / Double(trades.count)
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
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }.sorted { $0.date > $1.date }
        guard let latest = resolved.first?.status else { return "0" }
        let count = resolved.prefix { $0.status == latest }.count
        return "\(count)\(latest == .win ? "W" : "L")"
    }

    private func currentStreakCount(for trades: [Trade]) -> Int {
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }.sorted { $0.date > $1.date }
        guard let latest = resolved.first?.status else { return 0 }
        return resolved.prefix { $0.status == latest }.count
    }

    private func averageDuration(for trades: [Trade]) -> String {
        let durations = trades.compactMap { trade -> TimeInterval? in
            guard let open = trade.tradeOpenTime, let close = trade.tradeCloseTime, close > open else {
                return nil
            }

            return close.timeIntervalSince(open)
        }

        guard !durations.isEmpty else {
            return "--"
        }

        let average = durations.reduce(0, +) / Double(durations.count)
        let hours = Int(average) / 3600
        let minutes = (Int(average) % 3600) / 60

        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func rating(for score: Int) -> String {
        switch score {
        case 85...100:
            return "Elite"
        case 70..<85:
            return "Great"
        case 55..<70:
            return "Good"
        case 35..<55:
            return "Fair"
        default:
            return "Poor"
        }
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func percentage(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func riskReward(_ value: Double) -> String {
        value > 0 ? "1:\(String(format: "%.2f", value))" : "--"
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

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }
}
