import Foundation
import Combine
import SwiftUI

struct AIIntelligenceMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
    let progress: Double
}

struct AIIntelligenceInsight: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let category: String
    let confidence: Int
    let tint: Color
}

struct AIIntelligencePattern: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
}

struct AIBehaviourSignal: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
    let trend: String
    let tint: Color
}

struct AITraderProfile {
    let personality: String
    let confidence: String
    let risk: String
    let decisionSpeed: String
    let emotionalControl: String
    let journalQuality: Int
    let planning: Int
    let execution: Int
}

struct AIImprovementPlan {
    let strengths: [String]
    let weaknesses: [String]
    let mostImprovedMetric: String
    let needsAttention: String
    let nextMilestone: String
    let tomorrowFocus: String
    let weeklyChallenge: String
    let monthlyChallenge: String
}

struct AIConfidenceSummary {
    let score: Int
    let label: String
    let explanation: String
}

struct AIDailyBrief {
    let greeting: String
    let disciplineScore: Int
    let traderScore: Int
    let streak: Int
    let londonCountdown: String
    let strongestSetup: String
    let strongestSetupWinRate: Double
    let todayFocus: String
    let recentImprovement: String
    let biggestRisk: String
}

struct AIIntelligenceSnapshot {
    let dailyBrief: AIDailyBrief
    let confidence: AIConfidenceSummary
    let profile: AITraderProfile
    let improvementPlan: AIImprovementPlan
    let performanceTrends: [AIIntelligenceMetric]
    let disciplineMetrics: [AIIntelligenceMetric]
    let patterns: [AIIntelligencePattern]
    let behaviours: [AIBehaviourSignal]
    let insights: [AIIntelligenceInsight]
    let memoryWarnings: [AIIntelligenceInsight]
    let notificationSuggestions: [String]
    let recentLessons: [String]
}

@MainActor
final class AIIntelligenceViewModel: ObservableObject {
    func snapshot(
        trades: [Trade],
        reviews: [AITradeReview],
        disciplineDays: [DisciplineDay],
        plans: [MorningPlan],
        userProfiles: [UserProfile]
    ) -> AIIntelligenceSnapshot {
        let sortedTrades = trades.sorted { $0.date > $1.date }
        let disciplineScore = latestDisciplineScore(from: disciplineDays, trades: sortedTrades)
        let journalQuality = journalCompletion(for: sortedTrades)
        let planning = latestPlanCompletion(from: plans)
        let execution = executionScore(trades: sortedTrades, reviews: reviews)
        let risk = riskScore(for: sortedTrades)
        let consistency = consistencyScore(for: sortedTrades)
        let traderScore = weightedScore([disciplineScore, journalQuality, planning, execution, risk, consistency])
        let name = userProfiles.first?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let greetingName = (name?.isEmpty == false ? name : "Trader") ?? "Trader"
        let strongestSetup = bestStrategy(for: sortedTrades).name
        let strongestSetupWinRate = bestStrategy(for: sortedTrades).winRate
        let commonMistake = mostCommonMistake(in: sortedTrades)

        let profile = AITraderProfile(
            personality: personality(for: sortedTrades),
            confidence: confidenceLabel(from: sortedTrades.map(\.confidence)),
            risk: risk <= 55 ? "Aggressive" : (risk >= 82 ? "Conservative" : "Balanced"),
            decisionSpeed: sortedTrades.contains { $0.mistakeTags.contains(.enteredEarly) } ? "Fast" : "Medium",
            emotionalControl: psychologyScore(for: sortedTrades) >= 82 ? "Excellent" : "Developing",
            journalQuality: journalQuality,
            planning: planning,
            execution: execution
        )

        let confidenceSummary = confidenceSummary(
            score: weightedScore([disciplineScore, planning, risk, consistency, journalQuality]),
            discipline: disciplineScore,
            planning: planning,
            risk: risk,
            journal: journalQuality
        )

        return AIIntelligenceSnapshot(
            dailyBrief: AIDailyBrief(
                greeting: "\(timeGreeting()) \(greetingName).",
                disciplineScore: disciplineScore,
                traderScore: traderScore,
                streak: currentDisciplineStreak(from: disciplineDays),
                londonCountdown: countdown(toHour: 8),
                strongestSetup: strongestSetup,
                strongestSetupWinRate: strongestSetupWinRate,
                todayFocus: focusText(trades: sortedTrades, plans: plans),
                recentImprovement: improvementText(for: sortedTrades),
                biggestRisk: commonMistake == "None" ? "Avoid overtrading after three positions." : "Watch recurring \(commonMistake.lowercased())."
            ),
            confidence: confidenceSummary,
            profile: profile,
            improvementPlan: improvementPlan(trades: sortedTrades, profile: profile, commonMistake: commonMistake),
            performanceTrends: performanceMetrics(trades: sortedTrades, traderScore: traderScore, confidence: confidenceSummary.score),
            disciplineMetrics: disciplineMetrics(trades: sortedTrades, disciplineDays: disciplineDays, plans: plans),
            patterns: patterns(trades: sortedTrades),
            behaviours: behaviours(trades: sortedTrades),
            insights: insights(trades: sortedTrades, plans: plans),
            memoryWarnings: memoryWarnings(trades: sortedTrades),
            notificationSuggestions: notificationSuggestions(trades: sortedTrades, plans: plans, disciplineDays: disciplineDays),
            recentLessons: recentLessons(from: sortedTrades)
        )
    }

