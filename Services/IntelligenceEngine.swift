import Foundation
import SwiftData

enum IntelligenceEvent {
    case morningPlanCompleted
    case tradeSaved
    case tradeEdited
    case tradeDeleted
    case replayCompleted
    case aiReviewSaved
    case pdfExported
    case analyticsUpdated
    case checklistCompleted
    case goalAchieved
    case achievementUnlocked
    case calendarSessionCompleted
}

struct InsightDraft {
    let title: String
    let subtitle: String
    let icon: String
    let priority: Int
    let category: Insight.Category
    let confidence: Double
    let relatedTradeID: UUID?
    let fingerprint: String
}

private struct SessionAggregate {
    let session: Trade.Session
    let trades: [Trade]
    let profit: Double
}

private struct MarketAggregate {
    let pair: String
    let trades: [Trade]
    let profit: Double
}

private struct WeekdayAggregate {
    let weekday: Int
    let trades: [Trade]
    let winRate: Double
}

@MainActor
final class IntelligenceEngine {
    private let context: ModelContext
    private let repository: InsightRepository
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.repository = InsightRepository(context: context)
        self.calendar = calendar
    }

    func observe(_ event: IntelligenceEvent) {
        do {
            try refreshInsights(trigger: event)
        } catch {
            assertionFailure("Unable to refresh insights: \(error)")
        }
    }

    func refreshInsights(trigger: IntelligenceEvent = .analyticsUpdated) throws {
        let trades = try context.fetch(FetchDescriptor<Trade>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        let reviews = try context.fetch(FetchDescriptor<AITradeReview>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        let days = try context.fetch(FetchDescriptor<DisciplineDay>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        let achievements = try context.fetch(FetchDescriptor<Achievement>(sortBy: [SortDescriptor(\.title)]))
        let plans = try context.fetch(FetchDescriptor<MorningPlan>(sortBy: [SortDescriptor(\.date, order: .reverse)]))

        var drafts: [InsightDraft] = []
        drafts += sessionInsights(from: trades)
        drafts += riskInsights(from: trades)
        drafts += executionInsights(from: trades)
        drafts += psychologyInsights(from: trades, reviews: reviews)
        drafts += marketInsights(from: trades)
        drafts += weekdayInsights(from: trades)
        drafts += disciplineInsights(days: days, achievements: achievements, plans: plans)
        drafts += improvementInsights(from: trades, reviews: reviews)

        if let latest = trades.first {
            drafts.append(InsightDraft(
                title: "Latest trade connected",
                subtitle: "\(latest.pair) now informs your coaching, replay, analytics, and discipline score.",
                icon: "link.circle.fill",
                priority: 58,
                category: .execution,
                confidence: 0.78,
                relatedTradeID: latest.id,
                fingerprint: "latest-trade-\(latest.id.uuidString)"
            ))
        }

        let prioritizedDrafts = drafts.sorted {
            if $0.priority == $1.priority {
                return $0.confidence > $1.confidence
            }
            return $0.priority > $1.priority
        }
        try repository.upsert(Array(prioritizedDrafts.prefix(24)))
    }

    func insightsForReplayCompletion(trade: Trade) -> [InsightDraft] {
        [
            InsightDraft(
                title: "Lessons learned added",
                subtitle: replayLesson(for: trade),
                icon: "lightbulb.max.fill",
                priority: 82,
                category: .replay,
                confidence: 0.86,
                relatedTradeID: trade.id,
                fingerprint: "replay-lesson-\(trade.id.uuidString)"
            )
        ]
    }

    private func sessionInsights(from trades: [Trade]) -> [InsightDraft] {
        let grouped = Dictionary(grouping: trades, by: \.session)
        let aggregates = grouped.map { session, trades in
            SessionAggregate(session: session, trades: trades, profit: trades.reduce(0) { $0 + $1.profitLoss })
        }
        guard let best = aggregates.max(by: { $0.profit < $1.profit }) else {
            return []
        }

        return [
            InsightDraft(
                title: "You perform best during \(best.session.rawValue).",
                subtitle: "\(best.trades.count) trades produced \(currency(best.profit)) net P/L in this session.",
                icon: "clock.badge.checkmark.fill",
                priority: 88,
                category: .performance,
                confidence: min(0.96, 0.55 + Double(best.trades.count) * 0.05),
                relatedTradeID: best.trades.sorted { $0.date > $1.date }.first?.id,
                fingerprint: "best-session-\(best.session.rawValue)"
            )
        ]
    }

    private func riskInsights(from trades: [Trade]) -> [InsightDraft] {
        let sorted = trades.sorted { $0.date > $1.date }
        let respected = sorted.prefix { $0.riskPercent == 0 || $0.riskPercent <= 2 }.count
        guard respected > 0 else { return [] }

        return [
            InsightDraft(
                title: "You've respected risk for \(respected) consecutive trades.",
                subtitle: "Keep position sizing boring. That is where longevity comes from.",
                icon: "shield.checkered",
                priority: min(96, 70 + respected),
                category: .risk,
                confidence: 0.82,
                relatedTradeID: sorted.first?.id,
                fingerprint: "risk-streak-\(respected)"
            )
        ]
    }

    private func executionInsights(from trades: [Trade]) -> [InsightDraft] {
        let wins = trades.filter { $0.status == .win }
        let closedEarly = wins.filter { $0.mistakeTags.contains(.closedEarly) }
        guard wins.count >= 3, !closedEarly.isEmpty else { return [] }

        return [
            InsightDraft(
                title: "You exited early on \(closedEarly.count) of your last \(min(10, wins.count)) winning trades.",
                subtitle: "Review winner management and whether exits followed the original thesis.",
                icon: "arrow.down.forward.circle.fill",
                priority: 84,
                category: .execution,
                confidence: 0.79,
                relatedTradeID: closedEarly.sorted { $0.date > $1.date }.first?.id,
                fingerprint: "closed-early-wins-\(closedEarly.count)"
            )
        ]
    }

    private func psychologyInsights(from trades: [Trade], reviews: [AITradeReview]) -> [InsightDraft] {
        var drafts: [InsightDraft] = []
        let sorted = trades.sorted { $0.date > $1.date }
        let calmStreak = sorted.prefix { trade in
            !trade.mistakeTags.contains(.fomo)
                && !trade.mistakeTags.contains(.revengeTrade)
                && !trade.mistakeTags.contains(.overtrading)
                && trade.emotion != "Revenge"
        }.count

        if calmStreak > 0 {
            drafts.append(InsightDraft(
                title: "You haven't traded emotionally in \(calmStreak) trades.",
                subtitle: "Psychology is becoming a repeatable part of the process.",
                icon: "brain.head.profile",
                priority: 86,
                category: .psychology,
                confidence: 0.80,
                relatedTradeID: sorted.first?.id,
                fingerprint: "calm-streak-\(calmStreak)"
            ))
        }

        if reviews.count >= 2, let latest = reviews.first, let previous = reviews.dropFirst().first, latest.psychologyScore > previous.psychologyScore {
            drafts.append(InsightDraft(
                title: "Psychology score improved.",
                subtitle: "Latest review increased from \(previous.psychologyScore) to \(latest.psychologyScore).",
                icon: "arrow.up.heart.fill",
                priority: 80,
                category: .psychology,
                confidence: 0.77,
                relatedTradeID: latest.tradeID,
                fingerprint: "psychology-improved-\(latest.id.uuidString)"
            ))
        }

        return drafts
    }

    private func marketInsights(from trades: [Trade]) -> [InsightDraft] {
        let grouped = Dictionary(grouping: trades, by: \.pair)
        let aggregates = grouped.map { pair, trades in
            MarketAggregate(pair: pair, trades: trades, profit: trades.reduce(0) { $0 + $1.profitLoss })
        }
        guard let best = aggregates.filter({ $0.trades.count >= 2 }).max(by: { $0.profit < $1.profit }) else {
            return []
        }

        return [
            InsightDraft(
                title: "\(best.pair) has become your strongest market.",
                subtitle: "\(best.trades.count) logged trades, \(currency(best.profit)) net performance.",
                icon: "star.circle.fill",
                priority: 83,
                category: .performance,
                confidence: min(0.94, 0.58 + Double(best.trades.count) * 0.04),
                relatedTradeID: best.trades.sorted { $0.date > $1.date }.first?.id,
                fingerprint: "best-market-\(best.pair)"
            )
        ]
    }

    private func weekdayInsights(from trades: [Trade]) -> [InsightDraft] {
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }
        let grouped = Dictionary(grouping: resolved) { calendar.component(.weekday, from: $0.date) }
        let aggregates = grouped.map { weekday, trades in
            let wins = trades.filter { $0.status == .win }.count
            let winRate = Double(wins) / Double(max(trades.count, 1)) * 100
            return WeekdayAggregate(weekday: weekday, trades: trades, winRate: winRate)
        }
        guard let best = aggregates.filter({ $0.trades.count >= 2 }).max(by: { $0.winRate < $1.winRate }) else {
            return []
        }

        return [
            InsightDraft(
                title: "\(weekdayName(best.weekday)) has your highest win rate.",
                subtitle: "\(Int(best.winRate.rounded()))% across \(best.trades.count) resolved trades.",
                icon: "calendar.badge.checkmark",
                priority: 76,
                category: .performance,
                confidence: 0.72,
                relatedTradeID: best.trades.sorted { $0.date > $1.date }.first?.id,
                fingerprint: "best-weekday-\(best.weekday)"
            )
        ]
    }

    private func disciplineInsights(days: [DisciplineDay], achievements: [Achievement], plans: [MorningPlan]) -> [InsightDraft] {
        var drafts: [InsightDraft] = []
        let streak = currentDisciplineStreak(days: days)
        if streak > 0 {
            drafts.append(InsightDraft(
                title: streak == 6 ? "Discipline streak reaches 7 days tomorrow." : "Current discipline streak: \(streak) days.",
                subtitle: "Plan, risk, and journal consistency are compounding.",
                icon: "flame.fill",
                priority: streak >= 6 ? 92 : 78,
                category: .discipline,
                confidence: 0.82,
                relatedTradeID: nil,
                fingerprint: "discipline-streak-\(streak)"
            ))
        }

        if let unlocked = achievements.first(where: { $0.unlockedDate != nil }) {
            drafts.append(InsightDraft(
                title: "Achievement unlocked: \(unlocked.title)",
                subtitle: unlocked.achievementDescription,
                icon: unlocked.symbolName,
                priority: 74,
                category: .discipline,
                confidence: 0.88,
                relatedTradeID: nil,
                fingerprint: "achievement-\(unlocked.kind.rawValue)"
            ))
        }

        if let today = plans.first(where: { calendar.isDate($0.date, inSameDayAs: Date()) }) {
            drafts.append(InsightDraft(
                title: "Today's plan bias is \(today.bias.rawValue).",
                subtitle: "Use the plan as your filter before taking the next setup.",
                icon: "sunrise.fill",
                priority: 60,
                category: .planning,
                confidence: 0.70,
                relatedTradeID: nil,
                fingerprint: "today-plan-\(calendar.startOfDay(for: Date()).timeIntervalSince1970)"
            ))
        }

        return drafts
    }

    private func improvementInsights(from trades: [Trade], reviews: [AITradeReview]) -> [InsightDraft] {
        guard trades.count >= 4 else { return [] }
        let sorted = trades.sorted { $0.date < $1.date }
        let midpoint = sorted.count / 2
        let firstRR = averageRR(Array(sorted.prefix(midpoint)))
        let secondRR = averageRR(Array(sorted.suffix(sorted.count - midpoint)))
        guard firstRR > 0, secondRR > firstRR else { return [] }
        let increase = ((secondRR - firstRR) / firstRR * 100).rounded()

        return [
            InsightDraft(
                title: "Average RR increased by \(Int(increase))%.",
                subtitle: "Your later trades show stronger planned reward relative to risk.",
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                priority: 81,
                category: .risk,
                confidence: 0.76,
                relatedTradeID: sorted.last?.id,
                fingerprint: "rr-improved-\(Int(increase))"
            ),
            InsightDraft(
                title: "You improve after reviewing trades.",
                subtitle: "\(reviews.count) saved AI reviews are feeding better decision quality.",
                icon: "book.pages.fill",
                priority: reviews.isEmpty ? 42 : 79,
                category: .discipline,
                confidence: reviews.isEmpty ? 0.52 : 0.78,
                relatedTradeID: sorted.last?.id,
                fingerprint: "review-improvement-\(reviews.count)"
            )
        ]
    }

    private func replayLesson(for trade: Trade) -> String {
        if trade.mistakeTags.contains(.closedEarly) {
            return "Replay suggests focusing on holding winners until the original thesis is invalidated."
        }
        if trade.mistakeTags.contains(.fomo) || trade.mistakeTags.contains(.enteredEarly) {
            return "Replay highlights patience before entry as the next execution edge."
        }
        if trade.status == .win {
            return "Replay confirms the value of repeating the same preparation and risk process."
        }
        return "Replay complete. Capture one clear lesson before the next trade."
    }

    private func currentDisciplineStreak(days: [DisciplineDay]) -> Int {
        let daysByDate = Dictionary(uniqueKeysWithValues: days.map { (calendar.startOfDay(for: $0.date), $0) })
        var cursor = calendar.startOfDay(for: Date())
        var count = 0
        while let day = daysByDate[cursor], day.disciplineScore >= 80 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private func averageRR(_ trades: [Trade]) -> Double {
        let values = trades.map(\.riskReward).filter { $0 > 0 }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private func weekdayName(_ weekday: Int) -> String {
        calendar.weekdaySymbols[max(0, min(weekday - 1, calendar.weekdaySymbols.count - 1))]
    }

    private func currency(_ value: Double) -> String {
        "\(value >= 0 ? "+" : "-")$\(Int(abs(value)).formatted())"
    }
}
