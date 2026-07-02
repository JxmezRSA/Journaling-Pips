import SwiftUI

private struct PerformanceCenterScore: Identifiable {
    let id = UUID()
    let title: String
    let score: Int
    let detail: String
    let icon: String
    let tint: Color
}

private struct PerformanceCenterDelta: Identifiable {
    let id = UUID()
    let title: String
    let current: String
    let previous: String
    let delta: Double
}

private struct PerformanceCenterFocus {
    let title: String
    let detail: String
    let progress: Double
}

private struct PerformanceCenterSnapshot {
    let overallScore: Int
    let grade: String
    let gradeDetail: String
    let scores: [PerformanceCenterScore]
    let monthlyDeltas: [PerformanceCenterDelta]
    let weakestArea: PerformanceCenterScore
    let focusGoal: PerformanceCenterFocus
}

private struct PerformanceCenterEngine {
    func snapshot(for trades: [Trade]) -> PerformanceCenterSnapshot {
        let scores = categoryScores(for: trades)
        let weighted = weightedScore(scores)
        let weakest = scores.min { $0.score < $1.score } ?? fallbackScore

        return PerformanceCenterSnapshot(
            overallScore: weighted,
            grade: grade(for: weighted),
            gradeDetail: gradeDetail(for: weighted),
            scores: scores,
            monthlyDeltas: monthlyDeltas(for: trades),
            weakestArea: weakest,
            focusGoal: focusGoal(for: weakest, trades: trades)
        )
    }

    private var fallbackScore: PerformanceCenterScore {
        PerformanceCenterScore(title: "Consistency", score: 0, detail: "Log trades to measure consistency.", icon: "repeat.circle.fill", tint: JPColors.blue)
    }

    private func categoryScores(for trades: [Trade]) -> [PerformanceCenterScore] {
        [
            PerformanceCenterScore(title: "Execution", score: executionScore(for: trades), detail: "Timing, confirmation, and management.", icon: "scope", tint: JPColors.accent),
            PerformanceCenterScore(title: "Risk Management", score: riskScore(for: trades), detail: "Risk %, stop behavior, and R:R.", icon: "shield.lefthalf.filled", tint: JPColors.profit),
            PerformanceCenterScore(title: "Psychology", score: psychologyScore(for: trades), detail: "Emotion, confidence, and impulse control.", icon: "brain.head.profile", tint: JPColors.purple),
            PerformanceCenterScore(title: "Discipline", score: disciplineScore(for: trades), detail: "Plan adherence and rule quality.", icon: "checkmark.seal.fill", tint: JPColors.warning),
            PerformanceCenterScore(title: "Consistency", score: consistencyScore(for: trades), detail: "Repeatable process over time.", icon: "repeat.circle.fill", tint: JPColors.blue)
        ]
    }

    private func weightedScore(_ scores: [PerformanceCenterScore]) -> Int {
        let weights = ["Execution": 0.22, "Risk Management": 0.24, "Psychology": 0.18, "Discipline": 0.22, "Consistency": 0.14]
        let total = scores.reduce(0.0) { partial, score in
            partial + Double(score.score) * (weights[score.title] ?? 0.2)
        }
        return clamp(Int(total.rounded()))
    }