    private func performanceMetrics(trades: [Trade], traderScore: Int, confidence: Int) -> [AIIntelligenceMetric] {
        [
            AIIntelligenceMetric(title: "Trader Score", value: "\(traderScore)", subtitle: rating(for: traderScore), icon: "sparkles", tint: JPColors.accent, progress: Double(traderScore) / 100),
            AIIntelligenceMetric(title: "AI Confidence", value: "\(confidence)", subtitle: rating(for: confidence), icon: "brain.head.profile", tint: JPColors.blue, progress: Double(confidence) / 100),
            AIIntelligenceMetric(title: "Win Rate", value: percent(winRate(for: trades)), subtitle: "All resolved trades", icon: "target", tint: JPColors.warning, progress: winRate(for: trades) / 100),
            AIIntelligenceMetric(title: "Average RR", value: rr(averageRR(for: trades)), subtitle: "Reward quality", icon: "scale.3d", tint: JPColors.profit, progress: min(1, averageRR(for: trades) / 4))
        ]
    }

    private func disciplineMetrics(trades: [Trade], disciplineDays: [DisciplineDay], plans: [MorningPlan]) -> [AIIntelligenceMetric] {
        let journal = journalCompletion(for: trades)
        let screenshots = screenshotCompletion(for: trades)
        let lessons = lessonCompletion(for: trades)
        let plan = latestPlanCompletion(from: plans)
        let review = reviewCompletion(for: trades)
        let discipline = latestDisciplineScore(from: disciplineDays, trades: trades)
        return [
            AIIntelligenceMetric(title: "Checklist", value: "\(plan)%", subtitle: "Latest morning plan", icon: "checklist.checked", tint: JPColors.blue, progress: Double(plan) / 100),
            AIIntelligenceMetric(title: "Morning Routine", value: "\(plan)%", subtitle: "Preparation quality", icon: "sunrise.fill", tint: JPColors.warning, progress: Double(plan) / 100),
            AIIntelligenceMetric(title: "Review Completion", value: "\(review)%", subtitle: "Trade reviews", icon: "checkmark.seal.fill", tint: JPColors.accent, progress: Double(review) / 100),
            AIIntelligenceMetric(title: "Journal Completion", value: "\(journal)%", subtitle: "Written context", icon: "book.pages.fill", tint: JPColors.purple, progress: Double(journal) / 100),
            AIIntelligenceMetric(title: "Screenshot Completion", value: "\(screenshots)%", subtitle: "Visual journal", icon: "photo.on.rectangle", tint: JPColors.blue, progress: Double(screenshots) / 100),
            AIIntelligenceMetric(title: "Lesson Completion", value: "\(lessons)%", subtitle: "Lessons captured", icon: "lightbulb.fill", tint: JPColors.warning, progress: Double(lessons) / 100),
            AIIntelligenceMetric(title: "Voice Notes", value: "0%", subtitle: "Placeholder ready", icon: "waveform.circle.fill", tint: JPColors.secondaryText, progress: 0),
            AIIntelligenceMetric(title: "Overall Discipline", value: "\(discipline)%", subtitle: "Current behavior score", icon: "shield.checkered", tint: JPColors.profit, progress: Double(discipline) / 100)
        ]
    }

