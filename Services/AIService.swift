import Foundation
import SwiftData
import Supabase

@MainActor
final class AIService {
    private let backendService: AIBackendService
    private let calendar: Calendar

    init(
        backendService: AIBackendService? = nil,
        calendar: Calendar = .current
    ) {
        self.backendService = backendService ?? AIBackendService()
        self.calendar = calendar
    }

    var isBackendConfigured: Bool {
        backendService.isConfigured
    }

    func analyzeTrade(_ trade: Trade, context: ModelContext) async throws -> AIReviewResponse {
        try await backendService.post(
            await makeTradeReviewRequest(for: trade, context: context),
            endpoint: .tradeReview,
            responseType: AIReviewResponse.self
        )
    }

    func testConnection() async -> Bool {
        await backendService.healthCheck()
    }

    func makeTradeReviewRequest(for trade: Trade, context: ModelContext) async -> AIReviewRequest {
        AIReviewRequest(
            trade: AIReviewRequest.TradePayload(
                pair: trade.pair,
                direction: trade.direction.rawValue,
                entryPrice: trade.entryPrice,
                stopLoss: trade.stopLoss,
                takeProfit: trade.takeProfit,
                outcome: trade.status.rawValue,
                profitLoss: trade.profitLoss,
                riskReward: trade.riskReward,
                session: trade.session.rawValue,
                strategy: trade.strategy.rawValue,
                mistakes: trade.mistakeTags.map(\.rawValue),
                notes: [trade.tradeThesis, trade.marketContext, trade.lessonsLearned, trade.notes]
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n\n"),
                executionReview: trade.executionReview,
                psychologyNotes: "Emotion: \(trade.emotion). Confidence: \(Int(trade.confidence.rounded()))/10. Followed plan: \(trade.followedPlan ? "Yes" : "No").",
                screenshotsCount: screenshotCount(for: trade),
                screenshots: await screenshotPayloads(for: trade)
            ),
            morningPlan: morningPlanPayload(context: context),
            recentTradeStats: recentTradeStatsPayload(context: context),
            coachingStyle: coachingStyle(context: context)
        )
    }

    private func screenshotCount(for trade: Trade) -> Int {
        [trade.beforeEntryImageData, trade.duringTradeImageData, trade.afterExitImageData].compactMap { $0 }.count
    }

    private func screenshotPayloads(for trade: Trade) async -> [AIReviewRequest.ScreenshotPayload] {
        let userID = try? await SupabaseClientManager.shared.client?.auth.session.user.id.uuidString.lowercased()
        let tradeRemoteID = trade.remoteId?.lowercased()

        return [
            screenshotPayload(slot: .beforeEntry, data: trade.beforeEntryImageData, userID: userID, tradeRemoteID: tradeRemoteID),
            screenshotPayload(slot: .duringTrade, data: trade.duringTradeImageData, userID: userID, tradeRemoteID: tradeRemoteID),
            screenshotPayload(slot: .afterExit, data: trade.afterExitImageData, userID: userID, tradeRemoteID: tradeRemoteID)
        ]
    }

    private func screenshotPayload(
        slot: Trade.ScreenshotSlot,
        data: Data?,
        userID: String?,
        tradeRemoteID: String?
    ) -> AIReviewRequest.ScreenshotPayload {
        let exists = data != nil
        let storagePath: String?
        if exists, let userID, let tradeRemoteID {
            storagePath = "\(userID)/\(tradeRemoteID)/\(slot.cloudFileName)"
        } else {
            storagePath = nil
        }

        return AIReviewRequest.ScreenshotPayload(
            slot: slot.rawValue,
            exists: exists,
            storagePath: storagePath
        )
    }

    private func morningPlanPayload(context: ModelContext) -> AIReviewRequest.MorningPlanPayload {
        let descriptor = FetchDescriptor<MorningPlan>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let plans = (try? context.fetch(descriptor)) ?? []
        guard let plan = plans.first(where: { calendar.isDate($0.date, inSameDayAs: Date()) }) else {
            return AIReviewRequest.MorningPlanPayload(bias: "Neutral", checklistCompletion: 0)
        }

        return AIReviewRequest.MorningPlanPayload(
            bias: plan.bias.rawValue,
            checklistCompletion: checklistCompletion(from: plan)
        )
    }

    private func recentTradeStatsPayload(context: ModelContext) -> AIReviewRequest.RecentTradeStatsPayload {
        let trades = (try? context.fetch(FetchDescriptor<Trade>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        let resolvedTrades = trades.filter { $0.status == .win || $0.status == .loss }
        let wins = resolvedTrades.filter { $0.status == .win }.count
        let rrValues = trades.map(\.riskReward).filter { $0 > 0 }

        return AIReviewRequest.RecentTradeStatsPayload(
            totalTrades: trades.count,
            winRate: resolvedTrades.isEmpty ? 0 : Double(wins) / Double(resolvedTrades.count) * 100,
            netProfit: trades.reduce(0) { $0 + $1.profitLoss },
            averageRiskReward: rrValues.isEmpty ? 0 : rrValues.reduce(0, +) / Double(rrValues.count),
            currentStreak: currentStreak(for: trades)
        )
    }

    private func coachingStyle(context: ModelContext) -> String {
        let profile = try? context.fetch(FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])).first
        return profile?.coachingStyle.rawValue ?? UserProfile.CoachingStyle.professionalMentor.rawValue
    }

    private func checklistCompletion(from plan: MorningPlan) -> Double {
        guard let data = plan.checklistRawValue.data(using: .utf8),
              let checklist = try? JSONDecoder().decode([PlanChecklistItem].self, from: data),
              !checklist.isEmpty else {
            return 0
        }
        return Double(checklist.filter(\.isComplete).count) / Double(checklist.count) * 100
    }

    private func currentStreak(for trades: [Trade]) -> String {
        let resolved = trades
            .filter { $0.status == .win || $0.status == .loss }
            .sorted { $0.date > $1.date }

        guard let latest = resolved.first?.status else {
            return "0"
        }

        let count = resolved.prefix { $0.status == latest }.count
        return "\(count)\(latest == .win ? "W" : "L")"
    }
}

private extension Trade.ScreenshotSlot {
    var cloudFileName: String {
        switch self {
        case .beforeEntry:
            return "before-entry.jpg"
        case .duringTrade:
            return "during-trade.jpg"
        case .afterExit:
            return "after-exit.jpg"
        }
    }
}
