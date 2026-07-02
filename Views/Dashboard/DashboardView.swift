import Charts
import Combine
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("jp.dailyMissionCompletedDate") private var dailyMissionCompletedDate = ""
    @AppStorage("jp.lastUnlockedAchievementCount") private var lastUnlockedAchievementCount = 0
    @AppStorage("jp.dashboardDailyPlanDate") private var dashboardDailyPlanDate = ""
    @AppStorage("jp.dashboardDailyPlanChecks") private var dashboardDailyPlanChecks = "false|false|false|false"
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var disciplineViewModel = DisciplineViewModel()
    @StateObject private var insightViewModel = InsightViewModel()
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    @Query(sort: \AITradeReview.updatedAt, order: .reverse) private var aiReviews: [AITradeReview]
    @State private var didAppear = false
    @State private var userName = "James"
    @State private var planCompletion = 0.0
    @State private var dailyGoal = "Prepare cleanly before taking the first setup."
    @State private var marketBias = MorningPlan.MarketBias.neutral
    @State private var maxRiskPercent = 1.0
    @State private var maxTrades = 3
    @State private var insightPage = 0
    @State private var celebration: CelebrationPayload?
    @State private var performanceCache = DashboardPerformanceCache.empty
    private let insightTimer = Timer.publish(every: 7, on: .main, in: .common).autoconnect()

    let onLogFirstTrade: () -> Void
    let onOpenPlan: () -> Void
    let onOpenAnalytics: () -> Void
    let onOpenCalendar: () -> Void

    init(
        onLogFirstTrade: @escaping () -> Void = {},
        onOpenPlan: @escaping () -> Void = {},
        onOpenAnalytics: @escaping () -> Void = {},
        onOpenCalendar: @escaping () -> Void = {}
    ) {
        self.onLogFirstTrade = onLogFirstTrade
        self.onOpenPlan = onOpenPlan
        self.onOpenAnalytics = onOpenAnalytics
        self.onOpenCalendar = onOpenCalendar
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                JPColors.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        premiumHeroPerformanceCard
                        todaysFocusSection
                        dailyRiskTrackerSection
                        dailyTradePlanSection
                        yesterdaysLessonSection
                        currentStreakSection
                        premiumAIInsightCard
                        premiumQuickStats
                        premiumWeeklyGoalProgress
                        premiumRecentTrades
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 112)
                }
                .refreshable {
                    JPHaptics.selection()
                    refreshDashboard()
                }
            }
            .navigationTitle("Dashboard")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .overlay(alignment: .center) {
            if let celebration {
                CelebrationOverlay(
                    title: celebration.title,
                    subtitle: celebration.subtitle,
                    symbolName: celebration.symbolName,
                    tint: celebration.tint
                )
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .onTapGesture {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                        self.celebration = nil
                    }
                }
            }
        }
        .onAppear {
            disciplineViewModel.configure(context: modelContext)
            insightViewModel.configure(context: modelContext)
            resetDailyPlanIfNeeded()
            loadPersonalization()
            rebuildPerformanceCache()
            withAnimation(.easeOut(duration: 0.45)) {
                didAppear = true
            }
        }
        .onChange(of: tradeViewModel.trades.count) { _, _ in
            refreshDashboard()
        }
        .onChange(of: disciplineViewModel.unlockedCount) { oldValue, newValue in
            guard newValue > oldValue, newValue > lastUnlockedAchievementCount else {
                lastUnlockedAchievementCount = max(lastUnlockedAchievementCount, newValue)
                return
            }
            lastUnlockedAchievementCount = newValue
            showCelebration(title: "Achievement Unlocked", subtitle: "Your discipline system has recorded new progress.", symbolName: "rosette", tint: JPColors.warning)
        }
        .onReceive(insightTimer) { _ in
            guard insightViewModel.rotatingInsights.count > 1 else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                insightPage = (insightPage + 1) % insightViewModel.rotatingInsights.count
            }
        }
    }

    private var premiumHeroPerformanceCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(timeGreeting),")
                        .font(.title3.weight(.black))
                        .foregroundStyle(JPColors.secondaryText)

                    Text("\(userName) 👋")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)

                    Text(viewModel.quote)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(JPColors.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    JPHaptics.selection()
                    debugPrint("Profile tapped")
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(JPColors.blue)
                        .frame(width: 46, height: 46)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(JPColors.border, lineWidth: 1))
                        .shadow(color: JPColors.blue.opacity(0.18), radius: 14, x: 0, y: 8)
                }
                .buttonStyle(ScalingButtonStyle())
                .accessibilityLabel("Profile")
                .accessibilityHint("Profile screen coming soon")

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Today")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.secondaryText)
                        .textCase(.uppercase)

                    Text(currency(todayProfitLoss))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(tint(for: todayProfitLoss))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                }
            }

            HStack(spacing: 10) {
                premiumHeroMetric("Today's R", rrText(todayAverageR), "target", JPColors.warning)
                premiumHeroMetric("Trades", "\(todayTrades.count)", "number.circle.fill", JPColors.blue)
            }

            HStack(spacing: 10) {
                premiumHeroMetric("Current Streak", streakText(currentOutcomeStreak), "flame.fill", currentOutcomeStreak.tint)
                premiumHeroMetric("Win Rate", "\(Int(tradeViewModel.winRate.rounded()))%", "checkmark.seal.fill", JPColors.accent)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [JPColors.elevatedSurface.opacity(0.98), JPColors.surface.opacity(0.92), JPColors.graphite.opacity(0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        .shadow(color: JPColors.accent.opacity(0.16), radius: 28, x: 0, y: 18)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 16)
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: didAppear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dashboard summary. Today profit \(currency(todayProfitLoss)), today's R \(rrText(todayAverageR)), \(todayTrades.count) trades, current streak \(streakText(currentOutcomeStreak))")
    }

    private var premiumAIInsightCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(JPColors.warning)
                .frame(width: 52, height: 52)
                .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Daily Insight")
                    .font(.caption.weight(.black))
                    .foregroundStyle(JPColors.secondaryText)
                    .textCase(.uppercase)

                Text(dailyDashboardInsight)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Generated locally from your saved trade stats.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.mutedText)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 12)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 14)
        .animation(.spring(response: 0.46, dampingFraction: 0.86).delay(0.04), value: didAppear)
    }

    private var todaysFocusSection: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "scope")
                .font(.system(size: 29, weight: .black))
                .foregroundStyle(JPColors.accent)
                .frame(width: 60, height: 60)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Focus")
                    .font(.caption.weight(.black))
                    .foregroundStyle(JPColors.secondaryText)
                    .textCase(.uppercase)

                Text(todaysFocusMessage)
                    .font(.title3.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Built from your plan, saved trades, and local performance signals.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.mutedText)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [JPColors.accent.opacity(0.15), JPColors.surface.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(JPColors.accent.opacity(0.18), lineWidth: 1))
        .shadow(color: JPColors.accent.opacity(0.12), radius: 18, x: 0, y: 12)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 14)
        .animation(.spring(response: 0.46, dampingFraction: 0.86).delay(0.03), value: didAppear)
    }

    private var dailyRiskTrackerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Daily Risk Tracker")
                        .font(.title3.weight(.black))
                        .foregroundStyle(JPColors.primaryText)

                    Text("\(riskText(todayRiskUsed)) used of \(riskText(dailyRiskLimit)) daily limit")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                }

                Spacer()

                Text("\(Int((dailyRiskProgress * 100).rounded()))%")
                    .font(.title3.weight(.black))
                    .foregroundStyle(dailyRiskProgress >= 1 ? JPColors.loss : JPColors.accent)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(JPColors.graphite)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: dailyRiskProgress >= 1 ? [JPColors.warning, JPColors.loss] : [JPColors.accent, JPColors.profit],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: didAppear ? proxy.size.width * CGFloat(min(dailyRiskProgress, 1)) : 0)
                        .animation(.spring(response: 0.62, dampingFraction: 0.86), value: didAppear)
                        .animation(.easeInOut(duration: 0.35), value: dailyRiskProgress)
                }
            }
            .frame(height: 12)

            HStack {
                Text("\(todayTrades.count) trades today")
                Spacer()
                Text("Max \(max(maxTrades, 1)) trades")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(JPColors.secondaryText)
        }
        .padding(18)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 14)
        .animation(.spring(response: 0.46, dampingFraction: 0.86).delay(0.06), value: didAppear)
    }

    private var dailyTradePlanSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Daily Trade Plan")
                        .font(.title3.weight(.black))
                        .foregroundStyle(JPColors.primaryText)

                    Text("\(dailyPlanCompletedCount) / \(dailyPlanItems.count) complete")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                }

                Spacer()

                Text("\(Int((dailyPlanProgress * 100).rounded()))%")
                    .font(.title3.weight(.black))
                    .foregroundStyle(JPColors.warning)
            }

            VStack(spacing: 10) {
                ForEach(Array(dailyPlanItems.enumerated()), id: \.offset) { index, item in
                    Button {
                        toggleDailyPlanItem(index)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(item.isComplete ? LinearGradient(colors: [JPColors.accent, JPColors.profit], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(item.isComplete ? JPColors.blue.opacity(0.45) : JPColors.secondaryText.opacity(0.55), lineWidth: 1.5))
                                    .shadow(color: item.isComplete ? JPColors.blue.opacity(0.22) : .clear, radius: 10, x: 0, y: 5)

                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(item.isComplete ? JPColors.background : Color.clear)
                                    .scaleEffect(item.isComplete ? 1 : 0.4)
                                    .opacity(item.isComplete ? 1 : 0)
                            }
                            .animation(.spring(response: 0.32, dampingFraction: 0.76), value: item.isComplete)

                            Text(item.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(JPColors.primaryText)

                            Spacer()
                        }
                        .padding(13)
                        .background(item.isComplete ? JPColors.accent.opacity(0.10) : JPColors.graphite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(item.isComplete ? JPColors.accent.opacity(0.22) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(ScalingButtonStyle())
                }
            }
        }
        .padding(18)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 14)
        .animation(.spring(response: 0.46, dampingFraction: 0.86).delay(0.09), value: didAppear)
    }

    private var yesterdaysLessonSection: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "lightbulb.max.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(JPColors.warning)
                .frame(width: 52, height: 52)
                .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Yesterday's Lesson")
                    .font(.caption.weight(.black))
                    .foregroundStyle(JPColors.secondaryText)
                    .textCase(.uppercase)

                Text(yesterdaysLessonText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Pulled from your latest completed journal.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.mutedText)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 14)
        .animation(.spring(response: 0.46, dampingFraction: 0.86).delay(0.12), value: didAppear)
    }

    private var currentStreakSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(currentOutcomeStreak.tint)
                .frame(width: 72, height: 72)
                .background(currentOutcomeStreak.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Current Streak")
                    .font(.caption.weight(.black))
                    .foregroundStyle(JPColors.secondaryText)
                    .textCase(.uppercase)

                Text(streakText(currentOutcomeStreak))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(currentOutcomeStreak.tint)

                Text(currentOutcomeStreak.count == 0 ? "Start the streak with a clean, journaled trade." : "Stay process-first. Do not let the streak change your risk.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [currentOutcomeStreak.tint.opacity(0.16), JPColors.surface.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(currentOutcomeStreak.tint.opacity(0.18), lineWidth: 1))
        .shadow(color: currentOutcomeStreak.tint.opacity(0.12), radius: 20, x: 0, y: 14)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 14)
        .animation(.spring(response: 0.46, dampingFraction: 0.86).delay(0.15), value: didAppear)
    }

    private var premiumQuickStats: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Quick Stats", subtitle: "Core performance from saved trades")

            HStack(spacing: 12) {
                premiumStatCard("Win Rate", "\(Int(tradeViewModel.winRate.rounded()))%", JPColors.accent)
                premiumStatCard("Net P/L", currency(tradeViewModel.totalNetProfitLoss), tint(for: tradeViewModel.totalNetProfitLoss))
            }

            HStack(spacing: 12) {
                premiumStatCard("Average R", rrText(averageRR(for: tradeViewModel.trades)), JPColors.warning)
                premiumStatCard("Total Trades", "\(tradeViewModel.trades.count)", JPColors.blue)
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 14)
        .animation(.spring(response: 0.46, dampingFraction: 0.86).delay(0.08), value: didAppear)
    }

    private var premiumWeeklyGoalProgress: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Weekly Goal")
                        .font(.title3.weight(.black))
                        .foregroundStyle(JPColors.primaryText)
                    Text("\(weeklyTradeCount) / 10 Trades")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                }

                Spacer()

                Text("\(Int((weeklyGoalProgress * 100).rounded()))%")
                    .font(.title3.weight(.black))
                    .foregroundStyle(JPColors.accent)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(JPColors.graphite)
                        .frame(height: 12)
                    Capsule()
                        .fill(LinearGradient(colors: [JPColors.accent, JPColors.profit], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * weeklyGoalProgress, height: 12)
                }
            }
            .frame(height: 12)
        }
        .padding(18)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 14)
        .animation(.spring(response: 0.48, dampingFraction: 0.86).delay(0.12), value: didAppear)
        .animation(.easeInOut(duration: 0.55), value: weeklyGoalProgress)
    }

    private var premiumRecentTrades: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(title: "Recent Trades", subtitle: "Latest saved journal entries")

                Spacer()

                NavigationLink {
                    TradeHistoryView()
                        .environmentObject(tradeViewModel)
                } label: {
                    Text("View All")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.accent)
                }
            }

            if tradeViewModel.trades.isEmpty {
                Button {
                    JPHaptics.impact(.light)
                    onLogFirstTrade()
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(JPColors.accent)
                        Text("Ready for today's first setup?")
                            .font(.title3.weight(.black))
                            .foregroundStyle(JPColors.primaryText)
                        Text("Stick to your plan and log only A+ trades.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(JPColors.border, lineWidth: 1))
                }
                .buttonStyle(ScalingButtonStyle())
                .accessibilityLabel("Log first trade")
                .accessibilityHint("Opens Add Trade")
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(tradeViewModel.trades.prefix(5).enumerated()), id: \.element.id) { index, trade in
                        NavigationLink {
                            TradeDetailView(trade: trade)
                                .environmentObject(tradeViewModel)
                        } label: {
                            premiumRecentTradeCard(trade)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded { JPHaptics.selection() })
                        .accessibilityLabel("\(trade.pair), \(trade.direction.rawValue), \(trade.status.rawValue), profit loss \(currency(trade.profitLoss))")
                        .accessibilityHint("Opens trade details")
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 12)
                        .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.14 + Double(index) * 0.035), value: didAppear)
                    }
                }
            }
        }
    }

    private func premiumHeroMetric(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2.weight(.black))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(JPColors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .contentTransition(.numericText())
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JPColors.border, lineWidth: 1))
    }

    private func premiumStatCard(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .contentTransition(.numericText())
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        .shadow(color: tint.opacity(0.08), radius: 14, x: 0, y: 8)
    }

    private func premiumRecentTradeCard(_ trade: Trade) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                Text(trade.pair)
                    .font(.title3.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 8) {
                    Text(trade.direction.rawValue)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(trade.direction == .buy ? JPColors.profit : JPColors.loss)
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .background((trade.direction == .buy ? JPColors.profit : JPColors.loss).opacity(0.13), in: Capsule())

                    Text(trade.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 6) {
                Text(currency(trade.profitLoss))
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(tint(for: trade.profitLoss))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(rrText(trade.riskReward))
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(JPColors.blue)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [JPColors.surface.opacity(0.96), JPColors.graphite.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 12)
    }

    private var dashboardHero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [JPColors.elevatedSurface.opacity(0.98), JPColors.surface.opacity(0.86), JPColors.background.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(JPColors.accent.opacity(0.28))
                .frame(width: 210, height: 210)
                .blur(radius: 58)
                .offset(x: didAppear ? 160 : 110, y: didAppear ? -84 : -46)
                .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: didAppear)

            Circle()
                .fill(JPColors.blue.opacity(0.18))
                .frame(width: 170, height: 170)
                .blur(radius: 54)
                .offset(x: -64, y: 92)

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(timeGreeting) \(userName)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)

                        Text("\"\(viewModel.quote)\"")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(JPColors.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    EliteScoreRing(score: overallTraderScore, label: traderRating)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    heroStat("Current Streak", "\(disciplineViewModel.currentDisciplineStreak)d", icon: "flame.fill", tint: JPColors.accent)
                    heroStat("XP Progress", "\(Int((disciplineViewModel.progressToNextLevel * 100).rounded()))%", icon: "star.circle.fill", tint: JPColors.warning)
                    heroStat("Discipline", "Level \(disciplineViewModel.level)", icon: "checkmark.seal.fill", tint: JPColors.blue)
                    heroStat("Weekly", "\(weeklyAverageScore)%", icon: "chart.line.uptrend.xyaxis", tint: JPColors.profit)
                }
            }
            .padding(22)
        }
        .frame(minHeight: 318)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(JPColors.border, lineWidth: 1)
        )
        .shadow(color: JPColors.accent.opacity(0.10), radius: 28, x: 0, y: 18)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 12)
    }

    private func heroStat(_ title: String, _ value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                    .contentTransition(.numericText())
                    .lineLimit(1)

                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JPColors.border, lineWidth: 1))
    }

    private var dailyMissionSection: some View {
        DailyMissionCard(
            title: dailyMissionTitle,
            subtitle: dailyMissionSubtitle,
            xp: 10,
            isComplete: isDailyMissionComplete
        ) {
            guard !isDailyMissionComplete else { return }
            dailyMissionCompletedDate = todayKey
            disciplineViewModel.completeDailyMission()
            showCelebration(title: "Daily Mission Complete", subtitle: "+10 XP added to your discipline progress.", symbolName: "flag.checkered", tint: JPColors.warning)
        }
        .premiumEntrance(active: didAppear, delay: 0.02)
    }

    private var dailyCoachSection: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(JPColors.warning)
                    .frame(width: 52, height: 52)
                    .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text("Daily AI Coaching")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                        .textCase(.uppercase)

                    Text(dailyCoachingMessage)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Generated locally from your smart insights.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.mutedText)
                }

                Spacer(minLength: 0)
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.03)
    }

    private var disciplineHero: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(JPColors.graphite, lineWidth: 15)

                        Circle()
                            .trim(from: 0, to: Double(disciplineViewModel.score) / 100.0)
                            .stroke(
                                AngularGradient(
                                    colors: [JPColors.accent, JPColors.blue, JPColors.warning, JPColors.accent],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 15, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .shadow(color: JPColors.accent.opacity(0.34), radius: 16, x: 0, y: 6)
                            .animation(.spring(response: 0.7, dampingFraction: 0.86), value: disciplineViewModel.score)

                        VStack(spacing: 2) {
                            Text("\(disciplineViewModel.score)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(JPColors.primaryText)
                                .contentTransition(.numericText())

                            Text("score")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(JPColors.secondaryText)
                        }
                    }
                    .frame(width: 118, height: 118)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Discipline Command")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)

                        Text(disciplineViewModel.scoreRating)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(JPColors.accent)

                        Text("Streak \(disciplineViewModel.currentDisciplineStreak) days")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)
                            .contentTransition(.numericText())
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 12) {
                    commandStat("XP Level", "Level \(disciplineViewModel.level)", icon: "star.circle.fill", tint: JPColors.warning)
                    commandStat("Next Level", "\(Int((disciplineViewModel.progressToNextLevel * 100).rounded()))%", icon: "arrow.up.right.circle.fill", tint: JPColors.blue)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(JPColors.graphite).frame(height: 10)
                        Capsule()
                            .fill(LinearGradient(colors: [JPColors.warning, JPColors.accent], startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * disciplineViewModel.progressToNextLevel, height: 10)
                            .animation(.spring(response: 0.5, dampingFraction: 0.86), value: disciplineViewModel.progressToNextLevel)
                    }
                }
                .frame(height: 10)
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
        .animation(.spring(response: 0.44, dampingFraction: 0.86).delay(0.05), value: didAppear)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: disciplineViewModel.score)
    }

    private var commandCenterMetrics: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Command Center", subtitle: "Live trading, discipline, and risk signals")

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(commandMetrics.enumerated()), id: \.element.id) { index, metric in
                    EliteMetricCard(metric: metric)
                        .opacity(didAppear ? 1 : 0)
                        .offset(y: didAppear ? 0 : 18)
                        .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.04 + Double(index) * 0.025), value: didAppear)
                }
            }
        }
    }

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Performance", subtitle: "Live analytics from saved trades")

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(viewModel.metrics(for: tradeViewModel).enumerated()), id: \.element.id) { index, metric in
                    MetricCard(
                        title: metric.title,
                        value: metric.value,
                        detail: metric.detail,
                        icon: metric.icon,
                        tint: metric.tint
                    )
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 18)
                    .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(Double(index) * 0.025), value: didAppear)
                }
            }
        }
    }

    private var smartInsightsCarousel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Smart Insights", subtitle: "Rotating coaching signals from your journal")

            if insightViewModel.rotatingInsights.isEmpty {
                SkeletonCard(height: 148)
            } else {
                TabView(selection: $insightPage) {
                    ForEach(Array(insightViewModel.rotatingInsights.enumerated()), id: \.element.id) { index, insight in
                        InsightCard(insight: insight)
                            .tag(index)
                            .padding(.vertical, 2)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 178)
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.04)
    }

    private var todayFocus: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Today's Focus")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)

                        Text(dailyGoal)
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "scope")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(JPColors.background)
                        .frame(width: 50, height: 50)
                        .background(JPColors.warning, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    focusTile("Plan", "\(Int((planCompletion * 100).rounded()))%", icon: "checklist.checked", tint: JPColors.blue)
                    focusTile("Bias", marketBias.rawValue, icon: "arrow.left.and.right", tint: biasColor)
                    focusTile("Risk", "\(riskText(maxRiskPercent))", icon: "shield.lefthalf.filled", tint: JPColors.accent)
                    focusTile("Readiness", "\(Int((planCompletion * 100).rounded()))%", icon: "bolt.heart.fill", tint: JPColors.warning)
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
        .animation(.spring(response: 0.44, dampingFraction: 0.86).delay(0.1), value: didAppear)
    }

    private var tradingSessionCard: some View {
        let session = currentTradingSession
        let next = nextTradingSession

        return GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Trading Session")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)

                        Text(session.name)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(session.color)

                        Text("Next: \(next.name) in \(countdownText(toHour: next.startHour))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: session.icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(session.color)
                        .frame(width: 56, height: 56)
                        .background(session.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                HStack(spacing: 8) {
                    sessionSegment(name: "Asia", isActive: session.name == "Asia", color: JPColors.warning)
                    sessionSegment(name: "London", isActive: session.name == "London", color: JPColors.accent)
                    sessionSegment(name: "New York", isActive: session.name == "New York", color: JPColors.blue)
                }

                Divider().overlay(JPColors.border)

                LazyVGrid(columns: columns, spacing: 12) {
                    focusTile("Win Rate", "\(Int(sessionPerformance.winRate.rounded()))%", icon: "target", tint: session.color)
                    focusTile("Avg RR", rrText(sessionPerformance.averageRR), icon: "scale.3d", tint: JPColors.warning)
                    focusTile("Profit", currency(sessionPerformance.netProfit), icon: "chart.line.uptrend.xyaxis", tint: tint(for: sessionPerformance.netProfit))
                    focusTile("Status", sessionStatusText, icon: "dot.radiowaves.left.and.right", tint: session.color)
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
        .animation(.spring(response: 0.44, dampingFraction: 0.86).delay(0.15), value: didAppear)
    }

    private var latestTradeHero: some View {
        guard let trade = tradeViewModel.trades.first else {
            return AnyView(EmptyView())
        }

        return AnyView(
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Trade")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)

                            Text(trade.pair)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(JPColors.primaryText)

                            HStack(spacing: 8) {
                                badge(trade.direction.rawValue, color: trade.direction == .buy ? JPColors.profit : JPColors.loss)
                                badge(trade.status.rawValue, color: outcomeColor(for: trade))
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(currency(trade.profitLoss))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(trade.profitLoss >= 0 ? JPColors.profit : JPColors.loss)

                            Text("R \(String(format: "%.2f", trade.riskReward))")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(JPColors.warning)

                            Text("AI \(aiScore(for: trade))")
                                .font(.caption.weight(.black))
                                .foregroundStyle(JPColors.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(JPColors.blue.opacity(0.14), in: Capsule())
                        }
                    }

                    HStack(spacing: 12) {
                        PremiumGateLink {
                            ReplayStudioView(trade: trade)
                        } label: {
                            Label("Replay Trade", systemImage: "play.rectangle.fill")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(JPColors.background)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: JPColors.accent.opacity(0.22), radius: 16, x: 0, y: 8)
                        }
                        .buttonStyle(ScalingButtonStyle())

                        NavigationLink {
                            TradeDetailView(trade: trade)
                                .environmentObject(tradeViewModel)
                        } label: {
                            Label("Detail", systemImage: "arrow.up.right")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(JPColors.primaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(JPColors.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JPColors.border, lineWidth: 1))
                        }
                        .buttonStyle(ScalingButtonStyle())
                    }
                }
            }
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : 18)
            .animation(.spring(response: 0.44, dampingFraction: 0.86).delay(0.2), value: didAppear)
        )
    }

    private var weeklyProgress: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Weekly Progress", subtitle: "Last seven discipline days")

            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 9) {
                        ForEach(lastSevenDays, id: \.self) { date in
                            weeklyDay(date)
                        }
                    }

                    Divider().overlay(JPColors.border)

                    ConsistencyHeatmapView(days: disciplineViewModel.history, weekCount: 4)
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
        .animation(.spring(response: 0.44, dampingFraction: 0.86).delay(0.25), value: didAppear)
    }

    private var performanceSnapshot: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Performance Snapshot", subtitle: "The fastest read on your trading edge")

            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Equity Preview")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.secondaryText)

                            DashboardMiniEquityChart(series: viewModel.equitySeries(for: tradeViewModel.trades))
                                .frame(height: 92)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Weekly Heatmap")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.secondaryText)

                            HStack(spacing: 6) {
                                ForEach(lastSevenDays, id: \.self) { date in
                                    miniHeatDay(date)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Divider().overlay(JPColors.border)

                    LazyVGrid(columns: columns, spacing: 12) {
                        snapshotTile("Best Pair", bestPair.name, bestPair.value, icon: "crown.fill", tint: JPColors.warning)
                        snapshotTile("Worst Pair", worstPair.name, worstPair.value, icon: "exclamationmark.triangle.fill", tint: JPColors.loss)
                        snapshotTile("Best Session", bestSessionPerformance.name, bestSessionPerformance.value, icon: "sun.max.fill", tint: JPColors.accent)
                        snapshotTile("Common Mistake", mostCommonMistake, "Watch this pattern", icon: "scope", tint: JPColors.purple)
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.24)
    }

    private var disciplineCommandSystem: some View {
        NavigationLink {
            GoalsStreaksView()
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 18) {
                        EliteScoreRing(score: disciplineViewModel.score, label: "Level \(disciplineViewModel.level)")
                            .frame(width: 122, height: 122)

                        VStack(alignment: .leading, spacing: 9) {
                            Text("Discipline System")
                                .font(.caption.weight(.black))
                                .foregroundStyle(JPColors.secondaryText)
                                .textCase(.uppercase)

                            Text(traderRating)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(JPColors.accent)

                            Text("\(disciplineViewModel.totalXP) XP • \(disciplineViewModel.unlockedCount) achievements unlocked")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(JPColors.primaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(nextAchievementText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 10) {
                        miniRing(title: "Plan", progress: disciplineViewModel.planRing, color: JPColors.blue)
                        miniRing(title: "Risk", progress: disciplineViewModel.riskRing, color: JPColors.accent)
                        miniRing(title: "Journal", progress: disciplineViewModel.journalRing, color: JPColors.warning)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .premiumEntrance(active: didAppear, delay: 0.28)
    }

    private var disciplineWidgets: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Discipline Rhythm", subtitle: "Streak, weekly focus, and monthly summary")

            LazyVGrid(columns: columns, spacing: 14) {
                rhythmWidget("Daily Streak", "\(disciplineViewModel.currentDisciplineStreak)", "disciplined days", icon: "flame.fill", tint: JPColors.accent)
                rhythmWidget("Weekly Avg", "\(weeklyAverageScore)", "discipline score", icon: "chart.line.uptrend.xyaxis", tint: JPColors.blue)
                rhythmWidget("Month XP", "\(monthlyXP)", "earned this month", icon: "star.circle.fill", tint: JPColors.warning)
                rhythmWidget("Perfect Days", "\(monthlyPerfectDays)", "this month", icon: "crown.fill", tint: JPColors.profit)
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.28)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Quick Actions", subtitle: "Move to the next best action")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    actionButton("Log Trade", icon: "plus.circle.fill", tint: JPColors.accent, action: onLogFirstTrade)
                    NavigationLink {
                        TradeHistoryView()
                            .environmentObject(tradeViewModel)
                    } label: {
                        actionPill("Open Trade History", icon: "clock.arrow.circlepath", tint: JPColors.accent)
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        EliteStatsDashboardView(onLogFirstTrade: onLogFirstTrade)
                            .environmentObject(tradeViewModel)
                    } label: {
                        actionPill("Open Elite Stats", icon: "chart.xyaxis.line", tint: JPColors.blue)
                    }
                    .buttonStyle(.plain)
                    if let latestTrade = tradeViewModel.trades.first {
                        NavigationLink {
                            ReplayStudioView(trade: latestTrade)
                        } label: {
                            actionPill("Analyze Trade", icon: "sparkles", tint: JPColors.purple)
                        }
                        .buttonStyle(.plain)
                    }
                    actionButton("Plan Session", icon: "sunrise.fill", tint: JPColors.warning, action: onOpenPlan)
                    actionButton("Export Report", icon: "doc.richtext", tint: JPColors.blue, action: onOpenAnalytics)
                    actionButton("Open Calendar", icon: "calendar", tint: JPColors.purple, action: onOpenCalendar)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var commandCenterEmptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(JPColors.accent)
                    .frame(width: 68, height: 68)
                    .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your trading journey starts here.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Log your first trade to unlock analytics, insights, AI reviews, replay, and discipline tracking.")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        JPHaptics.impact(.light)
                        onOpenPlan()
                    } label: {
                        actionPill("Morning Plan", icon: "sunrise.fill", tint: JPColors.warning)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Morning Plan")

                    Button {
                        JPHaptics.impact(.light)
                        onLogFirstTrade()
                    } label: {
                        actionPill("Log First Trade", icon: "plus.circle.fill", tint: JPColors.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log first trade")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
        .animation(.spring(response: 0.44, dampingFraction: 0.86).delay(0.2), value: didAppear)
    }

    private func commandStat(_ title: String, _ value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)

                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 60)
        .background(JPColors.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func focusTile(_ title: String, _ value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding(13)
        .background(JPColors.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sessionSegment(name: String, isActive: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.caption.weight(.bold))
                .foregroundStyle(isActive ? color : JPColors.secondaryText)

            Capsule()
                .fill(isActive ? color : JPColors.graphite)
                .frame(height: 8)
                .shadow(color: isActive ? color.opacity(0.25) : Color.clear, radius: 10, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            JPHaptics.impact(.light)
            action()
        } label: {
            actionPill(title, icon: icon, tint: tint)
        }
        .buttonStyle(ScalingButtonStyle())
        .accessibilityLabel(title)
    }

    private func actionPill(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(tint.opacity(0.13), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.28), lineWidth: 1))
    }

    private func weeklyDay(_ date: Date) -> some View {
        let item = disciplineViewModel.history.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let score = item?.score ?? 0
        let color: Color = score >= 100 ? JPColors.warning : (score >= 80 ? JPColors.profit : JPColors.loss)

        return VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(item == nil ? JPColors.graphite : color.opacity(0.82))
                .frame(height: 50)
                .overlay(
                    Text(item == nil ? "--" : "\(score)")
                        .font(.caption.weight(.black))
                        .foregroundStyle(item == nil ? JPColors.secondaryText : JPColors.background)
                        .contentTransition(.numericText())
                )

            Text(date.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func rhythmWidget(_ title: String, _ value: String, _ subtitle: String, icon: String, tint: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .contentTransition(.numericText())

                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)

                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(JPColors.mutedText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func outcomeColor(for trade: Trade) -> Color {
        switch trade.status {
        case .win:
            return JPColors.profit
        case .loss:
            return JPColors.loss
        case .breakeven:
            return JPColors.warning
        }
    }

    private var overallTraderScore: Int {
        let discipline = Double(disciplineViewModel.score)
        let performance = min(100, max(0, tradeViewModel.winRate))
        let risk = Double(riskScore)
        let consistency = Double(consistencyScore)
        guard !tradeViewModel.trades.isEmpty else {
            return max(42, Int((discipline * 0.72 + Double(planCompletion * 100) * 0.28).rounded()))
        }
        return Int((discipline * 0.30 + performance * 0.22 + risk * 0.20 + consistency * 0.18 + Double(executionScore) * 0.10).rounded())
    }

    private var traderRating: String {
        switch overallTraderScore {
        case 92...:
            return "Elite Trader"
        case 82..<92:
            return "Great Trader"
        case 70..<82:
            return "Consistent Trader"
        case 55..<70:
            return "Building Trader"
        default:
            return "Preparing Trader"
        }
    }

    private var commandMetrics: [EliteMetricData] {
        [
            EliteMetricData(title: "This Month P/L", value: currency(tradeViewModel.monthlyProfitLoss), subtitle: "Current month", icon: "calendar", tint: tint(for: tradeViewModel.monthlyProfitLoss), progress: normalizedMoney(tradeViewModel.monthlyProfitLoss)),
            EliteMetricData(title: "Today P/L", value: currency(tradeViewModel.dailyProfitLoss), subtitle: "Today's net", icon: "sun.max.fill", tint: tint(for: tradeViewModel.dailyProfitLoss), progress: normalizedMoney(tradeViewModel.dailyProfitLoss)),
            EliteMetricData(title: "Win Rate", value: "\(Int(tradeViewModel.winRate.rounded()))%", subtitle: "Wins vs losses", icon: "target", tint: JPColors.accent, progress: tradeViewModel.winRate / 100),
            EliteMetricData(title: "Average RR", value: rrText(averageRR(for: tradeViewModel.trades)), subtitle: "Reward quality", icon: "scale.3d", tint: JPColors.warning, progress: min(1, averageRR(for: tradeViewModel.trades) / 4)),
            EliteMetricData(title: "Total Trades", value: "\(tradeViewModel.trades.count)", subtitle: "Saved journals", icon: "number", tint: JPColors.blue, progress: min(1, Double(tradeViewModel.trades.count) / 100)),
            EliteMetricData(title: "Discipline Score", value: "\(disciplineViewModel.score)", subtitle: disciplineViewModel.scoreRating, icon: "checkmark.seal.fill", tint: JPColors.accent, progress: Double(disciplineViewModel.score) / 100),
            EliteMetricData(title: "Psychology Score", value: "\(psychologyScore)", subtitle: "Emotion control", icon: "brain.head.profile", tint: JPColors.purple, progress: Double(psychologyScore) / 100),
            EliteMetricData(title: "Execution Score", value: "\(executionScore)", subtitle: "Entry quality", icon: "scope", tint: JPColors.blue, progress: Double(executionScore) / 100),
            EliteMetricData(title: "Consistency Score", value: "\(consistencyScore)", subtitle: "Steady behavior", icon: "waveform.path.ecg", tint: JPColors.profit, progress: Double(consistencyScore) / 100),
            EliteMetricData(title: "Risk Score", value: "\(riskScore)", subtitle: "Risk control", icon: "shield.lefthalf.filled", tint: JPColors.warning, progress: Double(riskScore) / 100)
        ]
    }

    private var todayTrades: [Trade] {
        performanceCache.todayTrades
    }

    private var todayProfitLoss: Double {
        performanceCache.todayProfitLoss
    }

    private var todayAverageR: Double {
        performanceCache.todayAverageR
    }

    private var weeklyTradeCount: Int {
        performanceCache.weeklyTradeCount
    }

    private var weeklyGoalProgress: Double {
        min(1, Double(weeklyTradeCount) / 10.0)
    }

    private var currentOutcomeStreak: DashboardOutcomeStreak {
        performanceCache.currentOutcomeStreak
    }

    private var dailyDashboardInsight: String {
        guard !tradeViewModel.trades.isEmpty else {
            return "Log your first trade today. The dashboard gets sharper with every journal entry."
        }

        if todayTrades.isEmpty {
            return "No trades logged today. Complete your plan first, then wait for a clean setup."
        }

        if let strongest = strongestSessionInsight {
            return strongest
        }

        if let rrInsight = averageRRImprovementInsight {
            return rrInsight
        }

        if let planInsight = followedPlanInsight {
            return planInsight
        }

        if tradeViewModel.winRate >= 60 {
            return "Your win rate is above 60%. Keep protecting your best setups and avoid forcing extra trades."
        }

        return "Focus on execution quality today. Your journal will reveal the pattern after each saved trade."
    }

    private var todaysFocusMessage: String {
        if planCompletion < 1 {
            return "Complete your checklist before entering. Preparation is today's edge."
        }

        if todayTrades.count >= max(maxTrades, 1) {
            return "You have reached your planned trade limit. Protect discipline from here."
        }

        if dailyRiskProgress >= 1 {
            return "Daily risk is fully used. Stop trading and review your execution."
        }

        if let strongest = strongestSessionInsight {
            return strongest
        }

        return dailyDashboardInsight
    }

    private var todayRiskUsed: Double {
        performanceCache.todayRiskUsed
    }

    private var dailyRiskLimit: Double {
        max(maxRiskPercent * Double(max(maxTrades, 1)), maxRiskPercent, 0.1)
    }

    private var dailyRiskProgress: Double {
        min(max(todayRiskUsed / dailyRiskLimit, 0), 1)
    }

    private var dailyPlanItems: [(title: String, isComplete: Bool)] {
        let checks = dailyPlanCheckValues
        return [
            ("Trade only A+ setups", checks.indices.contains(0) ? checks[0] : false),
            ("Respect risk", checks.indices.contains(1) ? checks[1] : false),
            ("Maximum trades", checks.indices.contains(2) ? checks[2] : false),
            ("Follow trading plan", checks.indices.contains(3) ? checks[3] : false)
        ]
    }

    private var dailyPlanCheckValues: [Bool] {
        let values = dashboardDailyPlanChecks.split(separator: "|").map { $0 == "true" }
        return (0..<4).map { index in
            values.indices.contains(index) ? values[index] : false
        }
    }

    private var dailyPlanCompletedCount: Int {
        dailyPlanCheckValues.filter { $0 }.count
    }

    private var dailyPlanProgress: Double {
        Double(dailyPlanCompletedCount) / Double(max(dailyPlanItems.count, 1))
    }

    private var yesterdaysLessonText: String {
        performanceCache.yesterdaysLessonText
    }

    private var strongestSessionInsight: String? {
        let sessions = ["Asia", "London", "New York"].map { name in (name, performance(for: name)) }
        guard let best = sessions.filter({ $0.1.tradeCount > 0 }).max(by: { $0.1.netProfit < $1.1.netProfit }) else {
            return nil
        }
        return "Your strongest session is \(best.0) with \(currency(best.1.netProfit)) net P/L. Respect that window."
    }

    private var averageRRImprovementInsight: String? {
        let sortedTrades = tradeViewModel.trades.sorted { $0.date < $1.date }
        guard sortedTrades.count >= 6 else { return nil }

        let midpoint = sortedTrades.count / 2
        let earlierAverage = averageRR(for: Array(sortedTrades.prefix(midpoint)))
        let recentAverage = averageRR(for: Array(sortedTrades.suffix(sortedTrades.count - midpoint)))
        guard recentAverage > earlierAverage, earlierAverage > 0 else { return nil }

        return "Your average RR improved from \(rrText(earlierAverage)) to \(rrText(recentAverage)). Keep prioritizing quality setups."
    }

    private var followedPlanInsight: String? {
        guard !tradeViewModel.trades.isEmpty else { return nil }
        let followed = tradeViewModel.trades.filter(\.followedPlan).count
        let percentage = Int((Double(followed) / Double(tradeViewModel.trades.count) * 100).rounded())
        return "You followed your plan on \(percentage)% of trades. Discipline is becoming measurable."
    }

    private func streakText(_ streak: DashboardOutcomeStreak) -> String {
        guard streak.count > 0 else { return "No Active Streak" }
        if streak.kind == "Winning" {
            return "🔥 \(streak.count) Trade Win Streak"
        }
        return "\(streak.count) Trade Losing Streak"
    }

    private var psychologyScore: Int {
        guard !tradeViewModel.trades.isEmpty else { return max(0, Int((planCompletion * 100).rounded())) }
        let recent = Array(tradeViewModel.trades.prefix(20))
        let majorMistakes = recent.filter { trade in
            trade.mistakeTags.contains(.revengeTrade) || trade.mistakeTags.contains(.fomo) || trade.mistakeTags.contains(.overtrading) || trade.mistakeTags.contains(.brokeRules)
        }.count
        let calmTrades = recent.filter { ["Calm", "Confident", "Focused", "Neutral"].contains($0.emotion) }.count
        return max(0, min(100, 72 + calmTrades * 2 - majorMistakes * 8))
    }

    private var executionScore: Int {
        let explicitScores = tradeViewModel.trades.map(\.executionScore).filter { $0 > 0 }
        if !explicitScores.isEmpty {
            return Int((Double(explicitScores.reduce(0, +)) / Double(explicitScores.count)).rounded())
        }
        let reviews = aiReviews.filter { review in tradeViewModel.trades.contains { $0.id == review.tradeID } }
        guard !reviews.isEmpty else { return tradeViewModel.trades.isEmpty ? 0 : 72 }
        return Int((Double(reviews.map(\.executionScore).reduce(0, +)) / Double(reviews.count)).rounded())
    }

    private var consistencyScore: Int {
        guard !tradeViewModel.trades.isEmpty else { return max(0, Int((planCompletion * 100).rounded())) }
        let recent = Array(tradeViewModel.trades.prefix(20))
        let journaled = recent.filter { !$0.notes.isEmpty || !$0.executionReview.isEmpty || !$0.lessonsLearned.isEmpty }.count
        let followed = recent.filter(\.followedPlan).count
        return max(0, min(100, Int(((Double(journaled) / Double(recent.count)) * 45 + (Double(followed) / Double(recent.count)) * 45 + 10).rounded())))
    }

    private var riskScore: Int {
        guard !tradeViewModel.trades.isEmpty else { return max(0, Int((planCompletion * 100).rounded())) }
        let recent = Array(tradeViewModel.trades.prefix(20))
        let highRisk = recent.filter { $0.riskPercent > 2.5 || $0.mistakeTags.contains(.riskTooHigh) || $0.mistakeTags.contains(.movedStop) }.count
        let cleanRisk = recent.filter { $0.riskPercent <= 2 && !$0.mistakeTags.contains(.riskTooHigh) }.count
        return max(0, min(100, 70 + cleanRisk * 2 - highRisk * 10))
    }

    private var sessionPerformance: DashboardSessionPerformance {
        performance(for: currentTradingSession.name)
    }

    private var bestSessionPerformance: (name: String, value: String) {
        ["Asia", "London", "New York"]
            .map { name in (name, performance(for: name)) }
            .max { $0.1.netProfit < $1.1.netProfit }
            .map { ($0.0, currency($0.1.netProfit)) } ?? ("None", "--")
    }

    private var bestPair: (name: String, value: String) {
        pairRanking(best: true)
    }

    private var worstPair: (name: String, value: String) {
        pairRanking(best: false)
    }

    private var mostCommonMistake: String {
        let mistakes = tradeViewModel.trades.flatMap { $0.mistakeTags.map(\.rawValue) }
        var counts: [String: Int] = [:]
        for mistake in mistakes {
            counts[mistake, default: 0] += 1
        }
        let sortedCounts = counts.sorted { left, right in
            if left.value == right.value {
                return left.key < right.key
            }
            return left.value > right.value
        }
        return sortedCounts.first?.key ?? "None"
    }

    private var sessionStatusText: String {
        "Open"
    }

    private var nextAchievementText: String {
        if let next = disciplineViewModel.achievements.first(where: { !$0.isUnlocked }) {
            return "Next badge: \(next.title)"
        }
        return "All current badges unlocked."
    }

    private func performance(for sessionName: String) -> DashboardSessionPerformance {
        let trades = tradeViewModel.trades.filter { $0.session.rawValue == sessionName }
        let netProfit = trades.reduce(0) { $0 + $1.profitLoss }
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }
        let winRate = resolved.isEmpty ? 0 : Double(resolved.filter { $0.status == .win }.count) / Double(resolved.count) * 100
        return DashboardSessionPerformance(
            winRate: winRate,
            averageRR: averageRR(for: trades),
            netProfit: netProfit,
            tradeCount: trades.count
        )
    }

    private func pairRanking(best: Bool) -> (name: String, value: String) {
        let grouped = Dictionary(grouping: tradeViewModel.trades, by: \.pair)
        let ranked = grouped
            .map { pair, trades in (pair, trades.reduce(0) { $0 + $1.profitLoss }) }
            .sorted { best ? $0.1 > $1.1 : $0.1 < $1.1 }
        guard let first = ranked.first else { return ("None", "--") }
        return (first.0, currency(first.1))
    }

    private func averageRR(for trades: [Trade]) -> Double {
        let values = trades.map(\.riskReward).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func aiScore(for trade: Trade) -> String {
        aiReviews.first { $0.tradeID == trade.id }.map { "\($0.overallScore)" } ?? "Pending"
    }

    private func normalizedMoney(_ value: Double) -> Double {
        min(1, abs(value) / max(100, abs(tradeViewModel.totalNetProfitLoss)))
    }

    private func rrText(_ value: Double) -> String {
        value > 0 ? String(format: "%.2f R", value) : "--"
    }

    private func tint(for value: Double) -> Color {
        if value > 0 { return JPColors.profit }
        if value < 0 { return JPColors.loss }
        return JPColors.warning
    }

    private func snapshotTile(_ title: String, _ value: String, _ subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(JPColors.mutedText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(JPColors.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func miniHeatDay(_ date: Date) -> some View {
        let item = disciplineViewModel.history.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let score = item?.score ?? 0
        let color: Color = score >= 100 ? JPColors.warning : (score >= 80 ? JPColors.profit : (score > 0 ? JPColors.loss : JPColors.graphite))
        return RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color.opacity(item == nil ? 0.5 : 0.92))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(item == nil ? JPColors.secondaryText : JPColors.background)
            )
            .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide))), discipline \(score)")
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }

    private var dynamicGreetingDetail: String {
        let dateText = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        if tradeViewModel.trades.isEmpty {
            return "\(dateText) • Prepare before the first trade."
        }
        if tradeViewModel.dailyProfitLoss > 0 {
            return "\(dateText) • Protect today's gains."
        }
        if tradeViewModel.dailyProfitLoss < 0 {
            return "\(dateText) • Reset, slow down, follow the plan."
        }
        return "\(dateText) • \(tradeViewModel.trades.count) trades logged."
    }

    private var dailyCoachingMessage: String {
        if let insight = insightViewModel.rotatingInsights.first {
            return "\(insight.title) \(insight.subtitle)"
        }
        if planCompletion < 1 {
            return "Complete your morning plan before looking for a setup. Preparation is today's edge."
        }
        if tradeViewModel.trades.isEmpty {
            return "Your journal is ready. Wait for an A+ setup, then capture the full execution story."
        }
        return "Review your latest trade before adding risk. The next improvement is already in your journal."
    }

    private var dailyMissionTitle: String {
        if planCompletion < 1 { return "Complete your morning plan" }
        if tradeViewModel.trades.isEmpty { return "Log one high-quality trade" }
        return "Review your latest trade"
    }

    private var dailyMissionSubtitle: String {
        if isDailyMissionComplete { return "Nice work. The mission is complete for today." }
        if planCompletion < 1 { return "Finish the checklist and bias before trading." }
        if tradeViewModel.trades.isEmpty { return "Wait for a clean setup and journal it fully." }
        return "Open replay or AI Coach and capture one lesson."
    }

    private var isDailyMissionComplete: Bool {
        dailyMissionCompletedDate == todayKey
    }

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var weeklyAverageScore: Int {
        let values = disciplineViewModel.history.prefix(7).map(\.score)
        guard !values.isEmpty else { return 0 }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private var monthlyXP: Int {
        disciplineViewModel.history
            .filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.xp }
    }

    private var monthlyPerfectDays: Int {
        disciplineViewModel.history
            .filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) && $0.score >= 100 }
            .count
    }

    private func refreshDashboard() {
        disciplineViewModel.refresh()
        insightViewModel.refresh(event: .analyticsUpdated)
        resetDailyPlanIfNeeded()
        loadPersonalization()
        rebuildPerformanceCache()
    }

    private func rebuildPerformanceCache() {
        performanceCache = DashboardPerformanceCache.build(
            trades: tradeViewModel.trades,
            averageRR: averageRR(for:)
        )
    }

    private func resetDailyPlanIfNeeded() {
        guard dashboardDailyPlanDate != todayKey else { return }
        dashboardDailyPlanDate = todayKey
        dashboardDailyPlanChecks = "false|false|false|false"
    }

    private func toggleDailyPlanItem(_ index: Int) {
        resetDailyPlanIfNeeded()
        var checks = dailyPlanCheckValues
        guard checks.indices.contains(index) else { return }
        checks[index].toggle()
        dashboardDailyPlanChecks = checks.map { $0 ? "true" : "false" }.joined(separator: "|")
        JPHaptics.selection()
        if checks.allSatisfy({ $0 }) {
            JPHaptics.notify(.success)
        }
    }

    private func showCelebration(title: String, subtitle: String, symbolName: String, tint: Color) {
        JPHaptics.notify(.success)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            celebration = CelebrationPayload(title: title, subtitle: subtitle, symbolName: symbolName, tint: tint)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            withAnimation(.easeInOut(duration: 0.28)) {
                celebration = nil
            }
        }
    }

    private var biasColor: Color {
        switch marketBias {
        case .bullish:
            return JPColors.profit
        case .bearish:
            return JPColors.loss
        case .neutral:
            return JPColors.warning
        }
    }

    private var lastSevenDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -6 + $0, to: today) }
    }

    private var currentTradingSession: DashboardSession {
        let hour = Calendar.current.component(.hour, from: Date())
        if (0..<8).contains(hour) {
            return DashboardSession(name: "Asia", startHour: 0, icon: "moon.stars.fill", color: JPColors.warning)
        }
        if (8..<14).contains(hour) {
            return DashboardSession(name: "London", startHour: 8, icon: "sunrise.fill", color: JPColors.accent)
        }
        return DashboardSession(name: "New York", startHour: 14, icon: "building.columns.fill", color: JPColors.blue)
    }

    private var nextTradingSession: DashboardSession {
        switch currentTradingSession.name {
        case "Asia":
            return DashboardSession(name: "London", startHour: 8, icon: "sunrise.fill", color: JPColors.accent)
        case "London":
            return DashboardSession(name: "New York", startHour: 14, icon: "building.columns.fill", color: JPColors.blue)
        default:
            return DashboardSession(name: "Asia", startHour: 0, icon: "moon.stars.fill", color: JPColors.warning)
        }
    }

    private func countdownText(toHour targetHour: Int) -> String {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = targetHour
        components.minute = 0
        components.second = 0
        var target = calendar.date(from: components) ?? now
        if target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }

    private func loadPersonalization() {
        if let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])).first {
            let cleanedName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            userName = cleanedName.isEmpty ? "Trader" : cleanedName
        }

        let plans = (try? modelContext.fetch(FetchDescriptor<MorningPlan>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        guard let todayPlan = plans.first(where: { Calendar.current.isDate($0.date, inSameDayAs: Date()) }) else {
            return
        }

        marketBias = todayPlan.bias
        maxRiskPercent = todayPlan.maximumRiskPercent
        maxTrades = max(todayPlan.maximumTrades, 1)
        planCompletion = checklistCompletion(from: todayPlan)
        dailyGoal = firstGoal(from: todayPlan) ?? todayPlan.dailyNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if dailyGoal.isEmpty {
            dailyGoal = "Prepare cleanly before taking the first setup."
        }
    }

    private func checklistCompletion(from plan: MorningPlan) -> Double {
        guard let data = plan.checklistRawValue.data(using: .utf8),
              let checklist = try? JSONDecoder().decode([PlanChecklistItem].self, from: data),
              !checklist.isEmpty else {
            return 0
        }
        return Double(checklist.filter(\.isComplete).count) / Double(checklist.count)
    }

    private func firstGoal(from plan: MorningPlan) -> String? {
        guard let data = plan.goalsRawValue.data(using: .utf8),
              let goals = try? JSONDecoder().decode([PlanGoal].self, from: data) else {
            return nil
        }
        return goals.first(where: { !$0.isComplete })?.title ?? goals.first?.title
    }

    private func riskText(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))%"
        }
        return "\(String(format: "%.1f", value))%"
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private var disciplineCard: some View {
        NavigationLink {
            GoalsStreaksView()
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(JPColors.graphite, lineWidth: 10)

                            Circle()
                                .trim(from: 0, to: Double(disciplineViewModel.score) / 100.0)
                                .stroke(
                                    AngularGradient(
                                        colors: [JPColors.accent, JPColors.blue, JPColors.warning, JPColors.accent],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            Text("\(disciplineViewModel.score)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(JPColors.primaryText)
                        }
                        .frame(width: 78, height: 78)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Discipline System")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)

                            Text(disciplineViewModel.scoreRating)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(JPColors.accent)

                            Text("Streak \(disciplineViewModel.currentDisciplineStreak) • Level \(disciplineViewModel.level) • \(disciplineViewModel.totalXP) XP")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    HStack(spacing: 10) {
                        miniRing(title: "Plan", progress: disciplineViewModel.planRing, color: JPColors.blue)
                        miniRing(title: "Risk", progress: disciplineViewModel.riskRing, color: JPColors.accent)
                        miniRing(title: "Journal", progress: disciplineViewModel.journalRing, color: JPColors.warning)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 14)
        .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.06), value: didAppear)
    }

    private func miniRing(title: String, progress: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(JPColors.graphite, lineWidth: 4)

                Circle()
                    .trim(from: 0, to: min(1, max(0, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)

                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(JPColors.surface.opacity(0.76), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(JPColors.accent)
                    .frame(width: 68, height: 68)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(JPColors.accentSoft)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your trading journey starts here.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Log your first trade and begin tracking your performance with real analytics.")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    onLogFirstTrade()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Log First Trade")
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(JPColors.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: JPColors.accent.opacity(0.22), radius: 18, x: 0, y: 8)
                }
                .buttonStyle(ScalingButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 16)
        .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.08), value: didAppear)
    }

    private var equitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Equity Curve", subtitle: "Cumulative P/L from saved trades")

            GlassCard {
                EquityCurveCard(
                    series: viewModel.equitySeries(for: tradeViewModel.trades),
                    finalEquity: viewModel.finalEquity(for: tradeViewModel.trades)
                )
                .frame(height: 260)
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
        .animation(.spring(response: 0.46, dampingFraction: 0.88).delay(0.12), value: didAppear)
    }

    private var recentTrades: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(title: "Recent Trades", subtitle: "Latest 5 saved entries")

                Spacer()

                NavigationLink {
                    TradeHistoryView()
                        .environmentObject(tradeViewModel)
                } label: {
                    Text("View All")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.accent)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(JPColors.accentSoft, in: Capsule())
                }
                .buttonStyle(ScalingButtonStyle())
            }

            VStack(spacing: 14) {
                ForEach(Array(tradeViewModel.trades.prefix(5).enumerated()), id: \.element.id) { index, trade in
                    NavigationLink {
                        TradeDetailView(trade: trade)
                            .environmentObject(tradeViewModel)
                    } label: {
                        TradeCard(trade: trade)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        PremiumGateLink {
                            ReplayStudioView(trade: trade)
                        } label: {
                            Label("Replay Trade", systemImage: "play.rectangle.fill")
                        }
                    }
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 18)
                    .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.16 + Double(index) * 0.035), value: didAppear)
                }
            }
        }
    }
}