    private func patterns(trades: [Trade]) -> [AIIntelligencePattern] {
        [
            pattern("Best Weekday", bestDateComponent(trades: trades, component: .weekday).best, "Highest net result", "calendar.badge.checkmark", JPColors.profit),
            pattern("Worst Weekday", bestDateComponent(trades: trades, component: .weekday).worst, "Needs caution", "calendar.badge.exclamationmark", JPColors.loss),
            pattern("Best Month", bestDateComponent(trades: trades, component: .month).best, "Strongest month", "calendar", JPColors.accent),
            pattern("Worst Month", bestDateComponent(trades: trades, component: .month).worst, "Weakest month", "calendar.badge.minus", JPColors.loss),
            pattern("Best Session", rankedGroup(trades: trades, value: { $0.session.rawValue }).best, "Session edge", "sun.max.fill", JPColors.accent),
            pattern("Worst Session", rankedGroup(trades: trades, value: { $0.session.rawValue }).worst, "Session risk", "moon.zzz.fill", JPColors.loss),
            pattern("Best Pair", rankedGroup(trades: trades, value: { $0.pair }).best, "Instrument edge", "crown.fill", JPColors.warning),
            pattern("Worst Pair", rankedGroup(trades: trades, value: { $0.pair }).worst, "Instrument drag", "exclamationmark.triangle.fill", JPColors.loss),
            pattern("Best Setup", rankedGroup(trades: trades, value: { $0.strategy.rawValue }).best, "Highest net setup", "sparkles", JPColors.profit),
            pattern("Worst Setup", rankedGroup(trades: trades, value: { $0.strategy.rawValue }).worst, "Review setup filter", "xmark.seal.fill", JPColors.loss),
            pattern("Best RR", rr(trades.map(\.riskReward).max() ?? 0), "Largest planned reward", "arrow.up.forward.circle.fill", JPColors.warning),
            pattern("Common Mistake", mostCommonMistake(in: trades), "Recurring behavior", "scope", JPColors.purple),
            pattern("Avg Hold Time", averageHoldTime(for: trades), "Trade duration", "timer", JPColors.blue),
            pattern("Max Drawdown", currency(maximumDrawdown(for: trades)), "Largest equity dip", "chart.line.downtrend.xyaxis", JPColors.loss),
            pattern("Winning Streak", "\(longestStreak(in: trades, status: .win))", "Largest win run", "flame.fill", JPColors.profit),
            pattern("Losing Streak", "\(longestStreak(in: trades, status: .loss))", "Largest loss run", "bolt.slash.fill", JPColors.loss)
        ]
    }

