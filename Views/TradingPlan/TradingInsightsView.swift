import SwiftUI

private struct TradingInsightStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let icon: String
}

private struct TradingInsightsSnapshot {
    let topInsight: String
    let strengths: [TradingInsightStat]
    let weaknesses: [TradingInsightStat]
    let consistency: [TradingInsightStat]
    let recommendations: [String]
}

private struct TradingInsightsEngine {
    func snapshot(for trades: [Trade]) -> TradingInsightsSnapshot {
        let sorted = trades.sorted { $0.date > $1.date }

        return TradingInsightsSnapshot(
            topInsight: topInsight(for: sorted),
            strengths: strengths(for: sorted),
            weaknesses: weaknesses(for: sorted),
            consistency: consistency(for: sorted),
            recommendations: recommendations(for: sorted)
        )
    }

    private func topInsight(for trades: [Trade]) -> String {
        guard !trades.isEmpty else {
            return "Log more trades to unlock your first trading insight."
        }

        if let session = bestSession(for: trades), session.winRate >= 60 {
            return "You perform best during the \(session.name) Session."
        }

        let afterThree = trades.filter { Calendar.current.component(.hour, from: $0.date) >= 15 }
        if afterThree.count >= 3 {
            let lossRate = rate(afterThree.filter { $0.status == .loss }.count, afterThree.count)
            if lossRate >= 60 {
                return "You lose \(Int(lossRate.rounded()))% of trades taken after 15:00."
            }
        }

        if monthlyRRIsImproving(trades) {
            return "Your average RR is increasing every month."
        }

        if let pair = bestPair(for: trades) {
            return "\(pair.name) is currently your strongest market."
        }

        return "Your best edge will become clearer as your trade history grows."
    }

    private func strengths(for trades: [Trade]) -> [TradingInsightStat] {
        [
            TradingInsightStat(title: "Best Pair", value: bestPair(for: trades)?.name ?? "--", detail: bestPair(for: trades).map { "\(percent($0.winRate)) win rate - \(currency($0.netProfit))" } ?? "Needs more trades", icon: "chart.line.uptrend.xyaxis"),
            TradingInsightStat(title: "Best Session", value: bestSession(for: trades)?.name ?? "--", detail: bestSession(for: trades).map { "\(percent($0.winRate)) win rate - \(rr($0.averageRR)) avg" } ?? "Needs more trades", icon: "clock.badge.checkmark"),
            TradingInsightStat(title: "Best Weekday", value: bestWeekday(for: trades)?.name ?? "--", detail: bestWeekday(for: trades).map { "\(currency($0.netProfit)) - \(percent($0.winRate)) win rate" } ?? "Needs more trades", icon: "calendar.badge.checkmark"),
            TradingInsightStat(title: "Best RR", value: rr(trades.map(\.riskReward).max() ?? 0), detail: "Highest planned reward multiple", icon: "scale.3d")
        ]
    }

    private func weaknesses(for trades: [Trade]) -> [TradingInsightStat] {
        [
            TradingInsightStat(title: "Worst Pair", value: worstPair(for: trades)?.name ?? "--", detail: worstPair(for: trades).map { "\(currency($0.netProfit)) - \(percent($0.winRate)) win rate" } ?? "Needs more trades", icon: "chart.line.downtrend.xyaxis"),
            TradingInsightStat(title: "Worst Session", value: worstSession(for: trades)?.name ?? "--", detail: worstSession(for: trades).map { "\(currency($0.netProfit)) - \(rr($0.averageRR)) avg" } ?? "Needs more trades", icon: "clock.badge.exclamationmark"),
            TradingInsightStat(title: "Losing Mistake", value: mostCommonLosingMistake(for: trades) ?? "None", detail: "Most common tag on losing trades", icon: "exclamationmark.triangle.fill"),
            TradingInsightStat(title: "Psychology", value: "\(Int(averagePsychologyScore(for: trades).rounded()))", detail: "Estimated average psychology score", icon: "brain.head.profile")
        ]
    }

    private func consistency(for trades: [Trade]) -> [TradingInsightStat] {
        let ruleAdherence = rate(trades.filter(\.followedPlan).count, trades.count)
        let averageRisk = trades.isEmpty ? 0 : trades.reduce(0) { $0 + $1.riskPercent } / Double(trades.count)
        let averageExecution = trades.isEmpty ? 0 : trades.reduce(0) { $0 + executionScore(for: $1) } / Double(trades.count)

        return [
            TradingInsightStat(title: "Rule Adherence", value: percent(ruleAdherence), detail: "Trades marked as following plan", icon: "checkmark.seal.fill"),
            TradingInsightStat(title: "Average Risk", value: "\(number(averageRisk))%", detail: "Average risk per trade", icon: "shield.lefthalf.filled"),
            TradingInsightStat(title: "Average Hold", value: averageHoldTime(for: trades), detail: "Open to close duration", icon: "timer"),
            TradingInsightStat(title: "Execution Score", value: "\(Int(averageExecution.rounded()))", detail: "Estimated execution quality", icon: "scope")
        ]
    }