    private func monthlyDeltas(for trades: [Trade]) -> [PerformanceCenterDelta] {
        let calendar = Calendar.current
        let now = Date()
        let current = trades.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        let previousDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let previous = trades.filter { calendar.isDate($0.date, equalTo: previousDate, toGranularity: .month) }

        let currentWinRate = winRate(for: current)
        let previousWinRate = winRate(for: previous)
        let currentRR = averageRR(for: current)
        let previousRR = averageRR(for: previous)
        let currentProfit = netProfit(for: current)
        let previousProfit = netProfit(for: previous)
        let currentDiscipline = disciplineScore(for: current)
        let previousDiscipline = disciplineScore(for: previous)
        let currentPsychology = psychologyScore(for: current)
        let previousPsychology = psychologyScore(for: previous)

        return [
            PerformanceCenterDelta(title: "Win Rate", current: percent(currentWinRate), previous: percent(previousWinRate), delta: currentWinRate - previousWinRate),
            PerformanceCenterDelta(title: "Average RR", current: rr(currentRR), previous: rr(previousRR), delta: currentRR - previousRR),
            PerformanceCenterDelta(title: "Profit", current: currency(currentProfit), previous: currency(previousProfit), delta: currentProfit - previousProfit),
            PerformanceCenterDelta(title: "Discipline", current: "\(currentDiscipline)", previous: "\(previousDiscipline)", delta: Double(currentDiscipline - previousDiscipline)),
            PerformanceCenterDelta(title: "Psychology", current: "\(currentPsychology)", previous: "\(previousPsychology)", delta: Double(currentPsychology - previousPsychology))
        ]
    }

    private func focusGoal(for weakest: PerformanceCenterScore, trades: [Trade]) -> PerformanceCenterFocus {
        switch weakest.title {
        case "Execution":
            return PerformanceCenterFocus(title: "Improve Execution Quality", detail: "Wait for confirmation and avoid early or late entries.", progress: Double(weakest.score) / 100)
        case "Risk Management":
            return PerformanceCenterFocus(title: "Increase Average RR", detail: "Prioritize setups above 2R and avoid oversized risk.", progress: min(1, averageRR(for: trades) / 2))
        case "Psychology":
            return PerformanceCenterFocus(title: "Stabilize Trading Psychology", detail: "Reduce emotional tags and document confidence before entry.", progress: Double(weakest.score) / 100)
        case "Discipline":
            return PerformanceCenterFocus(title: "Follow The Plan", detail: "Target 90% plan adherence across the next trade sample.", progress: planAdherence(for: trades) / 90)
        default:
            return PerformanceCenterFocus(title: "Build Consistency", detail: "Log, review, and score every trade this month.", progress: Double(weakest.score) / 100)
        }
    }

    private func executionScore(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let total = trades.reduce(0.0) { partial, trade in
            var score = trade.executionScore > 0 ? Double(trade.executionScore * 20) : 64
            if trade.followedPlan { score += 10 }
            if trade.mistakeTags.contains(.enteredEarly) || trade.mistakeTags.contains(.enteredLate) { score -= 16 }
            if trade.mistakeTags.contains(.goodDiscipline) { score += 8 }
            return partial + min(max(score, 0), 100)
        }
        return clamp(Int((total / Double(trades.count)).rounded()))
    }

    private func riskScore(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let total = trades.reduce(0.0) { partial, trade in
            var score = 68.0
            if trade.riskPercent > 0, trade.riskPercent <= 1 { score += 18 }
            else if trade.riskPercent > 0, trade.riskPercent <= 2 { score += 12 }
            else if trade.riskPercent > 3 { score -= 22 }
            if trade.riskReward >= 2 { score += 14 }
            else if trade.riskReward < 1, trade.riskReward > 0 { score -= 10 }
            if trade.mistakeTags.contains(.riskTooHigh) || trade.mistakeTags.contains(.movedStop) { score -= 18 }
            return partial + min(max(score, 0), 100)
        }
        return clamp(Int((total / Double(trades.count)).rounded()))
    }

    private func psychologyScore(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let total = trades.reduce(0.0) { partial, trade in
            var score = 72.0
            if trade.followedPlan { score += 10 } else { score -= 18 }
            if ["Fear", "Greedy", "Revenge", "Frustrated", "Overconfident", "Nervous"].contains(trade.emotion) { score -= 14 }
            if trade.confidence >= 7, trade.confidence <= 9 { score += 8 }
            if trade.mistakeTags.contains(.fomo) || trade.mistakeTags.contains(.revengeTrade) { score -= 16 }
            return partial + min(max(score, 0), 100)
        }
        return clamp(Int((total / Double(trades.count)).rounded()))
    }