    private func behaviours(trades: [Trade]) -> [AIBehaviourSignal] {
        [
            behaviour("Revenge Trading", trades, .revengeTrade, JPColors.loss),
            behaviour("Overtrading", trades, .overtrading, JPColors.warning),
            behaviour("Trading Outside Plan", trades.filter { !$0.followedPlan }.count, JPColors.loss),
            behaviour("High Confidence Wins", trades.filter { $0.confidence >= 8 && $0.status == .win }.count, JPColors.profit),
            behaviour("Low Confidence Losses", trades.filter { $0.confidence <= 4 && $0.status == .loss }.count, JPColors.loss),
            behaviour("Entered Too Early", trades, .enteredEarly, JPColors.warning),
            behaviour("Held Too Long", trades, .heldTooLong, JPColors.warning),
            behaviour("Cut Winners", trades, .closedEarly, JPColors.loss),
            behaviour("Moved Stop", trades, .movedStop, JPColors.loss),
            behaviour("Large Risk Days", trades.filter { $0.riskPercent > 2.5 }.count, JPColors.loss),
            behaviour("Small Risk Days", trades.filter { $0.riskPercent > 0 && $0.riskPercent <= 1 }.count, JPColors.accent)
        ]
    }

    private func insights(trades: [Trade], plans: [MorningPlan]) -> [AIIntelligenceInsight] {
        let bestSession = rankedGroup(trades: trades, value: { $0.session.rawValue }).best
        let bestSetup = bestStrategy(for: trades)
        let bestDay = bestDateComponent(trades: trades, component: .weekday).best
        var items: [AIIntelligenceInsight] = [
            insight("You perform strongest during \(bestSession).", "Session data shows this is currently your cleanest environment.", "clock.fill", "Performance", 84, JPColors.accent),
            insight("You average \(rr(bestSetup.averageRR)) on \(bestSetup.name) setups.", "This setup has a \(percent(bestSetup.winRate)) win rate from saved trades.", "sparkles", "Execution", 82, JPColors.warning),
            insight("\(bestDay) is your strongest trading day.", "Use this pattern to protect energy and risk around the week.", "calendar", "Performance", 78, JPColors.blue),
            insight("Trades with screenshots are easier to review.", "\(screenshotCompletion(for: trades))% of trades include screenshots.", "photo.on.rectangle", "Journal", 74, JPColors.purple)
        ]
        if latestPlanCompletion(from: plans) >= 90 {
            items.append(insight("Your checklist is supporting consistency.", "High checklist completion is a strong discipline signal.", "checklist.checked", "Discipline", 86, JPColors.profit))
        }
        return items.sorted { $0.confidence > $1.confidence }
    }

    private func memoryWarnings(trades: [Trade]) -> [AIIntelligenceInsight] {
        let repeatedTags = Dictionary(grouping: trades.flatMap(\.mistakeTags), by: { $0 })
            .map { ($0.key, $0.value.count) }
            .filter { $0.1 >= 2 }
            .sorted { $0.1 > $1.1 }
        return repeatedTags.prefix(4).map { tag, count in
            insight("Recurring: \(tag.rawValue)", "Detected \(count) times. Treat this as an active coaching memory.", "exclamationmark.triangle.fill", "AI Memory", min(95, 62 + count * 7), JPColors.warning)
        }
    }

    private func improvementPlan(trades: [Trade], profile: AITraderProfile, commonMistake: String) -> AIImprovementPlan {
        AIImprovementPlan(
            strengths: [
                profile.journalQuality >= 75 ? "You are documenting enough context to learn from trades." : "You are building a repeatable review habit.",
                riskScore(for: trades) >= 75 ? "Risk behavior is mostly controlled." : "You are aware of risk patterns and can tighten them.",
                "Your best setup is identifiable from the data."
            ],
            weaknesses: [
                commonMistake == "None" ? "Keep watching for emotional trades." : commonMistake,
                screenshotCompletion(for: trades) < 60 ? "More screenshots would improve visual review." : "Continue attaching charts to key trades.",
                latestThreeTradeRisk(trades) > 2 ? "Risk is elevated across recent trades." : "Maintain risk discipline after wins."
            ],
            mostImprovedMetric: improvementText(for: trades),
            needsAttention: commonMistake == "None" ? "Consistency after the third trade." : commonMistake,
            nextMilestone: "Reach 90% journal completion.",
            tomorrowFocus: focusText(trades: trades, plans: []),
            weeklyChallenge: "Review every losing trade within 24 hours.",
            monthlyChallenge: "Complete 20 visual journal entries with screenshots."
        )
    }

