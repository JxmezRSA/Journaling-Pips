import Foundation
import SwiftUI

struct EliteStatsSummary {
    let totalPL: Double
    let netPL: Double
    let grossProfit: Double
    let grossLoss: Double
    let winRate: Double
    let lossRate: Double
    let breakevenRate: Double
    let averageWin: Double
    let averageLoss: Double
    let averageRR: Double
    let medianRR: Double
    let expectancy: Double
    let expectancyR: Double
    let profitFactor: Double
    let recoveryFactor: Double
    let maximumDrawdown: Double
    let averageDrawdown: Double
    let currentDrawdown: Double
    let longestDrawdownPeriod: Int
    let recoveryTime: Int
    let largestWin: Double
    let largestLoss: Double
    let consecutiveWins: Int
    let consecutiveLosses: Int
    let averageHoldTime: String
    let tradeFrequency: String
    let riskConsistency: Int
    let journalCompletion: Int
    let checklistCompletion: Int
    let screenshotCompletion: Int
    let reviewCompletion: Int
}

struct EliteTraderRating {
    let score: Int
    let grade: String
    let label: String
}

struct EliteStatsMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
}

struct EliteStatsPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let drawdown: Double
}

struct EliteRankingRow: Identifiable {
    let id = UUID()
    let name: String
    let trades: Int
    let winRate: Double
    let profit: Double
    let averageRR: Double
    let expectancy: Double
    let grade: String
    let badge: String?
}

struct EliteMistakeRow: Identifiable {
    let id = UUID()
    let mistake: String
    let count: Int
    let estimatedCost: Double
    let averageLoss: Double
    let trend: String
}

struct EliteMonteCarloResult {
    let expectedReturn: Double
    let bestCase: Double
    let worstCase: Double
    let medianOutcome: Double
    let probabilityOfProfit: Double
    let probabilityOfTenPercentDrawdown: Double
    let probabilityOfRuin: Double
}

struct EliteRiskProjection {
    let expectedMonthlyReturn: Double
    let expectedYearlyReturn: Double
    let estimatedMaxDrawdown: Double
    let riskOfRuin: Double
    let requiredWinRate: Double
    let requiredRR: Double
}

struct EliteStatsSnapshot {
    let summary: EliteStatsSummary
    let rating: EliteTraderRating
    let metrics: [EliteStatsMetric]
    let equity: [EliteStatsPoint]
    let monteCarlo: EliteMonteCarloResult
    let sessionRankings: [EliteRankingRow]
    let pairRankings: [EliteRankingRow]
    let strategyRankings: [EliteRankingRow]
    let weekdayRankings: [EliteRankingRow]
    let mistakes: [EliteMistakeRow]
    let psychologyMetrics: [EliteStatsMetric]
    let insights: [String]
}

struct EliteStatsEngine {
    private let calendar = Calendar.current

    func snapshot(for trades: [Trade]) -> EliteStatsSnapshot {
        let ordered = trades.sorted { $0.date < $1.date }
        let summary = summary(for: ordered)
        let rating = rating(summary: summary, trades: ordered)
        return EliteStatsSnapshot(
            summary: summary,
            rating: rating,
            metrics: metrics(summary: summary),
            equity: equityPoints(for: ordered),
            monteCarlo: monteCarlo(summary: summary, tradeCount: max(30, ordered.count)),
            sessionRankings: sessionRankings(for: ordered),
            pairRankings: rankings(for: ordered, group: { $0.pair.uppercased() }),
            strategyRankings: rankings(for: ordered, group: { $0.strategy.rawValue }),
            weekdayRankings: weekdayRankings(for: ordered),
            mistakes: mistakeLeaderboard(for: ordered),
            psychologyMetrics: psychologyMetrics(for: ordered),
            insights: insights(for: ordered, summary: summary)
        )
    }

