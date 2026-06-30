import Foundation
import SwiftData

struct DisciplineRings {
    let plan: Double
    let risk: Double
    let journal: Double
}

struct DisciplineSnapshot {
    let score: Int
    let rings: DisciplineRings
    let currentDisciplineStreak: Int
    let longestDisciplineStreak: Int
    let greenDayStreak: Int
    let journalStreak: Int
    let planStreak: Int
    let totalXP: Int
    let level: Int
    let progressToNextLevel: Double
    let achievements: [Achievement]
    let recentDays: [DisciplineDay]
}

@MainActor
final class DisciplineTracker {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func snapshot() throws -> DisciplineSnapshot {
        try ensureAchievementsExist()
        try refreshToday()
        try refreshAchievements()

        let achievements = try fetchAchievements()
        let days = try fetchDays()
        let today = try day(for: Date())
        let totalXP = days.reduce(0) { $0 + $1.xpEarned }
        let level = max(1, totalXP / 100 + 1)
        let progress = Double(totalXP % 100) / 100.0

        return DisciplineSnapshot(
            score: today.disciplineScore,
            rings: DisciplineRings(plan: today.planProgress, risk: today.riskProgress, journal: today.journalProgress),
            currentDisciplineStreak: streak(in: days) { $0.disciplineScore >= 80 },
            longestDisciplineStreak: longestStreak(in: days) { $0.disciplineScore >= 80 },
            greenDayStreak: try greenDayStreak(),
            journalStreak: streak(in: days) { $0.journalProgress >= 1 },
            planStreak: streak(in: days) { $0.planProgress >= 1 },
            totalXP: totalXP,
            level: level,
            progressToNextLevel: progress,
            achievements: achievements,
            recentDays: Array(days.prefix(14))
        )
    }

    func recordPlanProgress(checklistCompletion: Double) {
        do {
            let today = try day(for: Date())
            let wasComplete = today.planProgress >= 1
            today.checklistCompletion = clamped(checklistCompletion)
            today.planProgress = clamped(checklistCompletion)
            if today.planProgress >= 1, !wasComplete {
                today.xpEarned += 10
            }
            updateScore(for: today)
            try refreshAchievements()
            try context.save()
        } catch {
            assertionFailure("Unable to record plan progress: \(error)")
        }
    }

    func recordTradeSaved(_ trade: Trade) {
        do {
            let day = try day(for: trade.date)
            day.tradesLogged += 1
            day.xpEarned += 10
            refreshTradeDerivedValues(for: day)
            updateScore(for: day)
            try refreshAchievements()
            try context.save()
        } catch {
            assertionFailure("Unable to record saved trade: \(error)")
        }
    }

    func recordTradeReviewCompleted(_ trade: Trade) {
        do {
            let day = try day(for: trade.date)
            day.reviewsCompleted = max(day.reviewsCompleted, 1)
            day.xpEarned += 15
            if trade.followedPlan {
                day.xpEarned += 20
            }
            refreshTradeDerivedValues(for: day)
            updateScore(for: day)
            try refreshAchievements()
            try context.save()
        } catch {
            assertionFailure("Unable to record trade review: \(error)")
        }
    }

    func recordAIReviewSaved(for trade: Trade) {
        do {
            let day = try day(for: trade.date)
            day.aiReviewsSaved += 1
            day.journalProgress = max(day.journalProgress, 1)
            updateScore(for: day)
            try unlock(.firstAIReviewSaved)
            try context.save()
        } catch {
            assertionFailure("Unable to record AI review: \(error)")
        }
    }

    func recordReplayViewed(for trade: Trade) {
        do {
            let day = try day(for: trade.date)
            day.replaysViewed += 1
            try unlock(.firstTradeReplayViewed)
            try context.save()
        } catch {
            assertionFailure("Unable to record replay view: \(error)")
        }
    }

    func recordPDFReportExported() {
        do {
            let today = try day(for: Date())
            today.reportsExported += 1
            try unlock(.firstPDFReportExported)
            try context.save()
        } catch {
            assertionFailure("Unable to record report export: \(error)")
        }
    }

    func recordDailyMissionCompleted() {
        do {
            let today = try day(for: Date())
            today.xpEarned += 10
            today.planProgress = max(today.planProgress, 0.35)
            updateScore(for: today)
            try context.save()
        } catch {
            assertionFailure("Unable to record daily mission: \(error)")
        }
    }

