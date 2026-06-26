import Charts
import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject private var tradeViewModel: TradeViewModel
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
                        greeting
                            .opacity(didAppear ? 1 : 0)
                            .offset(y: didAppear ? 0 : 10)

                        if tradeViewModel.trades.isEmpty {
                            emptyState
                            equitySection
                        } else {
                            metricsGrid
                            equitySection
                            recentTrades
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 112)
                }
            }
            .navigationTitle("Dashboard")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                didAppear = true
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Good Evening James")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(JPColors.warning)
                }

                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
            }

            Text("\"\(viewModel.quote)\"")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(JPColors.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(JPColors.border, lineWidth: 1)
                )
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
            SectionHeader(title: "Recent Trades", subtitle: "Latest 5 saved entries")

            VStack(spacing: 14) {
                ForEach(Array(tradeViewModel.trades.prefix(5).enumerated()), id: \.element.id) { index, trade in
                    NavigationLink {
                        TradeDetailView(trade: trade)
                            .environmentObject(tradeViewModel)
                    } label: {
                        TradeCard(trade: trade)
                    }
                    .buttonStyle(.plain)
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 18)
                    .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.16 + Double(index) * 0.035), value: didAppear)
                }
            }
        }
    }
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
