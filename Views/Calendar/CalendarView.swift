import SwiftData
import SwiftUI
import UIKit

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \AITradeReview.updatedAt, order: .reverse) private var aiReviews: [AITradeReview]
    @Query(sort: \DisciplineDay.date, order: .reverse) private var disciplineDays: [DisciplineDay]

    @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var selectedDay: CalendarDaySnapshot?
    @State private var replayTrade: Trade?
    @State private var showAddTrade = false
    @State private var showReplay = false
    @State private var showCalendarAction = false
    @State private var calendarActionMessage = ""
    @State private var didAppear = false

    @State private var searchText = ""
    @State private var selectedFilter = CalendarTradeFilter.all
    @State private var selectedDayFilter: Date?

    private let calendar = Calendar.current

    private var monthTrades: [Trade] {
        filteredTrades(tradeViewModel.trades.filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) })
    }

    private var allMonthTrades: [Trade] {
        tradeViewModel.trades.filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
    }

    private var dailySnapshots: [CalendarDaySnapshot] {
        let days = daysInMonth(for: displayedMonth)
        let groupedTrades = Dictionary(grouping: monthTrades) { calendar.startOfDay(for: $0.date) }
        return days.map { day in
            snapshot(for: day, trades: groupedTrades[calendar.startOfDay(for: day)] ?? [])
        }
    }

    private var monthlyAnalytics: TradingCalendarAnalytics {
        TradingCalendarAnalytics(trades: allMonthTrades, reviews: aiReviews, disciplineDays: disciplineDays, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JPColors.backgroundGradient.ignoresSafeArea()
                backgroundGlow

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        header
                        monthSelector

                        if tradeViewModel.trades.isEmpty {
                            emptyState
                        } else {
                            filterSection
                            heatmapSection
                            monthlyInsights
                            monthlyAchievements
                            quickActions
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 160)
                }
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedDay) { day in
                DailyReviewWorkspace(
                    day: day,
                    reviews: aiReviews,
                    discipline: disciplineDays.first { calendar.isDate($0.date, inSameDayAs: day.date) },
                    replayTrade: $replayTrade,
                    showReplay: $showReplay
                )
                .environmentObject(tradeViewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddTrade) {
                AddTradeView {
                    tradeViewModel.fetchTrades()
                    showAddTrade = false
                }
                .environmentObject(tradeViewModel)
            }
            .sheet(isPresented: $showReplay) {
                if subscriptionManager.isPremiumUnlocked, let replayTrade {
                    ReplayStudioView(trade: replayTrade)
                } else {
                    PremiumPaywallView()
                        .environmentObject(subscriptionManager)
                }
            }
            .alert("Calendar Action", isPresented: $showCalendarAction) {
                Button("Done", role: .cancel) {}
            } message: {
                Text(calendarActionMessage)
            }
            .onAppear {
                tradeViewModel.configure(context: modelContext)
                tradeViewModel.fetchTrades()
                withAnimation(JPDesign.smoothSpring) {
                    didAppear = true
                }
            }
        }
    }

    private var backgroundGlow: some View {
        VStack {
            Circle()
                .fill(JPColors.accent.opacity(0.13))
                .frame(width: 260, height: 260)
                .blur(radius: 72)
                .offset(x: 118, y: -96)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Calendar")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(JPColors.primaryText)

                Text("Review your trading journey.")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
            }

            CalendarHeroCard(month: displayedMonth, analytics: monthlyAnalytics)
        }
        .premiumEntrance(active: didAppear)
    }

    private var monthSelector: some View {
        GlassCard(padding: 14, cornerRadius: 30) {
            HStack(spacing: 12) {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(ScalingButtonStyle())
                .accessibilityLabel("Previous month")

                Spacer()

                VStack(spacing: 3) {
                    Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text(calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) ? "Current Month" : "Selected Month")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.accent)
                }

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(ScalingButtonStyle())
                .accessibilityLabel("Next month")
            }
            .foregroundStyle(JPColors.primaryText)
        }
        .premiumEntrance(active: didAppear, delay: 0.04)
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(JPColors.secondaryText)

                TextField("Search pair, setup, session...", text: $searchText)
                    .textInputAutocapitalization(.characters)
                    .foregroundStyle(JPColors.primaryText)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        withAnimation(JPDesign.quickSpring) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(JPColors.mutedText)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(JPColors.border, lineWidth: 1)
            )

            Menu {
                ForEach(CalendarTradeFilter.allCases) { filter in
                    Button {
                        withAnimation(JPDesign.quickSpring) {
                            selectedFilter = filter
                        }
                        JPHaptics.selection()
                    } label: {
                        Label(filter.rawValue, systemImage: filter.icon)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedFilter.icon)
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.accent)
                    Text(selectedFilter.rawValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.secondaryText)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(JPColors.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JPColors.border, lineWidth: 1))
            }
            .accessibilityLabel("Calendar filter")

            if let selectedDayFilter {
                Button {
                    withAnimation(JPDesign.quickSpring) {
                        self.selectedDayFilter = nil
                    }
                } label: {
                    Label("Showing \(selectedDayFilter.formatted(.dateTime.month(.abbreviated).day())). Clear date filter", systemImage: "line.3.horizontal.decrease.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(JPColors.accentSoft, in: Capsule())
                }
                .buttonStyle(ScalingButtonStyle())
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.08)
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Trading Heatmap", subtitle: "Profit, discipline, and AI quality by day")

            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    CalendarLegend()

                    HStack(spacing: 8) {
                        ForEach(calendar.veryShortStandaloneWeekdaySymbols, id: \.self) { symbol in
                            Text(symbol.uppercased())
                                .font(.caption2.weight(.black))
                                .foregroundStyle(JPColors.mutedText)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    GeometryReader { proxy in
                        let spacing: CGFloat = 8
                        let cellSize = max(28, (proxy.size.width - spacing * 6) / 7)

                        VStack(spacing: spacing) {
                            ForEach(heatmapRows) { row in
                                HStack(spacing: spacing) {
                                    ForEach(row.items) { item in
                                        if let day = item.snapshot {
                                            CalendarHeatmapCell(
                                                snapshot: day,
                                                isSelected: selectedDayFilter.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false,
                                                isToday: calendar.isDateInToday(day.date)
                                            ) {
                                                withAnimation(JPDesign.smoothSpring) {
                                                    selectedDayFilter = day.date
                                                    selectedDay = day
                                                }
                                                JPHaptics.selection()
                                            }
                                            .frame(width: cellSize, height: cellSize)
                                        } else {
                                            Color.clear
                                                .frame(width: cellSize, height: cellSize)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: heatmapHeight)
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.12)
    }

    private var monthlyInsights: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Monthly Insights", subtitle: "A clear read on this month")

            VStack(spacing: 12) {
                ForEach(monthlyInsightRows) { row in
                    HStack(spacing: 12) {
                        ForEach(row.items) { tile in
                            CalendarInsightTile(tile: tile)
                        }
                        if row.items.count == 1 {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.16)
    }

    private var monthlyAchievements: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Monthly Achievements", subtitle: "Badges earned from trading behavior")

            VStack(spacing: 12) {
                ForEach(monthlyAchievementRows) { row in
                    HStack(spacing: 12) {
                        ForEach(row.items) { badge in
                            CalendarAchievementBadge(badge: badge)
                        }
                        if row.items.count == 1 {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.20)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Quick Actions", subtitle: "Keep momentum after the review")

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    CalendarActionButton(title: "Export Month", icon: "square.and.arrow.up", tint: JPColors.blue) {
                        showAction("Monthly export is ready for the existing Reports system.")
                    }

                    CalendarActionButton(title: "Share Statistics", icon: "chart.bar.xaxis", tint: JPColors.warning) {
                        showAction("Statistics sharing placeholder is ready.")
                    }
                }

                HStack(spacing: 12) {
                    CalendarActionButton(title: "AI Monthly Review", icon: "sparkles", tint: JPColors.purple) {
                        showAction("AI monthly review will use saved trades and local insights when connected.")
                    }

                    NavigationLink {
                        TradeHistoryView()
                            .environmentObject(tradeViewModel)
                    } label: {
                        CalendarActionLabel(title: "Trade History", icon: "clock.arrow.circlepath", tint: JPColors.accent)
                    }
                    .buttonStyle(ScalingButtonStyle())
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.24)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(JPColors.accent)
                    .frame(width: 78, height: 78)
                    .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your trading journey begins here.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Log your first trade and the calendar will become a visual map of your discipline, performance, and growth.")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    JPHaptics.impact(.medium)
                    showAddTrade = true
                } label: {
                    Label("Create First Trade", systemImage: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(colors: [JPColors.accent, JPColors.profit], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                }
                .buttonStyle(ScalingButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .premiumEntrance(active: didAppear, delay: 0.10)
    }

    private var monthlyInsightTiles: [CalendarInsightTileModel] {
        [
            .init(title: "Total Profit", value: currency(max(monthlyAnalytics.netProfit, 0)), icon: "arrow.up.right", tint: JPColors.profit),
            .init(title: "Total Loss", value: currency(min(monthlyAnalytics.netProfit, 0)), icon: "arrow.down.right", tint: JPColors.loss),
            .init(title: "Average RR", value: rr(monthlyAnalytics.averageRR), icon: "scale.3d", tint: JPColors.warning),
            .init(title: "Win Rate", value: percent(monthlyAnalytics.winRate), icon: "target", tint: JPColors.accent),
            .init(title: "Trades", value: "\(monthlyAnalytics.totalTrades)", icon: "number", tint: JPColors.blue),
            .init(title: "Avg Hold", value: monthlyAnalytics.averageHoldTime, icon: "timer", tint: JPColors.purple),
            .init(title: "Best Session", value: monthlyAnalytics.bestSession, icon: "sun.max.fill", tint: JPColors.profit),
            .init(title: "Worst Session", value: monthlyAnalytics.worstSession, icon: "cloud.rain.fill", tint: JPColors.loss),
            .init(title: "Most Traded Pair", value: monthlyAnalytics.mostTradedPair, icon: "chart.line.uptrend.xyaxis", tint: JPColors.accent),
            .init(title: "Best Setup", value: monthlyAnalytics.bestSetup, icon: "sparkles", tint: JPColors.warning),
            .init(title: "Worst Setup", value: monthlyAnalytics.worstSetup, icon: "exclamationmark.triangle.fill", tint: JPColors.loss),
            .init(title: "Winning Streak", value: "\(monthlyAnalytics.longestWinningStreak)", icon: "flame.fill", tint: JPColors.profit),
            .init(title: "Losing Streak", value: "\(monthlyAnalytics.longestLosingStreak)", icon: "bolt.slash.fill", tint: JPColors.loss),
            .init(title: "Avg AI Score", value: "\(monthlyAnalytics.averageAIScore)", icon: "sparkles", tint: JPColors.blue),
            .init(title: "Discipline", value: percent(Double(monthlyAnalytics.averageDisciplineScore)), icon: "checkmark.seal.fill", tint: JPColors.accent),
            .init(title: "Journal Complete", value: percent(monthlyAnalytics.journalCompletion), icon: "book.closed.fill", tint: JPColors.purple)
        ]
    }

    private var monthlyInsightRows: [CalendarInsightRow] {
        monthlyInsightTiles.chunked(into: 2).map { CalendarInsightRow(items: $0) }
    }

    private var monthlyAchievementBadges: [CalendarAchievementModel] {
        [
            .init(title: "Perfect Week", icon: "7.circle.fill", tint: JPColors.accent, isUnlocked: monthlyAnalytics.longestWinningStreak >= 5),
            .init(title: "100% Journal", icon: "book.fill", tint: JPColors.purple, isUnlocked: monthlyAnalytics.journalCompletion >= 100),
            .init(title: "Highest RR", icon: "crown.fill", tint: JPColors.warning, isUnlocked: monthlyAnalytics.averageRR >= 3),
            .init(title: "Most Consistent", icon: "waveform.path.ecg", tint: JPColors.blue, isUnlocked: monthlyAnalytics.winRate >= 60 && monthlyAnalytics.totalTrades >= 5),
            .init(title: "No Revenge", icon: "shield.lefthalf.filled", tint: JPColors.accent, isUnlocked: !allMonthTrades.contains { $0.mistakeTags.contains(.revengeTrade) }),
            .init(title: "No Rule Breaks", icon: "checkmark.shield.fill", tint: JPColors.profit, isUnlocked: !allMonthTrades.contains { $0.mistakeTags.contains(.brokeRules) || $0.mistakeTags.contains(.ignoredPlan) }),
            .init(title: "Morning Routine", icon: "sunrise.fill", tint: JPColors.warning, isUnlocked: monthlyAnalytics.averageDisciplineScore >= 75),
            .init(title: "Weekly Champion", icon: "rosette", tint: JPColors.blue, isUnlocked: monthlyAnalytics.netProfit > 0 && monthlyAnalytics.totalTrades >= 7)
        ]
    }

    private var monthlyAchievementRows: [CalendarAchievementRow] {
        monthlyAchievementBadges.chunked(into: 2).map { CalendarAchievementRow(items: $0) }
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(JPDesign.smoothSpring) {
            displayedMonth = newMonth
            selectedDayFilter = nil
        }
        JPHaptics.selection()
    }

    private func showAction(_ message: String) {
        calendarActionMessage = message
        showCalendarAction = true
        JPHaptics.impact(.light)
    }

    private func filteredTrades(_ trades: [Trade]) -> [Trade] {
        trades
            .filter(matchesSearch)
            .filter(matchesSelectedFilter)
            .filter { trade in
                selectedDayFilter.map { calendar.isDate(trade.date, inSameDayAs: $0) } ?? true
            }
    }

    private func matchesSearch(_ trade: Trade) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let haystack = [
            trade.pair,
            trade.strategy.rawValue,
            trade.session.rawValue,
            trade.direction.rawValue,
            trade.status.rawValue,
            trade.notes,
            trade.mistakeTags.map(\.rawValue).joined(separator: " ")
        ].joined(separator: " ").localizedCaseInsensitiveContains(query)
        return haystack
    }

    private func matchesSelectedFilter(_ trade: Trade) -> Bool {
        switch selectedFilter {
        case .all: return true
        case .winning: return trade.status == .win
        case .losing: return trade.status == .loss
        case .breakeven: return trade.status == .breakeven
        case .buy: return trade.direction == .buy
        case .sell: return trade.direction == .sell
        case .asian: return trade.session == .asian
        case .london: return trade.session == .london
        case .newYork: return trade.session == .newYork
        case .aiExcellent: return (aiReviews.first { $0.tradeID == trade.id }?.overallScore ?? 0) >= 85
        case .disciplined: return trade.followedPlan && !trade.mistakeTags.contains(.brokeRules) && !trade.mistakeTags.contains(.revengeTrade)
        }
    }

    private func snapshot(for day: Date, trades: [Trade]) -> CalendarDaySnapshot {
        let reviewScores = trades.compactMap { trade in aiReviews.first { $0.tradeID == trade.id }?.overallScore }
        let discipline = disciplineDays.first { calendar.isDate($0.date, inSameDayAs: day) }
        return CalendarDaySnapshot(
            date: day,
            trades: trades.sorted { $0.date < $1.date },
            aiScores: reviewScores,
            disciplineScore: discipline?.disciplineScore ?? inferredDiscipline(for: trades)
        )
    }

    private func inferredDiscipline(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let followed = Double(trades.filter(\.followedPlan).count) / Double(trades.count)
        let journals = Double(trades.filter { !$0.lessonsLearned.isEmpty || !$0.executionReview.isEmpty || !$0.tradeThesis.isEmpty }.count) / Double(trades.count)
        let mistakes = Double(trades.filter { $0.mistakeTags.contains(.revengeTrade) || $0.mistakeTags.contains(.brokeRules) || $0.mistakeTags.contains(.riskTooHigh) }.count)
        return max(0, min(100, Int(((followed * 55) + (journals * 35) - (mistakes * 12) + 10).rounded())))
    }

    private func daysInMonth(for date: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    private func leadingBlankDays(for date: Date) -> Int {
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return 0 }
        return max(calendar.component(.weekday, from: start) - 1, 0)
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func rr(_ value: Double) -> String {
        value > 0 ? String(format: "%.2f R", value) : "0.00 R"
    }

    private var heatmapRows: [CalendarHeatmapRow] {
        let blanks = (0..<leadingBlankDays(for: displayedMonth)).map { CalendarHeatmapItem(id: "blank-\($0)", snapshot: nil) }
        let days = dailySnapshots.map { CalendarHeatmapItem(id: "day-\($0.id.timeIntervalSince1970)", snapshot: $0) }
        return (blanks + days).chunked(into: 7).enumerated().map { index, items in
            let trailingBlanks = (items.count..<7).map { CalendarHeatmapItem(id: "trailing-\(index)-\($0)", snapshot: nil) }
            return CalendarHeatmapRow(items: items + trailingBlanks)
        }
    }

    private var heatmapHeight: CGFloat {
        CGFloat(heatmapRows.count) * 46 + CGFloat(max(heatmapRows.count - 1, 0)) * 8
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}

private struct CalendarHeatmapItem: Identifiable {
    let id: String
    let snapshot: CalendarDaySnapshot?
}

private struct CalendarHeatmapRow: Identifiable {
    let id = UUID()
    let items: [CalendarHeatmapItem]
}

private struct CalendarAchievementRow: Identifiable {
    let id = UUID()
    let items: [CalendarAchievementModel]
}

private enum CalendarTradeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case winning = "Wins"
    case losing = "Losses"
    case breakeven = "Breakeven"
    case buy = "Buy"
    case sell = "Sell"
    case asian = "Asian"
    case london = "London"
    case newYork = "New York"
    case aiExcellent = "AI 85+"
    case disciplined = "Discipline"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .winning: return "arrow.up.right"
        case .losing: return "arrow.down.right"
        case .breakeven: return "equal"
        case .buy: return "cart.badge.plus"
        case .sell: return "cart.badge.minus"
        case .asian: return "moon.stars.fill"
        case .london: return "sun.max.fill"
        case .newYork: return "building.2.fill"
        case .aiExcellent: return "sparkles"
        case .disciplined: return "checkmark.seal.fill"
        }
    }
}

private struct CalendarDaySnapshot: Identifiable {
    let id: Date
    let date: Date
    let trades: [Trade]
    let aiScores: [Int]
    let disciplineScore: Int

    init(date: Date, trades: [Trade], aiScores: [Int], disciplineScore: Int) {
        self.id = Calendar.current.startOfDay(for: date)
        self.date = date
        self.trades = trades
        self.aiScores = aiScores
        self.disciplineScore = disciplineScore
    }

    var netProfit: Double { trades.reduce(0) { $0 + $1.profitLoss } }
    var totalTrades: Int { trades.count }
    var averageRR: Double {
        let values = trades.filter { $0.riskReward > 0 }
        return values.isEmpty ? 0 : values.reduce(0) { $0 + $1.riskReward } / Double(values.count)
    }
    var winRate: Double {
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }
        return resolved.isEmpty ? 0 : Double(resolved.filter { $0.status == .win }.count) / Double(resolved.count) * 100
    }
    var averageAIScore: Int {
        aiScores.isEmpty ? 0 : Int((Double(aiScores.reduce(0, +)) / Double(aiScores.count)).rounded())
    }
    var bestPair: String {
        bestByNet(trades.map(\.pair)) ?? "None"
    }
    var bestSession: String {
        bestByNet(trades.map { $0.session.rawValue }) ?? "None"
    }
    var worstMistake: String {
        let tags = trades.flatMap(\.mistakeTags).map(\.rawValue)
        return tags.frequencySorted().first ?? "None"
    }
    var lesson: String {
        trades.first { !$0.lessonsLearned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?.lessonsLearned ?? "Review the day, protect capital, and document the next improvement."
    }

    private func bestByNet(_ keys: [String]) -> String? {
        let groups = Dictionary(grouping: trades) { trade in
            keys.contains(trade.pair) ? trade.pair : trade.session.rawValue
        }
        return groups.max { left, right in
            left.value.reduce(0) { $0 + $1.profitLoss } < right.value.reduce(0) { $0 + $1.profitLoss }
        }?.key
    }
}

private struct TradingCalendarAnalytics {
    let trades: [Trade]
    let reviews: [AITradeReview]
    let disciplineDays: [DisciplineDay]
    let calendar: Calendar

    var netProfit: Double { trades.reduce(0) { $0 + $1.profitLoss } }
    var totalTrades: Int { trades.count }
    var averageRR: Double {
        let values = trades.filter { $0.riskReward > 0 }
        return values.isEmpty ? 0 : values.reduce(0) { $0 + $1.riskReward } / Double(values.count)
    }
    var winRate: Double {
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }
        return resolved.isEmpty ? 0 : Double(resolved.filter { $0.status == .win }.count) / Double(resolved.count) * 100
    }
    var averageAIScore: Int {
        let ids = Set(trades.map(\.id))
        let scores = reviews.filter { ids.contains($0.tradeID) }.map(\.overallScore)
        return scores.isEmpty ? 0 : Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }
    var averageDisciplineScore: Int {
        let monthDays = disciplineDays.filter { day in trades.contains { calendar.isDate($0.date, inSameDayAs: day.date) } || calendar.isDate(day.date, equalTo: Date(), toGranularity: .month) }
        let scores = monthDays.map(\.disciplineScore).filter { $0 > 0 }
        return scores.isEmpty ? inferredDiscipline : Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }
    var inferredDiscipline: Int {
        guard !trades.isEmpty else { return 0 }
        let followed = Double(trades.filter(\.followedPlan).count) / Double(trades.count)
        let majorMistakes = Double(trades.filter { $0.mistakeTags.contains(.revengeTrade) || $0.mistakeTags.contains(.brokeRules) }.count)
        return max(0, min(100, Int((followed * 88 - majorMistakes * 8 + 10).rounded())))
    }
    var journalCompletion: Double {
        guard !trades.isEmpty else { return 0 }
        let completed = trades.filter { !$0.tradeThesis.isEmpty || !$0.executionReview.isEmpty || !$0.lessonsLearned.isEmpty || !$0.notes.isEmpty }
        return Double(completed.count) / Double(trades.count) * 100
    }
    var currentStreak: Int {
        let grouped = Dictionary(grouping: trades) { calendar.startOfDay(for: $0.date) }
        let orderedDays = grouped.keys.sorted(by: >)
        var streak = 0
        for day in orderedDays {
            let net = grouped[day, default: []].reduce(0) { $0 + $1.profitLoss }
            guard net >= 0 else { break }
            streak += 1
        }
        return streak
    }
    var bestSession: String { bestGroup(Trade.Session.allCases.map(\.rawValue), value: { $0.session.rawValue }) ?? "None" }
    var worstSession: String { worstGroup(Trade.Session.allCases.map(\.rawValue), value: { $0.session.rawValue }) ?? "None" }
    var mostTradedPair: String { trades.map(\.pair).frequencySorted().first ?? "None" }
    var bestSetup: String { bestGroup(Trade.Strategy.allCases.map(\.rawValue), value: { $0.strategy.rawValue }) ?? "None" }
    var worstSetup: String { worstGroup(Trade.Strategy.allCases.map(\.rawValue), value: { $0.strategy.rawValue }) ?? "None" }
    var longestWinningStreak: Int { longestStreak { $0.status == .win } }
    var longestLosingStreak: Int { longestStreak { $0.status == .loss } }
    var averageHoldTime: String {
        let durations = trades.compactMap { trade -> TimeInterval? in
            guard let open = trade.tradeOpenTime, let close = trade.tradeCloseTime else { return nil }
            return close.timeIntervalSince(open)
        }
        guard !durations.isEmpty else { return "Pending" }
        let minutes = Int((durations.reduce(0, +) / Double(durations.count) / 60).rounded())
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }

    private func bestGroup(_ keys: [String], value: (Trade) -> String) -> String? {
        let grouped = Dictionary(grouping: trades, by: value)
        return keys.compactMap { key in grouped[key].map { (key, $0.reduce(0) { $0 + $1.profitLoss }) } }
            .max { $0.1 < $1.1 }?.0
    }

    private func worstGroup(_ keys: [String], value: (Trade) -> String) -> String? {
        let grouped = Dictionary(grouping: trades, by: value)
        return keys.compactMap { key in grouped[key].map { (key, $0.reduce(0) { $0 + $1.profitLoss }) } }
            .min { $0.1 < $1.1 }?.0
    }

    private func longestStreak(_ predicate: (Trade) -> Bool) -> Int {
        var best = 0
        var current = 0
        for trade in trades.sorted(by: { $0.date < $1.date }) {
            if predicate(trade) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }
}

private struct CalendarHeroCard: View {
    let month: Date
    let analytics: TradingCalendarAnalytics

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(month.formatted(.dateTime.month(.wide).year()))
                            .font(.title2.weight(.black))
                            .foregroundStyle(JPColors.primaryText)

                        Text("Monthly command view")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()

                    CalendarScoreRing(value: analytics.averageDisciplineScore, title: "Discipline")
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        heroMetric("Total P/L", currency(analytics.netProfit), analytics.netProfit >= 0 ? JPColors.profit : JPColors.loss)
                        heroMetric("Win Rate", percent(analytics.winRate), JPColors.accent)
                    }
                    HStack(spacing: 12) {
                        heroMetric("Trades", "\(analytics.totalTrades)", JPColors.blue)
                        heroMetric("Average RR", analytics.averageRR > 0 ? String(format: "%.2f R", analytics.averageRR) : "0.00 R", JPColors.warning)
                    }
                    HStack(spacing: 12) {
                        heroMetric("Journal", percent(analytics.journalCompletion), JPColors.purple)
                        heroMetric("Streak", "\(analytics.currentStreak) days", JPColors.profit)
                    }
                }
            }
        }
    }

    private func heroMetric(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}

private struct CalendarScoreRing: View {
    let value: Int
    let title: String
    @State private var animated = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(JPColors.border, lineWidth: 8)
            Circle()
                .trim(from: 0, to: animated ? CGFloat(value) / 100 : 0)
                .stroke(LinearGradient(colors: [JPColors.accent, JPColors.blue], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                Text(title)
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(JPColors.primaryText)
        }
        .frame(width: 84, height: 84)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.82).delay(0.1)) {
                animated = true
            }
        }
    }
}

private struct CalendarLegend: View {
    private let items: [(String, Color)] = [
        ("No Trades", JPColors.mutedText),
        ("Loss", JPColors.loss),
        ("Breakeven", JPColors.warning),
        ("Win", JPColors.profit),
        ("Discipline", JPColors.accent),
        ("AI", JPColors.blue)
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items, id: \.0) { item in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(item.1)
                            .frame(width: 12, height: 12)
                        Text(item.0)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                }
            }
        }
    }
}

