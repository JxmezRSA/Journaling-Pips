import Charts
import SwiftUI
import UIKit

struct AnalyticsView: View {
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    @StateObject private var viewModel = AnalyticsViewModel()
    @StateObject private var insightViewModel = InsightViewModel()
    @StateObject private var reportViewModel = ReportViewModel()
    @State private var didAppear = false
    @State private var chartReveal = 0.0
    @State private var selectedWeekday = Calendar.current.component(.weekday, from: Date())
    @State private var selectedFilter = AnalyticsTimeFilter.allTime
    @State private var pairSort = PairPerformanceSort.profit
    @State private var cachedAnalyticsTrades: [Trade]?

    let onLogFirstTrade: () -> Void

    init(onLogFirstTrade: @escaping () -> Void = {}) {
        self.onLogFirstTrade = onLogFirstTrade
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var analyticsTrades: [Trade] {
        cachedAnalyticsTrades ?? viewModel.filteredTrades(tradeViewModel.trades, by: selectedFilter)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JPColors.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        filterSection

                        if tradeViewModel.trades.isEmpty {
                            emptyState
                        } else {
                            analyticsV1Dashboard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 176)
                }
                .refreshable {
                    JPHaptics.selection()
                    insightViewModel.refresh(event: .analyticsUpdated)
                    withAnimation(.easeInOut(duration: 0.7)) {
                        chartReveal = 0
                    }
                    withAnimation(.easeInOut(duration: 0.9).delay(0.12)) {
                        chartReveal = 1
                    }
                }
            }
            .navigationTitle("Analytics")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            insightViewModel.configure(context: modelContext)
            reportViewModel.configure(context: modelContext)
            refreshAnalyticsTrades()
            debugPrint("ANALYTICS RECALCULATED:", analyticsTrades.count, "trades")
            debugPrint("EQUITY CURVE UPDATED:", viewModel.equityCurve(for: analyticsTrades).count, "points")
            withAnimation(.easeOut(duration: 0.45)) {
                didAppear = true
            }
            withAnimation(.easeInOut(duration: 0.9).delay(0.18)) {
                chartReveal = 1
            }
        }
        .sheet(item: $reportViewModel.shareItem) { item in
            AnalyticsReportShareSheet(url: item.url)
        }
        .onChange(of: selectedFilter) { _, newValue in
            refreshAnalyticsTrades()
            debugPrint("DASHBOARD FILTER CHANGED:", newValue.rawValue)
            debugPrint("ANALYTICS RECALCULATED:", analyticsTrades.count, "trades")
            debugPrint("EQUITY CURVE UPDATED:", viewModel.equityCurve(for: analyticsTrades).count, "points")
            JPHaptics.selection()
            withAnimation(.easeInOut(duration: 0.42)) {
                chartReveal = 0
            }
            withAnimation(.easeInOut(duration: 0.72).delay(0.08)) {
                chartReveal = 1
            }
        }
        .onChange(of: tradeViewModel.trades.count) { _, _ in
            refreshAnalyticsTrades()
            debugPrint("ANALYTICS RECALCULATED:", analyticsTrades.count, "trades")
            debugPrint("EQUITY CURVE UPDATED:", viewModel.equityCurve(for: analyticsTrades).count, "points")
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func refreshAnalyticsTrades() {
        cachedAnalyticsTrades = viewModel.filteredTrades(tradeViewModel.trades, by: selectedFilter)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Professional Analytics")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(JPColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("A performance platform built from your saved trades.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 10)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(JPColors.accent)
                    .frame(width: 68, height: 68)
                    .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Add your first trade to unlock analytics.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Your saved trades will power win rate, R multiple, pair performance, and monthly breakdowns.")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    onLogFirstTrade()
                } label: {
                    Label("Log First Trade", systemImage: "plus.circle.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(JPColors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(ScalingButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 16)
    }

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AnalyticsTimeFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.black))
                            .foregroundStyle(selectedFilter == filter ? JPColors.background : JPColors.secondaryText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(
                                selectedFilter == filter
                                ? LinearGradient(colors: [JPColors.accent, JPColors.profit], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [JPColors.graphite, JPColors.graphite], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                            .overlay(Capsule().stroke(selectedFilter == filter ? JPColors.accent.opacity(0.4) : JPColors.border, lineWidth: 1))
                    }
                    .buttonStyle(ScalingButtonStyle())
                    .accessibilityLabel("Filter analytics by \(filter.rawValue)")
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 2)
            .padding(.trailing, 20)
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 10)
    }

    private var analyticsV1Dashboard: some View {
        VStack(alignment: .leading, spacing: 24) {
            performanceCenterEntry
            TradingInsightsView(trades: analyticsTrades)
            performanceOverviewV1
            winLossBreakdownV1
            pairPerformanceV1
            monthlyPerformanceV1
        }
    }

    private var performanceCenterEntry: some View {
        NavigationLink {
            PerformanceCenterView(trades: analyticsTrades)
        } label: {
            GlassCard {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(JPColors.warning)
                        .frame(width: 54, height: 54)
                        .background(
                            LinearGradient(colors: [JPColors.accent.opacity(0.18), JPColors.purple.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 19, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Open Performance Center")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text("Track your grade, monthly improvement, weakest area, and next focus goal.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.black))
                        .foregroundStyle(JPColors.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .premiumEntrance(active: didAppear, delay: 0.02)
    }

    private var performanceOverviewV1: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Performance Overview", subtitle: "\(selectedFilter.rawValue) stats from saved trades")

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    analyticsCardV1(title: "Total Trades", value: "\(analyticsTrades.count)", subtitle: "Saved entries", tint: JPColors.accent)
                    analyticsCardV1(title: "Win Rate", value: percent(winRateV1(analyticsTrades)), subtitle: "Wins / losses", tint: JPColors.warning)
                }

                HStack(spacing: 12) {
                    analyticsCardV1(title: "Net P/L", value: currency(netProfitV1(analyticsTrades)), subtitle: "Realized result", tint: tintV1(netProfitV1(analyticsTrades)))
                    analyticsCardV1(title: "Average R", value: rrV1(averageRRV1(analyticsTrades)), subtitle: "Average R multiple", tint: JPColors.blue)
                }

                HStack(spacing: 12) {
                    analyticsCardV1(title: "Best Trade", value: currency(bestTradeV1(analyticsTrades)), subtitle: "Largest win", tint: JPColors.profit)
                    analyticsCardV1(title: "Worst Trade", value: currency(worstTradeV1(analyticsTrades)), subtitle: "Largest loss", tint: JPColors.loss)
                }

                HStack(spacing: 12) {
                    analyticsCardV1(title: "Winning Streak", value: "\(winningStreakV1(analyticsTrades))", subtitle: "Longest run", tint: JPColors.profit)
                    analyticsCardV1(title: "Losing Streak", value: "\(losingStreakV1(analyticsTrades))", subtitle: "Longest run", tint: JPColors.loss)
                }
            }
        }
    }

    private var winLossBreakdownV1: some View {
        let wins = analyticsTrades.filter { $0.status == .win }.count
        let losses = analyticsTrades.filter { $0.status == .loss }.count
        let breakeven = analyticsTrades.filter { $0.status == .breakeven }.count

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Win/Loss Breakdown", subtitle: "Outcome count by saved trade")

            VStack(spacing: 10) {
                analyticsRowV1(title: "Wins", value: "\(wins)", detail: percent(rateV1(wins, analyticsTrades.count)), tint: JPColors.profit)
                analyticsRowV1(title: "Losses", value: "\(losses)", detail: percent(rateV1(losses, analyticsTrades.count)), tint: JPColors.loss)
                analyticsRowV1(title: "Breakeven", value: "\(breakeven)", detail: percent(rateV1(breakeven, analyticsTrades.count)), tint: JPColors.warning)
            }
            .padding(16)
            .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        }
    }

    private var pairPerformanceV1: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Pair Performance", subtitle: "Performance grouped by instrument")

            VStack(spacing: 10) {
                ForEach(pairRowsV1(analyticsTrades), id: \.pair) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(row.pair)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(JPColors.primaryText)
                            Spacer()
                            Text(currency(row.netProfit))
                                .font(.headline.weight(.black))
                                .foregroundStyle(tintV1(row.netProfit))
                        }

                        HStack {
                            Text("\(row.trades) trades")
                            Spacer()
                            Text("Win \(percent(row.winRate))")
                            Spacer()
                            Text("Avg \(rrV1(row.averageRR))")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                    }
                    .padding(14)
                    .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(16)
            .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        }
    }

    private var monthlyPerformanceV1: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Monthly Performance", subtitle: "Monthly net result and consistency")

            VStack(spacing: 10) {
                ForEach(monthRowsV1(analyticsTrades), id: \.month) { row in
                    analyticsRowV1(
                        title: row.month,
                        value: currency(row.netProfit),
                        detail: "\(row.trades) trades • \(percent(row.winRate)) win rate",
                        tint: tintV1(row.netProfit)
                    )
                }
            }
            .padding(16)
            .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        }
    }

    private func analyticsCardV1(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)

            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JPColors.border, lineWidth: 1))
    }

    private func analyticsRowV1(title: String, value: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
            }

            Spacer()

            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(14)
        .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var sprintOverviewSection: some View {
        section(title: "Dashboard Overview", subtitle: "\(selectedFilter.rawValue) performance from local trades") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(viewModel.overviewCards(for: analyticsTrades).enumerated()), id: \.element.id) { index, card in
                    analyticsOverviewCard(card)
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 16)
                        .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(Double(index) * 0.035), value: didAppear)
                }
            }
        }
    }

    private var sprintChartsSection: some View {
        section(title: "Performance Charts", subtitle: "Equity, outcome distribution, and filtered edge") {
            VStack(spacing: 14) {
                analyticsChart(
                    title: "Equity Curve",
                    subtitle: "Running cumulative P/L",
                    points: viewModel.equityCurve(for: analyticsTrades),
                    style: .line
                )

                winLossDistributionCard
            }
        }
    }

    private var winLossDistributionCard: some View {
        let rows = viewModel.winLossDistribution(for: analyticsTrades)
        let maxCount = max(rows.map(\.count).max() ?? 1, 1)

        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Win/Loss Distribution")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)
                        Text("Green vs red outcome mix")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chart.bar.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.accent)
                }

                Chart(rows) { row in
                    BarMark(
                        x: .value("Outcome", row.title),
                        y: .value("Trades", Double(row.count) * chartReveal)
                    )
                    .foregroundStyle(row.tint)
                    .cornerRadius(8)
                }
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...Double(maxCount))
                .frame(height: 180)
            }
        }
    }

    private var sprintSessionSection: some View {
        section(title: "Trading Sessions", subtitle: "Trades, win rate, and net profit by session") {
            VStack(spacing: 12) {
                ForEach(viewModel.dashboardSessions(for: analyticsTrades)) { session in
                    sessionDashboardRow(session)
                }
            }
        }
    }

    private var sprintPairPerformanceSection: some View {
        section(title: "Pair Performance", subtitle: "Sortable instrument performance") {
            VStack(alignment: .leading, spacing: 14) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PairPerformanceSort.allCases) { sort in
                            Button {
                                JPHaptics.selection()
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                    pairSort = sort
                                }
                            } label: {
                                Text(sort.rawValue)
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(pairSort == sort ? JPColors.background : JPColors.secondaryText)
                                    .padding(.horizontal, 12)
                                    .frame(height: 34)
                                    .background(pairSort == sort ? JPColors.warning : JPColors.graphite, in: Capsule())
                            }
                            .buttonStyle(ScalingButtonStyle())
                        }
                    }
                }

                let rows = viewModel.sortedPairPerformance(for: analyticsTrades, sort: pairSort)
                if rows.isEmpty {
                    chartEmptyState("No pair performance yet.", "Filtered trades will appear here automatically.")
                } else {
                    VStack(spacing: 12) {
                        ForEach(rows) { pair in
                            pairRow(pair)
                        }
                    }
                }
            }
        }
    }

    private var sprintMonthlyCardsSection: some View {
        let months = viewModel.monthlyPerformanceCards(for: analyticsTrades)

        return section(title: "Monthly Performance", subtitle: "Monthly net profit, win rate, and trade count") {
            if months.isEmpty {
                chartEmptyState("No monthly data yet.", "Saved trades will build your month-by-month performance.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(months) { month in
                            monthlyCard(month)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var sprintBestWorstSection: some View {
        let summary = viewModel.bestWorstSummary(for: analyticsTrades)

        return section(title: "Best & Worst", subtitle: "Automatic strengths, weaknesses, streaks, and hold time") {
            LazyVGrid(columns: columns, spacing: 14) {
                bestWorstTile("Best Pair", summary.bestPair, "trophy.fill", JPColors.warning)
                bestWorstTile("Worst Pair", summary.worstPair, "exclamationmark.triangle.fill", JPColors.loss)
                bestWorstTile("Best Weekday", summary.bestWeekday, "calendar.badge.checkmark", JPColors.profit)
                bestWorstTile("Worst Weekday", summary.worstWeekday, "calendar.badge.exclamationmark", JPColors.warning)
                bestWorstTile("Best Session", summary.bestSession, "clock.badge.checkmark.fill", JPColors.accent)
                bestWorstTile("Worst Session", summary.worstSession, "clock.badge.exclamationmark.fill", JPColors.loss)
                bestWorstTile("Largest Win", currency(summary.largestWin), "arrow.up.right.circle.fill", JPColors.profit)
                bestWorstTile("Largest Loss", currency(summary.largestLoss), "arrow.down.right.circle.fill", JPColors.loss)
                bestWorstTile("Win Streak", "\(summary.longestWinningStreak)", "flame.fill", JPColors.profit)
                bestWorstTile("Loss Streak", "\(summary.longestLosingStreak)", "bolt.slash.fill", JPColors.loss)
                bestWorstTile("Avg Hold Time", summary.averageHoldTime, "timer", JPColors.secondaryText)
            }
        }
    }

    private var intelligenceHero: some View {
        let score = viewModel.performanceScore(for: analyticsTrades)
        let monthly = viewModel.monthlyProfit(for: analyticsTrades)
        let weekly = viewModel.weeklyProfit(for: analyticsTrades)
        let weeklyDelta = deltaText(points: weekly)
        let monthlyDelta = deltaText(points: monthly)

        return GlassCard {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Overall Trading Grade", systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.warning)

                        Text(letterGrade(for: score.value))
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [JPColors.warning, JPColors.accent, JPColors.profit],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.black))
                                .foregroundStyle(JPColors.profit)
                            Text("You're outperforming \(outperformancePercent(for: score.value))% of your previous months.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)

                    scoreRing(score.value, lineWidth: 14, size: 132)
                }

                HStack(spacing: 12) {
                    trendPill("Weekly", weeklyDelta)
                    trendPill("Monthly", monthlyDelta)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(JPColors.accent.opacity(0.08))
                .blur(radius: 26)
                .scaleEffect(didAppear ? 1.04 : 0.92)
        )
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
        .animation(.spring(response: 0.58, dampingFraction: 0.84), value: didAppear)
    }

    private var eliteStatsSection: some View {
        section(title: "Elite Stats", subtitle: "Institutional-grade performance, drawdown, risk, and edge analysis") {
            NavigationLink {
                EliteStatsDashboardView(onLogFirstTrade: onLogFirstTrade)
                    .environmentObject(tradeViewModel)
            } label: {
                GlassCard {
                    HStack(spacing: 16) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.title2.weight(.black))
                            .foregroundStyle(JPColors.accent)
                            .frame(width: 58, height: 58)
                            .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Open Elite Statistics Engine")
                                .font(.headline.weight(.black))
                                .foregroundStyle(JPColors.primaryText)
                            Text("Expectancy, Monte Carlo, drawdown, risk simulator, rankings, and psychology stats.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.black))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var performanceSnapshots: some View {
        section(title: "Performance Snapshots", subtitle: "Live read on edge, reward, and expectancy") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(viewModel.snapshotMetrics(for: analyticsTrades).enumerated()), id: \.element.id) { index, metric in
                    snapshotCard(metric)
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 16)
                        .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(Double(index) * 0.04), value: didAppear)
                }
            }
        }
    }

    private var bestWorstSection: some View {
        section(title: "Best & Worst Performance", subtitle: "Where your edge is strongest and weakest") {
            VStack(spacing: 14) {
                if let best = viewModel.bestPair(for: analyticsTrades) {
                    performanceRankingCard(
                        title: "Best Pair",
                        subtitle: "Favorite market",
                        pair: best.pair,
                        winRate: best.winRate,
                        profit: best.netProfit,
                        averageRR: best.averageRiskReward,
                        icon: "trophy.fill",
                        tint: JPColors.warning,
                        recommendation: nil
                    )
                }

                if let worst = viewModel.worstPair(for: analyticsTrades), worst.netProfit < 0 || worst.winRate < 45 {
                    performanceRankingCard(
                        title: "Worst Performance",
                        subtitle: "Consistency warning",
                        pair: worst.pair,
                        winRate: worst.winRate,
                        profit: worst.netProfit,
                        averageRR: worst.averageRiskReward,
                        icon: "exclamationmark.triangle.fill",
                        tint: JPColors.warning,
                        recommendation: "Avoid this market until consistency improves."
                    )
                }
            }
        }
    }

    private var bestSessionSection: some View {
        let session = viewModel.sessionAnalysis(for: analyticsTrades).first(where: \.isStrongest)

        return section(title: "Best Session", subtitle: "Automatically detected from saved trades") {
            if let session {
                GlassCard {
                    HStack(spacing: 16) {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(JPColors.accent)
                            .frame(width: 58, height: 58)
                            .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.session.rawValue)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(JPColors.primaryText)

                            HStack(spacing: 8) {
                                miniStat("Win Rate", percentage(session.winRate))
                                miniStat("Profit", currency(session.netProfit))
                                miniStat("Avg RR", riskReward(session.averageRiskReward))
                                miniStat("Trades", "\(session.trades)")
                            }
                        }
                    }
                }
            } else {
                chartEmptyState("No session edge yet.", "Log trades across sessions to reveal your best window.")
            }
        }
    }

    private var timeOfDaySection: some View {
        let rows = viewModel.timeOfDayAnalysis(for: analyticsTrades)
        let maxProfit = max(rows.map { abs($0.netProfit) }.max() ?? 1, 1)

        return section(title: "Time of Day Analysis", subtitle: "Morning, afternoon, evening, and night rhythm") {
            GlassCard {
                VStack(spacing: 16) {
                    ForEach(rows) { item in
                        horizontalPerformanceBar(item.label, profit: item.netProfit, winRate: item.winRate, averageRR: item.averageRiskReward, trades: item.trades, maxProfit: maxProfit)
                    }
                }
            }
        }
    }

    private var weekdayHeatmapSection: some View {
        let days = viewModel.weekdayHeatmap(for: analyticsTrades)
        let selected = days.first { $0.weekday == selectedWeekday }

        return section(title: "Day of Week Heatmap", subtitle: "Tap a day to inspect its edge") {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        ForEach(days) { day in
                            weekdayCell(day)
                        }
                    }

                    if let selected {
                        HStack(spacing: 10) {
                            miniStat("Day", selected.label)
                            miniStat("Win Rate", percentage(selected.winRate))
                            miniStat("Profit", currency(selected.netProfit))
                            miniStat("Avg RR", riskReward(selected.averageRiskReward))
                        }
                    }
                }
            }
        }
    }

    private var monthlyPerformanceSection: some View {
        section(title: "Monthly Performance", subtitle: "Scrollable profit curve by month") {
            analyticsChart(
                title: "Monthly Profit",
                subtitle: "Animated net P/L progression",
                points: viewModel.monthlyProfit(for: analyticsTrades),
                style: .line
            )
        }
    }

    private var pairPerformanceSection: some View {
        section(title: "Pair Performance", subtitle: "Ranked markets with favorite and risk badges") {
            VStack(spacing: 12) {
                ForEach(viewModel.pairPerformance(for: analyticsTrades)) { pair in
                    pairRow(pair)
                }
            }
        }
    }

    private var strategyIntelligenceSection: some View {
        section(title: "Strategy Performance", subtitle: "Your playbook ranked by outcome quality") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(viewModel.strategyAnalysis(for: analyticsTrades)) { strategy in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(tint(for: strategy.netProfit))

                            Text(strategy.strategy.rawValue)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(JPColors.primaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(currency(strategy.netProfit))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(tint(for: strategy.netProfit))

                            VStack(spacing: 8) {
                                miniStat("Win %", percentage(strategy.winRate))
                                miniStat("Avg RR", riskReward(strategy.averageRiskReward))
                                miniStat("Trades", "\(strategy.trades)")
                            }
                        }
                    }
                }
            }
        }
    }

    private var riskManagementSection: some View {
        let risk = viewModel.riskSnapshot(for: analyticsTrades)

        return section(title: "Risk Management", subtitle: "Position sizing, losses, wins, and hold time") {
            GlassCard {
                HStack(alignment: .center, spacing: 18) {
                    scoreRing(risk.score, lineWidth: 12, size: 116)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Risk Score")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)

                        HStack(spacing: 8) {
                            miniStat("Avg Risk", String(format: "%.1f%%", risk.averageRisk))
                            miniStat("Avg Size", String(format: "%.2f", risk.averagePositionSize))
                        }

                        HStack(spacing: 8) {
                            miniStat("Largest Win", currency(risk.largestWin))
                            miniStat("Largest Loss", currency(risk.largestLoss))
                        }

                        miniStat("Avg Hold", risk.averageHoldTime)
                    }
                }
            }
        }
    }

    private var psychologySection: some View {
        section(title: "Psychology Analysis", subtitle: "Behavioral signals from tags and reviews") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(viewModel.psychologySignals(for: analyticsTrades)) { signal in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(signal.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(JPColors.primaryText)
                                Spacer()
                                Text("\(signal.value)%")
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(signal.tint)
                            }

                            ProgressView(value: Double(signal.value), total: 100)
                                .tint(signal.tint)
                                .scaleEffect(x: 1, y: 1.4, anchor: .center)

                            Text(signal.subtitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)
                        }
                    }
                }
            }
        }
    }

    private var disciplineSection: some View {
        let discipline = viewModel.disciplineSnapshot(for: analyticsTrades)

        return section(title: "Discipline Score", subtitle: "Current, last month, and historical discipline range") {
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        scoreRing(discipline.currentScore, lineWidth: 12, size: 112)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Current Score")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.secondaryText)

                            Text("\(discipline.currentScore)")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(scoreColor(discipline.currentScore))

                            HStack(spacing: 8) {
                                miniStat("Last Month", "\(discipline.lastMonth)")
                                miniStat("Highest", "\(discipline.highestEver)")
                                miniStat("Lowest", "\(discipline.lowestEver)")
                            }
                        }
                    }

                    if !discipline.history.isEmpty {
                        Chart(discipline.history) { point in
                            AreaMark(
                                x: .value("Month", point.date),
                                yStart: .value("Base", 0),
                                yEnd: .value("Score", point.value * chartReveal)
                            )
                            .foregroundStyle(LinearGradient(colors: [JPColors.accent.opacity(0.24), .clear], startPoint: .top, endPoint: .bottom))

                            LineMark(
                                x: .value("Month", point.date),
                                y: .value("Score", point.value * chartReveal)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(JPColors.accent)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 120)
                    }
                }
            }
        }
    }

    private var streaksSection: some View {
        let streaks = viewModel.streakSnapshot(for: analyticsTrades)
        let items = [
            ("Winning Streak", "\(streaks.winning)", "flame.fill", JPColors.profit),
            ("Journal Streak", "\(streaks.journal)", "book.closed.fill", JPColors.accent),
            ("Plan Streak", "\(streaks.plan)", "checklist.checked", JPColors.blue),
            ("Review Streak", "\(streaks.review)", "sparkles", JPColors.warning),
            ("Replay Streak", "\(streaks.replay)", "play.rectangle.fill", JPColors.purple)
        ]

        return section(title: "Streaks", subtitle: "Consistency markers beyond profit") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(items, id: \.0) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: item.2)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(item.3)

                            Text(item.1)
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(JPColors.primaryText)

                            Text(item.0)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var aiInsightsCarousel: some View {
        let localInsights = viewModel.insights(for: analyticsTrades)

        return section(title: "AI Insights", subtitle: "Smart coaching signals generated from your journal") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if insightViewModel.sortedInsights.isEmpty {
                        ForEach(localInsights, id: \.self) { insight in
                            insightTile(title: "Coaching Insight", subtitle: insight)
                        }
                    } else {
                        ForEach(insightViewModel.sortedInsights.prefix(8)) { insight in
                            insightTile(title: insight.title, subtitle: insight.subtitle)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var recommendationsSection: some View {
        let recommendations = viewModel.recommendations(for: analyticsTrades)
        let visibleRecommendations = recommendations.isEmpty ? ["Keep logging trades to unlock sharper recommendations."] : recommendations
        let subtitle = visibleRecommendations.count >= 3 ? "Three actions to improve your next trading week" : "Actions to improve your next trading week"

        return section(title: "Recommendations", subtitle: subtitle) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(visibleRecommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrow.up.forward.circle.fill")
                                .foregroundStyle(JPColors.accent)
                                .frame(width: 28, height: 28)

                            Text(recommendation)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JPColors.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var goalsSection: some View {
        section(title: "Goals", subtitle: "Weekly, monthly, profit, RR, journal, and checklist progress") {
            VStack(spacing: 12) {
                ForEach(viewModel.goalProgress(for: analyticsTrades)) { goal in
                    goalRow(goal)
                }
            }
        }
    }

    private var exportSection: some View {
        section(title: "Export", subtitle: "Generate an analytics PDF with charts, insights, heatmaps, and rankings") {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.richtext.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(JPColors.accent)
                            .frame(width: 56, height: 56)
                            .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Analytics Summary")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(JPColors.primaryText)

                            Text("Includes performance charts, AI insights, heatmaps, and pair rankings.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Button {
                        JPHaptics.selection()
                        reportViewModel.export(.allTime)
                    } label: {
                        HStack {
                            if reportViewModel.isGenerating {
                                PremiumInlineLoader(title: "Preparing", tint: JPColors.background)
                            } else {
                                Image(systemName: "square.and.arrow.up.fill")
                            }
                            Text(reportViewModel.isGenerating ? "Preparing PDF..." : "Export Analytics PDF")
                        }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(colors: [JPColors.accent, JPColors.profit], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .shadow(color: JPColors.accent.opacity(0.24), radius: 18, x: 0, y: 10)
                    }
                    .buttonStyle(ScalingButtonStyle())
                    .disabled(reportViewModel.isGenerating)

                    if let error = reportViewModel.errorMessage {
                        Text(error)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.loss)
                    }
                }
            }
        }
    }

    private var performanceHero: some View {
        let score = viewModel.performanceScore(for: analyticsTrades)

        return GlassCard {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(JPColors.graphite, lineWidth: 13)

                    Circle()
                        .trim(from: 0, to: CGFloat(score.value) / 100)
                        .stroke(
                            AngularGradient(
                                colors: [JPColors.accent, JPColors.warning, JPColors.profit, JPColors.accent],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 13, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(score.value)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)

                        Text("/100")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                }
                .frame(width: 118, height: 118)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Performance Score")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)

                    Text(score.rating)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(score.value))

                    Text("Calculated from consistency, profitability, and risk management.")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 16)
        .animation(.spring(response: 0.46, dampingFraction: 0.88).delay(0.06), value: didAppear)
    }

    private var metricsGrid: some View {
        section(title: "Metrics", subtitle: "Institutional view of your trading performance") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(viewModel.metrics(for: analyticsTrades).enumerated()), id: \.element.id) { index, metric in
                    MetricCard(
                        title: metric.title,
                        value: metric.value,
                        detail: metric.detail,
                        icon: metric.icon,
                        tint: metric.tint
                    )
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 18)
                    .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(Double(index) * 0.02), value: didAppear)
                }
            }
        }
    }

    private var smartInsightsSection: some View {
        section(title: "Smart Insights", subtitle: "Unified coaching from journal, replay, AI, plan, and discipline") {
            VStack(alignment: .leading, spacing: 14) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(InsightSort.allCases) { sort in
                            Button {
                                JPHaptics.selection()
                                insightViewModel.selectedSort = sort
                            } label: {
                                Text(sort.rawValue)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(insightViewModel.selectedSort == sort ? JPColors.background : JPColors.secondaryText)
                                    .padding(.horizontal, 12)
                                    .frame(height: 34)
                                    .background(insightViewModel.selectedSort == sort ? JPColors.accent : JPColors.graphite, in: Capsule())
                            }
                            .buttonStyle(ScalingButtonStyle())
                        }
                    }
                }

                if insightViewModel.sortedInsights.isEmpty {
                    chartEmptyState("No smart insights yet.", "Insights will populate automatically as you trade, review, replay, and plan.")
                        .padding(18)
                        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    VStack(spacing: 12) {
                        ForEach(insightViewModel.sortedInsights.prefix(5)) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                }
            }
        }
    }

    private var chartsSection: some View {
        section(title: "Charts", subtitle: "Equity, profit rhythm, and win-rate trend") {
            VStack(spacing: 14) {
                analyticsChart(
                    title: "Equity Curve",
                    subtitle: "Cumulative P/L",
                    points: viewModel.equityCurve(for: analyticsTrades),
                    style: .line
                )
                analyticsChart(
                    title: "Monthly Profit",
                    subtitle: "Net P/L by month",
                    points: viewModel.monthlyProfit(for: analyticsTrades),
                    style: .bar
                )
                analyticsChart(
                    title: "Weekly Profit",
                    subtitle: "Net P/L by week",
                    points: viewModel.weeklyProfit(for: analyticsTrades),
                    style: .bar
                )
                analyticsChart(
                    title: "Win Rate Trend",
                    subtitle: "Monthly resolved win rate",
                    points: viewModel.winRateTrend(for: analyticsTrades),
                    style: .line
                )
            }
        }
    }

    private var sessionSection: some View {
        section(title: "Session Analysis", subtitle: "Asian, London, and New York performance") {
            VStack(spacing: 14) {
                ForEach(viewModel.sessionAnalysis(for: analyticsTrades)) { session in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(session.session.rawValue)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(JPColors.primaryText)

                                if session.isStrongest {
                                    Text("Strongest")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(JPColors.background)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(JPColors.warning, in: Capsule())
                                }

                                Spacer()

                                Text(currency(session.netProfit))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(tint(for: session.netProfit))
                            }

                            HStack(spacing: 10) {
                                miniStat("Win Rate", percentage(session.winRate))
                                miniStat("Avg RR", riskReward(session.averageRiskReward))
                                miniStat("Trades", "\(session.trades)")
                            }
                        }
                    }
                    .shadow(color: session.isStrongest ? JPColors.warning.opacity(0.14) : Color.clear, radius: 18, x: 0, y: 8)
                }
            }
        }
    }

    private var strategySection: some View {
        section(title: "Strategy Analysis", subtitle: "Sorted from best to worst net performance") {
            VStack(spacing: 14) {
                ForEach(viewModel.strategyAnalysis(for: analyticsTrades)) { strategy in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                Text(strategy.strategy.rawValue)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(JPColors.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()

                                Text(currency(strategy.netProfit))
                                    .font(.system(size: 21, weight: .bold, design: .rounded))
                                    .foregroundStyle(tint(for: strategy.netProfit))
                            }

                            HStack(spacing: 10) {
                                miniStat("Trades", "\(strategy.trades)")
                                miniStat("Win Rate", percentage(strategy.winRate))
                                miniStat("Avg RR", riskReward(strategy.averageRiskReward))
                            }
                        }
                    }
                }
            }
        }
    }

    private var mistakeSection: some View {
        let mistakes = viewModel.mistakeAnalysis(for: analyticsTrades)

        return section(title: "Mistake Analysis", subtitle: "Behavior tags by frequency and P/L impact") {
            if mistakes.isEmpty {
                chartEmptyState("No mistake tags yet.", "Tag trades in the journal to reveal behavior patterns.")
            } else {
                VStack(spacing: 14) {
                    ForEach(mistakes) { mistake in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(mistake.tag.rawValue)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(JPColors.primaryText)

                                    Spacer()

                                    Text(currency(mistake.profitImpact))
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(tint(for: mistake.profitImpact))
                                }

                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(JPColors.graphite)

                                        Capsule()
                                            .fill(mistake.profitImpact >= 0 ? JPColors.profit : JPColors.loss)
                                            .frame(width: max(8, proxy.size.width * min(mistake.percentage / 100, 1)))
                                    }
                                }
                                .frame(height: 8)

                                HStack {
                                    Text("\(mistake.count) tags")
                                    Spacer()
                                    Text(percentage(mistake.percentage))
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)
                            }
                        }
                    }
                }
            }
        }
    }

    private var insightsSection: some View {
        section(title: "Performance Insights", subtitle: "Simple automatic observations from your journal") {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(viewModel.insights(for: analyticsTrades), id: \.self) { insight in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.warning)
                                .frame(width: 28, height: 28)
                                .background(JPColors.warning.opacity(0.14), in: Circle())

                            Text(insight)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JPColors.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func analyticsChart(title: String, subtitle: String, points: [AnalyticsChartPoint], style: AnalyticsChartStyle) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: style == .line ? "chart.xyaxis.line" : "chart.bar.xaxis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(JPColors.accent)
                }

                if points.isEmpty {
                    chartEmptyState("No chart data yet.", "Saved trades will populate this chart automatically.")
                        .frame(height: 190)
                } else {
                    Chart(points) { point in
                        switch style {
                        case .line:
                            AreaMark(
                                x: .value("Date", point.date),
                                yStart: .value("Baseline", 0),
                                yEnd: .value("Value", point.value * chartReveal)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [chartTint(points).opacity(0.28), chartTint(points).opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value * chartReveal)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(chartTint(points))
                        case .bar:
                            BarMark(
                                x: .value("Period", point.label),
                                y: .value("Value", point.value * chartReveal)
                            )
                            .foregroundStyle(point.value >= 0 ? JPColors.profit : JPColors.loss)
                            .cornerRadius(6)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 210)
                    .chartPlotStyle { plotArea in
                        plotArea
                            .background(JPColors.surface.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .opacity(chartReveal == 0 ? 0.2 : 1)
                    .animation(.easeInOut(duration: 0.55), value: chartReveal)
                }
            }
        }
    }

    private func section<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle)
            content()
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
        .animation(.spring(response: 0.44, dampingFraction: 0.88).delay(0.10), value: didAppear)
    }

    private func chartEmptyState(_ title: String, _ message: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(JPColors.accent)
                .frame(width: 56, height: 56)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shimmer()

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)

                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func analyticsOverviewCard(_ card: AnalyticsOverviewCard) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: card.icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(card.tint)
                    .frame(width: 44, height: 44)
                    .background(card.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(card.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)

                    Text(card.value)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(card.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)

                    Text(card.subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(JPColors.mutedText)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        }
        .shadow(color: card.tint.opacity(0.10), radius: 18, x: 0, y: 10)
    }

    private func sessionDashboardRow(_ session: AnalyticsSessionRow) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: session.title == "Other" ? "ellipsis.circle.fill" : "clock.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(tint(for: session.netProfit))
                    .frame(width: 48, height: 48)
                    .background(tint(for: session.netProfit).opacity(0.14), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(session.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(JPColors.primaryText)

                    Text("\(session.trades) trades")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text(currency(session.netProfit))
                        .font(.headline.weight(.black))
                        .foregroundStyle(tint(for: session.netProfit))
                    Text("Win \(percentage(session.winRate))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                }
            }
        }
    }

    private func monthlyCard(_ month: MonthlyPerformanceCard) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(month.month)
                        .font(.headline.weight(.black))
                        .foregroundStyle(JPColors.primaryText)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.caption.weight(.black))
                        .foregroundStyle(tint(for: month.netProfit))
                }

                Text(currency(month.netProfit))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(tint(for: month.netProfit))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 8) {
                    miniStat("Win", percentage(month.winRate))
                    miniStat("Trades", "\(month.trades)")
                }
            }
            .frame(width: 230, alignment: .leading)
        }
    }

    private func bestWorstTile(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                Text(value.isEmpty ? "--" : value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)

                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        }
    }

    private func miniStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(JPColors.mutedText)

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(JPColors.border, lineWidth: 1)
        )
    }

    private func snapshotCard(_ metric: SnapshotMetric) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: metric.icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(metric.tint)
                        .frame(width: 42, height: 42)
                        .background(metric.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    Spacer()

                    Text(metric.trend)
                        .font(.caption.weight(.black))
                        .foregroundStyle(metric.trend.contains("▼") ? JPColors.loss : JPColors.profit)
                }

                Text(metric.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)

                Text(metric.value)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                sparkline(metric.sparkline, tint: metric.tint)
                    .frame(height: 42)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func performanceRankingCard(title: String, subtitle: String, pair: String, winRate: Double, profit: Double, averageRR: Double, icon: String, tint: Color, recommendation: String?) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(title, systemImage: icon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tint)

                        Text(pair)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)

                        Text(subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()

                    Text(currency(profit))
                        .font(.title3.weight(.black))
                        .foregroundStyle(self.tint(for: profit))
                }

                HStack(spacing: 10) {
                    miniStat("Win %", percentage(winRate))
                    miniStat("Profit", currency(profit))
                    miniStat("Avg RR", riskReward(averageRR))
                }

                if let recommendation {
                    Text(recommendation)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.warning)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(JPColors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .shadow(color: tint.opacity(0.16), radius: 22, x: 0, y: 12)
    }

    private func horizontalPerformanceBar(_ title: String, profit: Double, winRate: Double, averageRR: Double, trades: Int, maxProfit: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)

                Spacer()

                Text(currency(profit))
                    .font(.headline.weight(.black))
                    .foregroundStyle(tint(for: profit))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(JPColors.graphite)

                    Capsule()
                        .fill(tint(for: profit))
                        .frame(width: max(10, proxy.size.width * min(abs(profit) / maxProfit, 1) * chartReveal))
                }
            }
            .frame(height: 10)

            HStack(spacing: 8) {
                miniStat("Win Rate", percentage(winRate))
                miniStat("Avg RR", riskReward(averageRR))
                miniStat("Trades", "\(trades)")
            }
        }
    }

    private func weekdayCell(_ day: WeekdayPerformance) -> some View {
        Button {
            JPHaptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                selectedWeekday = day.weekday
            }
        } label: {
            VStack(spacing: 8) {
                Text(String(day.label.prefix(3)))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(JPColors.secondaryText)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(weekdayTint(day).opacity(selectedWeekday == day.weekday ? 0.95 : 0.48))
                    .frame(height: selectedWeekday == day.weekday ? 54 : 44)
                    .overlay(
                        Text("\(day.trades)")
                            .font(.caption.weight(.black))
                            .foregroundStyle(day.trades == 0 ? JPColors.mutedText : JPColors.background)
                    )
                    .shadow(color: weekdayTint(day).opacity(selectedWeekday == day.weekday ? 0.24 : 0), radius: 14, x: 0, y: 8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func pairRow(_ pair: PairPerformance) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(pair.pair)
                                .font(.title3.weight(.black))
                                .foregroundStyle(JPColors.primaryText)

                            if pair.isBest {
                                badge("Favorite", tint: JPColors.warning)
                            }

                            if pair.isWorst {
                                badge("Worst", tint: JPColors.loss)
                            }
                        }

                        Text("\(pair.trades) trades")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()

                    Text(currency(pair.netProfit))
                        .font(.headline.weight(.black))
                        .foregroundStyle(tint(for: pair.netProfit))
                }

                HStack(spacing: 8) {
                    miniStat("Win Rate", percentage(pair.winRate))
                    miniStat("Profit", currency(pair.netProfit))
                    miniStat("Avg RR", riskReward(pair.averageRiskReward))
                }
            }
        }
    }

    private func insightTile(title: String, subtitle: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.warning)
                    .frame(width: 44, height: 44)
                    .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 270, alignment: .leading)
        }
    }

    private func goalRow(_ goal: GoalProgress) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text(goal.subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()

                    Text("\(Int((goal.value * 100).rounded()))%")
                        .font(.headline.weight(.black))
                        .foregroundStyle(goal.tint)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(JPColors.graphite)

                        Capsule()
                            .fill(goal.tint)
                            .frame(width: proxy.size.width * goal.value * chartReveal)
                    }
                }
                .frame(height: 10)
            }
        }
    }

    private func scoreRing(_ score: Int, lineWidth: CGFloat, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(JPColors.graphite, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(Double(score) / 100 * chartReveal))
                .stroke(
                    AngularGradient(colors: [scoreColor(score), JPColors.warning, JPColors.accent, scoreColor(score)], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: size > 120 ? 34 : 28, weight: .black, design: .rounded))
                    .foregroundStyle(JPColors.primaryText)
                Text("/100")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(JPColors.secondaryText)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.7, dampingFraction: 0.86), value: chartReveal)
    }

    private func sparkline(_ values: [Double], tint: Color) -> some View {
        let normalized = values.isEmpty ? [0] : values

        return Chart(Array(normalized.enumerated()), id: \.offset) { index, value in
            LineMark(
                x: .value("Index", index),
                y: .value("Value", value * chartReveal)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

            AreaMark(
                x: .value("Index", index),
                yStart: .value("Base", 0),
                yEnd: .value("Value", value * chartReveal)
            )
            .foregroundStyle(LinearGradient(colors: [tint.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    private func trendPill(_ title: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(value.contains("▼") ? JPColors.loss : JPColors.profit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(JPColors.surface, in: Capsule())
        .overlay(Capsule().stroke(JPColors.border, lineWidth: 1))
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.black))
            .foregroundStyle(JPColors.background)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint, in: Capsule())
    }

    private func weekdayTint(_ day: WeekdayPerformance) -> Color {
        guard day.trades > 0 else { return JPColors.graphite }
        if abs(day.netProfit) < 0.01 { return JPColors.warning }
        return day.netProfit > 0 ? JPColors.profit : JPColors.loss
    }

    private func letterGrade(for score: Int) -> String {
        switch score {
        case 94...100: return "A+"
        case 88..<94: return "A"
        case 82..<88: return "B+"
        case 74..<82: return "B"
        case 62..<74: return "C"
        default: return "D"
        }
    }

    private func outperformancePercent(for score: Int) -> Int {
        min(96, max(52, 50 + Int(Double(score) * 0.36)))
    }

    private func deltaText(points: [AnalyticsChartPoint]) -> String {
        guard let latest = points.last?.value else { return "• 0%" }
        let previous = points.dropLast().last?.value ?? 0
        let delta = latest - previous
        if abs(previous) > 0 {
            let pct = delta / abs(previous) * 100
            return "\(delta >= 0 ? "▲" : "▼") \(delta >= 0 ? "+" : "")\(Int(pct.rounded()))%"
        }
        return "\(delta >= 0 ? "▲" : "▼") \(delta >= 0 ? "+" : "-")$\(Int(abs(delta)).formatted())"
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...100:
            return JPColors.accent
        case 70..<85:
            return JPColors.profit
        case 55..<70:
            return JPColors.warning
        case 35..<55:
            return JPColors.secondaryText
        default:
            return JPColors.loss
        }
    }

    private func chartTint(_ points: [AnalyticsChartPoint]) -> Color {
        (points.last?.value ?? 0) >= 0 ? JPColors.profit : JPColors.loss
    }

    private func tint(for value: Double) -> Color {
        if value > 0 {
            return JPColors.profit
        }

        if value < 0 {
            return JPColors.loss
        }

        return JPColors.secondaryText
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func percentage(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func riskReward(_ value: Double) -> String {
        value > 0 ? "\(String(format: "%.2f", value)) R" : "--"
    }

    private func winRateV1(_ trades: [Trade]) -> Double {
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }
        guard !resolved.isEmpty else { return 0 }
        return rateV1(resolved.filter { $0.status == .win }.count, resolved.count)
    }

    private func netProfitV1(_ trades: [Trade]) -> Double {
        trades.reduce(0) { $0 + $1.profitLoss }
    }

    private func averageRRV1(_ trades: [Trade]) -> Double {
        guard !trades.isEmpty else { return 0 }
        return trades.reduce(0) { $0 + $1.riskReward } / Double(trades.count)
    }

    private func bestTradeV1(_ trades: [Trade]) -> Double {
        trades.map(\.profitLoss).max() ?? 0
    }

    private func worstTradeV1(_ trades: [Trade]) -> Double {
        trades.map(\.profitLoss).min() ?? 0
    }

    private func winningStreakV1(_ trades: [Trade]) -> Int {
        longestStreakV1(trades, status: .win)
    }

    private func losingStreakV1(_ trades: [Trade]) -> Int {
        longestStreakV1(trades, status: .loss)
    }

    private func longestStreakV1(_ trades: [Trade], status: Trade.Status) -> Int {
        var current = 0
        var longest = 0

        for trade in trades.sorted(by: { $0.date < $1.date }) {
            if trade.status == status {
                current += 1
                longest = max(longest, current)
            } else if trade.status == .win || trade.status == .loss {
                current = 0
            }
        }

        return longest
    }

    private func pairRowsV1(_ trades: [Trade]) -> [AnalyticsPairRowV1] {
        Dictionary(grouping: trades) { $0.pair.isEmpty ? "Unknown" : $0.pair }
            .map { pair, pairTrades in
                AnalyticsPairRowV1(
                    pair: pair,
                    trades: pairTrades.count,
                    winRate: winRateV1(pairTrades),
                    netProfit: netProfitV1(pairTrades),
                    averageRR: averageRRV1(pairTrades)
                )
            }
            .sorted { $0.netProfit > $1.netProfit }
    }

    private func monthRowsV1(_ trades: [Trade]) -> [AnalyticsMonthRowV1] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        return Dictionary(grouping: trades) { trade in
            calendar.date(from: calendar.dateComponents([.year, .month], from: trade.date)) ?? trade.date
        }
        .map { monthDate, monthTrades in
            AnalyticsMonthRowV1(
                month: formatter.string(from: monthDate),
                date: monthDate,
                trades: monthTrades.count,
                winRate: winRateV1(monthTrades),
                netProfit: netProfitV1(monthTrades)
            )
        }
        .sorted { $0.date > $1.date }
    }

    private func rateV1(_ value: Int, _ total: Int) -> Double {
        guard total > 0 else { return 0 }
        return (Double(value) / Double(total)) * 100
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func rrV1(_ value: Double) -> String {
        value > 0 ? "\(String(format: "%.2f", value)) R" : "--"
    }

    private func tintV1(_ value: Double) -> Color {
        if value > 0 { return JPColors.profit }
        if value < 0 { return JPColors.loss }
        return JPColors.secondaryText
    }
}

private enum AnalyticsChartStyle {
    case line
    case bar
}

private struct AnalyticsPairRowV1 {
    let pair: String
    let trades: Int
    let winRate: Double
    let netProfit: Double
    let averageRR: Double
}

private struct AnalyticsMonthRowV1 {
    let month: String
    let date: Date
    let trades: Int
    let winRate: Double
    let netProfit: Double
}

private struct AnalyticsReportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