    private func refreshToday() throws {
        let today = try day(for: Date())
        if let plan = try fetchPlan(for: Date()) {
            let completion = checklistCompletion(from: plan)
            today.checklistCompletion = completion
            today.planProgress = completion
        }
        refreshTradeDerivedValues(for: today)
        updateScore(for: today)
        try context.save()
    }

    private func refreshTradeDerivedValues(for day: DisciplineDay) {
        let dayTrades = (try? fetchTrades(on: day.date)) ?? []
        let reviewedTrades = dayTrades.filter { hasJournal(for: $0) }
        let followed = dayTrades.filter(\.followedPlan)
        let majorMistakes = dayTrades.reduce(0) { partial, trade in
            partial + trade.mistakeTags.filter(Self.isMajorMistake).count
        }
        let riskRespected = dayTrades.filter { $0.riskPercent <= 2 || $0.riskPercent == 0 }.count

        day.tradesLogged = max(day.tradesLogged, dayTrades.count)
        day.reviewsCompleted = max(day.reviewsCompleted, reviewedTrades.count)
        day.followedPlanTrades = followed.count
        day.majorMistakes = majorMistakes
        day.riskProgress = dayTrades.isEmpty ? 0 : Double(riskRespected) / Double(dayTrades.count)
        day.journalProgress = dayTrades.isEmpty ? min(day.journalProgress, 1) : Double(reviewedTrades.count) / Double(dayTrades.count)
    }

    private func updateScore(for day: DisciplineDay) {
        let planScore = day.planProgress * 25
        let riskScore = day.riskProgress * 25
        let journalScore = day.journalProgress * 20
        let followedPlanScore = day.tradesLogged == 0 ? 8 : (Double(day.followedPlanTrades) / Double(max(day.tradesLogged, 1))) * 15
        let aiScore = day.aiReviewsSaved > 0 ? 7.0 : 0
        let mistakeScore = day.majorMistakes == 0 ? 8.0 : max(0, 8.0 - Double(day.majorMistakes * 3))
        let score = Int((planScore + riskScore + journalScore + followedPlanScore + aiScore + mistakeScore).rounded())

        let previousScore = day.disciplineScore
        day.disciplineScore = min(100, max(0, score))
        if previousScore < 100, day.disciplineScore == 100 {
            day.xpEarned += 25
        }
        day.updatedAt = Date()
    }

    private func refreshAchievements() throws {
        try ensureAchievementsExist()
        let trades = try fetchTrades()
        let days = try fetchDays()

        if !trades.isEmpty {
            try unlock(.firstTradeLogged)
        }

        if trades.count >= 10 { try unlock(.tenTradesLogged) }
        if trades.count >= 25 { try unlock(.twentyFiveTradesLogged) }
        if trades.count >= 50 { try unlock(.fiftyTradesLogged) }
        if trades.count >= 100 { try unlock(.hundredTradesLogged) }
        if tradesByDay(trades).values.contains(where: { dayTrades in dayTrades.reduce(0) { $0 + $1.profitLoss } > 0 }) {
            try unlock(.firstGreenDay)
        }
        if hasGreenWeek(trades) {
            try unlock(.firstGreenWeek)
        }
        if longestStreak(in: days) { $0.disciplineScore >= 80 } >= 7 {
            try unlock(.sevenDayDisciplineStreak)
        }
        if longestStreak(in: days) { $0.disciplineScore >= 80 } >= 30 {
            try unlock(.thirtyDayDisciplineStreak)
        }
        if days.contains(where: { $0.tradesLogged > 0 && $0.majorMistakes == 0 }) {
            try unlock(.zeroRuleBreakDay)
        }
        if hasPerfectRiskWeek(trades) {
            try unlock(.perfectRiskWeek)
        }
    }

    private func ensureAchievementsExist() throws {
        let existingKinds = Set(try fetchAchievements().map(\.kind))
        for kind in AchievementKind.allCases where !existingKinds.contains(kind) {
            context.insert(Achievement(
                kind: kind,
                title: kind.title,
                achievementDescription: kind.description,
                symbolName: kind.symbolName
            ))
        }
        try context.save()
    }

    private func unlock(_ kind: AchievementKind) throws {
        try ensureAchievementsExist()
        let kindRawValue = kind.rawValue
        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate { achievement in
                achievement.kindRawValue == kindRawValue
            }
        )