private struct CalendarHeatmapCell: View {
    let snapshot: CalendarDaySnapshot
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    private var color: Color {
        guard snapshot.totalTrades > 0 else { return JPColors.mutedText.opacity(0.38) }
        if snapshot.averageAIScore >= 90 { return JPColors.blue }
        if snapshot.disciplineScore >= 92 { return JPColors.accent }
        if snapshot.netProfit > 0 { return JPColors.profit }
        if snapshot.netProfit < 0 { return JPColors.loss }
        return JPColors.warning
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: snapshot.date))")
                    .font(.caption.weight(.black))
                    .foregroundStyle(snapshot.totalTrades > 0 ? JPColors.primaryText : JPColors.secondaryText)

                if snapshot.totalTrades > 0 {
                    Text("\(snapshot.totalTrades)")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.background)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(snapshot.totalTrades > 0 ? 0.25 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isToday || isSelected ? JPColors.accent : color.opacity(0.25), lineWidth: isToday || isSelected ? 2 : 1)
            )
            .shadow(color: color.opacity(snapshot.averageAIScore >= 90 ? 0.36 : 0.12), radius: snapshot.averageAIScore >= 90 ? 16 : 7, x: 0, y: 6)
            .scaleEffect(isSelected ? 1.06 : 1)
            .animation(JPDesign.quickSpring, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let date = snapshot.date.formatted(.dateTime.month(.wide).day())
        guard snapshot.totalTrades > 0 else { return "\(date), no trades" }
        return "\(date), \(snapshot.totalTrades) trades, net \(Int(snapshot.netProfit)), discipline \(snapshot.disciplineScore)"
    }
}

