import SwiftData
import SwiftUI

struct TradeHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \AITradeReview.updatedAt, order: .reverse) private var aiReviews: [AITradeReview]
    @AppStorage("jp.favoriteTradeIDs") private var favoriteTradeIDs = ""
    @StateObject private var viewModel = TradeHistoryViewModel()
    @State private var didAppear = false
    @State private var tradePendingDelete: Trade?
    @State private var duplicateTrade: Trade?
    @State private var replayTrade: Trade?
    @State private var showAddTrade = false
    @State private var showDuplicateTrade = false
    @State private var showReplayTrade = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    heroSection
                    TradeHistoryFilterBar(viewModel: viewModel)
                    miniCalendarStrip

                    if tradeViewModel.trades.isEmpty {
                        TradeHistoryEmptyState(hasTrades: false) { showAddTrade = true }
                            .premiumEntrance(active: didAppear, delay: 0.12)
                    } else {
                        smartInsightsSection

                        if visibleTrades.isEmpty {
                            TradeHistoryEmptyState(hasTrades: true) { showAddTrade = true }
                                .premiumEntrance(active: didAppear, delay: 0.12)
                        } else {
                            timeline
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }
        }
        .navigationTitle("Trade History")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    JPHaptics.selection()
                    showAddTrade = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.accent)
                }
                .accessibilityLabel("Log trade")
            }
        }
        .sheet(isPresented: $showAddTrade) {
            NavigationStack {
                AddTradeView {
                    showAddTrade = false
                    tradeViewModel.fetchTrades()
                }
                .environmentObject(tradeViewModel)
            }
        }
        .sheet(isPresented: $showDuplicateTrade) {
            NavigationStack {
                if let duplicateTrade {
                    AddTradeView(mode: .duplicate(duplicateTrade)) {
                        self.duplicateTrade = nil
                        showDuplicateTrade = false
                        tradeViewModel.fetchTrades()
                    }
                    .environmentObject(tradeViewModel)
                }
            }
        }
        .sheet(isPresented: $showReplayTrade) {
            NavigationStack {
                if subscriptionManager.isPremiumUnlocked, let replayTrade {
                    ReplayStudioView(trade: replayTrade)
                        .environmentObject(tradeViewModel)
                } else {
                    PremiumPaywallView()
                        .environmentObject(subscriptionManager)
                }
            }
        }
        .onChange(of: showDuplicateTrade) { _, isPresented in
            if !isPresented {
                duplicateTrade = nil
            }
        }
        .onChange(of: showReplayTrade) { _, isPresented in
            if !isPresented {
                replayTrade = nil
            }
        }
        .confirmationDialog("Delete Trade?", isPresented: deleteDialogBinding, titleVisibility: .visible) {
            Button("Delete Trade", role: .destructive) {
                guard let trade = tradePendingDelete else { return }
                JPHaptics.notify(.warning)
                tradeViewModel.deleteTrade(trade)
                tradePendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                tradePendingDelete = nil
            }
        } message: {
            Text("This removes the trade from Dashboard, Calendar, Analytics, and Trade History.")
        }
        .onAppear {
            tradeViewModel.configure(context: modelContext)
            withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                didAppear = true
            }
        }
    }

    private var heroSection: some View {
        let metrics = viewModel.metrics(for: tradeViewModel.trades)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trade History")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Search, filter, replay, and learn from every logged trade.")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(JPColors.background)
                    .frame(width: 58, height: 58)
                    .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            LazyVGrid(columns: columns, spacing: 12) {
                metricTile("Trades", "\(metrics.totalTrades)", "number", JPColors.accent)
                metricTile("Win Rate", percentage(metrics.winRate), "target", JPColors.warning)
                metricTile("Total P/L", currency(metrics.totalProfit), "chart.line.uptrend.xyaxis", metrics.totalProfit >= 0 ? JPColors.profit : JPColors.loss)
                metricTile("Avg RR", riskReward(metrics.averageRiskReward), "scale.3d", JPColors.blue)
                metricTile("Streak", metrics.currentStreak, "flame.fill", JPColors.warning)
            }
        }
        .premiumEntrance(active: didAppear)
    }

    private var smartInsightsSection: some View {
        let insights = viewModel.smartInsights(for: tradeViewModel.trades)
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Smart Insights", subtitle: "Quick coaching signals from your history")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(insights, id: \.self) { insight in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(JPColors.warning)
                                    .frame(width: 42, height: 42)
                                    .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                Text(insight)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(JPColors.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(width: 250, alignment: .leading)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.08)
    }

    private var miniCalendarStrip: some View {
        let days = viewModel.weekStrip(for: tradeViewModel.trades)
        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trade Days")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)
                        Text("Tap a day to filter the timeline")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                    Spacer()
                    if viewModel.selectedDay != nil {
                        Button("Clear") {
                            JPHaptics.selection()
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                viewModel.selectedDay = nil
                            }
                        }
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.accent)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(days) { day in
                        dayButton(day)
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.06)
    }

    private var timeline: some View {
        LazyVStack(alignment: .leading, spacing: 22) {
            ForEach(viewModel.groupedTrades(visibleTrades)) { group in
                VStack(alignment: .leading, spacing: 14) {
                    groupHeader(group)

                    LazyVStack(spacing: 14) {
                        ForEach(Array(group.trades.enumerated()), id: \.element.id) { index, trade in
                            NavigationLink {
                                TradeDetailView(trade: trade)
                                    .environmentObject(tradeViewModel)
                            } label: {
                                TradeHistoryCard(
                                    trade: trade,
                                    isFavorite: favoriteIDs.contains(trade.id),
                                    aiScore: aiReviews.first { $0.tradeID == trade.id }?.overallScore,
                                    screenshotCount: viewModel.screenshotCount(for: trade)
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    toggleFavorite(trade)
                                } label: {
                                    Label(favoriteIDs.contains(trade.id) ? "Unfavorite" : "Favorite", systemImage: "star.fill")
                                }
                                .tint(.yellow)

                                Button {
                                    JPHaptics.selection()
                                    duplicateTrade = trade
                                    showDuplicateTrade = true
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc.fill")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    tradePendingDelete = trade
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }

                                Button {
                                    JPHaptics.impact(.medium)
                                    replayTrade = trade
                                    showReplayTrade = true
                                } label: {
                                    Label("Replay Trade", systemImage: "play.rectangle.fill")
                                }
                                .tint(JPColors.profit)
                            }
                            .opacity(didAppear ? 1 : 0)
                            .offset(y: didAppear ? 0 : 18)
                            .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(Double(index) * 0.025), value: visibleTrades.count)
                        }
                    }
                }
            }
        }
    }

    private var visibleTrades: [Trade] {
        viewModel.visibleTrades(tradeViewModel.trades, favorites: favoriteIDs, reviews: aiReviews)
    }

    private var favoriteIDs: Set<UUID> {
        Set(favoriteTradeIDs.split(separator: "|").compactMap { UUID(uuidString: String($0)) })
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { tradePendingDelete != nil },
            set: { if !$0 { tradePendingDelete = nil } }
        )
    }

    private func metricTile(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        GlassCard(padding: 15, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(value)
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func groupHeader(_ group: TradeHistoryGroup) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(group.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                Text("\(group.trades.count) trades • \(percentage(group.winRate)) win rate")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
            }
            Spacer()
            Text(currency(group.netProfit))
                .font(.headline.weight(.black))
                .foregroundStyle(group.netProfit >= 0 ? JPColors.profit : JPColors.loss)
        }
        .padding(.top, 4)
    }

    private func dayButton(_ day: TradeHistoryDay) -> some View {
        let isSelected = viewModel.selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day.date) } ?? false
        return Button {
            JPHaptics.selection()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                viewModel.selectedDay = isSelected ? nil : day.date
            }
        } label: {
            VStack(spacing: 8) {
                Text(day.label)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(JPColors.secondaryText)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(dayColor(day).opacity(isSelected ? 0.98 : 0.55))
                    .frame(height: isSelected ? 54 : 44)
                    .overlay(
                        Text("\(day.trades)")
                            .font(.caption.weight(.black))
                            .foregroundStyle(day.trades == 0 ? JPColors.secondaryText : JPColors.background)
                    )
                    .shadow(color: dayColor(day).opacity(isSelected ? 0.24 : 0), radius: 12, x: 0, y: 8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.label), \(day.trades) trades")
    }

    private func dayColor(_ day: TradeHistoryDay) -> Color {
        guard day.trades > 0 else { return JPColors.graphite }
        if abs(day.netProfit) < 0.01 { return JPColors.warning }
        return day.netProfit > 0 ? JPColors.profit : JPColors.loss
    }

    private func toggleFavorite(_ trade: Trade) {
        JPHaptics.selection()
        var ids = favoriteIDs
        if ids.contains(trade.id) {
            ids.remove(trade.id)
        } else {
            ids.insert(trade.id)
        }
        favoriteTradeIDs = ids.map(\.uuidString).sorted().joined(separator: "|")
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func percentage(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func riskReward(_ value: Double) -> String {
        value > 0 ? "1:\(String(format: "%.2f", value))" : "--"
    }
}
