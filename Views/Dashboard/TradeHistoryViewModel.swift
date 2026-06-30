import Combine
import Foundation
import SwiftUI

enum TradeHistoryFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "All"
    case wins = "Wins"
    case losses = "Losses"
    case breakeven = "Breakeven"
    case london = "London"
    case newYork = "New York"
    case asia = "Asia"
    case highRR = "High RR"
    case lowRR = "Low RR"
    case screenshots = "With Screenshots"
    case aiReview = "With AI Review"
    case favorites = "Favorites"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "rectangle.stack.fill"
        case .wins: return "arrow.up.right.circle.fill"
        case .losses: return "arrow.down.right.circle.fill"
        case .breakeven: return "equal.circle.fill"
        case .london, .newYork, .asia: return "clock.fill"
        case .highRR: return "target"
        case .lowRR: return "exclamationmark.triangle.fill"
        case .screenshots: return "photo.stack.fill"
        case .aiReview: return "sparkles"
        case .favorites: return "star.fill"
        }
    }
}

enum TradeHistorySort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"
    case highestProfit = "Highest Profit"
    case biggestLoss = "Biggest Loss"
    case bestRR = "Best RR"
    case worstRR = "Worst RR"
    case bestAIScore = "Best AI Score"

    var id: String { rawValue }
}

struct TradeHistoryGroup: Identifiable {
    let id: String
    let title: String
    let trades: [Trade]
    let netProfit: Double
    let winRate: Double
}

private struct TradeHistoryGroupKey: Hashable {
    let id: String
    let title: String
}

struct TradeHistoryMetrics {
    let totalTrades: Int
    let winRate: Double
    let totalProfit: Double
    let averageRiskReward: Double
    let currentStreak: String
}

struct TradeHistoryDay: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let label: String
    let netProfit: Double
    let trades: Int
}

