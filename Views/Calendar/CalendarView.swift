import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    @State private var selectedDay: SelectedCalendarDay?
    @State private var didAppear = false

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private var monthTrades: [Trade] {
        tradeViewModel.trades.filter { calendar.isDate($0.date, equalTo: monthStart, toGranularity: .month) }
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }

    private var leadingBlankDays: Int {
        max(calendar.component(.weekday, from: monthStart) - 1, 0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JPColors.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        monthlySummary
                        calendarGrid

                        if monthTrades.isEmpty {
                            monthEmptyState
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 112)
                }
            }
            .navigationTitle("Calendar")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(item: $selectedDay) { selectedDay in
            DailySummaryView(date: selectedDay.date, trades: trades(on: selectedDay.date))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.42)) {
                didAppear = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Journal Calendar")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(JPColors.primaryText)

            Text(monthStart.formatted(.dateTime.month(.wide).year()))
                .font(.headline.weight(.semibold))
                .foregroundStyle(JPColors.accent)
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 10)
    }

    private var monthlySummary: some View {
        let summary = CalendarAnalytics.summary(for: monthTrades, calendar: calendar)

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Monthly Summary", subtitle: "Performance from saved trades")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                CalendarSummaryTile(
                    title: "Total P/L",
                    value: currency(summary.totalProfitLoss),
                    subtitle: "Net result",
                    icon: summary.totalProfitLoss >= 0 ? "arrow.up.right" : "arrow.down.right",
                    tint: summary.totalProfitLoss >= 0 ? JPColors.profit : JPColors.loss
                )

                CalendarSummaryTile(
                    title: "Trades",
                    value: "\(summary.totalTrades)",
                    subtitle: "This month",
                    icon: "number",
                    tint: JPColors.accent
                )

                CalendarSummaryTile(
                    title: "Win Rate",
                    value: percentage(summary.winRate),
                    subtitle: "Wins vs losses",
                    icon: "target",
                    tint: JPColors.warning
                )

                CalendarSummaryTile(
                    title: "Best / Worst",
                    value: "\(currency(summary.bestDay)) / \(currency(summary.worstDay))",
                    subtitle: "Daily range",
                    icon: "calendar.badge.clock",
                    tint: JPColors.blue
                )
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 14)
        .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.06), value: didAppear)
    }

    private var calendarGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Current Month", subtitle: "Tap any day to review its journal history")

            GlassCard {
                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(JPColors.mutedText)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                        spacing: 10
                    ) {
                        ForEach(0..<leadingBlankDays, id: \.self) { index in
                            Color.clear
                                .frame(height: 52)
                                .id("blank-\(index)")
                        }

                        ForEach(daysInMonth, id: \.self) { day in
                            CalendarDayButton(
                                day: day,
                                trades: trades(on: day),
                                isToday: calendar.isDateInToday(day),
                                calendar: calendar
                            ) {
                                selectedDay = SelectedCalendarDay(date: day)
                            }
                        }
                    }
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 16)
        .animation(.spring(response: 0.44, dampingFraction: 0.88).delay(0.12), value: didAppear)
    }

    private var monthEmptyState: some View {
        GlassCard {
            EmptyJournalState(
                icon: "calendar.badge.exclamationmark",
                title: "No trades this month.",
                message: "Your calendar will light up as you save trades and build a daily performance history.",
                buttonTitle: nil,
                action: nil
            )
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 16)
        .animation(.spring(response: 0.44, dampingFraction: 0.88).delay(0.18), value: didAppear)
    }

    private func trades(on day: Date) -> [Trade] {
        tradeViewModel.trades
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date > $1.date }
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func percentage(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}

private struct SelectedCalendarDay: Identifiable {
    let id = UUID()
    let date: Date
}

private struct CalendarAnalytics {
    let totalProfitLoss: Double
    let totalTrades: Int
    let winRate: Double
    let bestDay: Double
    let worstDay: Double
    let averageRiskReward: Double

    static func summary(for trades: [Trade], calendar: Calendar) -> CalendarAnalytics {
        let totalProfitLoss = trades.reduce(0) { $0 + $1.profitLoss }
        let resolvedTrades = trades.filter { $0.status == .win || $0.status == .loss }
        let winRate = resolvedTrades.isEmpty
            ? 0
            : (Double(resolvedTrades.filter { $0.status == .win }.count) / Double(resolvedTrades.count)) * 100
        let groupedByDay = Dictionary(grouping: trades) { calendar.startOfDay(for: $0.date) }
        let dayTotals = groupedByDay.values.map { dayTrades in
            dayTrades.reduce(0) { $0 + $1.profitLoss }
        }
        let riskRewardTrades = trades.filter { $0.riskReward > 0 }
        let averageRiskReward = riskRewardTrades.isEmpty
            ? 0
            : riskRewardTrades.reduce(0) { $0 + $1.riskReward } / Double(riskRewardTrades.count)

        return CalendarAnalytics(
            totalProfitLoss: totalProfitLoss,
            totalTrades: trades.count,
            winRate: winRate,
            bestDay: dayTotals.max() ?? 0,
            worstDay: dayTotals.min() ?? 0,
            averageRiskReward: averageRiskReward
        )
    }
}

