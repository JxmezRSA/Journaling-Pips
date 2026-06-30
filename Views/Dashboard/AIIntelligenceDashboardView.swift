import SwiftData
import SwiftUI

struct AIIntelligenceDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trade.date, order: .reverse) private var trades: [Trade]
    @Query(sort: \AITradeReview.updatedAt, order: .reverse) private var reviews: [AITradeReview]
    @Query(sort: \DisciplineDay.date, order: .reverse) private var disciplineDays: [DisciplineDay]
    @Query(sort: \MorningPlan.date, order: .reverse) private var plans: [MorningPlan]
    @Query(sort: \UserProfile.createdAt) private var userProfiles: [UserProfile]
    @StateObject private var viewModel = AIIntelligenceViewModel()
    @State private var didAppear = false

    private var snapshot: AIIntelligenceSnapshot {
        viewModel.snapshot(
            trades: trades,
            reviews: reviews,
            disciplineDays: disciplineDays,
            plans: plans,
            userProfiles: userProfiles
        )
    }

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()
            backgroundGlow

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 26) {
                    header

                    if trades.isEmpty {
                        emptyState
                    } else {
                        todaysBrief
                        weeklyCoaching
                        performanceTrends
                        behaviourAnalysis
                        patternRecognition
                        riskCoaching
                        psychologySection
                        disciplineSection
                        personalityProfile
                        aiMemory
                        recommendations
                        localSuggestions
                        recentLessons
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }
        }
        .navigationTitle("AI Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            withAnimation(JPDesign.smoothSpring) {
                didAppear = true
            }
        }
    }

    private var backgroundGlow: some View {
        VStack {
            HStack {
                Spacer()
                Circle()
                    .fill(JPColors.purple.opacity(0.16))
                    .frame(width: 250, height: 250)
                    .blur(radius: 80)
                    .offset(x: 80, y: -120)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(JPColors.warning)
                        .frame(width: 72, height: 72)
                        .background(
                            LinearGradient(colors: [JPColors.accent.opacity(0.22), JPColors.purple.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                        )
                        .shadow(color: JPColors.accent.opacity(0.22), radius: 22, x: 0, y: 12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Intelligence")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)

                        Text("Personal trading intelligence from your journal history.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                AIIntelConfidenceHero(confidence: snapshot.confidence)
            }
        }
        .premiumEntrance(active: didAppear)
    }

    private var todaysBrief: some View {
        let brief = snapshot.dailyBrief
        return section("Today's Brief", "Your local morning coaching report") {
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text(brief.greeting)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)

                    LazyVGrid(columns: columns, spacing: 12) {
                        intelligenceTile("Discipline", "\(brief.disciplineScore)", "Current score", "checkmark.seal.fill", JPColors.accent)
                        intelligenceTile("Trader Score", "\(brief.traderScore)", "Overall read", "sparkles", JPColors.warning)
                        intelligenceTile("Streak", "\(brief.streak) Days", "Current run", "flame.fill", JPColors.profit)
                        intelligenceTile("London Opens", brief.londonCountdown, "Next key session", "sunrise.fill", JPColors.blue)
                    }

                    Divider().overlay(JPColors.border)

                    VStack(alignment: .leading, spacing: 12) {
                        briefLine("Strongest setup", "\(brief.strongestSetup) • \(percent(brief.strongestSetupWinRate)) win rate", JPColors.profit)
                        briefLine("Today's focus", brief.todayFocus, JPColors.accent)
                        briefLine("Recent improvement", brief.recentImprovement, JPColors.blue)
                        briefLine("Biggest risk today", brief.biggestRisk, JPColors.warning)
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.04)
    }

    private var weeklyCoaching: some View {
        section("Weekly Coaching", "Your improvement plan") {
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    coachingBlock("Top Strengths", items: snapshot.improvementPlan.strengths, tint: JPColors.profit, icon: "checkmark.circle.fill")
                    coachingBlock("Top Weaknesses", items: snapshot.improvementPlan.weaknesses, tint: JPColors.warning, icon: "exclamationmark.triangle.fill")

                    Divider().overlay(JPColors.border)

                    LazyVGrid(columns: columns, spacing: 12) {
                        intelligenceTile("Most Improved", snapshot.improvementPlan.mostImprovedMetric, "Recent trend", "arrow.up.right.circle.fill", JPColors.profit)
                        intelligenceTile("Needs Attention", snapshot.improvementPlan.needsAttention, "Coach memory", "scope", JPColors.warning)
                        intelligenceTile("Next Milestone", snapshot.improvementPlan.nextMilestone, "Near-term target", "flag.checkered", JPColors.blue)
                        intelligenceTile("Tomorrow Focus", snapshot.improvementPlan.tomorrowFocus, "Next session", "sun.max.fill", JPColors.accent)
                    }

                    ChallengeCard(title: "Weekly Challenge", text: snapshot.improvementPlan.weeklyChallenge, tint: JPColors.accent)
                    ChallengeCard(title: "Monthly Challenge", text: snapshot.improvementPlan.monthlyChallenge, tint: JPColors.purple)
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.08)
    }

    private var performanceTrends: some View {
        section("Performance Trends", "Scores generated from saved trade data") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(snapshot.performanceTrends) { metric in
                    AIIntelMetricCard(metric: metric)
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.12)
    }

    private var behaviourAnalysis: some View {
        section("Behaviour Analysis", "Recurring actions and psychology signals") {
            GlassCard {
                VStack(spacing: 12) {
                    ForEach(snapshot.behaviours) { behaviour in
                        AIBehaviourRow(signal: behaviour)
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.16)
    }

    private var patternRecognition: some View {
        section("Pattern Recognition", "Best and worst trading conditions") {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(snapshot.patterns) { pattern in
                    AIPatternTile(pattern: pattern)
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.20)
    }

    private var riskCoaching: some View {
        section("Risk Coaching", snapshot.confidence.label) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    AIIntelProgressRing(value: snapshot.confidence.score, title: "Confidence", tint: confidenceTint)
                    Text(snapshot.confidence.explanation)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    ChallengeCard(title: "Risk Instruction", text: snapshot.improvementPlan.needsAttention == "None" ? "Keep risk consistent and avoid forcing late trades." : "Reduce exposure when \(snapshot.improvementPlan.needsAttention.lowercased()) appears.", tint: JPColors.warning)
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.24)
    }

    private var psychologySection: some View {
        section("Psychology", "Emotional control and decision quality") {
            GlassCard {
                LazyVGrid(columns: columns, spacing: 12) {
                    intelligenceTile("Confidence", snapshot.profile.confidence, "Self-rating trend", "bolt.heart.fill", JPColors.accent)
                    intelligenceTile("Emotional Control", snapshot.profile.emotionalControl, "Mistake analysis", "brain.head.profile", JPColors.purple)
                    intelligenceTile("Decision Speed", snapshot.profile.decisionSpeed, "Entry timing", "speedometer", JPColors.blue)
                    intelligenceTile("Risk Personality", snapshot.profile.risk, "Sizing behavior", "shield.lefthalf.filled", JPColors.warning)
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.28)
    }

    private var disciplineSection: some View {
        section("Discipline", "Preparation, journal, screenshots, lessons") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(snapshot.disciplineMetrics) { metric in
                    AIIntelMetricCard(metric: metric)
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.32)
    }

    private var personalityProfile: some View {
        section("Trading Personality", "A profile that evolves with your journal") {
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text(snapshot.profile.personality)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.accent)

                    LazyVGrid(columns: columns, spacing: 12) {
                        intelligenceTile("Journal Quality", "\(snapshot.profile.journalQuality)%", "Documentation", "book.pages.fill", JPColors.purple)
                        intelligenceTile("Planning", "\(snapshot.profile.planning)%", "Morning prep", "checklist.checked", JPColors.blue)
                        intelligenceTile("Execution", "\(snapshot.profile.execution)%", "Trade quality", "scope", JPColors.warning)
                        intelligenceTile("Risk", snapshot.profile.risk, "Sizing profile", "shield.checkered", JPColors.accent)
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.36)
    }

    private var aiMemory: some View {
        section("AI Memory", "Recurring mistakes the coach is tracking") {
            if snapshot.memoryWarnings.isEmpty {
                GlassCard {
                    inlineEmpty(icon: "checkmark.shield.fill", title: "No recurring warnings yet.", message: "Keep logging detailed trades and the coach will remember repeated mistakes.")
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(snapshot.memoryWarnings) { insight in
                        AIInsightObservationCard(insight: insight)
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.40)
    }

    private var recommendations: some View {
        section("Personalized Recommendations", "Ranked by confidence") {
            VStack(spacing: 12) {
                ForEach(snapshot.insights) { insight in
                    AIInsightObservationCard(insight: insight)
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.44)
    }

    private var localSuggestions: some View {
        section("Smart Notifications", "Local suggestions only, no push notifications yet") {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(snapshot.notificationSuggestions, id: \.self) { suggestion in
                        Label(suggestion, systemImage: "bell.badge.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.48)
    }

    private var recentLessons: some View {
        section("Recent Lessons", "Lessons learned from your latest reviews") {
            GlassCard {
                if snapshot.recentLessons.isEmpty {
                    inlineEmpty(icon: "lightbulb", title: "No lessons captured yet.", message: "Add lessons learned inside Trade Detail to strengthen the AI coach.")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(snapshot.recentLessons, id: \.self) { lesson in
                            Label(lesson, systemImage: "lightbulb.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JPColors.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.52)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(JPColors.warning)
                    .frame(width: 68, height: 68)
                    .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text("Your AI mentor is waiting for data.")
                    .font(.title2.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                Text("Log trades, complete your plan, add screenshots, and save reviews to unlock personalized intelligence.")
                    .font(.subheadline)
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .premiumEntrance(active: didAppear, delay: 0.04)
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private var confidenceTint: Color {
        switch snapshot.confidence.score {
        case 80...: return JPColors.profit
        case 58..<80: return JPColors.warning
        default: return JPColors.loss
        }
    }

    private func section<Content: View>(_ title: String, _ subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle)
            content()
        }
    }

    private func intelligenceTile(_ title: String, _ value: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(JPColors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.58)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
            Text(subtitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(JPColors.mutedText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(14)
        .background(JPColors.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JPColors.border, lineWidth: 1))
    }

    private func briefLine(_ title: String, _ value: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func coachingBlock(_ title: String, items: [String], tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JPColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlineEmpty(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(JPColors.accent)
                .frame(width: 52, height: 52)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
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

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}

private struct AIIntelConfidenceHero: View {
    let confidence: AIConfidenceSummary

    var body: some View {
        HStack(spacing: 18) {
            AIIntelProgressRing(value: confidence.score, title: "AI", tint: tint)
            VStack(alignment: .leading, spacing: 8) {
                Text(confidence.label)
                    .font(.title2.weight(.black))
                    .foregroundStyle(tint)
                Text(confidence.explanation)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var tint: Color {
        confidence.score >= 80 ? JPColors.profit : (confidence.score >= 58 ? JPColors.warning : JPColors.loss)
    }
}

private struct AIIntelProgressRing: View {
    let value: Int
    let title: String
    let tint: Color
    @State private var animated = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(JPColors.graphite, lineWidth: 10)
            Circle()
                .trim(from: 0, to: animated ? CGFloat(value) / 100 : 0)
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.24), radius: 12, x: 0, y: 6)
            VStack(spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                Text(title)
                    .font(.caption2.weight(.black))
            }
            .foregroundStyle(JPColors.primaryText)
        }
        .frame(width: 104, height: 104)
        .onAppear {
            withAnimation(.spring(response: 0.82, dampingFraction: 0.84).delay(0.08)) {
                animated = true
            }
        }
    }
}

private struct AIIntelMetricCard: View {
    let metric: AIIntelligenceMetric

    var body: some View {
        GlassCard(padding: 15, cornerRadius: 23) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: metric.icon)
                        .font(.caption.weight(.black))
                        .foregroundStyle(metric.tint)
                        .frame(width: 36, height: 36)
                        .background(metric.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    Spacer()
                }
                Text(metric.value)
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(metric.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)
                Text(metric.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                Text(metric.subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(JPColors.mutedText)
                    .lineLimit(1)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(JPColors.graphite).frame(height: 7)
                        Capsule()
                            .fill(metric.tint)
                            .frame(width: proxy.size.width * min(1, max(0.05, metric.progress)), height: 7)
                    }
                }
                .frame(height: 7)
            }
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        }
    }
}

private struct AIBehaviourRow: View {
    let signal: AIBehaviourSignal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: signal.count == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(signal.count == 0 ? JPColors.profit : signal.tint)
                .frame(width: 38, height: 38)
                .background((signal.count == 0 ? JPColors.profit : signal.tint).opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(signal.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                Text(signal.trend)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
            }
            Spacer()
            Text("\(signal.count)")
                .font(.headline.weight(.black))
                .foregroundStyle(signal.count == 0 ? JPColors.profit : signal.tint)
        }
        .padding(12)
        .background(JPColors.surface.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AIPatternTile: View {
    let pattern: AIIntelligencePattern

    var body: some View {
        GlassCard(padding: 14, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: pattern.icon)
                    .font(.caption.weight(.black))
                    .foregroundStyle(pattern.tint)
                    .frame(width: 34, height: 34)
                    .background(pattern.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(pattern.value)
                    .font(.headline.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.58)
                Text(pattern.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                Text(pattern.subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(JPColors.mutedText)
            }
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        }
    }
}

private struct AIInsightObservationCard: View {
    let insight: AIIntelligenceInsight

    var body: some View {
        GlassCard(padding: 16, cornerRadius: 24) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: insight.icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(insight.tint)
                    .frame(width: 44, height: 44)
                    .background(insight.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(insight.category)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(insight.tint)
                            .textCase(.uppercase)
                        Spacer()
                        Text("\(insight.confidence)%")
                            .font(.caption.weight(.black))
                            .foregroundStyle(JPColors.primaryText)
                    }
                    Text(insight.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(insight.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct ChallengeCard: View {
    let title: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.headline.weight(.black))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(tint)
                    .textCase(.uppercase)
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JPColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(tint.opacity(0.22), lineWidth: 1))
    }
}