private struct DashboardOutcomeStreak {
    let kind: String
    let count: Int
    let tint: Color
}

private struct DashboardPerformanceCache {
    let todayTrades: [Trade]
    let todayProfitLoss: Double
    let todayAverageR: Double
    let todayRiskUsed: Double
    let weeklyTradeCount: Int
    let currentOutcomeStreak: DashboardOutcomeStreak
    let yesterdaysLessonText: String

    static let empty = DashboardPerformanceCache(
        todayTrades: [],
        todayProfitLoss: 0,
        todayAverageR: 0,
        todayRiskUsed: 0,
        weeklyTradeCount: 0,
        currentOutcomeStreak: DashboardOutcomeStreak(kind: "No Streak", count: 0, tint: JPColors.secondaryText),
        yesterdaysLessonText: "No completed trade lesson yet. Your next journal entry becomes tomorrow's coaching fuel."
    )

    static func build(trades: [Trade], averageRR: ([Trade]) -> Double) -> DashboardPerformanceCache {
        let calendar = Calendar.current
        let todayTrades = trades.filter { calendar.isDateInToday($0.date) }
        let todayProfitLoss = todayTrades.reduce(0) { $0 + $1.profitLoss }
        let todayRiskUsed = todayTrades.reduce(0) { $0 + max($1.riskPercent, 0) }
        let weeklyTradeCount = trades.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }.count
        let streak = outcomeStreak(from: trades)
        let lesson = yesterdayLesson(from: trades, calendar: calendar)

