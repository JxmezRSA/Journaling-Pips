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
    @Published private(set) var mistakes: [String] = []
    @Published private(set) var psychologyNotes = "No psychology notes generated yet."
    @Published private(set) var nextTradeFocus = "Document the next trade with clear thesis, context, and lessons."
    @Published private(set) var riskFeedback = "Risk feedback will appear after analysis."
    @Published private(set) var patternWarnings: [String] = []
    @Published private(set) var confidenceLevel = "Preview"
    @Published private(set) var visionAnalysis: VisionAnalysisResponse?
    @Published private(set) var isAnalyzingVision = false
    @Published private(set) var isAnalyzing = false
    @Published private(set) var analysisNotice = "AI backend is not connected yet. Showing local coaching preview."
    @Published private(set) var hasGeneratedReview = false
    @Published private(set) var hasSavedReview = false
    @Published var showSavedConfirmation = false
    @Published var errorMessage: String?

    private var modelContext: ModelContext?
    private var savedReview: AITradeReview?
    private let aiService = AIService()
    private let visionService = VisionAnalysisService()

    func configure(context: ModelContext, trade: Trade) {
        modelContext = context
        loadSavedReview(for: trade)
        calculatePlaceholderReview(for: trade)
        if let savedReview {
            apply(savedReview)
            hasSavedReview = true
            analysisNotice = "Saved review loaded from this device."
        }
        analyzeChartContext(for: trade)
    }

    func analyzeTrade(_ trade: Trade) {
        Task {
            await runAnalysis(for: trade)
        }
    }

    func analyzeAndSaveReview(for trade: Trade) {
        Task {
            await runAnalysis(for: trade, saveAfterAnalysis: true)
        }
    }

    func regenerateReview(for trade: Trade) {
        JPHaptics.impact(.medium)
        Task {
            await runAnalysis(for: trade)
        }
    }

    func analyzeChartContext(for trade: Trade) {
        guard let modelContext else {
            return
        }

        Task {
            isAnalyzingVision = true
            visionAnalysis = await visionService.analyze(trade: trade, context: modelContext)
            isAnalyzingVision = false
        }
    }

    func saveReview(for trade: Trade) {
        guard let modelContext else {
            errorMessage = "Settings are still loading. Try again in a moment."
            return
        }

        let review = AITradeReview(
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
        modelContext.insert(review)

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
            debugPrint("AI REVIEW CACHED")
            debugPrint("AI REVIEW SAVED LOCALLY")
            debugPrint("AI REVIEW HISTORY UPDATED")
            queueAIReviewSync(review, context: modelContext)
            DisciplineTracker(context: modelContext).recordAIReviewSaved(for: trade)
            IntelligenceEngine(context: modelContext).observe(.aiReviewSaved)
            savedReview = review
            hasSavedReview = true
            showSavedConfirmation = true
            JPHaptics.notify(.success)
        } catch {
            debugPrint("AI REVIEW FAILED:", String(describing: error))
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

    private func runAnalysis(for trade: Trade, saveAfterAnalysis: Bool = false) async {
        debugPrint("AI REVIEW START")
        debugPrint("BEGIN AI TRADE REVIEW")
        defer { debugPrint("END AI TRADE REVIEW") }

        guard let modelContext else {
            debugPrint("AI REVIEW FAILED:", "Model context missing")
            errorMessage = "Settings are still loading. Try again in a moment."
            return
        }

        isAnalyzing = true
        errorMessage = nil

        do {
            let response = try await aiService.analyzeTrade(trade, context: modelContext)
            apply(response)
            analysisNotice = "AI review generated from the configured backend."
            hasGeneratedReview = true
            debugPrint("AI REVIEW COMPLETE")
            JPHaptics.notify(.success)
        } catch let error as AIServiceError {
            applyCachedOrLocalFallback(for: trade, notice: error.localizedDescription)
            if case .backendNotConfigured = error {
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            applyCachedOrLocalFallback(
                for: trade,
                notice: "AI backend is not connected yet. Showing local coaching preview."
            )
        }

        isAnalyzing = false

        if saveAfterAnalysis {
            saveReview(for: trade)
        }
    }

    private func queueAIReviewSync(_ review: AITradeReview, context: ModelContext) {
        let existingItems = (try? context.fetch(FetchDescriptor<SyncQueueItem>())) ?? []
        let alreadyQueued = existingItems.contains { item in
            item.entityID == review.id && item.entityType == .aiReview
        }

        guard alreadyQueued == false else {
            debugPrint("AI REVIEW SYNC QUEUED:", review.id.uuidString, "existing pending upload")
            return
        }

        context.insert(SyncQueueItem(entityID: review.id, entityType: .aiReview, operation: .upload))
        do {
            try context.save()
            debugPrint("AI REVIEW SYNC QUEUED:", review.id.uuidString)
        } catch {
            debugPrint("AI REVIEW FAILED:", "Unable to queue AI review sync:", String(describing: error))
        }
    }

    private func apply(_ review: AITradeReview) {
        overallScore = review.overallScore
        grade = review.grade
        gradeSummary = review.summary
        strengths = threeItemList(review.strengths, fallback: ["Review saved locally", "Trade documented", "Coaching history updated"])
        improvements = threeItemList(review.improvements, fallback: ["Regenerate to refresh improvement prompts", "Add richer context next time", "Review the exit against the thesis"])
        mistakes = threeItemList(review.improvements, fallback: ["No stored mistake details in this saved review", "Regenerate to refresh mistake detection", "Use tags and notes for sharper coaching"])
        breakdown = [
            AITradeScoreBreakdown(title: "Execution", score: review.executionScore, explanation: explanation(for: "Execution", score: review.executionScore), icon: "scope"),
            AITradeScoreBreakdown(title: "Risk Management", score: review.riskManagementScore, explanation: explanation(for: "Risk Management", score: review.riskManagementScore), icon: "shield.lefthalf.filled"),
            AITradeScoreBreakdown(title: "Psychology", score: review.psychologyScore, explanation: explanation(for: "Psychology", score: review.psychologyScore), icon: "brain.head.profile"),
            AITradeScoreBreakdown(title: "Journal Quality", score: review.journalQualityScore, explanation: explanation(for: "Journal Quality", score: review.journalQualityScore), icon: "book.pages"),
            AITradeScoreBreakdown(title: "Strategy Discipline", score: review.strategyDisciplineScore, explanation: explanation(for: "Strategy Discipline", score: review.strategyDisciplineScore), icon: "checklist.checked")
        ]
        psychologyNotes = "Saved review restored. Regenerate to refresh psychology notes."
        nextTradeFocus = improvements.first ?? "Repeat the process with cleaner documentation."
        riskFeedback = "Saved score: \(review.riskManagementScore)/100."
        patternWarnings = []
        confidenceLevel = "Saved"
    }

    private func apply(_ response: AIReviewResponse) {
        overallScore = clamp(response.overallScore)
        grade = response.grade
        gradeSummary = response.summary
        strengths = threeItemList(response.strengths, fallback: ["Trade was reviewed", "Risk context was evaluated", "Execution notes were processed"])
        improvements = threeItemList(response.improvements, fallback: ["Add more journal context", "Review risk before the next entry", "Capture screenshots for visual analysis"])
        mistakes = threeItemList(response.patternWarnings, fallback: improvements)
        psychologyNotes = response.psychologyNotes
        nextTradeFocus = response.nextTradeFocus
        riskFeedback = response.riskFeedback
        patternWarnings = response.patternWarnings
        confidenceLevel = response.confidenceLevel
        breakdown = [
            AITradeScoreBreakdown(title: "Execution", score: clamp(response.executionScore), explanation: explanation(for: "Execution", score: response.executionScore), icon: "scope"),
            AITradeScoreBreakdown(title: "Risk Management", score: clamp(response.riskScore), explanation: response.riskFeedback, icon: "shield.lefthalf.filled"),
            AITradeScoreBreakdown(title: "Psychology", score: clamp(response.psychologyScore), explanation: response.psychologyNotes, icon: "brain.head.profile"),
            AITradeScoreBreakdown(title: "Journal Quality", score: clamp(response.journalQualityScore), explanation: "Journal confidence: \(response.confidenceLevel).", icon: "book.pages"),
            AITradeScoreBreakdown(title: "Strategy Discipline", score: clamp(response.strategyDisciplineScore), explanation: response.nextTradeFocus, icon: "checklist.checked")
        ]
    }

    func scoreValue(named title: String) -> Int {
        score(named: title)
    }

    func patienceScore(for trade: Trade) -> Int {
        var score = 76

        if trade.mistakeTags.contains(.enteredEarly) || trade.mistakeTags.contains(.enteredLate) {
            score -= 18
        }

        if trade.mistakeTags.contains(.closedEarly) || trade.mistakeTags.contains(.heldTooLong) {
            score -= 12
        }

        if trade.mistakeTags.contains(.goodDiscipline) {
            score += 12
        }

        if trade.followedPlan {
            score += 8
        }

        return clamp(score)
    }

    func disciplineScore(for trade: Trade) -> Int {
        let planScore = trade.followedPlan ? 88 : 54
        let mistakePenalty = min(trade.mistakeTags.count * 6, 30)
        let journalBonus = min(journalLength(for: trade) / 80, 12)
        let screenshotBonus = screenshotCount(for: trade) * 4
        return clamp(planScore - mistakePenalty + journalBonus + screenshotBonus)
    }

    func nextTradeChecklist(for trade: Trade) -> [String] {
        var items = [
            "Confirm bias and session plan before entry.",
            "Respect the planned stop and risk percentage.",
            "Capture before, during, and after screenshots."
        ]

        items.append(contentsOf: improvements.prefix(3))

        if trade.mistakeTags.contains(.fomo) {
            items.append("Wait for confirmation before committing capital.")
        }

        if trade.mistakeTags.contains(.overtrading) || trade.mistakeTags.contains(.revengeTrade) {
            items.append("Stop trading after the max-trade or emotional limit is reached.")
        }

        return Array(Set(items)).prefix(6).map { $0 }
    }

    private func applyCachedOrLocalFallback(for trade: Trade, notice: String) {
        if let savedReview {
            apply(savedReview)
            analysisNotice = "Backend unavailable. Showing cached review from this device."
            hasGeneratedReview = true
            hasSavedReview = true
            debugPrint("AI REVIEW CACHED")
            debugPrint("AI REVIEW COMPLETE")
            return
        }

        let fallback = localFallbackResponse(for: trade)
        apply(fallback)
        debugPrint("AI REVIEW LOCAL PREVIEW")
        debugPrint("AI REVIEW COMPLETE")
        analysisNotice = notice
        hasGeneratedReview = true
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
        strengths = threeItemList(strengths(for: trade), fallback: ["Completed the review process", "Captured useful trade data", "Created a learning record"])
        improvements = threeItemList(improvements(for: trade), fallback: ["Keep documenting the setup and execution.", "Review whether the exit followed the original thesis.", "Repeat only the highest-quality setup criteria."])
        mistakes = threeItemList(mistakes(for: trade), fallback: ["No major mistake detected", "Keep protecting risk", "Repeat the strongest part of this process"])
        psychologyNotes = "Emotion: \(trade.emotion.isEmpty ? "Neutral" : trade.emotion). Confidence: \(Int(trade.confidence.rounded()))/10."
        nextTradeFocus = improvements.first ?? "Keep executing only A+ setups."
        riskFeedback = trade.riskPercent > 2 ? "Risk was above the preferred discipline range." : "Risk stayed within a reasonable local preview range."
        patternWarnings = trade.mistakeTags.filter { [.fomo, .revengeTrade, .overtrading, .riskTooHigh].contains($0) }.map(\.rawValue)
        confidenceLevel = "Local Preview"
    }

    private func localFallbackResponse(for trade: Trade) -> AIReviewResponse {
        calculatePlaceholderReview(for: trade)
        return AIReviewResponse(
            overallScore: overallScore,
            grade: grade,
            executionScore: score(named: "Execution"),
            riskScore: score(named: "Risk Management"),
            psychologyScore: score(named: "Psychology"),
            journalQualityScore: score(named: "Journal Quality"),
            strategyDisciplineScore: score(named: "Strategy Discipline"),
            summary: gradeSummary,
            strengths: strengths,
            improvements: improvements,
            psychologyNotes: psychologyNotes,
            nextTradeFocus: nextTradeFocus,
            riskFeedback: riskFeedback,
            patternWarnings: patternWarnings.isEmpty ? ["No major local pattern warning detected."] : patternWarnings,
            confidenceLevel: "Local Preview"
        )
    }

    private func explanation(for title: String, score: Int) -> String {
        let clampedScore = clamp(score)
        switch title {
        case "Execution":
            return clampedScore >= 85 ? "Execution quality is strong." : "Tighten timing and confirmation before entry."
        case "Risk Management":
            return clampedScore >= 85 ? "Risk stayed controlled." : "Review sizing, stop placement, and target quality."
        case "Psychology":
            return clampedScore >= 85 ? "Psychology supported the plan." : "Watch emotional triggers and rule breaks."
        case "Journal Quality":
            return clampedScore >= 85 ? "Journal detail supports useful review." : "Add richer thesis, context, screenshots, and lessons."
        default:
            return clampedScore >= 85 ? "Strategy discipline looks aligned." : "Clarify rules and avoid low-quality setups."
        }
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

    private func mistakes(for trade: Trade) -> [String] {
        var items = trade.mistakeTags
            .filter { $0 != .goodDiscipline }
            .map { "\($0.rawValue) showed up in this trade." }

        if trade.riskReward > 0, trade.riskReward < 1 {
            items.append("Reward did not justify the risk.")
        }

        if trade.riskPercent > 2 {
            items.append("Risk was above the preferred discipline range.")
        }

        if trade.followedPlan == false {
            items.append("The trade did not fully follow the plan.")
        }

        if journalLength(for: trade) < 100 {
            items.append("Journal detail is too light for a strong review.")
        }

        if screenshotCount(for: trade) == 0 {
            items.append("No screenshots were attached for visual proof.")
        }

        return items.isEmpty ? ["No major mistake detected. Protect this process."] : items
    }

    private func threeItemList(_ items: [String], fallback: [String]) -> [String] {
        var result = Array(items.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.prefix(3))
        for item in fallback where result.count < 3 {
            if !result.contains(item) {
                result.append(item)
            }
        }
        return Array(result.prefix(3))
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