    private func disciplineScore(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let plan = planAdherence(for: trades)
        let mistakePenalty = min(28, Double(trades.flatMap(\.mistakeTags).filter { $0 != .goodDiscipline }.count) / Double(trades.count) * 10)
        return clamp(Int((plan - mistakePenalty).rounded()))
    }

    private func consistencyScore(for trades: [Trade]) -> Int {
        guard !trades.isEmpty else { return 0 }
        let avgRisk = trades.reduce(0) { $0 + $1.riskPercent } / Double(trades.count)
        let riskVariance = trades.reduce(0) { $0 + abs($1.riskPercent - avgRisk) } / Double(trades.count)
        let journalRate = Double(trades.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.lessonsLearned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count) / Double(trades.count) * 100
        let riskConsistency = max(0, 100 - riskVariance * 22)
        return clamp(Int(((journalRate * 0.45) + (riskConsistency * 0.55)).rounded()))
    }

    private func winRate(for trades: [Trade]) -> Double {
        let resolved = trades.filter { $0.status == .win || $0.status == .loss }
        guard !resolved.isEmpty else { return 0 }
        return Double(resolved.filter { $0.status == .win }.count) / Double(resolved.count) * 100
    }

    private func averageRR(for trades: [Trade]) -> Double {
        guard !trades.isEmpty else { return 0 }
        return trades.reduce(0) { $0 + $1.riskReward } / Double(trades.count)
    }

    private func netProfit(for trades: [Trade]) -> Double {
        trades.reduce(0) { $0 + $1.profitLoss }
    }

    private func planAdherence(for trades: [Trade]) -> Double {
        guard !trades.isEmpty else { return 0 }
        return Double(trades.filter(\.followedPlan).count) / Double(trades.count) * 100
    }

    private func grade(for score: Int) -> String {
        switch score {
        case 95...100: return "A+"
        case 90...94: return "A"
        case 85...89: return "B+"
        case 80...84: return "B"
        default: return "C"
        }
    }

    private func gradeDetail(for score: Int) -> String {
        switch score {
        case 95...100: return "Elite process. Protect the system."
        case 90...94: return "Strong trader profile with minor refinements."
        case 85...89: return "Improving consistency with a clear edge forming."
        case 80...84: return "Solid foundation. Tighten the weakest category."
        default: return "Focus on process before increasing risk."
        }
    }

    private func clamp(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.0f", abs(value)))"
    }

    private func rr(_ value: Double) -> String {
        if value <= 0 { return "--" }
        return "\(String(format: "%.2f", value))R"
    }
}

struct PerformanceCenterView: View {
    @State private var didAppear = false
    @State private var cachedSnapshot: PerformanceCenterSnapshot?

    let trades: [Trade]
    private let engine = PerformanceCenterEngine()