        return DashboardPerformanceCache(
            todayTrades: todayTrades,
            todayProfitLoss: todayProfitLoss,
            todayAverageR: averageRR(todayTrades),
            todayRiskUsed: todayRiskUsed,
            weeklyTradeCount: weeklyTradeCount,
            currentOutcomeStreak: streak,
            yesterdaysLessonText: lesson
        )
    }

    private static func outcomeStreak(from trades: [Trade]) -> DashboardOutcomeStreak {
        let resolved = trades
            .filter { $0.status == .win || $0.status == .loss }
            .sorted { $0.date > $1.date }

        guard let first = resolved.first else {
            return DashboardOutcomeStreak(kind: "No Streak", count: 0, tint: JPColors.secondaryText)
        }

        var count = 0
        for trade in resolved {
            if trade.status == first.status {
                count += 1
            } else {
                break
            }
        }

        return DashboardOutcomeStreak(
            kind: first.status == .win ? "Winning" : "Losing",
            count: count,
            tint: first.status == .win ? JPColors.profit : JPColors.loss
        )
    }

    private static func yesterdayLesson(from trades: [Trade], calendar: Calendar) -> String {
        let previousTrade = trades
            .sorted { $0.date > $1.date }
            .first { !calendar.isDateInToday($0.date) } ?? trades.sorted { $0.date > $1.date }.first

        guard let trade = previousTrade else {
            return "No completed trade lesson yet. Your next journal entry becomes tomorrow's coaching fuel."
        }

        let lesson = [
            trade.lessonsLearned,
            trade.executionReview,
            trade.notes
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }

        return lesson ?? "No written lesson on the last trade. Add one after each close to sharpen tomorrow's focus."
    }
}

