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

struct SnapshotMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let trend: String
    let icon: String
    let tint: Color
    let sparkline: [Double]
}

struct PairPerformance: Identifiable {
    let id = UUID()
    let pair: String
    let trades: Int
    let winRate: Double
    let netProfit: Double
    let averageRiskReward: Double
    let isBest: Bool
    let isWorst: Bool
}

struct TimeOfDayPerformance: Identifiable {
    let id = UUID()
    let label: String
    let trades: Int
    let winRate: Double
    let netProfit: Double
    let averageRiskReward: Double
}

struct WeekdayPerformance: Identifiable {
    let id = UUID()
    let weekday: Int
    let label: String
    let trades: Int
    let winRate: Double
    let netProfit: Double
    let averageRiskReward: Double
}

struct RiskSnapshot {
    let averageRisk: Double
    let averagePositionSize: Double
    let largestLoss: Double
    let largestWin: Double
    let averageHoldTime: String
    let score: Int
}

struct PsychologySignal: Identifiable {
    let id = UUID()
    let title: String
    let value: Int
    let subtitle: String
    let tint: Color
}

struct DisciplineAnalyticsSnapshot {
    let currentScore: Int
    let lastMonth: Int
    let highestEver: Int
    let lowestEver: Int
    let history: [AnalyticsChartPoint]
}

struct StreakAnalyticsSnapshot {
    let winning: Int
    let journal: Int
    let plan: Int
    let review: Int
    let replay: Int
}

struct GoalProgress: Identifiable {
    let id = UUID()
    let title: String
    let value: Double
    let subtitle: String
    let tint: Color
}

enum AnalyticsTimeFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"
    case allTime = "All Time"

    var id: String { rawValue }
}

enum PairPerformanceSort: String, CaseIterable, Identifiable {
    case profit = "Profit"
    case winRate = "Win Rate"
    case trades = "Trades"
    case averageRiskReward = "Avg RR"

    var id: String { rawValue }
}

struct AnalyticsOverviewCard: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
}

struct WinLossDistribution: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
    let tint: Color
}

struct AnalyticsSessionRow: Identifiable {
    let id = UUID()
    let title: String
    let trades: Int
    let winRate: Double
    let netProfit: Double
}

struct MonthlyPerformanceCard: Identifiable {
    let id = UUID()
    let month: String
    let date: Date
    let netProfit: Double
    let winRate: Double
    let trades: Int
}

struct AnalyticsBestWorstSummary {
    let bestPair: String
    let worstPair: String
    let bestWeekday: String
    let worstWeekday: String
    let bestSession: String
    let worstSession: String
    let largestWin: Double
    let largestLoss: Double
    let longestWinningStreak: Int
    let longestLosingStreak: Int
    let averageHoldTime: String
}

@MainActor
final class AnalyticsViewModel: ObservableObject {
    private let calendar = Calendar.current