    private func notificationSuggestions(trades: [Trade], plans: [MorningPlan], disciplineDays: [DisciplineDay]) -> [String] {
        var suggestions = ["London opens in \(countdown(toHour: 8))."]
        if latestPlanCompletion(from: plans) < 100 {
            suggestions.append("You haven't completed today's checklist.")
        }
        if let latest = trades.first, !Calendar.current.isDateInToday(latest.date), reviewCompletion(for: [latest]) < 100 {
            suggestions.append("You forgot to review yesterday's trade.")
        }
        if currentDisciplineStreak(from: disciplineDays) > 0 {
            suggestions.append("You are one perfect day away from extending your streak.")
        }
        return suggestions
    }

    private func recentLessons(from trades: [Trade]) -> [String] {
        let lessons = trades
            .map(\.lessonsLearned)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(lessons.prefix(5))
    }

    private func latestDisciplineScore(from days: [DisciplineDay], trades: [Trade]) -> Int {
        if let score = days.sorted(by: { $0.date > $1.date }).first?.disciplineScore, score > 0 {
            return score
        }
        return consistencyScore(for: trades)
    }

    private func latestPlanCompletion(from plans: [MorningPlan]) -> Int {
        guard let plan = plans.sorted(by: { $0.date > $1.date }).first,
              let data = plan.checklistRawValue.data(using: .utf8),
              let checklist = try? JSONDecoder().decode([PlanChecklistItem].self, from: data),
              !checklist.isEmpty else {
            return 0
        }
        return Int((Double(checklist.filter(\.isComplete).count) / Double(checklist.count) * 100).rounded())
    }

