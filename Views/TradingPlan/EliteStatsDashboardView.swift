import Charts
import SwiftUI

struct EliteStatsDashboardView: View {
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    @StateObject private var viewModel = EliteStatsViewModel()
    @State private var didAppear = false
    @State private var equityScope = EliteEquityScope.allTime

    let onLogFirstTrade: () -> Void

    init(onLogFirstTrade: @escaping () -> Void = {}) {
        self.onLogFirstTrade = onLogFirstTrade
    }

    private var snapshot: EliteStatsSnapshot {
        viewModel.snapshot(for: tradeViewModel.trades)
    }

    private var scopedEquity: [EliteStatsPoint] {
        let points = snapshot.equity
        guard let last = points.last?.date else { return points }
        let calendar = Calendar.current
        switch equityScope {
        case .daily:
            return points.filter { calendar.isDate($0.date, inSameDayAs: last) }
        case .weekly:
            return points.filter { calendar.isDate($0.date, equalTo: last, toGranularity: .weekOfYear) }
        case .monthly:
            return points.filter { calendar.isDate($0.date, equalTo: last, toGranularity: .month) }
        case .allTime:
            return points
        }
    }

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 26) {
                    header

                    if tradeViewModel.trades.isEmpty {
                        emptyState
                    } else {
                        PerformanceScorecardView(snapshot: snapshot)
                        coreMetrics
                        expectancyAndProfitFactor
                        drawdownAnalysis
                        equityCurve
                        monteCarloSection
                        RiskSimulatorView(summary: snapshot.summary, viewModel: viewModel)
                        rankingSection("Session Matrix", "Asia, London, New York, and overlap", snapshot.sessionRankings)
                        rankingSection("Pair Rankings", "Instrument edge and avoid list", snapshot.pairRankings)
                        rankingSection("Strategy Rankings", "Setup performance laboratory", snapshot.strategyRankings)
                        rankingSection("Weekday Analysis", "Best and worst days", snapshot.weekdayRankings)
                        mistakeLeaderboard
                        psychologySection
                        localInsights
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }
        }
        .navigationTitle("Elite Stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            withAnimation(JPDesign.smoothSpring) {
                didAppear = true
            }
        }
    }

    private var header: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(JPColors.accent)
                    .frame(width: 72, height: 72)
                    .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Elite Statistics Engine")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Institutional-grade analytics from your saved trades.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .premiumEntrance(active: didAppear)
    }

    private var coreMetrics: some View {
        section("Core Metrics", "Professional performance laboratory") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(snapshot.metrics) { metric in
                    EliteStatsMetricCard(metric: metric)
                }
            }
        }
    }

    private var expectancyAndProfitFactor: some View {
        section("Expectancy & Profit Factor", "The heartbeat of trading quality") {
            HStack(spacing: 14) {
                EliteHeroStatCard(
                    title: "Expectancy in R",
                    value: "\(snapshot.summary.expectancyR >= 0 ? "+" : "")\(String(format: "%.2f", snapshot.summary.expectancyR))R",
                    subtitle: "On average, each trade is expected to return \(snapshot.summary.expectancyR >= 0 ? "+" : "")\(String(format: "%.2f", snapshot.summary.expectancyR))R.",
                    icon: "function",
                    tint: snapshot.summary.expectancyR >= 0 ? JPColors.profit : JPColors.loss
                )

                EliteHeroStatCard(
                    title: "Profit Factor",
                    value: snapshot.summary.profitFactor.isInfinite ? "∞" : String(format: "%.2f", snapshot.summary.profitFactor),
                    subtitle: profitFactorGrade(snapshot.summary.profitFactor),
                    icon: "divide.circle.fill",
                    tint: JPColors.blue
                )
            }
        }
    }

    private var drawdownAnalysis: some View {
        section("Drawdown Analysis", "Maximum drawdown, recovery, and current pressure") {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        compactMetric("Max DD", currency(snapshot.summary.maximumDrawdown), JPColors.loss)
                        compactMetric("Avg DD", currency(snapshot.summary.averageDrawdown), JPColors.loss)
                        compactMetric("Current", currency(snapshot.summary.currentDrawdown), JPColors.warning)
                    }
                    HStack(spacing: 12) {
                        compactMetric("Longest", "\(snapshot.summary.longestDrawdownPeriod) trades", JPColors.blue)
                        compactMetric("Recovery", "\(snapshot.summary.recoveryTime) trades", JPColors.accent)
                    }

                    Chart(snapshot.equity) { point in
                        BarMark(x: .value("Date", point.date), y: .value("Drawdown", point.drawdown))
                            .foregroundStyle(point.drawdown < 0 ? JPColors.loss.opacity(0.62) : JPColors.accent.opacity(0.4))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 132)
                }
            }
        }
    }

    private var equityCurve: some View {
        section("Equity Curve", "Starting balance, high watermark, and drawdown zones") {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Equity Scope", selection: $equityScope) {
                        ForEach(EliteEquityScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        compactMetric("Starting", "$0", JPColors.secondaryText)
                        compactMetric("Current", currency(snapshot.summary.netPL), snapshot.summary.netPL >= 0 ? JPColors.profit : JPColors.loss)
                        compactMetric("High", currency(snapshot.equity.map(\.value).max() ?? 0), JPColors.warning)
                    }

                    Chart(scopedEquity) { point in
                        if point.drawdown < 0 {
                            AreaMark(
                                x: .value("Date", point.date),
                                yStart: .value("Baseline", point.value - point.drawdown),
                                yEnd: .value("Equity", point.value)
                            )
                            .foregroundStyle(JPColors.loss.opacity(0.16))
                        }
                        LineMark(x: .value("Date", point.date), y: .value("Equity", point.value))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .foregroundStyle(snapshot.summary.netPL >= 0 ? JPColors.profit : JPColors.loss)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 220)
                }
            }
        }
    }

    private var monteCarloSection: some View {
        let result = snapshot.monteCarlo
        return section("Monte Carlo Simulation", "Local projected equity paths, no backend") {
            LazyVGrid(columns: columns, spacing: 14) {
                EliteStatsMetricCard(metric: metric("Expected Return", currency(result.expectedReturn), "Simulated average", "chart.line.uptrend.xyaxis", result.expectedReturn >= 0 ? JPColors.profit : JPColors.loss))
                EliteStatsMetricCard(metric: metric("Best Case", currency(result.bestCase), "Upper path", "arrow.up.right", JPColors.profit))
                EliteStatsMetricCard(metric: metric("Worst Case", currency(result.worstCase), "Lower path", "arrow.down.right", JPColors.loss))
                EliteStatsMetricCard(metric: metric("Median Outcome", currency(result.medianOutcome), "Middle path", "equal.circle", JPColors.warning))
                EliteStatsMetricCard(metric: metric("Profit Probability", percent(result.probabilityOfProfit), "Paths above zero", "target", JPColors.accent))
                EliteStatsMetricCard(metric: metric("10% DD Probability", percent(result.probabilityOfTenPercentDrawdown), "Drawdown pressure", "exclamationmark.triangle.fill", JPColors.loss))
                EliteStatsMetricCard(metric: metric("Ruin Probability", percent(result.probabilityOfRuin), "30% account hit", "shield.slash.fill", JPColors.loss))
            }
        }
    }

    private func rankingSection(_ title: String, _ subtitle: String, _ rows: [EliteRankingRow]) -> some View {
        section(title, subtitle) {
            VStack(spacing: 12) {
                ForEach(rows) { row in
                    EliteRankingCard(row: row)
                }
            }
        }
    }

    private var mistakeLeaderboard: some View {
        section("Mistake Leaderboard", "Estimated behavioral cost") {
            VStack(spacing: 12) {
                ForEach(snapshot.mistakes) { mistake in
                    GlassCard(padding: 16, cornerRadius: 24) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.headline.weight(.black))
                                .foregroundStyle(JPColors.warning)
                                .frame(width: 42, height: 42)
                                .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mistake.mistake)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(JPColors.primaryText)
                                Text("\(mistake.count) times • Estimated Cost: \(currency(mistake.estimatedCost))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(JPColors.secondaryText)
                                Text("Average loss \(currency(mistake.averageLoss)) • \(mistake.trend)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(JPColors.mutedText)
                            }
                            Spacer()
                        }
                    }
                }
                if let top = snapshot.mistakes.first {
                    ChallengeBanner(text: "Fixing your top mistake could improve profitability by approximately \(improvementPercent(top))%.")
                }
            }
        }
    }

    private var psychologySection: some View {
        section("Psychology Performance", "Confidence, fear, patience, revenge, and greed") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(snapshot.psychologyMetrics) { metric in
                    EliteStatsMetricCard(metric: metric)
                }
            }
        }
    }

    private var localInsights: some View {
        section("AI Statistical Insights", "Local calculations only") {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(snapshot.insights, id: \.self) { insight in
                        Label(insight, systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(JPColors.accent)
                    .frame(width: 68, height: 68)
                    .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text("Elite statistics unlock after your first trade.")
                    .font(.title2.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                Button(action: onLogFirstTrade) {
                    Label("Log First Trade", systemImage: "plus.circle.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(ScalingButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    }

    private func section<Content: View>(_ title: String, _ subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle)
            content()
        }
        .premiumEntrance(active: didAppear, delay: 0.05)
    }

    private func compactMetric(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(JPColors.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func metric(_ title: String, _ value: String, _ subtitle: String, _ icon: String, _ tint: Color) -> EliteStatsMetric {
        EliteStatsMetric(title: title, value: value, subtitle: subtitle, icon: icon, tint: tint)
    }

    private func profitFactorGrade(_ value: Double) -> String {
        if value.isInfinite || value >= 3 { return "Elite" }
        if value >= 2.2 { return "Professional" }
        if value >= 1.5 { return "Good" }
        if value >= 1.1 { return "Acceptable" }
        return "Weak"
    }

    private func improvementPercent(_ top: EliteMistakeRow) -> Int {
        let total = abs(snapshot.summary.grossLoss)
        guard total > 0 else { return 0 }
        return Int((abs(top.estimatedCost) / total * 100).rounded())
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}

enum EliteEquityScope: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case allTime = "All Time"

    var id: String { rawValue }
}

struct EliteStatsMetricCard: View {
    let metric: EliteStatsMetric

    var body: some View {
        GlassCard(padding: 15, cornerRadius: 23) {
            VStack(alignment: .leading, spacing: 13) {
                Image(systemName: metric.icon)
                    .font(.caption.weight(.black))
                    .foregroundStyle(metric.tint)
                    .frame(width: 36, height: 36)
                    .background(metric.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Text(metric.value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(metric.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(metric.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                Text(metric.subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(JPColors.mutedText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        }
    }
}

struct EliteHeroStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        GlassCard(padding: 16, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(JPColors.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        }
    }
}

struct EliteRankingCard: View {
    let row: EliteRankingRow

    var body: some View {
        GlassCard(padding: 16, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.name)
                            .font(.headline.weight(.black))
                            .foregroundStyle(JPColors.primaryText)
                        Text("\(row.trades) trades • Grade \(row.grade)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                    Spacer()
                    if let badge = row.badge {
                        Text(badge)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(badge == "Worst" || badge == "Avoid" ? JPColors.loss : JPColors.warning)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background((badge == "Worst" || badge == "Avoid" ? JPColors.loss : JPColors.warning).opacity(0.14), in: Capsule())
                    }
                }
                HStack(spacing: 8) {
                    stat("Win", "\(Int(row.winRate.rounded()))%")
                    stat("Profit", currency(row.profit))
                    stat("RR", row.averageRR > 0 ? String(format: "%.2f", row.averageRR) : "--")
                    stat("Exp", String(format: "%.2fR", row.expectancy))
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(JPColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(JPColors.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(JPColors.surface.opacity(0.62), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }
}

struct ChallengeBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "lightbulb.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(JPColors.warning)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(JPColors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JPColors.warning.opacity(0.24), lineWidth: 1))
    }
}
