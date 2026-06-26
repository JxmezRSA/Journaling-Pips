import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class TradeDetailViewModel: ObservableObject {
    static let emotions = [
        "Calm",
        "Confident",
        "Focused",
        "Neutral",
        "Nervous",
        "Fear",
        "Greedy",
        "Revenge",
        "Frustrated",
        "Overconfident"
    ]

    static let screenshotSlots = [
        ScreenshotSlot(title: "Before Entry", icon: "chart.line.uptrend.xyaxis"),
        ScreenshotSlot(title: "During Trade", icon: "waveform.path.ecg"),
        ScreenshotSlot(title: "Exit", icon: "flag.checkered")
    ]

    @Published var confidence: Double
    @Published var emotion: String
    @Published var executionScore: Int
    @Published var followedPlan: Bool
    @Published var selectedMistakeTags: Set<Trade.MistakeTag>
    @Published var tradeThesis: String
    @Published var marketContext: String
    @Published var executionReview: String
    @Published var lessonsLearned: String
    @Published var showSavedConfirmation = false

    init(trade: Trade) {
        confidence = trade.confidence
        emotion = trade.emotion.isEmpty ? "Neutral" : trade.emotion
        executionScore = trade.executionScore
        followedPlan = trade.followedPlan
        selectedMistakeTags = Set(trade.mistakeTags)
        tradeThesis = trade.tradeThesis.isEmpty ? trade.notes : trade.tradeThesis
        marketContext = trade.marketContext
        executionReview = trade.executionReview
        lessonsLearned = trade.lessonsLearned
    }

    func saveReview(for trade: Trade, using tradeViewModel: TradeViewModel) {
        let didSave = tradeViewModel.updateTradeReview(
            trade,
            confidence: confidence,
            emotion: emotion,
            executionScore: executionScore,
            followedPlan: followedPlan,
            mistakeTags: selectedMistakeTags.sorted { $0.rawValue < $1.rawValue },
            tradeThesis: tradeThesis,
            marketContext: marketContext,
            executionReview: executionReview,
            lessonsLearned: lessonsLearned
        )

        if didSave {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showSavedConfirmation = true
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
}

struct ScreenshotSlot: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
}