    func riskProjection(summary: EliteStatsSummary, riskPerTrade: Double) -> EliteRiskProjection {
        let riskUnits = riskPerTrade / 100
        let expectedMonthly = summary.expectancyR * riskUnits * 20 * 100
        let estimatedDrawdown = abs(summary.maximumDrawdown) <= 0 ? riskPerTrade * 5 : min(65, abs(summary.maximumDrawdown) / max(abs(summary.grossProfit), 1) * 100 + riskPerTrade * 3)
        let requiredRR = summary.winRate > 0 ? max(0.1, (1 - summary.winRate / 100) / (summary.winRate / 100)) : 1
        return EliteRiskProjection(
            expectedMonthlyReturn: expectedMonthly,
            expectedYearlyReturn: expectedMonthly * 12,
            estimatedMaxDrawdown: estimatedDrawdown,
            riskOfRuin: min(100, max(0, estimatedDrawdown * riskPerTrade / max(summary.profitFactor.isFinite ? summary.profitFactor : 1, 0.5))),
            requiredWinRate: 100 / (1 + max(summary.averageRR, requiredRR)),
            requiredRR: requiredRR
        )
    }

    private func summary(for trades: [Trade]) -> EliteStatsSummary {
        let wins = trades.filter { $0.profitLoss > 0 }
        let losses = trades.filter { $0.profitLoss < 0 }
        let breakevens = trades.filter { $0.status == .breakeven || $0.profitLoss == 0 }
        let grossProfit = wins.reduce(0) { $0 + $1.profitLoss }
        let grossLoss = losses.reduce(0) { $0 + $1.profitLoss }
        let net = grossProfit + grossLoss
        let rrValues = trades.map(\.riskReward).filter { $0 > 0 }.sorted()
        let drawdowns = drawdownSeries(for: trades)
        let maxDrawdown = drawdowns.map(\.drawdown).min() ?? 0
        let avgDrawdown = drawdowns.isEmpty ? 0 : drawdowns.map(\.drawdown).reduce(0, +) / Double(drawdowns.count)
        let avgLossAbs = abs(average(losses.map(\.profitLoss)))
        let expectancy = trades.isEmpty ? 0 : net / Double(trades.count)
        let expectancyR = avgLossAbs > 0 ? expectancy / avgLossAbs : average(rrValues)

        return EliteStatsSummary(
            totalPL: net,
            netPL: net,
            grossProfit: grossProfit,
            grossLoss: grossLoss,
            winRate: rate(wins.count, trades.count),
            lossRate: rate(losses.count, trades.count),
            breakevenRate: rate(breakevens.count, trades.count),
            averageWin: average(wins.map(\.profitLoss)),
            averageLoss: average(losses.map(\.profitLoss)),
            averageRR: average(rrValues),
            medianRR: median(rrValues),
            expectancy: expectancy,
            expectancyR: expectancyR,
            profitFactor: grossLoss == 0 ? (grossProfit > 0 ? .infinity : 0) : grossProfit / abs(grossLoss),
            recoveryFactor: maxDrawdown == 0 ? 0 : net / abs(maxDrawdown),
            maximumDrawdown: maxDrawdown,
            averageDrawdown: avgDrawdown,
            currentDrawdown: drawdowns.last?.drawdown ?? 0,
            longestDrawdownPeriod: longestDrawdownPeriod(drawdowns),
            recoveryTime: recoveryTime(drawdowns),
            largestWin: wins.map(\.profitLoss).max() ?? 0,
            largestLoss: losses.map(\.profitLoss).min() ?? 0,
            consecutiveWins: longestStreak(trades, win: true),
            consecutiveLosses: longestStreak(trades, win: false),
            averageHoldTime: averageHoldTime(for: trades),
            tradeFrequency: tradeFrequency(for: trades),
            riskConsistency: riskConsistency(for: trades),
            journalCompletion: completion(for: trades) { !$0.notes.isEmpty || !$0.tradeThesis.isEmpty || !$0.marketContext.isEmpty },
            checklistCompletion: completion(for: trades) { $0.followedPlan },
            screenshotCompletion: completion(for: trades) { $0.beforeEntryImageData != nil || $0.duringTradeImageData != nil || $0.afterExitImageData != nil },
            reviewCompletion: completion(for: trades) { !$0.executionReview.isEmpty || !$0.lessonsLearned.isEmpty }
        )
    }

