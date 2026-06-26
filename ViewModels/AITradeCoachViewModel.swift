import Combine
import Foundation
import SwiftData
import SwiftUI

struct AITradeScoreBreakdown: Identifiable {
    let id = UUID()
    let title: String
    let score: Int
    let explanation: String
    let icon: String
}

@MainActor
final class AITradeCoachViewModel: ObservableObject {
    @Published private(set) var overallScore: Int = 0
    @Published private(set) var grade: String = "C"
    @Published private(set) var gradeSummary: String = "More journal detail will improve this review."
    @Published private(set) var breakdown: [AITradeScoreBreakdown] = []
    @Published private(set) var strengths: [String] = []
    @Published private(set) var improvements: [String] = []
    @Published var showSavedConfirmation = false
    @Published var errorMessage: String?

    private var modelContext: ModelContext?
    private var savedReview: AITradeReview?

    func configure(context: ModelContext, trade: Trade) {
        modelContext = context
        loadSavedReview(for: trade)
        calculatePlaceholderReview(for: trade)
    }

    func saveReview(for trade: Trade) {
        guard let modelContext else {
            errorMessage = "Settings are still loading. Try again in a moment."
            return
        }

        let review = savedReview ?? AITradeReview(
            tradeID: trade.id,
            overallScore: overallScore,
            grade: grade,
            summary: gradeSummary,
            strengths: strengths,
            improvements: improvements,
            executionScore: score(named: "Execution"),
            riskManagementScore: score(named: "Risk Management"),
            psychologyScore: score(named: "Psychology"),
            journalQualityScore: score(named: "Journal Quality"),
            strategyDisciplineScore: score(named: "Strategy Discipline")
        )

        if savedReview == nil {
            modelContext.insert(review)
        }

        review.overallScore = overallScore
        review.grade = grade
        review.summary = gradeSummary
        review.strengths = strengths
        review.improvements = improvements
        review.executionScore = score(named: "Execution")
        review.riskManagementScore = score(named: "Risk Management")
        review.psychologyScore = score(named: "Psychology")
        review.journalQualityScore = score(named: "Journal Quality")
        review.strategyDisciplineScore = score(named: "Strategy Discipline")
        review.updatedAt = Date()

        do {
            try modelContext.save()
            savedReview = review
            showSavedConfirmation = true
        } catch {
            errorMessage = "Could not save this placeholder review."
        }
    }