        if let achievement = try context.fetch(descriptor).first, achievement.unlockedDate == nil {
            achievement.unlockedDate = Date()
        }
    }

    private func day(for date: Date) throws -> DisciplineDay {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw CocoaError(.featureUnsupported)
        }

        let descriptor = FetchDescriptor<DisciplineDay>(
            predicate: #Predicate { day in
                day.date >= start && day.date < end
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let created = DisciplineDay(date: start)
        context.insert(created)
        try context.save()
        return created
    }

    private func fetchDays() throws -> [DisciplineDay] {
        try context.fetch(FetchDescriptor<DisciplineDay>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
    }

    private func fetchAchievements() throws -> [Achievement] {
        try context.fetch(FetchDescriptor<Achievement>(sortBy: [SortDescriptor(\.title)]))
    }

    private func fetchTrades() throws -> [Trade] {
        try context.fetch(FetchDescriptor<Trade>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
    }

    private func fetchTrades(on date: Date) throws -> [Trade] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return []
        }
        let descriptor = FetchDescriptor<Trade>(
            predicate: #Predicate { trade in
                trade.date >= start && trade.date < end
            }
        )
        return try context.fetch(descriptor)
    }

    private func fetchPlan(for date: Date) throws -> MorningPlan? {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        let descriptor = FetchDescriptor<MorningPlan>(
            predicate: #Predicate { plan in
                plan.date >= start && plan.date < end
            }
        )
        return try context.fetch(descriptor).first
    }

    private func checklistCompletion(from plan: MorningPlan) -> Double {
        guard let data = plan.checklistRawValue.data(using: .utf8),
              let checklist = try? JSONDecoder().decode([PlanChecklistItem].self, from: data),
              !checklist.isEmpty else {
            return 0
        }

        return Double(checklist.filter(\.isComplete).count) / Double(checklist.count)
    }

    private func hasJournal(for trade: Trade) -> Bool {
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

    private static func isMajorMistake(_ tag: Trade.MistakeTag) -> Bool {
        switch tag {
        case .fomo, .revengeTrade, .brokeRules, .ignoredPlan, .overtrading, .riskTooHigh, .movedStop:
            return true
        default:
            return false
        }
    }

    private func streak(in days: [DisciplineDay], condition: (DisciplineDay) -> Bool) -> Int {
        var count = 0
        var cursor = calendar.startOfDay(for: Date())
        let daysByStart = Dictionary(uniqueKeysWithValues: days.map { (calendar.startOfDay(for: $0.date), $0) })

        while let day = daysByStart[cursor], condition(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return count
    }

    private func longestStreak(in days: [DisciplineDay], condition: (DisciplineDay) -> Bool) -> Int {
        let ordered = days.sorted { $0.date < $1.date }
        var current = 0
        var longest = 0

        for day in ordered {
            if condition(day) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }

        return longest
    }

    private func greenDayStreak() throws -> Int {
        let grouped = tradesByDay(try fetchTrades())
        var cursor = calendar.startOfDay(for: Date())
        var count = 0

        while let dayTrades = grouped[cursor], dayTrades.reduce(0, { $0 + $1.profitLoss }) > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return count
    }

    private func tradesByDay(_ trades: [Trade]) -> [Date: [Trade]] {
        Dictionary(grouping: trades) { calendar.startOfDay(for: $0.date) }
    }

    private func hasGreenWeek(_ trades: [Trade]) -> Bool {
        Dictionary(grouping: trades) { trade in
            calendar.dateInterval(of: .weekOfYear, for: trade.date)?.start ?? calendar.startOfDay(for: trade.date)
        }
        .values
        .contains { weekTrades in
            weekTrades.reduce(0) { $0 + $1.profitLoss } > 0
        }
    }

    private func hasPerfectRiskWeek(_ trades: [Trade]) -> Bool {
        Dictionary(grouping: trades) { trade in
            calendar.dateInterval(of: .weekOfYear, for: trade.date)?.start ?? calendar.startOfDay(for: trade.date)
        }
        .values
        .contains { weekTrades in
            !weekTrades.isEmpty && weekTrades.allSatisfy { $0.riskPercent <= 2 || $0.riskPercent == 0 }
        }
    }

    private func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