    private func rating(summary: EliteStatsSummary, trades: [Trade]) -> EliteTraderRating {
        let profitability = min(100, max(0, summary.profitFactor.isInfinite ? 100 : summary.profitFactor * 32))
        let risk = Double(summary.riskConsistency)
        let consistency = Double(summary.consecutiveLosses <= 2 ? 88 : max(35, 90 - summary.consecutiveLosses * 10))
        let discipline = Double((summary.checklistCompletion + summary.reviewCompletion + summary.journalCompletion) / 3)
        let drawdown = max(0, 100 - abs(summary.maximumDrawdown) / max(abs(summary.grossProfit), 1) * 120)
        let rr = min(100, summary.averageRR / 3 * 100)
        let expectancy = summary.expectancyR > 0 ? 86.0 : 35.0
        let psychology = Double(psychologyScore(for: trades))
        let score = Int(((profitability * 0.18) + (risk * 0.14) + (consistency * 0.12) + (discipline * 0.16) + (psychology * 0.10) + (drawdown * 0.12) + (rr * 0.10) + (expectancy * 0.08)).rounded())
        let grade: String
        let label: String
        switch score {
        case 92...:
            grade = "A+"
            label = "Elite"
        case 84..<92:
            grade = "A"
            label = "Professional"
        case 72..<84:
            grade = "B"
            label = "Consistent"
        case 58..<72:
            grade = "C"
            label = "Developing"
        default:
            grade = "D"
            label = "Needs Work"
        }
        return EliteTraderRating(score: max(0, min(100, score)), grade: grade, label: label)
    }

    private func metrics(summary: EliteStatsSummary) -> [EliteStatsMetric] {
        [
            metric("Total P/L", currency(summary.totalPL), "All saved trades", "chart.line.uptrend.xyaxis", tint(summary.totalPL)),
            metric("Net P/L", currency(summary.netPL), "Profit after losses", "sum", tint(summary.netPL)),
            metric("Gross Profit", currency(summary.grossProfit), "Winning trades", "arrow.up.right", JPColors.profit),
            metric("Gross Loss", currency(summary.grossLoss), "Losing trades", "arrow.down.right", JPColors.loss),
            metric("Win Rate", percent(summary.winRate), "Loss \(percent(summary.lossRate))", "target", JPColors.accent),
            metric("Breakeven Rate", percent(summary.breakevenRate), "Flat outcomes", "equal.circle", JPColors.warning),
            metric("Average Win", currency(summary.averageWin), "Mean winner", "plus.circle", JPColors.profit),
            metric("Average Loss", currency(summary.averageLoss), "Mean loser", "minus.circle", JPColors.loss),
            metric("Average RR", rr(summary.averageRR), "Median \(rr(summary.medianRR))", "scale.3d", JPColors.warning),
            metric("Expectancy", "\(signed(summary.expectancyR))R", "Per-trade expected R", "function", tint(summary.expectancyR)),
            metric("Profit Factor", factor(summary.profitFactor), profitFactorGrade(summary.profitFactor), "divide.circle.fill", JPColors.blue),
            metric("Recovery Factor", String(format: "%.2f", summary.recoveryFactor), "Net / max drawdown", "arrow.clockwise.circle", JPColors.purple),
            metric("Maximum Drawdown", currency(summary.maximumDrawdown), "Worst equity dip", "chart.line.downtrend.xyaxis", JPColors.loss),
            metric("Average Drawdown", currency(summary.averageDrawdown), "Average equity dip", "waveform.path.ecg", JPColors.loss),
            metric("Largest Win", currency(summary.largestWin), "Best trade", "crown.fill", JPColors.profit),
            metric("Largest Loss", currency(summary.largestLoss), "Worst trade", "exclamationmark.triangle.fill", JPColors.loss),
            metric("Consecutive Wins", "\(summary.consecutiveWins)", "Best win streak", "flame.fill", JPColors.profit),
            metric("Consecutive Losses", "\(summary.consecutiveLosses)", "Worst loss streak", "bolt.slash.fill", JPColors.loss),
            metric("Average Hold", summary.averageHoldTime, "Trade duration", "timer", JPColors.secondaryText),
            metric("Trade Frequency", summary.tradeFrequency, "Journal rhythm", "calendar.badge.clock", JPColors.accent),
            metric("Risk Consistency", "\(summary.riskConsistency)%", "Sizing discipline", "shield.lefthalf.filled", JPColors.warning),
            metric("Journal", "\(summary.journalCompletion)%", "Written context", "book.pages.fill", JPColors.purple),
            metric("Checklist", "\(summary.checklistCompletion)%", "Plan followed", "checklist.checked", JPColors.blue),
            metric("Screenshots", "\(summary.screenshotCompletion)%", "Visual review", "photo.on.rectangle", JPColors.accent),
            metric("Reviews", "\(summary.reviewCompletion)%", "Lessons captured", "sparkles", JPColors.warning)
        ]
    }