@MainActor
final class TradeHistoryViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedFilters: Set<TradeHistoryFilter> = [.all]
    @Published var sort = TradeHistorySort.newest
    @Published var selectedDay: Date?

    private let calendar = Calendar.current

    func metrics(for trades: [Trade]) -> TradeHistoryMetrics {
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }
        let wins = resolved.filter { $0.status == .win }.count
        let rrValues = trades.map(\.riskReward).filter { $0 > 0 }
        return TradeHistoryMetrics(
            totalTrades: trades.count,
            winRate: resolved.isEmpty ? 0 : Double(wins) / Double(resolved.count) * 100,
            totalProfit: trades.reduce(0) { $0 + $1.profitLoss },
            averageRiskReward: rrValues.isEmpty ? 0 : rrValues.reduce(0, +) / Double(rrValues.count),
            currentStreak: currentStreak(for: trades)
        )
    }

    func visibleTrades(_ trades: [Trade], favorites: Set<UUID>, reviews: [AITradeReview]) -> [Trade] {
        let searched = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trades.filter { trade in
            matchesSearch(trade, searched) &&
            matchesFilters(trade, favorites: favorites, reviews: reviews) &&
            matchesSelectedDay(trade)
        }

        return sortTrades(filtered, reviews: reviews)
    }

    func groupedTrades(_ trades: [Trade]) -> [TradeHistoryGroup] {
        let grouped = Dictionary(grouping: trades) { groupKey(for: $0.date) }
        return grouped.map { key, trades in
            let sorted = trades.sorted { $0.date > $1.date }
            let resolved = sorted.filter { $0.status == .win || $0.status == .loss }
            let wins = resolved.filter { $0.status == .win }.count
            return TradeHistoryGroup(
                id: key.id,
                title: key.title,
                trades: sorted,
                netProfit: sorted.reduce(0) { $0 + $1.profitLoss },
                winRate: resolved.isEmpty ? 0 : Double(wins) / Double(resolved.count) * 100
            )
        }
        .sorted { $0.id < $1.id }
    }

    func toggleFilter(_ filter: TradeHistoryFilter) {
        if filter == .all {
            selectedFilters = [.all]
            return
        }

        selectedFilters.remove(.all)
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            selectedFilters.insert(filter)
        }

        if selectedFilters.isEmpty {
            selectedFilters = [.all]
        }
    }

    func weekStrip(for trades: [Trade]) -> [TradeHistoryDay] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
            let dayTrades = trades.filter { calendar.isDate($0.date, inSameDayAs: date) }
            return TradeHistoryDay(
                date: date,
                label: calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1],
                netProfit: dayTrades.reduce(0) { $0 + $1.profitLoss },
                trades: dayTrades.count
            )
        }
    }

    func smartInsights(for trades: [Trade]) -> [String] {
        guard !trades.isEmpty else { return [] }
        var insights: [String] = []
        if let session = strongestSession(for: trades) {
            insights.append("You perform best during \(session.rawValue).")
        }
        if let pair = strongestPair(for: trades) {
            insights.append("\(pair) is currently your strongest pair.")
        }
        let screenshotTrades = trades.filter { screenshotCount(for: $0) > 0 }
        if !screenshotTrades.isEmpty {
            insights.append("Trades with screenshots are easier to review later.")
        }
        if let mistake = mostCommonMistake(for: trades) {
            insights.append("Your most common mistake is \(mistake.rawValue.lowercased()).")
        }
        if trades.filter(\.followedPlan).count > trades.count / 2 {
            insights.append("Your win rate improves when checklist discipline is high.")
        }
        return Array(insights.prefix(5))
    }

    func screenshotCount(for trade: Trade) -> Int {
        [trade.beforeEntryImageData, trade.duringTradeImageData, trade.afterExitImageData].compactMap { $0 }.count
    }

    private func matchesSearch(_ trade: Trade, _ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let haystack = [
            trade.pair,
            trade.session.rawValue,
            trade.strategy.rawValue,
            trade.direction.rawValue,
            trade.status.rawValue,
            trade.notes,
            trade.tradeThesis,
            trade.marketContext,
            trade.executionReview,
            trade.lessonsLearned,
            trade.mistakeTags.map(\.rawValue).joined(separator: " ")
        ].joined(separator: " ").lowercased()
        return haystack.contains(query.lowercased())
    }

    private func matchesFilters(_ trade: Trade, favorites: Set<UUID>, reviews: [AITradeReview]) -> Bool {
        guard !selectedFilters.contains(.all) else { return true }
        return selectedFilters.allSatisfy { filter in
            switch filter {
            case .all: return true
            case .wins: return trade.status == .win
            case .losses: return trade.status == .loss
            case .breakeven: return trade.status == .breakeven
            case .london: return trade.session == .london
            case .newYork: return trade.session == .newYork
            case .asia: return trade.session == .asian
            case .highRR: return trade.riskReward >= 2
            case .lowRR: return trade.riskReward > 0 && trade.riskReward < 1
            case .screenshots: return screenshotCount(for: trade) > 0
            case .aiReview: return reviews.contains { $0.tradeID == trade.id }
            case .favorites: return favorites.contains(trade.id)
            }
        }
    }

    private func matchesSelectedDay(_ trade: Trade) -> Bool {
        guard let selectedDay else { return true }
        return calendar.isDate(trade.date, inSameDayAs: selectedDay)
    }

    private func sortTrades(_ trades: [Trade], reviews: [AITradeReview]) -> [Trade] {
        switch sort {
        case .newest:
            return trades.sorted { $0.date > $1.date }
        case .oldest:
            return trades.sorted { $0.date < $1.date }
        case .highestProfit:
            return trades.sorted { $0.profitLoss > $1.profitLoss }
        case .biggestLoss:
            return trades.sorted { $0.profitLoss < $1.profitLoss }
        case .bestRR:
            return trades.sorted { $0.riskReward > $1.riskReward }
        case .worstRR:
            return trades.sorted { $0.riskReward < $1.riskReward }
        case .bestAIScore:
            return trades.sorted { aiScore(for: $0, reviews: reviews) > aiScore(for: $1, reviews: reviews) }
        }
    }

    private func aiScore(for trade: Trade, reviews: [AITradeReview]) -> Int {
        reviews.first { $0.tradeID == trade.id }?.overallScore ?? -1
    }

    private func currentStreak(for trades: [Trade]) -> String {
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }.sorted { $0.date > $1.date }
        guard let latest = resolved.first?.status else { return "0" }
        let count = resolved.prefix { $0.status == latest }.count
        return "\(count)\(latest == .win ? "W" : "L")"
    }

    private func groupKey(for date: Date) -> TradeHistoryGroupKey {
        let today = calendar.startOfDay(for: Date())
        let day = calendar.startOfDay(for: date)
        if calendar.isDateInToday(date) { return TradeHistoryGroupKey(id: "0000", title: "Today") }
        if calendar.isDateInYesterday(date) { return TradeHistoryGroupKey(id: "0001", title: "Yesterday") }
        if calendar.isDate(date, equalTo: today, toGranularity: .weekOfYear) { return TradeHistoryGroupKey(id: "0002", title: "This Week") }
        if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: today),
           calendar.isDate(date, equalTo: lastWeek, toGranularity: .weekOfYear) {
            return TradeHistoryGroupKey(id: "0003", title: "Last Week")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let components = calendar.dateComponents([.year, .month], from: day)
        let sortID = String(format: "%04d%02d", 9999 - (components.year ?? 0), 13 - (components.month ?? 0))
        return TradeHistoryGroupKey(id: sortID, title: formatter.string(from: date))
    }

    private func strongestSession(for trades: [Trade]) -> Trade.Session? {
        Dictionary(grouping: trades, by: \.session)
            .max { lhs, rhs in
                lhs.value.reduce(0) { $0 + $1.profitLoss } < rhs.value.reduce(0) { $0 + $1.profitLoss }
            }?.key
    }

    private func strongestPair(for trades: [Trade]) -> String? {
        Dictionary(grouping: trades) { $0.pair }
            .max { lhs, rhs in
                lhs.value.reduce(0) { $0 + $1.profitLoss } < rhs.value.reduce(0) { $0 + $1.profitLoss }
            }?.key
    }

    private func mostCommonMistake(for trades: [Trade]) -> Trade.MistakeTag? {
        let tags = trades.flatMap(\.mistakeTags)
        return Dictionary(grouping: tags) { $0 }.max { $0.value.count < $1.value.count }?.key
    }
}