private struct EliteMetricData: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
    let progress: Double
}

private struct DashboardSessionPerformance {
    let winRate: Double
    let averageRR: Double
    let netProfit: Double
    let tradeCount: Int
}

private struct EliteScoreRing: View {
    let score: Int
    let label: String
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(JPColors.graphite.opacity(0.9), lineWidth: 12)

            Circle()
                .trim(from: 0, to: animate ? CGFloat(min(max(score, 0), 100)) / 100 : 0)
                .stroke(
                    AngularGradient(colors: [JPColors.accent, JPColors.blue, JPColors.warning, JPColors.accent], center: .center),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: JPColors.accent.opacity(0.26), radius: 18, x: 0, y: 8)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(JPColors.primaryText)
                    .contentTransition(.numericText())

                Text(label)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(JPColors.accent)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .frame(width: 72)
            }
        }
        .frame(width: 112, height: 112)
        .accessibilityLabel("Trader score \(score), \(label)")
        .onAppear {
            withAnimation(.spring(response: 0.82, dampingFraction: 0.84).delay(0.12)) {
                animate = true
            }
        }
        .onChange(of: score) { _, _ in
            animate = false
            withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
                animate = true
            }
        }
    }
}

private struct EliteMetricCard: View {
    let metric: EliteMetricData