    private func recommendations(for trades: [Trade]) -> [String] {
        guard !trades.isEmpty else {
            return [
                "Log at least 10 trades to unlock stronger recommendations.",
                "Capture screenshots for before, during, and after each trade.",
                "Tag mistakes honestly so the coach can identify behavior patterns."
            ]
        }

        var items: [String] = []

        if let session = worstSession(for: trades), session.trades >= 2 {
            items.append("Reduce size or skip the \(session.name) session until consistency improves.")
        }

        if let mistake = mostCommonLosingMistake(for: trades), mistake != "None" {
            items.append("Create a pre-entry rule that prevents \(mistake.lowercased()).")
        }

        if let pair = bestPair(for: trades), pair.averageRR < 2 {
            items.append("Increase RR quality on \(pair.name) before adding more trade frequency.")
        }

        let recentLosses = trades.prefix(2).filter { $0.status == .loss }.count
        if recentLosses == 2 {
            items.append("Pause after two consecutive losses and review the plan before the next entry.")
        }

        if rate(trades.filter(\.followedPlan).count, trades.count) < 80 {
            items.append("Do not enter unless the setup matches the plan checklist.")
        }

        return Array((items.isEmpty ? ["Keep trading your strongest session and protect current discipline."] : items).prefix(3))
    }

    private struct GroupStats {
        let name: String
        let trades: Int
        let winRate: Double
        let netProfit: Double
        let averageRR: Double
    }

    private func bestPair(for trades: [Trade]) -> GroupStats? {
        groupedStats(trades, by: { $0.pair.isEmpty ? "Unknown" : $0.pair.uppercased() }).max { score($0) < score($1) }
    }

    private func worstPair(for trades: [Trade]) -> GroupStats? {
        groupedStats(trades, by: { $0.pair.isEmpty ? "Unknown" : $0.pair.uppercased() }).min { score($0) < score($1) }
    }

    private func bestSession(for trades: [Trade]) -> GroupStats? {
        groupedStats(trades, by: { $0.session.rawValue }).max { score($0) < score($1) }
    }

    private func worstSession(for trades: [Trade]) -> GroupStats? {
        groupedStats(trades, by: { $0.session.rawValue }).min { score($0) < score($1) }
    }

    private func bestWeekday(for trades: [Trade]) -> GroupStats? {
        groupedStats(trades, by: { weekdayName($0.date) }).max { score($0) < score($1) }
    }

    private func groupedStats(_ trades: [Trade], by key: (Trade) -> String) -> [GroupStats] {
        Dictionary(grouping: trades, by: key).map { name, group in
            let net = group.reduce(0) { $0 + $1.profitLoss }
            let avgRR = group.isEmpty ? 0 : group.reduce(0) { $0 + $1.riskReward } / Double(group.count)
            return GroupStats(name: name, trades: group.count, winRate: rate(group.filter { $0.status == .win }.count, group.count), netProfit: net, averageRR: avgRR)
        }
        .filter { $0.trades > 0 }
    }

    private func score(_ stats: GroupStats) -> Double {
        stats.netProfit + (stats.winRate * 8) + (stats.averageRR * 120) + Double(stats.trades * 5)
    }

