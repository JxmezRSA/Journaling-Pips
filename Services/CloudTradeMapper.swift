import Foundation

struct CloudTradePayload: Codable, Identifiable {
    let id: UUID
    let pair: String
    let direction: String
    let entryPrice: Double
    let stopLoss: Double
    let takeProfit: Double
    let profitLoss: Double
    let notes: String
    let exitPrice: Double
    let lotSize: Double
    let riskPercent: Double
    let date: Date
    let status: String
    let riskReward: Double
    let session: String
    let strategy: String
    let mistakeTags: [String]
    let confidence: Double
    let emotion: String
    let executionScore: Int
    let followedPlan: Bool
    let tradeThesis: String
    let marketContext: String
    let executionReview: String
    let lessonsLearned: String
    let screenshotCount: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case pair
        case direction
        case entryPrice = "entry_price"
        case stopLoss = "stop_loss"
        case takeProfit = "take_profit"
        case profitLoss = "profit_loss"
        case notes
        case exitPrice = "exit_price"
        case lotSize = "lot_size"
        case riskPercent = "risk_percent"
        case date
        case status
        case riskReward = "risk_reward"
        case session
        case strategy
        case mistakeTags = "mistake_tags"
        case confidence
        case emotion
        case executionScore = "execution_score"
        case followedPlan = "followed_plan"
        case tradeThesis = "trade_thesis"
        case marketContext = "market_context"
        case executionReview = "execution_review"
        case lessonsLearned = "lessons_learned"
        case screenshotCount = "screenshot_count"
        case updatedAt = "updated_at"
    }
}

enum CloudTradeMapper {
    static func payload(from trade: Trade) -> CloudTradePayload {
        CloudTradePayload(
            id: trade.id,
            pair: trade.pair,
            direction: trade.direction.rawValue,
            entryPrice: trade.entryPrice,
            stopLoss: trade.stopLoss,
            takeProfit: trade.takeProfit,
            profitLoss: trade.profitLoss,
            notes: trade.notes,
            exitPrice: trade.exitPrice,
            lotSize: trade.lotSize,
            riskPercent: trade.riskPercent,
            date: trade.date,
            status: trade.status.rawValue,
            riskReward: trade.riskReward,
            session: trade.session.rawValue,
            strategy: trade.strategy.rawValue,
            mistakeTags: trade.mistakeTags.map(\.rawValue),
            confidence: trade.confidence,
            emotion: trade.emotion,
            executionScore: trade.executionScore,
            followedPlan: trade.followedPlan,
            tradeThesis: trade.tradeThesis,
            marketContext: trade.marketContext,
            executionReview: trade.executionReview,
            lessonsLearned: trade.lessonsLearned,
            screenshotCount: [trade.beforeEntryImageData, trade.duringTradeImageData, trade.afterExitImageData].compactMap { $0 }.count,
            updatedAt: Date()
        )
    }
}