private struct CalendarFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? JPColors.background : JPColors.primaryText)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(isSelected ? JPColors.accent : JPColors.elevatedSurface, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? JPColors.accent : JPColors.border, lineWidth: 1))
        }
        .buttonStyle(ScalingButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct CalendarInsightTileModel: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let tint: Color
}

private struct CalendarInsightRow: Identifiable {
    let id = UUID()
    let items: [CalendarInsightTileModel]
}

private struct CalendarInsightTile: View {
    let tile: CalendarInsightTileModel

    var body: some View {
        GlassCard(padding: 15, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: tile.icon)
                    .font(.caption.weight(.black))
                    .foregroundStyle(tile.tint)
                    .frame(width: 34, height: 34)
                    .background(tile.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(tile.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                    Text(tile.value)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CalendarAchievementModel: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let isUnlocked: Bool
}

private struct CalendarAchievementBadge: View {
    let badge: CalendarAchievementModel

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? badge.tint.opacity(0.18) : JPColors.elevatedSurface.opacity(0.75))
                    .frame(width: 78, height: 78)
                Circle()
                    .stroke(badge.isUnlocked ? badge.tint : JPColors.border, lineWidth: 1.4)
                    .frame(width: 78, height: 78)
                Image(systemName: badge.icon)
                    .font(.system(size: 27, weight: .black))
                    .foregroundStyle(badge.isUnlocked ? badge.tint : JPColors.mutedText)
            }

            Text(badge.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(badge.isUnlocked ? JPColors.primaryText : JPColors.mutedText)
                .multilineTextAlignment(.center)
                .frame(width: 92)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        .opacity(badge.isUnlocked ? 1 : 0.58)
    }
}

private struct CalendarActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CalendarActionLabel(title: title, icon: icon, tint: tint)
        }
        .buttonStyle(ScalingButtonStyle())
    }
}

