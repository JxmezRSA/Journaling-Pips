import Charts
import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var didAppear = false

    let onLogFirstTrade: () -> Void

    init(onLogFirstTrade: @escaping () -> Void = {}) {
        self.onLogFirstTrade = onLogFirstTrade
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
                        header

                        if tradeViewModel.trades.isEmpty {
                            emptyState
                        } else {
                            performanceHero
                            metricsGrid
                            chartsSection
                            sessionSection
                            strategySection
                            mistakeSection
                            insightsSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 112)
                }
            }
            .navigationTitle("Analytics")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                didAppear = true
            }
        }
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
                    Text("Your analytics will come alive after your first saved trade.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Log a trade to unlock performance score, session analysis, strategy breakdowns, and insights.")
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

    private var performanceHero: some View {
        let score = viewModel.performanceScore(for: tradeViewModel.trades)

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
                ForEach(Array(viewModel.metrics(for: tradeViewModel.trades).enumerated()), id: \.element.id) { index, metric in
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

    private var chartsSection: some View {
        section(title: "Charts", subtitle: "Equity, profit rhythm, and win-rate trend") {
            VStack(spacing: 14) {
                analyticsChart(
                    title: "Equity Curve",
                    subtitle: "Cumulative P/L",
                    points: viewModel.equityCurve(for: tradeViewModel.trades),
                    style: .line
                )
                analyticsChart(
                    title: "Monthly Profit",
                    subtitle: "Net P/L by month",
                    points: viewModel.monthlyProfit(for: tradeViewModel.trades),
                    style: .bar
                )
                analyticsChart(
                    title: "Weekly Profit",
                    subtitle: "Net P/L by week",
                    points: viewModel.weeklyProfit(for: tradeViewModel.trades),
                    style: .bar
                )
                analyticsChart(
                    title: "Win Rate Trend",
                    subtitle: "Monthly resolved win rate",
                    points: viewModel.winRateTrend(for: tradeViewModel.trades),
                    style: .line
                )
            }
        }
    }

    private var sessionSection: some View {
        section(title: "Session Analysis", subtitle: "Asian, London, and New York performance") {
            VStack(spacing: 14) {
                ForEach(viewModel.sessionAnalysis(for: tradeViewModel.trades)) { session in
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
                ForEach(viewModel.strategyAnalysis(for: tradeViewModel.trades)) { strategy in
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
        let mistakes = viewModel.mistakeAnalysis(for: tradeViewModel.trades)

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
                    ForEach(viewModel.insights(for: tradeViewModel.trades), id: \.self) { insight in
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
                                yEnd: .value("Value", point.value)
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
                                y: .value("Value", point.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(chartTint(points))
                        case .bar:
                            BarMark(
                                x: .value("Period", point.label),
                                y: .value("Value", point.value)
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
        value > 0 ? "1:\(String(format: "%.2f", value))" : "--"
    }
}

private enum AnalyticsChartStyle {
    case line
    case bar
}