private struct CalendarSummaryTile: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)

                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(JPColors.mutedText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        }
        .shadow(color: tint.opacity(0.08), radius: 14, x: 0, y: 8)
    }
}

private struct CalendarDayButton: View {
    let day: Date
    let trades: [Trade]
    let isToday: Bool
    let calendar: Calendar
    let action: () -> Void

    private var netProfitLoss: Double {
        trades.reduce(0) { $0 + $1.profitLoss }
    }

    private var statusColor: Color {
        guard !trades.isEmpty else {
            return JPColors.mutedText
        }

        if netProfitLoss > 0 {
            return JPColors.profit
        }

        if netProfitLoss < 0 {
            return JPColors.loss
        }

        return JPColors.warning
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(trades.isEmpty ? JPColors.secondaryText : JPColors.primaryText)

                Circle()
                    .fill(statusColor)
                    .frame(width: trades.isEmpty ? 4 : 7, height: trades.isEmpty ? 4 : 7)
                    .opacity(trades.isEmpty ? 0.42 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(statusColor.opacity(trades.isEmpty ? 0.05 : 0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isToday ? JPColors.accent : statusColor.opacity(trades.isEmpty ? 0.08 : 0.28), lineWidth: isToday ? 1.6 : 1)
            )
            .shadow(color: statusColor.opacity(trades.isEmpty ? 0 : 0.13), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(ScalingButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let dayName = day.formatted(.dateTime.day().month(.wide))

        if trades.isEmpty {
            return "\(dayName), no trades"
        }

        return "\(dayName), \(trades.count) trades, net \(Int(netProfitLoss))"
    }
}

private struct DailySummaryView: View {
    @EnvironmentObject private var tradeViewModel: TradeViewModel

    let date: Date
    let trades: [Trade]

    private let calendar = Calendar.current

    private var summary: CalendarAnalytics {
        CalendarAnalytics.summary(for: trades, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JPColors.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        dayHeader
                        dayMetrics

                        if trades.isEmpty {
                            GlassCard {
                                EmptyJournalState(
                                    icon: "tray",
                                    title: "No trades on this day.",
                                    message: "Select a day with saved trades to review its journal history.",
                                    buttonTitle: nil,
                                    action: nil
                                )
                            }
                        } else {
                            tradeList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Daily Summary")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(JPColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Daily trading performance")
                .font(.headline.weight(.semibold))
                .foregroundStyle(JPColors.accent)
        }
    }

    private var dayMetrics: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            CalendarSummaryTile(
                title: "Day P/L",
                value: currency(summary.totalProfitLoss),
                subtitle: "Net result",
                icon: summary.totalProfitLoss >= 0 ? "arrow.up.right" : "arrow.down.right",
                tint: summary.totalProfitLoss >= 0 ? JPColors.profit : JPColors.loss
            )

            CalendarSummaryTile(
                title: "Trades",
                value: "\(summary.totalTrades)",
                subtitle: "Logged entries",
                icon: "number",
                tint: JPColors.accent
            )

            CalendarSummaryTile(
                title: "Win Rate",
                value: "\(Int(summary.winRate.rounded()))%",
                subtitle: "Wins vs losses",
                icon: "target",
                tint: JPColors.warning
            )

            CalendarSummaryTile(
                title: "Avg R:R",
                value: summary.averageRiskReward > 0 ? String(format: "1:%.2f", summary.averageRiskReward) : "1:0.00",
                subtitle: "Risk profile",
                icon: "scale.3d",
                tint: JPColors.blue
            )
        }
    }

    private var tradeList: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Trades", subtitle: "Entries saved for this day")

            VStack(spacing: 14) {
                ForEach(trades) { trade in
                    NavigationLink {
                        TradeDetailView(trade: trade)
                            .environmentObject(tradeViewModel)
                    } label: {
                        CalendarTradeCard(trade: trade)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }
}

private struct CalendarTradeCard: View {
    let trade: Trade

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

    private var directionColor: Color {
        trade.direction == .buy ? JPColors.profit : JPColors.loss
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(trade.pair)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        HStack(spacing: 8) {
                            badge(trade.direction.rawValue, color: directionColor)
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
                    detailRow("Time", trade.date.formatted(.dateTime.hour().minute()), icon: "calendar")
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
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
                .frame(width: 18)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)

            Spacer()

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }
}

private struct EmptyJournalState: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(JPColors.accent)
                .frame(width: 68, height: 68)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let buttonTitle, let action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(JPColors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(ScalingButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