private struct CalendarActionLabel: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.headline.weight(.black))
                .foregroundStyle(tint)
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(JPColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JPColors.border, lineWidth: 1))
    }
}

private struct DailyReviewWorkspace: View {
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    @AppStorage("jp.calendar.dailyReviews") private var storedReviews = "{}"

    let day: CalendarDaySnapshot
    let reviews: [AITradeReview]
    let discipline: DisciplineDay?
    @Binding var replayTrade: Trade?
    @Binding var showReplay: Bool

    @State private var review = CalendarDailyReview()
    @State private var didAppear = false
    @State private var showSaved = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                JPColors.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        dailyHero
                        dailyTimeline
                        dailyReviewSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 42)
                }
            }
            .navigationTitle("Daily Review")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .overlay(alignment: .top) {
                if showSaved {
                    Text("Daily review saved")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.background)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(JPColors.accent, in: Capsule())
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear {
                loadReview()
                withAnimation(JPDesign.smoothSpring) {
                    didAppear = true
                }
            }
            .onChange(of: review) { _, _ in
                saveReview()
            }
        }
    }

    private var dailyHero: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(day.date.formatted(.dateTime.day().month(.wide).year()))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(day.date.formatted(.dateTime.weekday(.wide)))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.accent)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(currency(day.netProfit))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(day.netProfit >= 0 ? JPColors.profit : JPColors.loss)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        Text("\(day.totalTrades) Trades")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        dailyMetric("Win Rate", percent(day.winRate), "target", JPColors.accent)
                        dailyMetric("AI Score", day.averageAIScore == 0 ? "Pending" : "\(day.averageAIScore)", "sparkles", JPColors.blue)
                    }
                    HStack(spacing: 10) {
                        dailyMetric("Discipline", percent(Double(day.disciplineScore)), "checkmark.seal.fill", JPColors.profit)
                        dailyMetric("Session", day.bestSession, "clock.fill", JPColors.warning)
                    }
                    HStack(spacing: 10) {
                        dailyMetric("Best Pair", day.bestPair, "chart.line.uptrend.xyaxis", JPColors.purple)
                        dailyMetric("Worst Mistake", day.worstMistake, "exclamationmark.triangle.fill", JPColors.loss)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Lessons Learned")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                    Text(day.lesson)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Button {
                        replayTrade = day.trades.last
                        showReplay = replayTrade != nil
                        JPHaptics.impact(.medium)
                    } label: {
                        Label("Replay Day", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(day.trades.isEmpty)

                    Button {
                        JPHaptics.impact(.light)
                    } label: {
                        Label("Export Day", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.background)
                .buttonStyle(CalendarHeroButtonStyle())
            }
        }
        .premiumEntrance(active: didAppear)
    }

    private var dailyTimeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Daily Timeline", subtitle: "Every trade from this day")

            if day.trades.isEmpty {
                GlassCard {
                    CalendarInlineEmptyState(icon: "tray", title: "No trades on this day.", message: "Pick a day with trades or create a new entry to start building your timeline.")
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(day.trades) { trade in
                        DailyTimelineTradeCard(
                            trade: trade,
                            aiScore: reviews.first { $0.tradeID == trade.id }?.overallScore,
                            replay: {
                                replayTrade = trade
                                showReplay = true
                                JPHaptics.impact(.medium)
                            }
                        )
                        .environmentObject(tradeViewModel)
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.06)
    }

    private var dailyReviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Today's Reflection", subtitle: "Save the psychology behind the numbers")

            GlassCard {
                VStack(alignment: .leading, spacing: 20) {
                    moodPicker
                    sliderRow("Confidence", value: $review.confidence, icon: "bolt.heart.fill", tint: JPColors.accent)
                    sliderRow("Stress", value: $review.stress, icon: "waveform.path.ecg", tint: JPColors.loss)
                    sliderRow("Energy", value: $review.energy, icon: "sun.max.fill", tint: JPColors.warning)

                    reviewEditor("Journal Notes", text: $review.notes, prompt: "What happened today?")
                    placeholderVoiceNote
                    reviewEditor("Daily Lesson", text: $review.dailyLesson, prompt: "What did the market teach you?")
                    reviewEditor("Biggest Win", text: $review.biggestWin, prompt: "What did you do well?")
                    reviewEditor("Biggest Mistake", text: $review.biggestMistake, prompt: "What needs tightening?")
                    reviewEditor("Tomorrow Focus", text: $review.tomorrowFocus, prompt: "What is the next clean focus?")
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.12)
    }

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mood")
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)

            HStack(spacing: 10) {
                ForEach(CalendarMood.allCases) { mood in
                    Button {
                        withAnimation(JPDesign.quickSpring) {
                            review.mood = mood.rawValue
                        }
                        JPHaptics.selection()
                    } label: {
                        Text(mood.rawValue)
                            .font(.system(size: 26))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(review.mood == mood.rawValue ? JPColors.accentSoft : JPColors.elevatedSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(review.mood == mood.rawValue ? JPColors.accent : JPColors.border, lineWidth: 1))
                    }
                    .buttonStyle(ScalingButtonStyle())
                    .accessibilityLabel(mood.label)
                }
            }
        }
    }

    private var placeholderVoiceNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(JPColors.blue)

            VStack(alignment: .leading, spacing: 3) {
                Text("Voice Note")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                Text("Placeholder for future audio journaling.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
            }

            Spacer()

            Text("Soon")
                .font(.caption.weight(.black))
                .foregroundStyle(JPColors.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(JPColors.blue.opacity(0.14), in: Capsule())
        }
        .padding(14)
        .background(JPColors.elevatedSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func dailyMetric(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                Text(value)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(JPColors.elevatedSurface.opacity(0.48), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sliderRow(_ title: String, value: Binding<Double>, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded())) / 10")
                    .font(.caption.weight(.black))
                    .foregroundStyle(tint)
            }

            Slider(value: value, in: 1...10, step: 1)
                .tint(tint)
        }
    }

    private func reviewEditor(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)

            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .foregroundStyle(JPColors.primaryText)
                .frame(minHeight: 86)
                .padding(12)
                .background(JPColors.elevatedSurface.opacity(0.52), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(prompt)
                            .font(.subheadline)
                            .foregroundStyle(JPColors.mutedText)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private func loadReview() {
        let all = decodeReviews()
        review = all[reviewKey] ?? CalendarDailyReview()
    }

    private func saveReview() {
        var all = decodeReviews()
        all[reviewKey] = review
        if let data = try? JSONEncoder().encode(all),
           let string = String(data: data, encoding: .utf8) {
            storedReviews = string
            withAnimation(JPDesign.quickSpring) {
                showSaved = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(JPDesign.quickSpring) {
                    showSaved = false
                }
            }
        }
    }

    private func decodeReviews() -> [String: CalendarDailyReview] {
        guard let data = storedReviews.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: CalendarDailyReview].self, from: data)
        else { return [:] }
        return decoded
    }

    private var reviewKey: String {
        let components = calendar.dateComponents([.year, .month, .day], from: day.date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}

private struct CalendarDailyReview: Codable, Equatable {
    var mood = CalendarMood.neutral.rawValue
    var confidence = 5.0
    var stress = 5.0
    var energy = 5.0
    var notes = ""
    var dailyLesson = ""
    var biggestWin = ""
    var biggestMistake = ""
    var tomorrowFocus = ""
}

private enum CalendarMood: String, CaseIterable, Identifiable {
    case happy = "😀"
    case neutral = "😐"
    case sad = "😔"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .happy: return "Positive mood"
        case .neutral: return "Neutral mood"
        case .sad: return "Difficult mood"
        }
    }
}