    func filteredTrades(_ trades: [Trade], by filter: AnalyticsTimeFilter) -> [Trade] {
        let now = Date()

        return trades.filter { trade in
            switch filter {
            case .today:
                return calendar.isDateInToday(trade.date)
            case .thisWeek:
                return calendar.isDate(trade.date, equalTo: now, toGranularity: .weekOfYear)
            case .thisMonth:
                return calendar.isDate(trade.date, equalTo: now, toGranularity: .month)
            case .lastMonth:
                guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) else { return false }
                return calendar.isDate(trade.date, equalTo: lastMonth, toGranularity: .month)
            case .thisYear:
                return calendar.isDate(trade.date, equalTo: now, toGranularity: .year)
            case .allTime:
                return true
            }
        }
    }

    func overviewCards(for trades: [Trade]) -> [AnalyticsOverviewCard] {
        [
            AnalyticsOverviewCard(title: "Total Trades", value: "\(trades.count)", subtitle: "Filtered journal entries", icon: "number.circle.fill", tint: JPColors.purple),
            AnalyticsOverviewCard(title: "Win Rate", value: percentage(winRate(for: trades)), subtitle: "Wins vs losses", icon: "target", tint: JPColors.warning),
            AnalyticsOverviewCard(title: "Net Profit", value: currency(netProfit(for: trades)), subtitle: "Realized P/L", icon: "chart.line.uptrend.xyaxis.circle.fill", tint: tint(for: netProfit(for: trades))),
            AnalyticsOverviewCard(title: "Profit Factor", value: profitFactorText(for: trades), subtitle: "Gross wins / losses", icon: "divide.circle.fill", tint: JPColors.accent),
            AnalyticsOverviewCard(title: "Average RR", value: riskReward(averageRiskReward(for: trades)), subtitle: "Planned reward profile", icon: "scale.3d", tint: JPColors.blue)
        ]
    }

    func winLossDistribution(for trades: [Trade]) -> [WinLossDistribution] {
        [
            WinLossDistribution(title: "Wins", count: trades.filter { $0.status == .win }.count, tint: JPColors.profit),
            WinLossDistribution(title: "Losses", count: trades.filter { $0.status == .loss }.count, tint: JPColors.loss),
            WinLossDistribution(title: "Breakeven", count: trades.filter { $0.status == .breakeven }.count, tint: JPColors.warning)
        ]
    }

    func dashboardSessions(for trades: [Trade]) -> [AnalyticsSessionRow] {
        let known = Trade.Session.allCases.map { session in
            let sessionTrades = trades.filter { $0.session == session }
            return AnalyticsSessionRow(title: session.rawValue, trades: sessionTrades.count, winRate: winRate(for: sessionTrades), netProfit: netProfit(for: sessionTrades))
        }

        return known + [AnalyticsSessionRow(title: "Other", trades: 0, winRate: 0, netProfit: 0)]
    }

    func sortedPairPerformance(for trades: [Trade], sort: PairPerformanceSort) -> [PairPerformance] {
        let rows = pairPerformance(for: trades)
        switch sort {
        case .profit:
            return rows.sorted { $0.netProfit == $1.netProfit ? $0.winRate > $1.winRate : $0.netProfit > $1.netProfit }
        case .winRate:
            return rows.sorted { $0.winRate == $1.winRate ? $0.netProfit > $1.netProfit : $0.winRate > $1.winRate }
        case .trades:
            return rows.sorted { $0.trades == $1.trades ? $0.netProfit > $1.netProfit : $0.trades > $1.trades }
        case .averageRiskReward:
            return rows.sorted { $0.averageRiskReward == $1.averageRiskReward ? $0.netProfit > $1.netProfit : $0.averageRiskReward > $1.averageRiskReward }
        }
    }

    func monthlyPerformanceCards(for trades: [Trade]) -> [MonthlyPerformanceCard] {
        let grouped = Dictionary(grouping: trades) { trade in
            calendar.date(from: calendar.dateComponents([.year, .month], from: trade.date)) ?? trade.date
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"

        return grouped.map { date, monthTrades in
            MonthlyPerformanceCard(
                month: formatter.string(from: date),
                date: date,
                netProfit: netProfit(for: monthTrades),
                winRate: winRate(for: monthTrades),
                trades: monthTrades.count
            )
        }
        .sorted { $0.date > $1.date }
    }

    func bestWorstSummary(for trades: [Trade]) -> AnalyticsBestWorstSummary {
        let pairs = pairPerformance(for: trades)
        let weekdays = weekdayHeatmap(for: trades)
        let sessions = dashboardSessions(for: trades).filter { $0.trades > 0 }

        return AnalyticsBestWorstSummary(
            bestPair: pairs.max(by: { $0.netProfit < $1.netProfit })?.pair ?? "--",
            worstPair: pairs.min(by: { $0.netProfit < $1.netProfit })?.pair ?? "--",
            bestWeekday: weekdays.max(by: { $0.netProfit < $1.netProfit })?.label ?? "--",
            worstWeekday: weekdays.filter { $0.trades > 0 }.min(by: { $0.netProfit < $1.netProfit })?.label ?? "--",
            bestSession: sessions.max(by: { $0.netProfit < $1.netProfit })?.title ?? "--",
            worstSession: sessions.min(by: { $0.netProfit < $1.netProfit })?.title ?? "--",
            largestWin: largestWin(for: trades),
            largestLoss: largestLoss(for: trades),
            longestWinningStreak: longestStreak(for: trades, status: .win),
            longestLosingStreak: longestStreak(for: trades, status: .loss),
            averageHoldTime: averageDuration(for: trades)
        )
    }

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

    func snapshotMetrics(for trades: [Trade]) -> [SnapshotMetric] {
        [
            SnapshotMetric(title: "Win Rate", value: percentage(winRate(for: trades)), trend: trendText(current: winRate(for: recentTrades(trades, count: 10)), previous: winRate(for: previousTrades(trades, count: 10))), icon: "target", tint: JPColors.warning, sparkline: rollingWinRate(for: trades)),
            SnapshotMetric(title: "Average RR", value: riskReward(averageRiskReward(for: trades)), trend: trendText(current: averageRiskReward(for: recentTrades(trades, count: 10)), previous: averageRiskReward(for: previousTrades(trades, count: 10)), suffix: "RR"), icon: "scale.3d", tint: JPColors.accent, sparkline: trades.sorted { $0.date < $1.date }.suffix(10).map(\.riskReward)),
            SnapshotMetric(title: "Profit Factor", value: profitFactorText(for: trades), trend: trendText(current: profitFactorTrendValue(for: recentTrades(trades, count: 10)), previous: profitFactorTrendValue(for: previousTrades(trades, count: 10))), icon: "divide.circle.fill", tint: JPColors.blue, sparkline: rollingProfit(for: trades)),
            SnapshotMetric(title: "Expectancy", value: currency(expectancy(for: trades)), trend: trendText(current: expectancy(for: recentTrades(trades, count: 10)), previous: expectancy(for: previousTrades(trades, count: 10)), prefix: "$"), icon: "function", tint: tint(for: expectancy(for: trades)), sparkline: rollingExpectancy(for: trades))
        ]
    }

    func pairPerformance(for trades: [Trade]) -> [PairPerformance] {
        let grouped = Dictionary(grouping: trades) { $0.pair.uppercased() }
        let raw = grouped.map { pair, pairTrades in
            PairPerformance(
                pair: pair,
                trades: pairTrades.count,
                winRate: winRate(for: pairTrades),
                netProfit: netProfit(for: pairTrades),
                averageRiskReward: averageRiskReward(for: pairTrades),
                isBest: false,
                isWorst: false
            )
        }
        let best = raw.max { lhs, rhs in
            if lhs.netProfit == rhs.netProfit { return lhs.winRate < rhs.winRate }
            return lhs.netProfit < rhs.netProfit
        }?.pair
        let worst = raw.min { lhs, rhs in
            if lhs.netProfit == rhs.netProfit { return lhs.winRate > rhs.winRate }
            return lhs.netProfit < rhs.netProfit
        }?.pair

        return raw.map {
            PairPerformance(
                pair: $0.pair,
                trades: $0.trades,
                winRate: $0.winRate,
                netProfit: $0.netProfit,
                averageRiskReward: $0.averageRiskReward,
                isBest: $0.pair == best && $0.trades > 0,
                isWorst: $0.pair == worst && $0.trades > 0
            )
        }
        .sorted { lhs, rhs in
            if lhs.netProfit == rhs.netProfit { return lhs.winRate > rhs.winRate }
            return lhs.netProfit > rhs.netProfit
        }
    }

    func bestPair(for trades: [Trade]) -> PairPerformance? {
        pairPerformance(for: trades).first(where: \.isBest)
    }

    func worstPair(for trades: [Trade]) -> PairPerformance? {
        pairPerformance(for: trades).first(where: \.isWorst)
    }

    func timeOfDayAnalysis(for trades: [Trade]) -> [TimeOfDayPerformance] {
        let buckets = [
            ("Morning", 5..<12),
            ("Afternoon", 12..<17),
            ("Evening", 17..<22),
            ("Night", 0..<5)
        ]

        return buckets.map { label, range in
            let bucketTrades = trades.filter { trade in
                let hour = calendar.component(.hour, from: trade.tradeOpenTime ?? trade.date)
                if label == "Night" {
                    return range.contains(hour) || hour >= 22
                }
                return range.contains(hour)
            }
            return TimeOfDayPerformance(label: label, trades: bucketTrades.count, winRate: winRate(for: bucketTrades), netProfit: netProfit(for: bucketTrades), averageRiskReward: averageRiskReward(for: bucketTrades))
        }
    }

    func weekdayHeatmap(for trades: [Trade]) -> [WeekdayPerformance] {
        let symbols = calendar.weekdaySymbols
        return (1...7).map { weekday in
            let dayTrades = trades.filter { calendar.component(.weekday, from: $0.date) == weekday }
            return WeekdayPerformance(
                weekday: weekday,
                label: symbols[weekday - 1],
                trades: dayTrades.count,
                winRate: winRate(for: dayTrades),
                netProfit: netProfit(for: dayTrades),
                averageRiskReward: averageRiskReward(for: dayTrades)
            )
        }
    }

    func riskSnapshot(for trades: [Trade]) -> RiskSnapshot {
        let riskValues = trades.map(\.riskPercent).filter { $0 > 0 }
        let positionValues = trades.map(\.lotSize).filter { $0 > 0 }
        let avgRisk = riskValues.isEmpty ? 0 : riskValues.reduce(0, +) / Double(riskValues.count)
        let avgPosition = positionValues.isEmpty ? 0 : positionValues.reduce(0, +) / Double(positionValues.count)
        var score = 72
        if avgRisk > 0, avgRisk <= 1 { score += 16 }
        else if avgRisk <= 2 { score += 8 }
        else if avgRisk > 3 { score -= 18 }
        if abs(largestLoss(for: trades)) <= max(averageWin(for: trades), 1) { score += 8 }
        return RiskSnapshot(averageRisk: avgRisk, averagePositionSize: avgPosition, largestLoss: largestLoss(for: trades), largestWin: largestWin(for: trades), averageHoldTime: averageDuration(for: trades), score: min(100, max(0, score)))
    }

    func psychologySignals(for trades: [Trade]) -> [PsychologySignal] {
        let total = max(trades.count, 1)
        func count(_ tags: [Trade.MistakeTag]) -> Int {
            trades.filter { trade in !Set(trade.mistakeTags).intersection(tags).isEmpty }.count
        }
        func signal(_ title: String, _ value: Int, _ tint: Color) -> PsychologySignal {
            PsychologySignal(title: title, value: Int((Double(value) / Double(total) * 100).rounded()), subtitle: "\(value) of \(trades.count) trades", tint: tint)
        }
        return [
            signal("Fear", count([.enteredLate, .closedEarly]), JPColors.warning),
            signal("Greed", count([.heldTooLong, .riskTooHigh]), JPColors.loss),
            signal("FOMO", count([.fomo, .enteredEarly]), JPColors.loss),
            signal("Revenge Trading", count([.revengeTrade]), JPColors.loss),
            signal("Overtrading", count([.overtrading]), JPColors.warning),
            signal("Rule Breaking", count([.brokeRules, .ignoredPlan]), JPColors.loss),
            signal("Late Entries", count([.enteredLate]), JPColors.warning),
            signal("Early Exits", count([.closedEarly]), JPColors.warning)
        ]
    }

    func disciplineSnapshot(for trades: [Trade]) -> DisciplineAnalyticsSnapshot {
        let monthly = monthlyProfit(for: trades)
        let current = performanceScore(for: trades).value
        let lastMonthTrades = trades.filter { trade in
            guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: Date()) else { return false }
            return calendar.isDate(trade.date, equalTo: previousMonth, toGranularity: .month)
        }
        let last = performanceScore(for: lastMonthTrades).value
        let history = monthly.map { point in
            AnalyticsChartPoint(label: point.label, date: point.date, value: max(0, min(100, 50 + point.value / 100)))
        }
        let values = history.map { Int($0.value.rounded()) }
        return DisciplineAnalyticsSnapshot(currentScore: current, lastMonth: last, highestEver: values.max() ?? current, lowestEver: values.min() ?? current, history: history)
    }

    func streakSnapshot(for trades: [Trade]) -> StreakAnalyticsSnapshot {
        StreakAnalyticsSnapshot(
            winning: winningStreak(for: trades),
            journal: streakByDay(for: trades) { self.hasJournal($0) },
            plan: streakByDay(for: trades) { $0.followedPlan },
            review: streakByDay(for: trades) { self.hasJournal($0) || $0.executionScore > 0 },
            replay: trades.filter { $0.beforeEntryImageData != nil || $0.duringTradeImageData != nil || $0.afterExitImageData != nil }.count
        )
    }

    func goalProgress(for trades: [Trade]) -> [GoalProgress] {
        let weekTrades = trades.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
        let monthTrades = trades.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        return [
            GoalProgress(title: "Weekly Goal", value: min(Double(weekTrades.count) / 5, 1), subtitle: "\(weekTrades.count)/5 quality trades", tint: JPColors.accent),
            GoalProgress(title: "Monthly Goal", value: min(Double(monthTrades.count) / 20, 1), subtitle: "\(monthTrades.count)/20 trades", tint: JPColors.blue),
            GoalProgress(title: "Profit Goal", value: min(max(netProfit(for: monthTrades) / 5_000, 0), 1), subtitle: currency(netProfit(for: monthTrades)), tint: tint(for: netProfit(for: monthTrades))),
            GoalProgress(title: "RR Goal", value: min(averageRiskReward(for: trades) / 2.5, 1), subtitle: riskReward(averageRiskReward(for: trades)), tint: JPColors.warning),
            GoalProgress(title: "Journal Goal", value: trades.isEmpty ? 0 : Double(trades.filter(hasJournal).count) / Double(trades.count), subtitle: "\(trades.filter(hasJournal).count)/\(trades.count) reviewed", tint: JPColors.profit),
            GoalProgress(title: "Checklist Goal", value: trades.isEmpty ? 0 : Double(trades.filter(\.followedPlan).count) / Double(trades.count), subtitle: "\(trades.filter(\.followedPlan).count)/\(trades.count) followed plan", tint: JPColors.purple)
        ]
    }

    func recommendations(for trades: [Trade]) -> [String] {
        var items: [String] = []
        if let best = bestPair(for: trades), best.trades >= 2 {
            items.append("Focus on \(best.pair). It is currently your strongest market.")
        }
        if let worst = worstPair(for: trades), worst.netProfit < 0 {
            items.append("Avoid \(worst.pair) until consistency improves.")
        }
        if averageRiskReward(for: trades) < 1.5 {
            items.append("Increase RR target before taking marginal setups.")
        }
        if mistakeAnalysis(for: trades).first?.tag == .enteredLate {
            items.append("Reduce late entries by waiting for cleaner alerts.")
        }
        if trades.filter(hasJournal).count < trades.count {
            items.append("Review more losing trades and complete journal notes.")
        }
        if trades.filter(\.followedPlan).count < trades.count {
            items.append("Complete checklist before risking capital.")
        }
        return Array(items.prefix(6))
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

    private func recentTrades(_ trades: [Trade], count: Int) -> [Trade] {
        Array(trades.sorted { $0.date > $1.date }.prefix(count))
    }

    private func previousTrades(_ trades: [Trade], count: Int) -> [Trade] {
        Array(trades.sorted { $0.date > $1.date }.dropFirst(count).prefix(count))
    }

    private func profitFactorTrendValue(for trades: [Trade]) -> Double {
        let value = profitFactor(for: trades)
        return value.isInfinite ? 5 : value
    }

    private func trendText(current: Double, previous: Double, prefix: String = "", suffix: String = "%") -> String {
        guard previous != 0 || current != 0 else {
            return "• 0\(suffix)"
        }

        let delta = current - previous
        let arrow = delta >= 0 ? "▲" : "▼"

        if prefix == "$" {
            return "\(arrow) \(delta >= 0 ? "+" : "-")$\(Int(abs(delta)).formatted())"
        }

        if suffix == "RR" {
            return "\(arrow) \(delta >= 0 ? "+" : "")\(String(format: "%.2f", delta))RR"
        }

        return "\(arrow) \(delta >= 0 ? "+" : "")\(Int(delta.rounded()))\(suffix)"
    }

    private func rollingWinRate(for trades: [Trade]) -> [Double] {
        let ordered = trades.sorted { $0.date < $1.date }
        return ordered.indices.map { index in
            let start = max(0, index - 4)
            return winRate(for: Array(ordered[start...index]))
        }
    }

    private func rollingProfit(for trades: [Trade]) -> [Double] {
        let ordered = trades.sorted { $0.date < $1.date }
        var running = 0.0
        return ordered.map { trade in
            running += trade.profitLoss
            return running
        }
    }

    private func rollingExpectancy(for trades: [Trade]) -> [Double] {
        let ordered = trades.sorted { $0.date < $1.date }
        return ordered.indices.map { index in
            expectancy(for: Array(ordered[0...index]))
        }
    }

    private func hasJournal(_ trade: Trade) -> Bool {
        [
            trade.tradeThesis,
            trade.marketContext,
            trade.executionReview,
            trade.lessonsLearned,
            trade.notes
        ]
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .count >= 80
    }

    private func streakByDay(for trades: [Trade], condition: (Trade) -> Bool) -> Int {
        let days = Set(trades.filter(condition).map { calendar.startOfDay(for: $0.date) })
        var cursor = calendar.startOfDay(for: Date())
        var count = 0

        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return count
    }

    private func winningStreak(for trades: [Trade]) -> Int {
        let resolved = trades
            .filter { $0.status == .win || $0.status == .loss }
            .sorted { $0.date > $1.date }

        guard resolved.first?.status == .win else {
            return 0
        }

        return resolved.prefix { $0.status == .win }.count
    }

    private func longestStreak(for trades: [Trade], status: Trade.Status) -> Int {
        let resolved = trades
            .filter { $0.status == .win || $0.status == .loss }
            .sorted { $0.date < $1.date }

        var current = 0
        var longest = 0

        for trade in resolved {
            if trade.status == status {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }

        return longest
    }

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }
}
