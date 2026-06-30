import Combine
import Foundation
import SwiftData

@MainActor
final class TradeViewModel: ObservableObject {
    @Published private(set) var trades: [Trade] = []
    @Published var errorMessage: String?

    private var repository: TradeRepository?

    init() {
        debugPrint("ADD TRADE VIEWMODEL INIT")
    }

    var totalNetProfitLoss: Double {
        trades.reduce(0) { $0 + $1.profitLoss }
    }

    var dailyProfitLoss: Double {
        profitLoss(in: .day)
    }

    var weeklyProfitLoss: Double {
        profitLoss(in: .weekOfYear)
    }

    var monthlyProfitLoss: Double {
        profitLoss(in: .month)
    }

    var winRate: Double {
        let resolvedTrades = trades.filter { $0.status == .win || $0.status == .loss }
        guard !resolvedTrades.isEmpty else { return 0 }

        let wins = resolvedTrades.filter { $0.status == .win }.count
        return (Double(wins) / Double(resolvedTrades.count)) * 100
    }

    func configure(context: ModelContext) {
        if repository == nil {
            repository = TradeRepository(context: context)
            debugPrint("ADD TRADE MODEL CONTEXT READY")
        }

        fetchTrades()
    }

    func fetchTrades() {
        guard let repository else {
            return
        }

        do {
            trades = try repository.fetchTrades()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load trades."
        }
    }

    @discardableResult
    func addTrade(
        pair: String,
        direction: Trade.Direction,
        entryPrice: Double,
        stopLoss: Double,
        takeProfit: Double,
        profitLoss: Double,
        notes: String,
        status: Trade.Status,
        riskReward: Double,
        session: Trade.Session,
        strategy: Trade.Strategy,
        mistakeTags: [Trade.MistakeTag],
        exitPrice: Double = 0,
        lotSize: Double = 0,
        riskPercent: Double = 0,
        tradeThesis: String = "",
        marketContext: String = "",
        executionReview: String = "",
        lessonsLearned: String = "",
        beforeEntryImageData: Data? = nil,
        duringTradeImageData: Data? = nil,
        afterExitImageData: Data? = nil,
        tradeOpenTime: Date? = nil,
        tradeCloseTime: Date? = nil
    ) -> Bool {
        guard let repository else {
            errorMessage = "Trade storage is not ready."
            return false
        }

        if let validationMessage = validateTradeInput(
            pair: pair,
            entryPrice: entryPrice,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            lotSize: lotSize,
            riskPercent: riskPercent,
            date: tradeOpenTime ?? Date()
        ) {
            errorMessage = validationMessage
            return false
        }

        let trade = Trade(
            pair: pair.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            direction: direction,
            entryPrice: entryPrice,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            profitLoss: profitLoss,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            exitPrice: exitPrice,
            lotSize: lotSize,
            riskPercent: riskPercent,
            status: status,
            riskReward: riskReward,
            session: session,
            strategy: strategy,
            mistakeTags: mistakeTags,
            tradeThesis: tradeThesis.trimmingCharacters(in: .whitespacesAndNewlines),
            marketContext: marketContext.trimmingCharacters(in: .whitespacesAndNewlines),
            executionReview: executionReview.trimmingCharacters(in: .whitespacesAndNewlines),
            lessonsLearned: lessonsLearned.trimmingCharacters(in: .whitespacesAndNewlines),
            beforeEntryImageData: beforeEntryImageData,
            duringTradeImageData: duringTradeImageData,
            afterExitImageData: afterExitImageData,
            tradeOpenTime: tradeOpenTime,
            tradeCloseTime: tradeCloseTime
        )

        do {
            try repository.saveTrade(trade)
            DisciplineTracker(context: repository.context).recordTradeSaved(trade)
            IntelligenceEngine(context: repository.context).observe(.tradeSaved)
            fetchTrades()
            return true
        } catch {
            errorMessage = "Unable to save trade."
            return false
        }
    }

