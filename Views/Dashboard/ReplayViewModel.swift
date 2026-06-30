import Combine
import Foundation
import SwiftData
import SwiftUI

struct ReplayStage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let time: Date?
    let icon: String
    let tint: Color
    let screenshotData: Data?
    let screenshotSlot: Trade.ScreenshotSlot?
}

struct ReplayCommentary: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let tint: Color
}

struct ReplayScreenshot: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let slot: Trade.ScreenshotSlot
    let data: Data?
}

struct ReplayStudioStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let tint: Color
}

struct ReplayPsychologyMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: Int
    let icon: String
    let tint: Color
}

@MainActor
final class ReplayViewModel: ObservableObject {
    @Published private(set) var stages: [ReplayStage] = []
    @Published private(set) var visibleStageCount = 1
    @Published private(set) var isPlaying = false
    @Published private(set) var aiReview: AITradeReview?
    @Published private(set) var commentaryIndex = 0
    @Published var isFavorite = false
    @Published var isBestTrade = false
    @Published var isMistake = false
    @Published var isReviewLater = false
    @Published var didShowExportPlaceholder = false

    private var playbackTask: Task<Void, Never>?
    private var modelContext: ModelContext?
    private var trade: Trade?

    private let favoriteKey = "jp.replayStudio.favoriteTradeIDs"
    private let bestKey = "jp.replayStudio.bestTradeIDs"
    private let mistakeKey = "jp.replayStudio.mistakeTradeIDs"
    private let reviewLaterKey = "jp.replayStudio.reviewLaterTradeIDs"

    var progress: Double {
        guard !stages.isEmpty else { return 0 }
        return Double(visibleStageCount) / Double(stages.count)
    }

    var visibleStages: [ReplayStage] {
        Array(stages.prefix(visibleStageCount))
    }

    var isComplete: Bool {
        !stages.isEmpty && visibleStageCount >= stages.count
    }

    func configure(context: ModelContext, trade: Trade) {
        modelContext = context
        self.trade = trade
        aiReview = fetchAIReview(for: trade)
        stages = buildStages(for: trade)
        visibleStageCount = min(max(visibleStageCount, 1), max(stages.count, 1))
        loadFlags(for: trade)
    }

