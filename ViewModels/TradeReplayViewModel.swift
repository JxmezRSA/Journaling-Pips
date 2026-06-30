import Combine
import Foundation
import SwiftData
import SwiftUI
import UIKit

struct ReplayEvent: Identifiable {
    enum Kind {
        case tradeCreated
        case beforeEntryScreenshot
        case entryExecuted
        case duringTradeScreenshot
        case tradeManaged
        case afterExitScreenshot
        case tradeClosed
        case journalReview
        case aiCoachReview
    }

    let id = UUID()
    let kind: Kind
    let time: Date?
    let icon: String
    let title: String
    let description: String
    let detail: String
    let tint: Color
    let screenshotSlot: Trade.ScreenshotSlot?
    let screenshotData: Data?
}

@MainActor
final class TradeReplayViewModel: ObservableObject {
    @Published private(set) var events: [ReplayEvent] = []
    @Published private(set) var visibleEventCount = 1
    @Published private(set) var isPlaying = false
    @Published private(set) var savedAIReview: AITradeReview?

    private var playbackTask: Task<Void, Never>?
    private var modelContext: ModelContext?
    private var activeTrade: Trade?

    var progress: Double {
        guard !events.isEmpty else { return 0 }
        return Double(visibleEventCount) / Double(events.count)
    }

    var visibleEvents: [ReplayEvent] {
        Array(events.prefix(visibleEventCount))
    }

    var isComplete: Bool {
        visibleEventCount >= events.count && !events.isEmpty
    }

    func configure(context: ModelContext, trade: Trade) {
        modelContext = context
        activeTrade = trade
        savedAIReview = fetchAIReview(for: trade)
        events = buildEvents(for: trade)
        visibleEventCount = min(max(visibleEventCount, 1), max(events.count, 1))
    }

    func play() {
        guard !events.isEmpty else { return }
        playbackTask?.cancel()
        isPlaying = true

        playbackTask = Task { [weak self] in
            guard let self else { return }

            while self.canAdvance {
                try? await Task.sleep(for: .milliseconds(950))
                if Task.isCancelled { return }
                self.advanceFromPlayback()
            }

            self.finishPlayback()
        }

        JPHaptics.impact(.soft)
    }

