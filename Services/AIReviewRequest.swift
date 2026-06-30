import Foundation

struct AIReviewRequest: Codable {
    struct TradePayload: Codable {
        let pair: String
        let direction: String
        let entryPrice: Double
        let stopLoss: Double
        let takeProfit: Double
        let outcome: String
        let profitLoss: Double
        let riskReward: Double
        let session: String
        let strategy: String
        let mistakes: [String]
        let notes: String
        let executionReview: String
        let psychologyNotes: String
        let screenshotsCount: Int
        let screenshots: [ScreenshotPayload]
    }

    struct ScreenshotPayload: Codable {
        let slot: String
        let exists: Bool
        let storagePath: String?
    }

    struct MorningPlanPayload: Codable {
        let bias: String
        let checklistCompletion: Double
    }

    struct RecentTradeStatsPayload: Codable {
        let totalTrades: Int
        let winRate: Double
        let netProfit: Double
        let averageRiskReward: Double
        let currentStreak: String
    }

    let trade: TradePayload
    let morningPlan: MorningPlanPayload
    let recentTradeStats: RecentTradeStatsPayload
    let coachingStyle: String
}

struct AIReviewResponse: Codable {
    let overallScore: Int
    let grade: String
    let executionScore: Int
    let riskScore: Int
    let psychologyScore: Int
    let journalQualityScore: Int
    let strategyDisciplineScore: Int
    let summary: String
    let strengths: [String]
    let improvements: [String]
    let psychologyNotes: String
    let nextTradeFocus: String
    let riskFeedback: String
    let patternWarnings: [String]
    let confidenceLevel: String
}

enum AIServiceError: LocalizedError {
    case backendNotConfigured
    case invalidURL
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "AI backend is not connected yet. Showing local coaching preview."
        case .invalidURL:
            return "The AI backend URL is invalid."
        case .invalidResponse:
            return "The AI backend returned an unexpected response."
        case .requestFailed(let message):
            return message
        }
    }
}
