import Foundation

struct VisionPromptBuilder {
    func buildPrompt(for trade: Trade, provider: AIBackendProvider, screenshotSlots: [String], coachingStyle: String) -> String {
        """
        You are Journaling Pips Vision AI, a professional trading chart analyst.
        Provider target: \(provider.rawValue).
        Coaching style: \(coachingStyle).

        Analyze all supplied screenshots as a single trade story:
        \(screenshotSlots.isEmpty ? "No screenshots were supplied." : screenshotSlots.joined(separator: ", "))

        Trade context:
        Pair: \(trade.pair)
        Direction: \(trade.direction.rawValue)
        Result: \(trade.status.rawValue)
        Entry: \(trade.entryPrice)
        Stop Loss: \(trade.stopLoss)
        Take Profit: \(trade.takeProfit)
        Risk Reward: \(trade.riskReward)
        Session: \(trade.session.rawValue)
        Strategy: \(trade.strategy.rawValue)
        Profit/Loss: \(trade.profitLoss)
        Mistakes: \(trade.mistakeTags.map(\.rawValue).joined(separator: ", "))
        Notes: \(joinedNotes(for: trade))

        Analyze:
        - Market Structure
        - Trend
        - Liquidity
        - Fair Value Gaps
        - Order Blocks
        - Break of Structure
        - CHOCH
        - Momentum
        - Entry Quality
        - Stop Placement
        - Take Profit
        - Risk Placement
        - RR
        - Session
        - Bias
        - Trade Timing
        - Confluence
        - Confidence

        Return strict JSON only with these keys:
        {
          "overallGrade": "A, B, C, D, or F",
          "marketStructure": "string",
          "entryQuality": "string",
          "riskPlacement": "string",
          "tradeTiming": "string",
          "trendAlignment": "string",
          "liquidity": "string",
          "fairValueGap": "string",
          "orderBlocks": "string",
          "breakOfStructure": "string",
          "changeOfCharacter": "string",
          "momentum": "string",
          "confidence": 0,
          "strengths": ["string"],
          "mistakes": ["string"],
          "improvementPlan": ["string"],
          "nextTradeChecklist": ["string"],
          "finalVerdict": "string"
        }

        Be specific, concise, and professional. If a screenshot does not show enough detail, say what is missing instead of inventing facts.
        """
    }

    private func joinedNotes(for trade: Trade) -> String {
        [
            trade.notes,
            trade.tradeThesis,
            trade.marketContext,
            trade.executionReview,
            trade.lessonsLearned
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")
    }
}
