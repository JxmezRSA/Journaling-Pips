import Foundation
import SwiftData

@Model
final class MorningPlan {
    enum MarketBias: String, CaseIterable, Identifiable {
        case bullish = "Bullish"
        case bearish = "Bearish"
        case neutral = "Neutral"

        var id: String { rawValue }
    }

    var id: UUID = UUID()
    var date: Date = Date()
    private var biasRawValue: String = MarketBias.neutral.rawValue
    var watchlistRawValue: String = ""
    var maximumRiskPercent: Double = 1
    var maximumDailyLoss: Double = 0
    var maximumTrades: Int = 3
    var dailyProfitGoal: Double = 0
    var checklistRawValue: String = ""
    var dailyNotes: String = ""
    var goalsRawValue: String = ""

    var bias: MarketBias {
        get { MarketBias(rawValue: biasRawValue) ?? .neutral }
        set { biasRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        bias: MarketBias = .neutral,
        watchlistRawValue: String = "",
        maximumRiskPercent: Double = 1,
        maximumDailyLoss: Double = 0,
        maximumTrades: Int = 3,
        dailyProfitGoal: Double = 0,
        checklistRawValue: String = "",
        dailyNotes: String = "",
        goalsRawValue: String = ""
    ) {
        self.id = id
        self.date = date
        self.biasRawValue = bias.rawValue
        self.watchlistRawValue = watchlistRawValue
        self.maximumRiskPercent = maximumRiskPercent
        self.maximumDailyLoss = maximumDailyLoss
        self.maximumTrades = maximumTrades
        self.dailyProfitGoal = dailyProfitGoal
        self.checklistRawValue = checklistRawValue
        self.dailyNotes = dailyNotes
        self.goalsRawValue = goalsRawValue
    }
}