    func play() {
        guard !stages.isEmpty else { return }
        playbackTask?.cancel()
        isPlaying = true
        JPHaptics.impact(.soft)

        playbackTask = Task { [weak self] in
            guard let self else { return }
            while self.visibleStageCount < self.stages.count {
                try? await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }
                withAnimation(JPDesign.smoothSpring) {
                    self.visibleStageCount += 1
                    self.commentaryIndex = min(self.commentaryIndex + 1, max(self.commentary.count - 1, 0))
                }
            }
            self.finishPlayback()
        }
    }

    func pause() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }

    func restart() {
        pause()
        withAnimation(JPDesign.smoothSpring) {
            visibleStageCount = stages.isEmpty ? 0 : 1
            commentaryIndex = 0
        }
    }

    func stepForward() {
        pause()
        guard visibleStageCount < stages.count else { return }
        withAnimation(JPDesign.quickSpring) {
            visibleStageCount += 1
            commentaryIndex = min(commentaryIndex + 1, max(commentary.count - 1, 0))
        }
        if isComplete {
            recordCompletion()
            JPHaptics.notify(.success)
        } else {
            JPHaptics.selection()
        }
    }

    func stepBackward() {
        pause()
        guard visibleStageCount > 1 else { return }
        withAnimation(JPDesign.quickSpring) {
            visibleStageCount -= 1
            commentaryIndex = max(commentaryIndex - 1, 0)
        }
        JPHaptics.selection()
    }

    func toggleFavorite() {
        toggle(\.isFavorite, key: favoriteKey)
    }

    func toggleBestTrade() {
        toggle(\.isBestTrade, key: bestKey)
    }

    func toggleMistake() {
        toggle(\.isMistake, key: mistakeKey)
    }

    func toggleReviewLater() {
        toggle(\.isReviewLater, key: reviewLaterKey)
    }

    func exportPlaceholder() {
        didShowExportPlaceholder = true
        JPHaptics.notify(.success)
    }

    func screenshots(for trade: Trade) -> [ReplayScreenshot] {
        [
            ReplayScreenshot(title: "Before Entry", subtitle: "Setup before execution", slot: .beforeEntry, data: trade.beforeEntryImageData),
            ReplayScreenshot(title: "During Trade", subtitle: "Management while live", slot: .duringTrade, data: trade.duringTradeImageData),
            ReplayScreenshot(title: "After Exit", subtitle: "Resolved outcome", slot: .afterExit, data: trade.afterExitImageData)
        ]
    }

    func statistics(for trade: Trade) -> [ReplayStudioStat] {
        [
            stat("Entry Price", number(trade.entryPrice), "arrow.right.circle.fill", JPColors.accent),
            stat("Exit Price", trade.exitPrice > 0 ? number(trade.exitPrice) : "Not set", "flag.checkered", JPColors.warning),
            stat("Risk %", trade.riskPercent > 0 ? "\(number(trade.riskPercent))%" : "--", "shield.lefthalf.filled", JPColors.blue),
            stat("Reward", currency(trade.profitLoss), "banknote.fill", trade.profitLoss >= 0 ? JPColors.profit : JPColors.loss),
            stat("Risk:Reward", String(format: "%.2fR", trade.riskReward), "scale.3d", JPColors.warning),
            stat("Holding Time", holdingTime(for: trade), "timer", JPColors.secondaryText),
            stat("Max Drawdown", currency(estimatedDrawdown(for: trade)), "chart.line.downtrend.xyaxis", JPColors.loss),
            stat("Max Profit", currency(estimatedMaxProfit(for: trade)), "chart.line.uptrend.xyaxis", JPColors.profit),
            stat("Session", trade.session.rawValue, "clock.fill", JPColors.blue),
            stat("Strategy", trade.strategy.rawValue, "scope", JPColors.purple),
            stat("Checklist", trade.followedPlan ? "100%" : "50%", "checklist.checked", trade.followedPlan ? JPColors.profit : JPColors.warning),
            stat("Screenshots", "\(screenshotCount(for: trade))/3", "photo.stack.fill", JPColors.accent),
            stat("AI Score", aiReview.map { "\($0.overallScore)" } ?? "\(localAIScore(for: trade))", "sparkles", JPColors.warning),
            stat("Execution", "\(executionScore(for: trade))", "bolt.fill", JPColors.blue),
            stat("Discipline", "\(disciplineScore(for: trade))", "checkmark.seal.fill", JPColors.accent)
        ]
    }

    func psychology(for trade: Trade) -> [ReplayPsychologyMetric] {
        let confidence = Int((trade.confidence * 10).rounded())
        let discipline = disciplineScore(for: trade)
        let fearPenalty = trade.emotion.localizedCaseInsensitiveContains("fear") || trade.emotion.localizedCaseInsensitiveContains("nervous") ? 35 : 12
        let greedPenalty = trade.emotion.localizedCaseInsensitiveContains("greed") || trade.emotion.localizedCaseInsensitiveContains("overconfident") ? 36 : 14
        let revengePenalty = trade.mistakeTags.contains(.revengeTrade) ? 54 : 10
        return [
            psych("Confidence", confidence, "person.crop.circle.badge.checkmark", JPColors.blue),
            psych("Patience", trade.mistakeTags.contains(.enteredEarly) ? 48 : 82, "hourglass", JPColors.warning),
            psych("Discipline", discipline, "checkmark.seal.fill", JPColors.accent),
            psych("Fear", max(0, 100 - fearPenalty), "eye.trianglebadge.exclamationmark", JPColors.loss),
            psych("Greed", max(0, 100 - greedPenalty), "flame.fill", JPColors.warning),
            psych("Execution", executionScore(for: trade), "bolt.fill", JPColors.purple),
            psych("Risk", riskScore(for: trade), "shield.fill", JPColors.profit),
            psych(trade.emotion.isEmpty ? "Emotion" : trade.emotion, max(42, min(96, confidence)), "heart.text.square.fill", JPColors.secondaryText)
        ]
    }

    var commentary: [ReplayCommentary] {
        guard let trade else { return [] }
        if let aiReview {
            return ([aiReview.summary] + aiReview.strengths + aiReview.improvements).prefix(7).map {
                ReplayCommentary(text: $0, icon: "sparkles", tint: JPColors.warning)
            }
        }

        var items: [ReplayCommentary] = []
        if trade.followedPlan {
            items.append(ReplayCommentary(text: "Entry followed your plan.", icon: "checkmark.seal.fill", tint: JPColors.profit))
        } else {
            items.append(ReplayCommentary(text: "This trade needs a stricter plan review.", icon: "exclamationmark.triangle.fill", tint: JPColors.warning))
        }
        if trade.riskReward >= 2 {
            items.append(ReplayCommentary(text: "Risk management was disciplined with a strong reward profile.", icon: "shield.fill", tint: JPColors.accent))
        }
        if trade.status == .win {
            items.append(ReplayCommentary(text: "Excellent patience through a profitable setup.", icon: "chart.line.uptrend.xyaxis", tint: JPColors.profit))
        } else if trade.status == .loss {
            items.append(ReplayCommentary(text: "Replay the loss carefully and isolate the repeatable lesson.", icon: "chart.line.downtrend.xyaxis", tint: JPColors.loss))
        }
        if trade.mistakeTags.contains(.revengeTrade) || trade.mistakeTags.contains(.fomo) {
            items.append(ReplayCommentary(text: "Psychology tags suggest emotion influenced execution.", icon: "brain.head.profile", tint: JPColors.warning))
        }
        items.append(ReplayCommentary(text: "Exit respected structure when your journal explains the decision clearly.", icon: "flag.checkered", tint: JPColors.blue))
        return items
    }

    func executionScore(for trade: Trade) -> Int {
        if trade.executionScore > 0 { return min(100, max(0, trade.executionScore * 20)) }
        var score = 68
        if trade.followedPlan { score += 12 }
        if trade.riskReward >= 2 { score += 10 }
        if trade.mistakeTags.contains(.enteredEarly) || trade.mistakeTags.contains(.enteredLate) { score -= 16 }
        return min(100, max(0, score))
    }

    func disciplineScore(for trade: Trade) -> Int {
        var score = 58
        if trade.followedPlan { score += 18 }
        if trade.riskReward >= 1.5 { score += 10 }
        if !trade.tradeThesis.isEmpty || !trade.lessonsLearned.isEmpty { score += 8 }
        if screenshotCount(for: trade) > 0 { score += 6 }
        if trade.mistakeTags.contains(.fomo) || trade.mistakeTags.contains(.revengeTrade) || trade.mistakeTags.contains(.overtrading) { score -= 20 }
        return min(100, max(0, score))
    }

    func localAIScore(for trade: Trade) -> Int {
        min(100, max(0, (executionScore(for: trade) + disciplineScore(for: trade) + riskScore(for: trade)) / 3))
    }

    func holdingTime(for trade: Trade) -> String {
        guard let open = trade.tradeOpenTime, let close = trade.tradeCloseTime, close > open else { return "Open-ended" }
        let minutes = Int(close.timeIntervalSince(open) / 60)
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(remainder)m" : "\(max(minutes, 1))m"
    }

    func pips(for trade: Trade) -> String {
        let exit = trade.exitPrice > 0 ? trade.exitPrice : trade.takeProfit
        let raw = abs(exit - trade.entryPrice)
        return String(format: "%.1f", raw * 10_000)
    }

    func screenshotCount(for trade: Trade) -> Int {
        [trade.beforeEntryImageData, trade.duringTradeImageData, trade.afterExitImageData].compactMap { $0 }.count
    }

    private func finishPlayback() {
        isPlaying = false
        playbackTask = nil
        recordCompletion()
        JPHaptics.notify(.success)
    }

    private func recordCompletion() {
        guard let modelContext, let trade else { return }
        DisciplineTracker(context: modelContext).recordReplayViewed(for: trade)
        let engine = IntelligenceEngine(context: modelContext)
        try? InsightRepository(context: modelContext).upsert(engine.insightsForReplayCompletion(trade: trade))
        engine.observe(.replayCompleted)
    }

    private func fetchAIReview(for trade: Trade) -> AITradeReview? {
        guard let modelContext else { return nil }
        let tradeID = trade.id
        let descriptor = FetchDescriptor<AITradeReview>(
            predicate: #Predicate { review in
                review.tradeID == tradeID
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func buildStages(for trade: Trade) -> [ReplayStage] {
        [
            stage("Before Entry", "Setup, bias, and thesis before execution.", trade.tradeOpenTime ?? trade.date, "camera.viewfinder", JPColors.blue, trade.beforeEntryImageData, .beforeEntry),
            stage("Entry", "Entered \(trade.direction.rawValue.lowercased()) at \(number(trade.entryPrice)).", trade.tradeOpenTime ?? trade.date, "play.circle.fill", trade.direction == .buy ? JPColors.profit : JPColors.loss, nil, nil),
            stage("Management", trade.followedPlan ? "Managed according to plan." : "Management drifted from the plan.", trade.tradeOpenTime ?? trade.date, "slider.horizontal.3", trade.followedPlan ? JPColors.profit : JPColors.warning, trade.duringTradeImageData, .duringTrade),
            stage("Partial Exit", "Partial exit tracking is ready for future execution data.", trade.tradeCloseTime ?? trade.date, "arrow.triangle.branch", JPColors.purple, nil, nil),
            stage("Break Even", "Break-even management review based on journal notes.", trade.tradeCloseTime ?? trade.date, "equal.circle.fill", JPColors.warning, nil, nil),
            stage("Final Exit", "Closed with \(currency(trade.profitLoss)) and \(String(format: "%.2fR", trade.riskReward)).", trade.tradeCloseTime ?? trade.date, "flag.checkered", outcomeTint(for: trade), trade.afterExitImageData, .afterExit),
            stage("Lessons Learned", trade.lessonsLearned.isEmpty ? "Add a lesson to make this replay sharper." : trade.lessonsLearned, trade.date, "book.pages.fill", JPColors.accent, nil, nil)
        ]
    }

    private func loadFlags(for trade: Trade) {
        isFavorite = storedIDs(for: favoriteKey).contains(trade.id)
        isBestTrade = storedIDs(for: bestKey).contains(trade.id)
        isMistake = storedIDs(for: mistakeKey).contains(trade.id)
        isReviewLater = storedIDs(for: reviewLaterKey).contains(trade.id)
    }

    private func toggle(_ keyPath: ReferenceWritableKeyPath<ReplayViewModel, Bool>, key: String) {
        guard let trade else { return }
        var ids = storedIDs(for: key)
        if ids.contains(trade.id) {
            ids.remove(trade.id)
            self[keyPath: keyPath] = false
        } else {
            ids.insert(trade.id)
            self[keyPath: keyPath] = true
        }
        UserDefaults.standard.set(ids.map(\.uuidString).joined(separator: "|"), forKey: key)
        JPHaptics.selection()
    }

    private func storedIDs(for key: String) -> Set<UUID> {
        Set(UserDefaults.standard.string(forKey: key)?.split(separator: "|").compactMap { UUID(uuidString: String($0)) } ?? [])
    }

    private func stage(_ title: String, _ subtitle: String, _ time: Date?, _ icon: String, _ tint: Color, _ data: Data?, _ slot: Trade.ScreenshotSlot?) -> ReplayStage {
        ReplayStage(title: title, subtitle: subtitle, time: time, icon: icon, tint: tint, screenshotData: data, screenshotSlot: slot)
    }

    private func stat(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> ReplayStudioStat {
        ReplayStudioStat(title: title, value: value, icon: icon, tint: tint)
    }

    private func psych(_ title: String, _ value: Int, _ icon: String, _ tint: Color) -> ReplayPsychologyMetric {
        ReplayPsychologyMetric(title: title, value: min(100, max(0, value)), icon: icon, tint: tint)
    }

    private func riskScore(for trade: Trade) -> Int {
        var score = 70
        if trade.riskPercent > 0, trade.riskPercent <= 2 { score += 15 }
        if trade.riskPercent > 3 { score -= 18 }
        if trade.riskReward >= 2 { score += 10 }
        return min(100, max(0, score))
    }

    private func estimatedDrawdown(for trade: Trade) -> Double {
        trade.profitLoss < 0 ? trade.profitLoss : -abs(trade.profitLoss) * 0.22
    }

    private func estimatedMaxProfit(for trade: Trade) -> Double {
        trade.profitLoss > 0 ? trade.profitLoss : abs(trade.profitLoss) * 0.35
    }

    private func outcomeTint(for trade: Trade) -> Color {
        switch trade.status {
        case .win: return JPColors.profit
        case .loss: return JPColors.loss
        case .breakeven: return JPColors.warning
        }
    }

    private func number(_ value: Double) -> String {
        value == 0 ? "--" : String(format: "%.4f", value)
    }

    private func currency(_ value: Double) -> String {
        "\(value >= 0 ? "+" : "-")$\(Int(abs(value)).formatted())"
    }
}