    @discardableResult
    func applyTradeForm(
        to trade: Trade,
        pair: String,
        direction: Trade.Direction,
        entryPrice: Double,
        stopLoss: Double,
        takeProfit: Double,
        profitLoss: Double,
        notes: String,
        status: Trade.Status,
        riskReward: Double,
        session: Trade.Session,
        strategy: Trade.Strategy,
        mistakeTags: [Trade.MistakeTag],
        exitPrice: Double,
        lotSize: Double,
        riskPercent: Double,
        tradeThesis: String,
        marketContext: String,
        executionReview: String,
        lessonsLearned: String,
        beforeEntryImageData: Data?,
        duringTradeImageData: Data?,
        afterExitImageData: Data?,
        tradeOpenTime: Date?,
        tradeCloseTime: Date?
    ) -> Bool {
        if let validationMessage = validateTradeInput(
            pair: pair,
            entryPrice: entryPrice,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            lotSize: lotSize,
            riskPercent: riskPercent,
            date: tradeOpenTime ?? trade.date
        ) {
            errorMessage = validationMessage
            return false
        }

        trade.pair = pair.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        trade.direction = direction
        trade.entryPrice = entryPrice
        trade.stopLoss = stopLoss
        trade.takeProfit = takeProfit
        trade.profitLoss = profitLoss
        trade.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.status = status
        trade.riskReward = riskReward
        trade.session = session
        trade.strategy = strategy
        trade.mistakeTags = mistakeTags
        trade.exitPrice = exitPrice
        trade.lotSize = lotSize
        trade.riskPercent = riskPercent
        trade.tradeThesis = tradeThesis.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.marketContext = marketContext.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.executionReview = executionReview.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.lessonsLearned = lessonsLearned.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.beforeEntryImageData = beforeEntryImageData
        trade.duringTradeImageData = duringTradeImageData
        trade.afterExitImageData = afterExitImageData
        trade.tradeOpenTime = tradeOpenTime
        trade.tradeCloseTime = tradeCloseTime

        guard let repository else {
            errorMessage = "Trade storage is not ready."
            return false
        }

        do {
            try repository.updateTrade(trade)
            DisciplineTracker(context: repository.context).recordTradeReviewCompleted(trade)
            IntelligenceEngine(context: repository.context).observe(.tradeEdited)
            fetchTrades()
            return true
        } catch {
            errorMessage = "Unable to update trade."
            return false
        }
    }

    @discardableResult
    func updateTradeReview(
        _ trade: Trade,
        confidence: Double,
        emotion: String,
        executionScore: Int,
        followedPlan: Bool,
        mistakeTags: [Trade.MistakeTag],
        tradeThesis: String,
        marketContext: String,
        executionReview: String,
        lessonsLearned: String
    ) -> Bool {
        trade.confidence = confidence
        trade.emotion = emotion
        trade.executionScore = executionScore
        trade.followedPlan = followedPlan
        trade.mistakeTags = mistakeTags
        trade.tradeThesis = tradeThesis.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.marketContext = marketContext.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.executionReview = executionReview.trimmingCharacters(in: .whitespacesAndNewlines)
        trade.lessonsLearned = lessonsLearned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let repository else {
            errorMessage = "Trade storage is not ready."
            return false
        }

        do {
            try repository.updateTrade(trade)
            IntelligenceEngine(context: repository.context).observe(.tradeEdited)
            fetchTrades()
            return true
        } catch {
            errorMessage = "Unable to update trade review."
            return false
        }
    }

    func updateTrade(_ trade: Trade) {
        guard let repository else {
            errorMessage = "Trade storage is not ready."
            return
        }

        do {
            try repository.updateTrade(trade)
            IntelligenceEngine(context: repository.context).observe(.tradeEdited)
            fetchTrades()
        } catch {
            errorMessage = "Unable to update trade."
        }
    }

    @discardableResult
    func updateScreenshot(_ trade: Trade, slot: Trade.ScreenshotSlot, imageData: Data?) -> Bool {
        switch slot {
        case .beforeEntry:
            trade.beforeEntryImageData = imageData
        case .duringTrade:
            trade.duringTradeImageData = imageData
        case .afterExit:
            trade.afterExitImageData = imageData
        }

        guard let repository else {
            errorMessage = "Trade storage is not ready."
            return false
        }

        do {
            try repository.updateTrade(trade)
            IntelligenceEngine(context: repository.context).observe(.tradeEdited)
            fetchTrades()
            return true
        } catch {
            errorMessage = "Unable to update screenshot."
            return false
        }
    }

    func deleteTrade(_ trade: Trade) {
        guard let repository else {
            errorMessage = "Trade storage is not ready."
            return
        }

        do {
            try repository.deleteTrade(trade)
            IntelligenceEngine(context: repository.context).observe(.tradeDeleted)
            fetchTrades()
        } catch {
            errorMessage = "Unable to delete trade."
        }
    }

    private func profitLoss(in component: Calendar.Component) -> Double {
        let calendar = Calendar.current

        return trades
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: component) }
            .reduce(0) { $0 + $1.profitLoss }
    }

    private func validateTradeInput(
        pair: String,
        entryPrice: Double,
        stopLoss: Double,
        takeProfit: Double,
        lotSize: Double,
        riskPercent: Double,
        date: Date?
    ) -> String? {
        let trimmedPair = pair.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPair.isEmpty else {
            return "Pair is required."
        }

        guard entryPrice.isFinite, entryPrice > 0 else {
            return "Entry price must be greater than zero."
        }

        guard stopLoss.isFinite, stopLoss > 0 else {
            return "Stop loss must be greater than zero."
        }

        guard takeProfit.isFinite, takeProfit > 0 else {
            return "Take profit must be greater than zero."
        }

        guard abs(entryPrice - stopLoss) > 0.000_000_1 else {
            return "Entry price cannot equal stop loss."
        }

        guard lotSize.isFinite, lotSize > 0 else {
            return "Lot size must be greater than zero."
        }

        guard riskPercent.isFinite, riskPercent > 0 else {
            return "Risk percent must be greater than zero."
        }

        guard date != nil else {
            return "Trade date is required."
        }

        return nil
    }
}