    var body: some View {
        GlassCard(padding: 16, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: metric.icon)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(metric.tint)
                        .frame(width: 40, height: 40)
                        .background(metric.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    Spacer()

                    Text(metric.title)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(JPColors.secondaryText)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(metric.value)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(metric.tint)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.56)

                    Text(metric.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.mutedText)
                        .lineLimit(1)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(JPColors.graphite.opacity(0.8))
                            .frame(height: 7)
                        Capsule()
                            .fill(LinearGradient(colors: [metric.tint.opacity(0.82), metric.tint], startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * min(1, max(0.08, metric.progress)), height: 7)
                    }
                }
                .frame(height: 7)
            }
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
        }
        .shadow(color: metric.tint.opacity(0.07), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardMiniEquityChart: View {
    let series: [Double]

    private var points: [EquityPoint] {
        series.enumerated().map { EquityPoint(index: $0.offset, value: $0.element) }
    }

    var body: some View {
        if points.isEmpty {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(JPColors.surface.opacity(0.58))
                .overlay(
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(JPColors.accent)
                )
        } else {
            Chart(points) { point in
                AreaMark(
                    x: .value("Trade", point.index),
                    yStart: .value("Baseline", min(series.min() ?? 0, 0)),
                    yEnd: .value("Equity", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(colors: [chartTint.opacity(0.30), chartTint.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                )

                LineMark(
                    x: .value("Trade", point.index),
                    y: .value("Equity", point.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(chartTint)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { plot in
                plot.background(JPColors.surface.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var chartTint: Color {
        (series.last ?? 0) >= 0 ? JPColors.profit : JPColors.loss
    }
}

private struct CelebrationPayload {
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: Color
}

private struct DashboardSession {
    let name: String
    let startHour: Int
    let icon: String
    let color: Color
}

private struct EquityPoint: Identifiable {
    let id = UUID()
    let index: Int
    let value: Double
}

private struct EquityCurveCard: View {
    let series: [Double]
    let finalEquity: Double

    private var points: [EquityPoint] {
        series.enumerated().map { EquityPoint(index: $0.offset, value: $0.element) }
    }

    private var lowerBound: Double {
        min(series.min() ?? 0, 0)
    }

    var body: some View {
        if points.isEmpty {
            emptyCurve
        } else {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(currency(finalEquity))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(finalEquity >= 0 ? JPColors.profit : JPColors.loss)

                        Text("Net cumulative P/L")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: finalEquity >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(finalEquity >= 0 ? JPColors.profit : JPColors.loss)
                }

                Chart(points) { point in
                    AreaMark(
                        x: .value("Trade", point.index),
                        yStart: .value("Baseline", lowerBound),
                        yEnd: .value("Equity", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                (finalEquity >= 0 ? JPColors.profit : JPColors.loss).opacity(0.34),
                                (finalEquity >= 0 ? JPColors.profit : JPColors.loss).opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Trade", point.index),
                        y: .value("Equity", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(finalEquity >= 0 ? JPColors.profit : JPColors.loss)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(JPColors.surface.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var emptyCurve: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(JPColors.accent)
                .frame(width: 68, height: 68)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("No curve yet.")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)

                Text("Your equity curve will appear after your first saved trade.")
                    .font(.subheadline)
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }
}

private struct TradeCard: View {
    let trade: Trade

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(trade.pair)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        HStack(spacing: 8) {
                            badge(trade.direction.rawValue, color: trade.direction == .buy ? JPColors.profit : JPColors.loss)
                            badge(trade.status.rawValue, color: outcomeColor)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(currency(trade.profitLoss))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(trade.profitLoss >= 0 ? JPColors.profit : JPColors.loss)

                        Text("R:R \(String(format: "1:%.2f", trade.riskReward))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.warning)
                    }
                }

                Divider()
                    .overlay(JPColors.border)

                VStack(spacing: 10) {
                    detailRow("Session", trade.session.rawValue, icon: "clock")
                    detailRow("Strategy", trade.strategy.rawValue, icon: "point.topleft.down.curvedto.point.bottomright.up")
                    detailRow("Date", trade.date.formatted(.dateTime.day().month(.abbreviated).year()), icon: "calendar")
                }
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func detailRow(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
                .frame(width: 18)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)

            Spacer()

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.primaryText)
                .lineLimit(1)
        }
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private var outcomeColor: Color {
        switch trade.status {
        case .win:
            return JPColors.profit
        case .loss:
            return JPColors.loss
        case .breakeven:
            return JPColors.warning
        }
    }
}
