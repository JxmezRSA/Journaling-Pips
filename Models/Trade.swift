import Foundation
import SwiftData

@Model
final class Trade {
    enum Direction: String, CaseIterable, Identifiable {
        case buy = "Buy"
        case sell = "Sell"

        var id: String { rawValue }
    }

    enum Status: String, CaseIterable, Identifiable {
        case win = "Win"
        case loss = "Loss"
        case breakeven = "Breakeven"

        var id: String { rawValue }
    }

    enum Session: String, CaseIterable, Identifiable {
        case asian = "Asian"
        case london = "London"
        case newYork = "New York"

        var id: String { rawValue }
    }

    enum Strategy: String, CaseIterable, Identifiable {
        case liquiditySweep = "Liquidity Sweep"
        case orderBlock = "Order Block"
        case fairValueGap = "Fair Value Gap"
        case breakout = "Breakout"
        case supportResistance = "Support & Resistance"
        case other = "Other"

        var id: String { rawValue }
    }

    enum MistakeTag: String, CaseIterable, Identifiable {
        case fomo = "FOMO"
        case revengeTrade = "Revenge Trade"
        case enteredEarly = "Entered Early"
        case enteredLate = "Entered Late"
        case movedStop = "Moved Stop"
        case closedEarly = "Closed Early"
        case brokeRules = "Broke Rules"
        case ignoredPlan = "Ignored Plan"
        case noConfirmation = "No Confirmation"
        case goodDiscipline = "Good Discipline"
        case overtrading = "Overtrading"
        case heldTooLong = "Held Too Long"
        case riskTooHigh = "Risk Too High"

        var id: String { rawValue }
    }

    enum ScreenshotSlot: String, CaseIterable, Identifiable {
        case beforeEntry = "Before Entry"
        case duringTrade = "During Trade"
        case afterExit = "After Exit"

        var id: String { rawValue }

        var subtitle: String {
            switch self {
            case .beforeEntry:
                return "Capture the setup before entry"
            case .duringTrade:
                return "Document management during the trade"
            case .afterExit:
                return "Review the final exit and outcome"
            }
        }

        var emptyActionTitle: String {
            switch self {
            case .beforeEntry:
                return "Add Before Entry Screenshot"
            case .duringTrade:
                return "Add During Trade Screenshot"
            case .afterExit:
                return "Add After Exit Screenshot"
            }
        }

        var icon: String {
            switch self {
            case .beforeEntry:
                return "camera.viewfinder"
            case .duringTrade:
                return "waveform.path.ecg"
            case .afterExit:
                return "flag.checkered"
            }
        }
    }

    var id: UUID
    var pair: String
    private var directionRawValue: String
    var entryPrice: Double
    var stopLoss: Double
    var takeProfit: Double
    var profitLoss: Double
    var notes: String
    var exitPrice: Double
    var lotSize: Double
    var riskPercent: Double
    var date: Date
    private var statusRawValue: String
    var riskReward: Double
    private var sessionRawValue: String
    private var strategyRawValue: String
    private var mistakeTagsRawValue: String
    var confidence: Double
    var emotion: String
    var executionScore: Int
    var followedPlan: Bool
    var tradeThesis: String
    var marketContext: String
    var executionReview: String
    var lessonsLearned: String
    var beforeImagePath: String
    var duringImagePath: String
    var afterImagePath: String
    var beforeEntryImageData: Data?
    var duringTradeImageData: Data?
    var afterExitImageData: Data?
    var tradeOpenTime: Date?
    var tradeCloseTime: Date?

    var direction: Direction {
        get { Direction(rawValue: directionRawValue) ?? .buy }
        set { directionRawValue = newValue.rawValue }
    }

    var status: Status {
        get { Status(rawValue: statusRawValue) ?? .breakeven }
        set { statusRawValue = newValue.rawValue }
    }

    var session: Session {
        get { Session(rawValue: sessionRawValue) ?? .london }
        set { sessionRawValue = newValue.rawValue }
    }

    var strategy: Strategy {
        get { Strategy(rawValue: strategyRawValue) ?? .other }
        set { strategyRawValue = newValue.rawValue }
    }

    var mistakeTags: [MistakeTag] {
        get {
            mistakeTagsRawValue
                .split(separator: "|")
                .compactMap { MistakeTag(rawValue: String($0)) }
        }
        set {
            mistakeTagsRawValue = newValue.map(\.rawValue).joined(separator: "|")
        }
    }

    init(
        id: UUID = UUID(),
        pair: String,
        direction: Direction,
        entryPrice: Double,
        stopLoss: Double,
        takeProfit: Double,
        profitLoss: Double,
        notes: String,
        exitPrice: Double = 0,
        lotSize: Double = 0,
        riskPercent: Double = 0,
        date: Date = Date(),
        status: Status,
        riskReward: Double = 0,
        session: Session = .london,
        strategy: Strategy = .other,
        mistakeTags: [MistakeTag] = [],
        confidence: Double = 5,
        emotion: String = "Neutral",
        executionScore: Int = 0,
        followedPlan: Bool = true,
        tradeThesis: String = "",
        marketContext: String = "",
        executionReview: String = "",
        lessonsLearned: String = "",
        beforeImagePath: String = "",
        duringImagePath: String = "",
        afterImagePath: String = "",
        beforeEntryImageData: Data? = nil,
        duringTradeImageData: Data? = nil,
        afterExitImageData: Data? = nil,
        tradeOpenTime: Date? = nil,
        tradeCloseTime: Date? = nil
    ) {
        self.id = id
        self.pair = pair
        self.directionRawValue = direction.rawValue
        self.entryPrice = entryPrice
        self.stopLoss = stopLoss
        self.takeProfit = takeProfit
        self.profitLoss = profitLoss
        self.notes = notes
        self.exitPrice = exitPrice
        self.lotSize = lotSize
        self.riskPercent = riskPercent
        self.date = date
        self.statusRawValue = status.rawValue
        self.riskReward = riskReward
        self.sessionRawValue = session.rawValue
        self.strategyRawValue = strategy.rawValue
        self.mistakeTagsRawValue = mistakeTags.map(\.rawValue).joined(separator: "|")
        self.confidence = confidence
        self.emotion = emotion
        self.executionScore = executionScore
        self.followedPlan = followedPlan
        self.tradeThesis = tradeThesis
        self.marketContext = marketContext
        self.executionReview = executionReview
        self.lessonsLearned = lessonsLearned
        self.beforeImagePath = beforeImagePath
        self.duringImagePath = duringImagePath
        self.afterImagePath = afterImagePath
        self.beforeEntryImageData = beforeEntryImageData
        self.duringTradeImageData = duringTradeImageData
        self.afterExitImageData = afterExitImageData
        self.tradeOpenTime = tradeOpenTime
        self.tradeCloseTime = tradeCloseTime
    }
}