    private var snapshot: PerformanceCenterSnapshot {
        cachedSnapshot ?? engine.snapshot(for: trades)
    }

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if trades.isEmpty {
                        emptyState
                    } else {
                        tradingGrade
                        performanceScores
                        monthlyImprovement
                        weakestArea
                        focusGoal
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }
        }
        .navigationTitle("Performance Center")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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

    private var header: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(JPColors.warning)
                    .frame(width: 74, height: 74)
                    .background(
                        LinearGradient(colors: [JPColors.accent.opacity(0.22), JPColors.purple.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Center")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Measure trader improvement over time with local performance scoring.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .premiumEntrance(active: didAppear)
    }

    private var tradingGrade: some View {
        GlassCard {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(JPColors.graphite, lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: didAppear ? CGFloat(snapshot.overallScore) / 100 : 0)
                        .stroke(
                            LinearGradient(colors: [JPColors.accent, gradeTint], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text(snapshot.grade)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(gradeTint)
                        Text("\(snapshot.overallScore)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                }
                .frame(width: 116, height: 116)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trading Grade")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.secondaryText)
                        .textCase(.uppercase)

                    Text(snapshot.gradeDetail)
                        .font(.title3.weight(.black))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Weighted from execution, risk, psychology, discipline, and consistency.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.04)
    }

    private var performanceScores: some View {
        section(title: "Performance Scores", subtitle: "Five improvement pillars scored out of 100") {
            GlassCard {
                VStack(spacing: 14) {
                    ForEach(snapshot.scores) { score in
                        scoreRow(score)
                    }
                }
            }
        }
    }

    private var monthlyImprovement: some View {
        section(title: "Monthly Improvement", subtitle: "Current month compared to previous month") {
            VStack(spacing: 10) {
                ForEach(snapshot.monthlyDeltas) { delta in
                    deltaRow(delta)
                }
            }
        }
    }

    private var weakestArea: some View {
        section(title: "Weakest Area", subtitle: "Lowest scoring category") {
            GlassCard {
                HStack(spacing: 14) {
                    Image(systemName: snapshot.weakestArea.icon)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(JPColors.warning)
                        .frame(width: 56, height: 56)
                        .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot.weakestArea.title)
                            .font(.title3.weight(.black))
                            .foregroundStyle(JPColors.primaryText)

                        Text(snapshot.weakestArea.detail)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Text("\(snapshot.weakestArea.score)")
                        .font(.title.weight(.black))
                        .foregroundStyle(JPColors.warning)
                }
            }
        }
    }

    private var focusGoal: some View {
        section(title: "Focus Goal", subtitle: "One improvement target for the next sample") {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(snapshot.focusGoal.title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(JPColors.primaryText)

                    Text(snapshot.focusGoal.detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    progressBar(value: min(max(snapshot.focusGoal.progress, 0), 1), tint: JPColors.accent)

                    Text("\(Int((min(max(snapshot.focusGoal.progress, 0), 1) * 100).rounded()))% progress")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.accent)
                }
            }
        }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(JPColors.accent)

                Text("Your Performance Center is waiting for trade data.")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)

                Text("Save trades to unlock grades, monthly improvement, weakest area detection, and focus goals.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .premiumEntrance(active: didAppear, delay: 0.04)
    }

    private func section<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle)
            content()
        }
        .premiumEntrance(active: didAppear, delay: 0.08)
    }

    private func scoreRow(_ score: PerformanceCenterScore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: score.icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(score.tint)
                    .frame(width: 38, height: 38)
                    .background(score.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(score.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                    Text(score.detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }

                Spacer()

                Text("\(score.score)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(score.tint)
                    .monospacedDigit()
            }

            progressBar(value: Double(score.score) / 100, tint: score.tint)
        }
        .padding(14)
        .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func deltaRow(_ delta: PerformanceCenterDelta) -> some View {
        GlassCard(padding: 16, cornerRadius: 22) {
            HStack(spacing: 12) {
                Text(deltaArrow(delta.delta))
                    .font(.headline.weight(.black))
                    .foregroundStyle(deltaTint(delta.delta))
                    .frame(width: 38, height: 38)
                    .background(deltaTint(delta.delta).opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(delta.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Previous \(delta.previous)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }

                Spacer()

                Text(delta.current)
                    .font(.headline.weight(.black))
                    .foregroundStyle(deltaTint(delta.delta))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
    }

    private func progressBar(value: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(JPColors.graphite.opacity(0.85))

                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.72), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: didAppear ? proxy.size.width * CGFloat(value) : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.86), value: didAppear)
            }
        }
        .frame(height: 8)
    }

    private var gradeTint: Color {
        switch snapshot.overallScore {
        case 90...100: return JPColors.profit
        case 80...89: return JPColors.accent
        case 70...79: return JPColors.warning
        default: return JPColors.loss
        }
    }

    private func deltaArrow(_ delta: Double) -> String {
        if delta > 0.01 { return "↑" }
        if delta < -0.01 { return "↓" }
        return "="
    }

    private func deltaTint(_ delta: Double) -> Color {
        if delta > 0.01 { return JPColors.profit }
        if delta < -0.01 { return JPColors.loss }
        return JPColors.secondaryText
    }
}