private struct DailyTimelineTradeCard: View {
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    let trade: Trade
    let aiScore: Int?
    let replay: () -> Void

    private var tint: Color {
        switch trade.status {
        case .win: return JPColors.profit
        case .loss: return JPColors.loss
        case .breakeven: return JPColors.warning
        }
    }

    var body: some View {
        GlassCard(padding: 16, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    screenshotThumbnail

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(trade.pair)
                                .font(.title3.weight(.black))
                                .foregroundStyle(JPColors.primaryText)
                            Spacer()
                            Text(currency(trade.profitLoss))
                                .font(.headline.weight(.black))
                                .foregroundStyle(trade.profitLoss >= 0 ? JPColors.profit : JPColors.loss)
                        }

                        HStack(spacing: 8) {
                            badge(trade.direction.rawValue, color: trade.direction == .buy ? JPColors.profit : JPColors.loss)
                            badge(trade.status.rawValue, color: tint)
                            badge(String(format: "%.2f R", trade.riskReward), color: JPColors.warning)
                        }

                        HStack(spacing: 10) {
                            detail("Session", trade.session.rawValue)
                            detail("AI", aiScore.map { "\($0)" } ?? "Pending")
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button(action: replay) {
                        Label("Replay", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }

                    NavigationLink {
                        TradeDetailView(trade: trade)
                            .environmentObject(tradeViewModel)
                    } label: {
                        Label("Detail", systemImage: "arrow.up.right")
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.background)
                .buttonStyle(CalendarHeroButtonStyle())
            }
        }
    }

    private var screenshotThumbnail: some View {
        ZStack {
            if let data = trade.beforeEntryImageData ?? trade.duringTradeImageData ?? trade.afterExitImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tint.opacity(0.12))
            }
        }
        .frame(width: 70, height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JPColors.border, lineWidth: 1))
    }

    private func badge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.black))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(JPColors.mutedText)
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(JPColors.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }
}

private struct CalendarHeroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(
                LinearGradient(colors: [JPColors.accent, JPColors.profit], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(JPDesign.quickSpring, value: configuration.isPressed)
    }
}

private struct CalendarInlineEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(JPColors.accent)
                .frame(width: 48, height: 48)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(JPColors.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(JPColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension Array where Element == String {
    func frequencySorted() -> [String] {
        Dictionary(grouping: self, by: { $0 })
            .map { ($0.key, $0.value.count) }
            .sorted { left, right in
                if left.1 == right.1 { return left.0 < right.0 }
                return left.1 > right.1
            }
            .map(\.0)
    }
}