    private func currentDisciplineStreak(from days: [DisciplineDay]) -> Int {
        let ordered = days.sorted { $0.date > $1.date }
        var count = 0
        for day in ordered {
            if day.disciplineScore >= 75 {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    private func journalCompletion(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let complete = trades.filter { !$0.notes.isEmpty || !$0.tradeThesis.isEmpty || !$0.marketContext.isEmpty || !$0.executionReview.isEmpty || !$0.lessonsLearned.isEmpty }
        return Int((Double(complete.count) / Double(trades.count) * 100).rounded())
    }

    private func reviewCompletion(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let complete = trades.filter { !$0.executionReview.isEmpty || !$0.lessonsLearned.isEmpty }
        return Int((Double(complete.count) / Double(trades.count) * 100).rounded())
    }

    private func screenshotCompletion(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let complete = trades.filter { $0.beforeEntryImageData != nil || $0.duringTradeImageData != nil || $0.afterExitImageData != nil }
        return Int((Double(complete.count) / Double(trades.count) * 100).rounded())
    }

    private func lessonCompletion(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let complete = trades.filter { !$0.lessonsLearned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return Int((Double(complete.count) / Double(trades.count) * 100).rounded())
    }

    private func executionScore(trades: [Trade], reviews: [AITradeReview]) -> Int {
        let explicit = trades.map(\.executionScore).filter { $0 > 0 }
        if !explicit.isEmpty {
            return Int((Double(explicit.reduce(0, +)) / Double(explicit.count)).rounded())
        }
        let ids = Set(trades.map(\.id))
        let reviewScores = reviews.filter { ids.contains($0.tradeID) }.map(\.executionScore)
        return reviewScores.isEmpty ? 70 : Int((Double(reviewScores.reduce(0, +)) / Double(reviewScores.count)).rounded())
    }

    private func psychologyScore(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let majorMistakes = trades.filter { $0.mistakeTags.contains(.revengeTrade) || $0.mistakeTags.contains(.fomo) || $0.mistakeTags.contains(.overtrading) }.count
        return max(0, min(100, 82 - majorMistakes * 6))
    }

    private func consistencyScore(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let followed = Double(trades.filter(\.followedPlan).count) / Double(trades.count)
        let journal = Double(journalCompletion(for: trades)) / 100
        return Int(((followed * 55) + (journal * 45)).rounded())
    }

    private func riskScore(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let risky = trades.filter { $0.riskPercent > 2.5 || $0.mistakeTags.contains(.riskTooHigh) || $0.mistakeTags.contains(.movedStop) }.count
        return max(0, min(100, 88 - risky * 8))
    }

    private func weightedScore(_ scores: [Int]) -> Int {
        let valid = scores.filter { $0 > 0 }
        guard !valid.isEmpty else { return 0 }
        return Int((Double(valid.reduce(0, +)) / Double(valid.count)).rounded())
    }

    private func winRate(for trades: [Trade]) -> Double {
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }
        guard !resolved.isEmpty else { return 0 }
        return Double(resolved.filter { $0.status == .win }.count) / Double(resolved.count) * 100
    }

    private func averageRR(for trades: [Trade]) -> Double {
        let values = trades.map(\.riskReward).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func bestStrategy(for trades: [Trade]) -> (name: String, winRate: Double, averageRR: Double) {
        let grouped = Dictionary(grouping: trades, by: { $0.strategy.rawValue })
        guard let best = grouped.max(by: { netProfit($0.value) < netProfit($1.value) }) else {
            return ("None", 0, 0)
        }
        return (best.key, winRate(for: best.value), averageRR(for: best.value))
    }

    private func rankedGroup(trades: [Trade], value: (Trade) -> String) -> (best: String, worst: String) {
        let grouped = Dictionary(grouping: trades, by: value)
        let ranked = grouped.map { ($0.key, netProfit($0.value)) }.sorted { $0.1 > $1.1 }
        return (ranked.first?.0 ?? "None", ranked.last?.0 ?? "None")
    }

    private func bestDateComponent(trades: [Trade], component: Calendar.Component) -> (best: String, worst: String) {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: trades) { calendar.component(component, from: $0.date) }
        let ranked = grouped.map { (label(for: $0.key, component: component), netProfit($0.value)) }.sorted { $0.1 > $1.1 }
        return (ranked.first?.0 ?? "None", ranked.last?.0 ?? "None")
    }

    private func label(for value: Int, component: Calendar.Component) -> String {
        switch component {
        case .weekday:
            return Calendar.current.weekdaySymbols[max(0, min(6, value - 1))]
        case .month:
            return Calendar.current.monthSymbols[max(0, min(11, value - 1))]
        default:
            return "\(value)"
        }
    }

    private func mostCommonMistake(in trades: [Trade]) -> String {
        var counts: [String: Int] = [:]
        for tag in trades.flatMap(\.mistakeTags) {
            counts[tag.rawValue, default: 0] += 1
        }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.first?.key ?? "None"
    }

    private func maximumDrawdown(for trades: [Trade]) -> Double {
        var peak = 0.0
        var running = 0.0
        var drawdown = 0.0
        for trade in trades.sorted(by: { $0.date < $1.date }) {
            running += trade.profitLoss
            peak = max(peak, running)
            drawdown = min(drawdown, running - peak)
        }
        return drawdown
    }

    private func longestStreak(in trades: [Trade], status: Trade.Status) -> Int {
        var best = 0
        var current = 0
        for trade in trades.sorted(by: { $0.date < $1.date }) {
            if trade.status == status {
                current += 1
                best = max(best, current)
            } else if trade.status != .breakeven {
                current = 0
            }
        }
        return best
    }

    private func averageHoldTime(for trades: [Trade]) -> String {
        let durations = trades.compactMap { trade -> TimeInterval? in
            guard let open = trade.tradeOpenTime, let close = trade.tradeCloseTime else { return nil }
            return close.timeIntervalSince(open)
        }
        guard !durations.isEmpty else { return "Pending" }
        let minutes = Int((durations.reduce(0, +) / Double(durations.count) / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func personality(for trades: [Trade]) -> String {
        let commonStrategy = Dictionary(grouping: trades, by: { $0.strategy.rawValue })
            .max { $0.value.count < $1.value.count }?.key ?? "Process"
        if trades.contains(where: { $0.session == .london }) && averageRR(for: trades) >= 2 {
            return "Patient Trend Trader"
        }
        return "\(commonStrategy) Trader"
    }

    private func confidenceLabel(from values: [Double]) -> String {
        guard !values.isEmpty else { return "Unknown" }
        let average = values.reduce(0, +) / Double(values.count)
        if average >= 7.5 { return "High" }
        if average >= 5 { return "Medium" }
        return "Low"
    }

    private func confidenceSummary(score: Int, discipline: Int, planning: Int, risk: Int, journal: Int) -> AIConfidenceSummary {
        let label: String
        if score >= 80 {
            label = "High Confidence"
        } else if score >= 58 {
            label = "Medium Confidence"
        } else {
            label = "Low Confidence"
        }
        return AIConfidenceSummary(
            score: score,
            label: label,
            explanation: "Based on discipline \(discipline)%, planning \(planning)%, risk \(risk)%, and journal quality \(journal)%."
        )
    }

    private func focusText(trades: [Trade], plans: [MorningPlan]) -> String {
        if latestPlanCompletion(from: plans) < 100 {
            return "Complete your checklist before entering."
        }
        if trades.filter({ Calendar.current.isDateInToday($0.date) }).count >= 3 {
            return "You perform worse after 3 trades. Slow down."
        }
        if mostCommonMistake(in: trades) == Trade.MistakeTag.enteredEarly.rawValue {
            return "Wait for confirmation before entering."
        }
        return "Focus on patience today."
    }

    private func improvementText(for trades: [Trade]) -> String {
        let recent = Array(trades.prefix(10))
        let previous = Array(trades.dropFirst(10).prefix(10))
        let recentJournal = journalCompletion(for: recent)
        let previousJournal = journalCompletion(for: previous)
        let delta = recentJournal - previousJournal
        if delta > 0 {
            return "Journal quality improved \(delta)%."
        }
        return "Patience has increased through consistent reviews."
    }

    private func latestThreeTradeRisk(_ trades: [Trade]) -> Double {
        let values = trades.prefix(3).map(\.riskPercent).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func netProfit(_ trades: [Trade]) -> Double {
        trades.reduce(0) { $0 + $1.profitLoss }
    }

    private func pattern(_ title: String, _ value: String, _ subtitle: String, _ icon: String, _ tint: Color) -> AIIntelligencePattern {
        AIIntelligencePattern(title: title, value: value, subtitle: subtitle, icon: icon, tint: tint)
    }

    private func behaviour(_ title: String, _ trades: [Trade], _ tag: Trade.MistakeTag, _ tint: Color) -> AIBehaviourSignal {
        behaviour(title, trades.filter { $0.mistakeTags.contains(tag) }.count, tint)
    }

    private func behaviour(_ title: String, _ count: Int, _ tint: Color) -> AIBehaviourSignal {
        AIBehaviourSignal(title: title, count: count, trend: count == 0 ? "Clean" : "\(count) detected", tint: tint)
    }

    private func insight(_ title: String, _ subtitle: String, _ icon: String, _ category: String, _ confidence: Int, _ tint: Color) -> AIIntelligenceInsight {
        AIIntelligenceInsight(title: title, subtitle: subtitle, icon: icon, category: category, confidence: confidence, tint: tint)
    }

    private func timeGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        if hour < 17 { return "Good Afternoon" }
        return "Good Evening"
    }

    private func countdown(toHour hour: Int) -> String {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = 0
        components.second = 0
        var target = calendar.date(from: components) ?? now
        if target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
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

    private func rating(for score: Int) -> String {
        switch score {
        case 86...: return "Elite"
        case 72..<86: return "Strong"
        case 55..<72: return "Developing"
        default: return "Needs focus"
        }
    }
}