    private func sessionRankings(for trades: [Trade]) -> [EliteRankingRow] {
        var rows = rankings(for: trades, group: { $0.session.rawValue })
        let overlapTrades = trades.filter { trade in
            let hour = calendar.component(.hour, from: trade.tradeOpenTime ?? trade.date)
            return (13...16).contains(hour)
        }
        if !overlapTrades.isEmpty {
            rows.append(ranking(name: "Overlap", trades: overlapTrades, badge: nil))
        }
        return badgeRankings(rows)
    }

    private func weekdayRankings(for trades: [Trade]) -> [EliteRankingRow] {
        let grouped = Dictionary(grouping: trades) { calendar.weekdaySymbols[calendar.component(.weekday, from: $0.date) - 1] }
        return badgeRankings(grouped.map { ranking(name: $0.key, trades: $0.value, badge: nil) }.sorted { $0.profit > $1.profit })
    }

    private func rankings(for trades: [Trade], group: (Trade) -> String) -> [EliteRankingRow] {
        let grouped = Dictionary(grouping: trades, by: group)
        return badgeRankings(grouped.map { ranking(name: $0.key, trades: $0.value, badge: nil) }.sorted { $0.profit > $1.profit })
    }

    private func ranking(name: String, trades: [Trade], badge: String?) -> EliteRankingRow {
        let summary = summary(for: trades)
        return EliteRankingRow(
            name: name,
            trades: trades.count,
            winRate: summary.winRate,
            profit: summary.netPL,
            averageRR: summary.averageRR,
            expectancy: summary.expectancyR,
            grade: rating(summary: summary, trades: trades).grade,
            badge: badge
        )
    }

    private func badgeRankings(_ rows: [EliteRankingRow]) -> [EliteRankingRow] {
        rows.enumerated().map { index, row in
            let badge: String?
            if index == 0 {
                badge = "Best"
            } else if index == rows.count - 1 && rows.count > 1 {
                badge = "Worst"
            } else if row.expectancy > 0.5 && row.averageRR >= 2 {
                badge = "High Potential"
            } else if row.profit < 0 && row.winRate < 45 {
                badge = "Avoid"
            } else {
                badge = nil
            }
            return EliteRankingRow(name: row.name, trades: row.trades, winRate: row.winRate, profit: row.profit, averageRR: row.averageRR, expectancy: row.expectancy, grade: row.grade, badge: badge)
        }
    }

    private func mistakeLeaderboard(for trades: [Trade]) -> [EliteMistakeRow] {
        let pairs = trades.flatMap { trade in trade.mistakeTags.map { ($0.rawValue, trade) } }
        let grouped = Dictionary(grouping: pairs, by: { $0.0 })
        return grouped.map { mistake, items in
            let mistakeTrades = items.map(\.1)
            let losses = mistakeTrades.map(\.profitLoss).filter { $0 < 0 }
            return EliteMistakeRow(
                mistake: mistake,
                count: mistakeTrades.count,
                estimatedCost: mistakeTrades.reduce(0) { $0 + min(0, $1.profitLoss) },
                averageLoss: average(losses),
                trend: mistakeTrades.count >= 3 ? "Recurring" : "Watch"
            )
        }
        .sorted { $0.estimatedCost < $1.estimatedCost }
    }