    func durationText(for trade: Trade) -> String {
        guard
            let openTime = trade.tradeOpenTime,
            let closeTime = trade.tradeCloseTime
        else {
            return "Open-ended"
        }

        let duration = closeTime.timeIntervalSince(openTime)
        guard duration > 0 else {
            return "0m"
        }

        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    func journalLength(for trade: Trade) -> Int {
        [
            trade.tradeThesis,
            trade.marketContext,
            trade.executionReview,
            trade.lessonsLearned,
            trade.notes
        ]
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .count
    }

    func screenshotCount(for trade: Trade) -> Int {
        [
            trade.beforeEntryImageData,
            trade.duringTradeImageData,
            trade.afterExitImageData
        ]
        .compactMap { $0 }
        .count
    }

    private func loadSavedReview(for trade: Trade) {
        guard let modelContext else {
            return
        }

        let tradeID = trade.id
        let descriptor = FetchDescriptor<AITradeReview>(
            predicate: #Predicate { review in
                review.tradeID == tradeID
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        savedReview = try? modelContext.fetch(descriptor).first
    }

    private func calculatePlaceholderReview(for trade: Trade) {
        let execution = executionScore(for: trade)
        let risk = riskManagementScore(for: trade)
        let psychology = psychologyScore(for: trade)
        let journal = journalQualityScore(for: trade)
        let strategy = strategyDisciplineScore(for: trade)

        breakdown = [
            AITradeScoreBreakdown(
                title: "Execution",
                score: execution,
                explanation: execution >= 85 ? "Excellent entry location and clean execution." : "Execution can improve with clearer confirmation and timing.",
                icon: "scope"
            ),
            AITradeScoreBreakdown(
                title: "Risk Management",
                score: risk,
                explanation: risk >= 85 ? "Risk stayed controlled with a strong reward profile." : "Tighten risk, position sizing, or target quality.",
                icon: "shield.lefthalf.filled"
            ),
            AITradeScoreBreakdown(
                title: "Psychology",
                score: psychology,
                explanation: psychology >= 85 ? "Emotional control supported the trade plan." : "Review emotion, confidence, and rule adherence.",
                icon: "brain.head.profile"
            ),
            AITradeScoreBreakdown(
                title: "Journal Quality",
                score: journal,
                explanation: journal >= 85 ? "Strong notes and screenshots create a useful review trail." : "Add richer notes and chart screenshots for better coaching.",
                icon: "book.pages"
            ),
            AITradeScoreBreakdown(
                title: "Strategy Discipline",
                score: strategy,
                explanation: strategy >= 85 ? "The setup stayed aligned with your documented plan." : "Remove rule breaks and clarify setup criteria.",
                icon: "checklist.checked"
            )
        ]

        overallScore = clamp(Int(Double(execution + risk + psychology + journal + strategy) / 5.0))
        grade = letterGrade(for: overallScore)
        gradeSummary = gradeSummary(for: overallScore)
        strengths = strengths(for: trade)
        improvements = improvements(for: trade)
    }

    private func executionScore(for trade: Trade) -> Int {
        var score = trade.executionScore > 0 ? trade.executionScore * 20 : 62

        if trade.followedPlan {
            score += 10
        }

        if trade.mistakeTags.contains(.enteredEarly) || trade.mistakeTags.contains(.enteredLate) {
            score -= 14
        }

        if trade.mistakeTags.contains(.goodDiscipline) {
            score += 10
        }

        return clamp(score)
    }

    private func riskManagementScore(for trade: Trade) -> Int {
        var score = 68

        if trade.riskPercent > 0, trade.riskPercent <= 1 {
            score += 18
        } else if trade.riskPercent > 0, trade.riskPercent <= 2 {
            score += 12
        } else if trade.riskPercent > 3 {
            score -= 24
        }

        if trade.riskReward >= 2 {
            score += 12
        } else if trade.riskReward >= 1 {
            score += 4
        } else {
            score -= 8
        }

        if trade.mistakeTags.contains(.riskTooHigh) || trade.mistakeTags.contains(.movedStop) {
            score -= 18
        }

        return clamp(score)
    }

    private func psychologyScore(for trade: Trade) -> Int {
        var score = 72
        let difficultEmotions = ["Fear", "Greedy", "Revenge", "Frustrated", "Overconfident", "Nervous"]

        if trade.followedPlan {
            score += 12
        } else {
            score -= 20
        }

        if difficultEmotions.contains(trade.emotion) {
            score -= 14
        }

        if trade.confidence >= 7, trade.confidence <= 9 {
            score += 8
        } else if trade.confidence <= 3 {
            score -= 10
        }

        if trade.mistakeTags.contains(.fomo) || trade.mistakeTags.contains(.revengeTrade) || trade.mistakeTags.contains(.overtrading) {
            score -= 18
        }

        return clamp(score)
    }

    private func journalQualityScore(for trade: Trade) -> Int {
        var score = 48
        let length = journalLength(for: trade)

        if length > 700 {
            score += 34
        } else if length > 300 {
            score += 24
        } else if length > 100 {
            score += 14
        }

        score += screenshotCount(for: trade) * 8

        return clamp(score)
    }

    private func strategyDisciplineScore(for trade: Trade) -> Int {
        var score = 70

        if trade.strategy != .other {
            score += 10
        }

        if trade.followedPlan {
            score += 10
        }

        if trade.mistakeTags.contains(.brokeRules) || trade.mistakeTags.contains(.ignoredPlan) || trade.mistakeTags.contains(.noConfirmation) {
            score -= 24
        }

        return clamp(score)
    }

    private func strengths(for trade: Trade) -> [String] {
        var items: [String] = []

        if trade.riskPercent == 0 || trade.riskPercent <= 2 {
            items.append("Risk respected")
        }

        if trade.followedPlan {
            items.append("Entry matched plan")
        }

        if trade.riskReward >= 2 {
            items.append("Good R:R")
        }

        if ["Calm", "Confident", "Focused", "Neutral"].contains(trade.emotion) {
            items.append("Emotional control")
        }

        if trade.status == .win {
            items.append("Converted setup into profit")
        }

        return items.isEmpty ? ["Completed the review process", "Captured useful trade data"] : items
    }

    private func improvements(for trade: Trade) -> [String] {
        var items: [String] = []

        if trade.mistakeTags.contains(.enteredEarly) {
            items.append("Wait for candle close.")
        }

        if trade.mistakeTags.contains(.overtrading) || trade.mistakeTags.contains(.revengeTrade) {
            items.append("Reduce overtrading.")
        }

        if trade.mistakeTags.contains(.closedEarly) {
            items.append("Hold winners longer.")
        }

        if trade.mistakeTags.contains(.fomo) {
            items.append("Avoid early entries.")
        }

        if journalLength(for: trade) < 100 {
            items.append("Add more journal detail.")
        }

        if screenshotCount(for: trade) == 0 {
            items.append("Attach chart screenshots.")
        }

        return items.isEmpty ? ["Keep documenting the setup and execution.", "Review whether the exit followed the original thesis."] : items
    }

    private func score(named title: String) -> Int {
        breakdown.first { $0.title == title }?.score ?? 0
    }

    private func letterGrade(for score: Int) -> String {
        switch score {
        case 96...100:
            return "A+"
        case 90...95:
            return "A"
        case 80...89:
            return "B"
        case 70...79:
            return "C"
        case 60...69:
            return "D"
        default:
            return "F"
        }
    }

    private func gradeSummary(for score: Int) -> String {
        switch score {
        case 90...100:
            return "Excellent discipline. Minor execution improvements remain."
        case 80...89:
            return "Strong trade quality with a few areas to refine."
        case 70...79:
            return "Solid foundation. Improve consistency and journal detail."
        case 60...69:
            return "Review risk, execution, and emotional control before the next setup."
        default:
            return "This trade needs deeper review before repeating the setup."
        }
    }

    private func clamp(_ score: Int) -> Int {
        min(max(score, 0), 100)
    }
}