    func pause() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }

    func restart() {
        pause()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            visibleEventCount = events.isEmpty ? 0 : 1
        }
    }

    func stepForward() {
        pause()
        guard visibleEventCount < events.count else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            visibleEventCount += 1
        }
        if visibleEventCount == events.count {
            recordReplayCompletion()
            JPHaptics.notify(.success)
        }
    }

    func stepBackward() {
        pause()
        guard visibleEventCount > 1 else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            visibleEventCount -= 1
        }
    }

    func tradeGrade(for trade: Trade) -> String {
        if let savedAIReview {
            return savedAIReview.grade
        }

        var score = trade.executionScore > 0 ? trade.executionScore * 18 : 62
        if trade.followedPlan { score += 10 }
        if trade.riskReward >= 2 { score += 10 }
        if trade.status == .win { score += 8 }
        if trade.mistakeTags.contains(.goodDiscipline) { score += 6 }
        if trade.mistakeTags.contains(.fomo) || trade.mistakeTags.contains(.revengeTrade) || trade.mistakeTags.contains(.overtrading) { score -= 16 }

        switch min(max(score, 0), 100) {
        case 94...100: return "A+"
        case 86...93: return "A"
        case 76...85: return "B"
        case 66...75: return "C"
        case 55...65: return "D"
        default: return "F"
        }
    }

    func durationText(for trade: Trade) -> String {
        guard let open = trade.tradeOpenTime, let close = trade.tradeCloseTime, close > open else {
            return "Open-ended"
        }

        let duration = close.timeIntervalSince(open)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private var canAdvance: Bool {
        visibleEventCount < events.count
    }

    private func advanceFromPlayback() {
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
            visibleEventCount = min(visibleEventCount + 1, events.count)
        }

        if visibleEventCount == events.count {
            recordReplayCompletion()
            JPHaptics.notify(.success)
        }
    }

    private func finishPlayback() {
        isPlaying = false
        playbackTask = nil
    }

    private func recordReplayCompletion() {
        guard let modelContext, let activeTrade else {
            return
        }

        let engine = IntelligenceEngine(context: modelContext)
        do {
            try InsightRepository(context: modelContext).upsert(engine.insightsForReplayCompletion(trade: activeTrade))
            engine.observe(.replayCompleted)
        } catch {
            assertionFailure("Unable to record replay insight: \(error)")
        }
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

    private func buildEvents(for trade: Trade) -> [ReplayEvent] {
        [
            ReplayEvent(
                kind: .tradeCreated,
                time: trade.date,
                icon: "doc.badge.plus",
                title: "Trade Created",
                description: "\(trade.pair) was logged as a \(trade.direction.rawValue.lowercased()) idea.",
                detail: "Session: \(trade.session.rawValue) • Strategy: \(trade.strategy.rawValue)",
                tint: JPColors.accent,
                screenshotSlot: nil,
                screenshotData: nil
            ),
            screenshotEvent(
                .beforeEntry,
                data: trade.beforeEntryImageData,
                time: trade.tradeOpenTime ?? trade.date,
                title: "Before Entry Screenshot",
                description: "The setup before execution.",
                fallback: "No before-entry screenshot was attached."
            ),
            ReplayEvent(
                kind: .entryExecuted,
                time: trade.tradeOpenTime ?? trade.date,
                icon: "play.circle.fill",
                title: "Entry Executed",
                description: "Entry at \(number(trade.entryPrice)), with stop at \(number(trade.stopLoss)) and target at \(number(trade.takeProfit)).",
                detail: "Risk:Reward \(riskRewardText(for: trade))",
                tint: trade.direction == .buy ? JPColors.profit : JPColors.loss,
                screenshotSlot: nil,
                screenshotData: nil
            ),
            screenshotEvent(
                .duringTrade,
                data: trade.duringTradeImageData,
                time: trade.tradeOpenTime ?? trade.date,
                title: "During Trade Screenshot",
                description: "Management while the trade was live.",
                fallback: "No during-trade screenshot was attached."
            ),
            ReplayEvent(
                kind: .tradeManaged,
                time: trade.tradeOpenTime ?? trade.date,
                icon: "slider.horizontal.3",
                title: "Trade Managed",
                description: trade.followedPlan ? "Plan adherence stayed intact during management." : "This trade was marked as not fully following the plan.",
                detail: "Emotion: \(trade.emotion.isEmpty ? "Neutral" : trade.emotion) • Confidence: \(Int(trade.confidence.rounded()))/10",
                tint: trade.followedPlan ? JPColors.profit : JPColors.warning,
                screenshotSlot: nil,
                screenshotData: nil
            ),
            screenshotEvent(
                .afterExit,
                data: trade.afterExitImageData,
                time: trade.tradeCloseTime ?? trade.date,
                title: "After Exit Screenshot",
                description: "The chart after the trade was resolved.",
                fallback: "No after-exit screenshot was attached."
            ),
            ReplayEvent(
                kind: .tradeClosed,
                time: trade.tradeCloseTime ?? trade.date,
                icon: "flag.checkered",
                title: "Trade Closed",
                description: "\(trade.status.rawValue) result with \(currency(trade.profitLoss)) P/L.",
                detail: "Duration: \(durationText(for: trade))",
                tint: outcomeColor(for: trade),
                screenshotSlot: nil,
                screenshotData: nil
            ),
            ReplayEvent(
                kind: .journalReview,
                time: trade.date,
                icon: "quote.bubble.fill",
                title: "Journal Review",
                description: "Thesis, context, execution, and lessons were reviewed.",
                detail: journalDetail(for: trade),
                tint: JPColors.blue,
                screenshotSlot: nil,
                screenshotData: nil
            ),
            ReplayEvent(
                kind: .aiCoachReview,
                time: savedAIReview?.updatedAt,
                icon: "sparkles",
                title: "AI Coach Review",
                description: savedAIReview?.summary ?? "Generate an AI review from the Trade Detail screen.",
                detail: savedAIReview.map { "Saved grade: \($0.grade) • Score: \($0.overallScore)/100" } ?? "Placeholder ready",
                tint: JPColors.warning,
                screenshotSlot: nil,
                screenshotData: nil
            )
        ]
    }

    private func screenshotEvent(
        _ slot: Trade.ScreenshotSlot,
        data: Data?,
        time: Date?,
        title: String,
        description: String,
        fallback: String
    ) -> ReplayEvent {
        ReplayEvent(
            kind: slot == .beforeEntry ? .beforeEntryScreenshot : slot == .duringTrade ? .duringTradeScreenshot : .afterExitScreenshot,
            time: time,
            icon: slot.icon,
            title: title,
            description: data == nil ? fallback : description,
            detail: data == nil ? "Add this image in the Trade Workspace." : slot.subtitle,
            tint: data == nil ? JPColors.secondaryText : JPColors.accent,
            screenshotSlot: slot,
            screenshotData: data
        )
    }

    private func journalDetail(for trade: Trade) -> String {
        let count = [
            trade.tradeThesis,
            trade.marketContext,
            trade.executionReview,
            trade.lessonsLearned
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .count

        return count == 0 ? "No journal sections filled yet." : "\(count)/4 journal sections completed"
    }

    private func outcomeColor(for trade: Trade) -> Color {
        switch trade.status {
        case .win: return JPColors.profit
        case .loss: return JPColors.loss
        case .breakeven: return JPColors.warning
        }
    }

    private func riskRewardText(for trade: Trade) -> String {
        String(format: "1:%.2f", trade.riskReward)
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func number(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.4f", value)
    }
}