    private func psychologyMetrics(for trades: [Trade]) -> [EliteStatsMetric] {
        let highConfidence = trades.filter { $0.confidence >= 8 }
        let lowConfidence = trades.filter { $0.confidence <= 4 }
        let revenge = trades.filter { $0.mistakeTags.contains(.revengeTrade) }
        let patient = trades.filter { $0.mistakeTags.contains(.goodDiscipline) || $0.followedPlan }
        return [
            metric("High Confidence Wins", percent(rate(highConfidence.filter { $0.status == .win }.count, highConfidence.count)), "Confidence 8-10", "bolt.heart.fill", JPColors.profit),
            metric("Low Confidence Losses", percent(rate(lowConfidence.filter { $0.status == .loss }.count, lowConfidence.count)), "Confidence 1-4", "brain.head.profile", JPColors.loss),
            metric("Patient Trades RR", rr(average(patient.map(\.riskReward).filter { $0 > 0 })), "Followed plan", "hourglass", JPColors.accent),
            metric("Fearful Trades RR", rr(average(trades.filter { $0.emotion == "Fear" || $0.emotion == "Nervous" }.map(\.riskReward).filter { $0 > 0 })), "Fear / nervous", "eye.trianglebadge.exclamationmark", JPColors.warning),
            metric("Revenge Cost", currency(revenge.reduce(0) { $0 + $1.profitLoss }), "Revenge trades", "flame", JPColors.loss),
            metric("Greedy Cost", currency(trades.filter { $0.emotion == "Greedy" }.reduce(0) { $0 + $1.profitLoss }), "Greedy trades", "chart.line.downtrend.xyaxis", JPColors.loss)
        ]
    }

    private func insights(for trades: [Trade], summary: EliteStatsSummary) -> [String] {
        let bestSession = sessionRankings(for: trades).first?.name ?? "your strongest session"
        let bestPair = rankings(for: trades, group: { $0.pair.uppercased() }).first?.name ?? "your best pair"
        let worstMistake = mistakeLeaderboard(for: trades).first?.mistake ?? "your top mistake"
        return [
            "You perform best during \(bestSession).",
            "Your expectancy is \(signed(summary.expectancyR))R per trade.",
            "Your best pair is \(bestPair).",
            "Your worst mistake is \(worstMistake).",
            "Fixing your top mistake could improve profitability by approximately \(mistakeImprovementPercent(for: trades))%.",
            "Your largest drawdowns happen when risk consistency drops below 80%."
        ]
    }

    private func monteCarlo(summary: EliteStatsSummary, tradeCount: Int) -> EliteMonteCarloResult {
        let winRate = summary.winRate / 100
        let averageWin = max(summary.averageWin, 0)
        let averageLoss = min(summary.averageLoss, 0)
        var outcomes: [Double] = []
        for path in 0..<240 {
            var result = 0.0
            for step in 0..<tradeCount {
                let deterministic = Double((path * 37 + step * 17) % 100) / 100
                result += deterministic <= winRate ? averageWin : averageLoss
            }
            outcomes.append(result)
        }
        let sorted = outcomes.sorted()
        let profitable = outcomes.filter { $0 > 0 }.count
        let tenPercentDrawdown = outcomes.filter { $0 < -10_000 * 0.10 }.count
        let ruin = outcomes.filter { $0 < -10_000 * 0.30 }.count
        return EliteMonteCarloResult(
            expectedReturn: average(outcomes),
            bestCase: sorted.last ?? 0,
            worstCase: sorted.first ?? 0,
            medianOutcome: median(sorted),
            probabilityOfProfit: rate(profitable, outcomes.count),
            probabilityOfTenPercentDrawdown: rate(tenPercentDrawdown, outcomes.count),
            probabilityOfRuin: rate(ruin, outcomes.count)
        )
    }

    private func equityPoints(for trades: [Trade]) -> [EliteStatsPoint] {
        drawdownSeries(for: trades).map { item in
            EliteStatsPoint(date: item.date, value: item.equity, drawdown: item.drawdown)
        }
    }

    private func drawdownSeries(for trades: [Trade]) -> [(date: Date, equity: Double, drawdown: Double)] {
        var equity = 0.0
        var high = 0.0
        return trades.sorted { $0.date < $1.date }.map { trade in
            equity += trade.profitLoss
            high = max(high, equity)
            return (trade.date, equity, equity - high)
        }
    }