    private func mostCommonLosingMistake(for trades: [Trade]) -> String? {
        let tags = trades.filter { $0.status == .loss }.flatMap(\.mistakeTags).filter { $0 != .goodDiscipline }
        guard !tags.isEmpty else { return nil }
        let counts = Dictionary(grouping: tags, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key.rawValue
    }

    private func averagePsychologyScore(for trades: [Trade]) -> Double {
        guard !trades.isEmpty else { return 0 }
        return trades.reduce(0) { $0 + psychologyScore(for: $1) } / Double(trades.count)
    }

    private func psychologyScore(for trade: Trade) -> Double {
        var score = 72.0
        if trade.followedPlan { score += 12 } else { score -= 18 }
        if ["Fear", "Greedy", "Revenge", "Frustrated", "Overconfident", "Nervous"].contains(trade.emotion) { score -= 14 }
        if trade.confidence >= 7, trade.confidence <= 9 { score += 8 }
        if trade.mistakeTags.contains(.fomo) || trade.mistakeTags.contains(.revengeTrade) || trade.mistakeTags.contains(.overtrading) { score -= 16 }
        return min(max(score, 0), 100)
    }

    private func executionScore(for trade: Trade) -> Double {
        var score = trade.executionScore > 0 ? Double(trade.executionScore * 20) : 62
        if trade.followedPlan { score += 10 }
        if trade.mistakeTags.contains(.enteredEarly) || trade.mistakeTags.contains(.enteredLate) { score -= 14 }
        if trade.mistakeTags.contains(.goodDiscipline) { score += 10 }
        return min(max(score, 0), 100)
    }

    private func averageHoldTime(for trades: [Trade]) -> String {
        let durations = trades.compactMap { trade -> TimeInterval? in
            guard let open = trade.tradeOpenTime, let close = trade.tradeCloseTime, close > open else { return nil }
            return close.timeIntervalSince(open)
        }

        guard !durations.isEmpty else { return "--" }
        let average = durations.reduce(0, +) / Double(durations.count)
        let hours = Int(average) / 3600
        let minutes = (Int(average) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func monthlyRRIsImproving(_ trades: [Trade]) -> Bool {
        let grouped = Dictionary(grouping: trades) { trade in
            Calendar.current.dateInterval(of: .month, for: trade.date)?.start ?? trade.date
        }
        let points = grouped
            .map { date, group in (date, group.reduce(0) { $0 + $1.riskReward } / Double(max(group.count, 1))) }
            .sorted { $0.0 < $1.0 }

        guard points.count >= 3 else { return false }
        let latest = points.suffix(3).map(\.1)
        return latest[0] < latest[1] && latest[1] < latest[2]
    }

    private func weekdayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func rate(_ count: Int, _ total: Int) -> Double {
        total == 0 ? 0 : Double(count) / Double(total) * 100
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.0f", abs(value)))"
    }

    private func rr(_ value: Double) -> String {
        "\(number(value)) R"
    }

    private func number(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.2f", value)
    }
}

struct TradingInsightsView: View {
    @State private var didAppear = false
    @State private var cachedSnapshot: TradingInsightsSnapshot?

    let trades: [Trade]
    private let engine = TradingInsightsEngine()

    private var snapshot: TradingInsightsSnapshot {
        cachedSnapshot ?? engine.snapshot(for: trades)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeader(title: "Trading Insights", subtitle: "Actionable coaching from saved trade behavior")

            if trades.isEmpty {
                emptyState
            } else {
                topInsight
                insightGroup(title: "Strengths", subtitle: "Your strongest trading conditions", stats: snapshot.strengths, tint: JPColors.profit)
                insightGroup(title: "Weaknesses", subtitle: "The highest-value areas to improve", stats: snapshot.weaknesses, tint: JPColors.warning)
                insightGroup(title: "Consistency", subtitle: "Process quality and execution rhythm", stats: snapshot.consistency, tint: JPColors.blue)
                recommendations
            }
        }
        .onAppear {
            refreshSnapshot()
            withAnimation(JPDesign.smoothSpring) {
                didAppear = true
            }
        }
        .onChange(of: trades.count) { _, _ in
            refreshSnapshot()
        }
    }

    private func refreshSnapshot() {
        cachedSnapshot = engine.snapshot(for: trades)
    }

    private var topInsight: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [JPColors.accent.opacity(0.26), JPColors.purple.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(JPColors.warning)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Insight")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.secondaryText)
                        .textCase(.uppercase)

                    Text(snapshot.topInsight)
                        .font(.title3.weight(.black))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Generated locally from your saved journal data.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }
            }
        }
        .premiumEntrance(active: didAppear)
    }

    private func insightGroup(title: String, subtitle: String, stats: [TradingInsightStat], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle)

            VStack(spacing: 10) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    insightRow(stat: stat, tint: tint, isLast: index == stats.count - 1)
                }
            }
            .padding(16)
            .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(JPColors.border, lineWidth: 1)
            )
        }
        .premiumEntrance(active: didAppear, delay: 0.04)
    }

    private func insightRow(stat: TradingInsightStat, tint: Color, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Image(systemName: stat.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.14), in: Circle())

                if !isLast {
                    Rectangle()
                        .fill(tint.opacity(0.20))
                        .frame(width: 2, height: 28)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stat.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Spacer(minLength: 8)

                    Text(stat.value)
                        .font(.headline.weight(.black))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Text(stat.detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 3)
        }
        .padding(.bottom, isLast ? 0 : 8)
    }

    private var recommendations: some View {
        let subtitle = snapshot.recommendations.count >= 3 ? "Three actions to improve your next trading week" : "Actions to improve your next trading week"

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recommendations", subtitle: subtitle)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(snapshot.recommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.black))
                            .foregroundStyle(JPColors.background)
                            .frame(width: 28, height: 28)
                            .background(JPColors.accent, in: Circle())

                        Text(recommendation)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [JPColors.accent.opacity(0.14), JPColors.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(JPColors.accent.opacity(0.18), lineWidth: 1)
            )
        }
        .premiumEntrance(active: didAppear, delay: 0.08)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "lightbulb.max.fill")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(JPColors.warning)

                Text("Insights unlock after your first saved trade.")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)

                Text("Journaling Pips will analyze pairs, sessions, mistakes, risk, and consistency once trade data exists.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .premiumEntrance(active: didAppear)
    }
}