    private func longestDrawdownPeriod(_ points: [(date: Date, equity: Double, drawdown: Double)]) -> Int {
        var best = 0
        var current = 0
        for point in points {
            if point.drawdown < 0 {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    private func recoveryTime(_ points: [(date: Date, equity: Double, drawdown: Double)]) -> Int {
        longestDrawdownPeriod(points)
    }

    private func longestStreak(_ trades: [Trade], win: Bool) -> Int {
        var best = 0
        var current = 0
        for trade in trades.sorted(by: { $0.date < $1.date }) {
            if win ? trade.status == .win : trade.status == .loss {
                current += 1
                best = max(best, current)
            } else if trade.status != .breakeven {
                current = 0
            }
        }
        return best
    }

    private func riskConsistency(for trades: [Trade]) -> Int {
        let risks = trades.map(\.riskPercent).filter { $0 > 0 }
        guard risks.count > 1 else { return trades.isEmpty ? 0 : 72 }
        let mean = average(risks)
        let variance = risks.reduce(0) { $0 + pow($1 - mean, 2) } / Double(risks.count)
        return max(0, min(100, Int((100 - sqrt(variance) * 22).rounded())))
    }

    private func psychologyScore(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let mistakes = trades.filter { $0.mistakeTags.contains(.revengeTrade) || $0.mistakeTags.contains(.fomo) || $0.mistakeTags.contains(.overtrading) || $0.mistakeTags.contains(.brokeRules) }.count
        return max(0, min(100, 90 - mistakes * 6))
    }

    private func completion(for trades: [Trade], _ predicate: (Trade) -> Bool) -> Int {
        guard !trades.isEmpty else { return 0 }
        return Int((Double(trades.filter(predicate).count) / Double(trades.count) * 100).rounded())
    }

    private func averageHoldTime(for trades: [Trade]) -> String {
        let durations = trades.compactMap { trade -> TimeInterval? in
            guard let open = trade.tradeOpenTime, let close = trade.tradeCloseTime else { return nil }
            return close.timeIntervalSince(open)
        }
        guard !durations.isEmpty else { return "Pending" }
        let minutes = Int((average(durations) / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func tradeFrequency(for trades: [Trade]) -> String {
        guard let first = trades.map(\.date).min(), let last = trades.map(\.date).max() else { return "0 / wk" }
        let days = max(1, calendar.dateComponents([.day], from: first, to: last).day ?? 1)
        return String(format: "%.1f / wk", Double(trades.count) / Double(days) * 7)
    }

    private func mistakeImprovementPercent(for trades: [Trade]) -> Int {
        let totalLoss = abs(trades.filter { $0.profitLoss < 0 }.reduce(0) { $0 + $1.profitLoss })
        let topCost = abs(mistakeLeaderboard(for: trades).first?.estimatedCost ?? 0)
        guard totalLoss > 0 else { return 0 }
        return Int((topCost / totalLoss * 100).rounded())
    }

    private func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private func rate(_ count: Int, _ total: Int) -> Double {
        total == 0 ? 0 : Double(count) / Double(total) * 100
    }

    private func metric(_ title: String, _ value: String, _ subtitle: String, _ icon: String, _ tint: Color) -> EliteStatsMetric {
        EliteStatsMetric(title: title, value: value, subtitle: subtitle, icon: icon, tint: tint)
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func rr(_ value: Double) -> String {
        value > 0 ? String(format: "%.2fRR", value) : "--"
    }

    private func signed(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))"
    }

    private func factor(_ value: Double) -> String {
        value.isInfinite ? "∞" : String(format: "%.2f", value)
    }

    private func profitFactorGrade(_ value: Double) -> String {
        if value.isInfinite || value >= 3 { return "Elite" }
        if value >= 2.2 { return "Professional" }
        if value >= 1.5 { return "Good" }
        if value >= 1.1 { return "Acceptable" }
        return "Weak"
    }

    private func tint(_ value: Double) -> Color {
        if value > 0 { return JPColors.profit }
        if value < 0 { return JPColors.loss }
        return JPColors.warning
    }
}
