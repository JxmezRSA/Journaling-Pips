import SwiftData
import SwiftUI
import UIKit

struct AITradeCoachView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = AITradeCoachViewModel()
    @StateObject private var insightViewModel = InsightViewModel()
    @State private var didAppear = false
    @State private var activeScreenshot: AICoachScreenshotItem?
    @Query(sort: \Trade.date, order: .reverse) private var allTrades: [Trade]

    let trade: Trade

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    intelligenceDashboardEntry
                    aiHistoryEntry
                    analysisControls
                    professionalReviewSection
                    categoryScoresSection
                    scoreBreakdownSection
                    tradeSummarySection
                    chartAnalysisSection
                    coachEmptyState
                    strengthsSection
                    improvementsSection
                    mistakesSection
                    nextTradeFocusCard
                    coachingTimelineSection
                    weeklyMonthlySummarySection
                    coachMessageSection
                    generatedInsightsSection
                    warningsSection
                    screenshotReviewSection
                    nextTradeChecklistSection
                    overallGradeSection
                    saveReportButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }
        }
        .navigationTitle("AI Trade Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(item: $activeScreenshot) { item in
            AICoachScreenshotViewer(item: item)
        }
        .alert("Review Saved", isPresented: $viewModel.showSavedConfirmation) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("Your AI Trade Coach review was saved locally.")
        }
        .onAppear {
            viewModel.configure(context: modelContext, trade: trade)
            insightViewModel.configure(context: modelContext)

            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                didAppear = true
            }
        }
    }

    private var intelligenceDashboardEntry: some View {
        NavigationLink {
            AIIntelligenceDashboardView()
        } label: {
            GlassCard {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(JPColors.warning)
                        .frame(width: 54, height: 54)
                        .background(
                            LinearGradient(colors: [JPColors.accent.opacity(0.18), JPColors.purple.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 19, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Open Personal Intelligence")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text("Analyze your full trading history, behavior, risk, discipline, and recurring patterns.")
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
        .accessibilityLabel("Open Personal Intelligence dashboard")
    }

    private var aiHistoryEntry: some View {
        NavigationLink {
            AIReviewHistoryView()
        } label: {
            GlassCard {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 23, weight: .black))
                        .foregroundStyle(JPColors.blue)
                        .frame(width: 54, height: 54)
                        .background(JPColors.blue.opacity(0.16), in: RoundedRectangle(cornerRadius: 19, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("AI Review History")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text("Search saved reviews, track score progress, and compare coaching patterns over time.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.black))
                        .foregroundStyle(JPColors.blue)
                }
            }
        }
        .buttonStyle(.plain)
        .premiumEntrance(active: didAppear, delay: 0.04)
        .accessibilityLabel("Open AI review history")
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [JPColors.accent.opacity(0.28), JPColors.purple.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 74, height: 74)
                            .shadow(color: JPColors.accent.opacity(0.28), radius: 22, x: 0, y: 12)

                        Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(JPColors.warning)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Trade Coach")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)
                            .minimumScaleFactor(0.72)

                        Text("Review your execution like a professional trader.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 20) {
                    AICoachScoreRing(
                        score: viewModel.overallScore,
                        tint: scoreColor(viewModel.overallScore),
                        animate: didAppear
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trade Score")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                            .textCase(.uppercase)

                        Text("\(viewModel.overallScore) / 100")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor(viewModel.overallScore))

                        Text(viewModel.confidenceLevel == "Local Preview" ? "Local coaching preview from journal data, risk behavior, execution, and screenshots." : "Generated from saved trade context and coaching preferences.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .shadow(color: scoreColor(viewModel.overallScore).opacity(0.16), radius: 24, x: 0, y: 16)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
    }

    private var analysisControls: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: viewModel.hasSavedReview ? "checkmark.seal.fill" : "network")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(viewModel.hasSavedReview ? JPColors.profit : JPColors.accent)
                        .frame(width: 48, height: 48)
                        .background((viewModel.hasSavedReview ? JPColors.profit : JPColors.accent).opacity(0.14), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.hasGeneratedReview || viewModel.hasSavedReview ? "Review Ready" : "AI-Ready Review")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text(viewModel.analysisNotice)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                if viewModel.isAnalyzing {
                    PremiumLoadingBlock(
                        title: "Analyzing trade context",
                        subtitle: "Reviewing execution, risk, psychology, journal quality, and local insights.",
                        symbolName: "sparkles"
                    )
                }

                if let error = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(error)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.warning)

                        Button {
                            JPHaptics.selection()
                            viewModel.analyzeTrade(trade)
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(JPColors.warning)
                        }
                        .buttonStyle(ScalingButtonStyle())
                        .accessibilityLabel("Retry AI analysis")
                    }
                    .padding(14)
                    .background(JPColors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack(spacing: 10) {
                    Button {
                        JPHaptics.impact(.medium)
                        viewModel.analyzeTrade(trade)
                    } label: {
                        Label(viewModel.hasGeneratedReview ? "Analyze Again" : "Analyze Trade", systemImage: "sparkles")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .disabled(viewModel.isAnalyzing)
                    .buttonStyle(ScalingButtonStyle())
                    .accessibilityLabel(viewModel.hasGeneratedReview ? "Analyze trade again" : "Analyze trade")
                    .accessibilityHint("Generates a local or backend-ready coaching review.")

                    Button {
                        JPHaptics.selection()
                        viewModel.regenerateReview(for: trade)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.warning)
                            .frame(width: 52, height: 52)
                            .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .disabled(viewModel.isAnalyzing)
                    .buttonStyle(ScalingButtonStyle())
                    .accessibilityLabel("Regenerate AI review")
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
    }

    private var scoreBreakdownSection: some View {
        section(title: "Score Breakdown", subtitle: "Structured scores ready for backend AI reports") {
            VStack(spacing: 12) {
                ForEach(viewModel.breakdown) { item in
                    AICoachBreakdownCard(item: item, tint: scoreColor(item.score), animate: didAppear)
                }
            }
        }
    }

    private var categoryScoresSection: some View {
        section(title: "Category Scores", subtitle: "The four core coaching pillars") {
            GlassCard {
                VStack(spacing: 14) {
                    categoryScoreRow(
                        title: "Execution",
                        score: viewModel.scoreValue(named: "Execution"),
                        icon: "scope",
                        tint: JPColors.accent,
                        note: "Entry timing, confirmation, and management quality."
                    )

                    categoryScoreRow(
                        title: "Risk Management",
                        score: viewModel.scoreValue(named: "Risk Management"),
                        icon: "shield.lefthalf.filled",
                        tint: JPColors.profit,
                        note: "Risk percent, R:R, sizing discipline, and stop quality."
                    )

                    categoryScoreRow(
                        title: "Psychology",
                        score: viewModel.scoreValue(named: "Psychology"),
                        icon: "brain.head.profile",
                        tint: JPColors.purple,
                        note: "Emotion, confidence, patience, and impulse control."
                    )

                    categoryScoreRow(
                        title: "Discipline",
                        score: viewModel.disciplineScore(for: trade),
                        icon: "checkmark.seal.fill",
                        tint: JPColors.blue,
                        note: "Plan adherence, mistake control, and review quality."
                    )
                }
            }
        }
    }

    private var professionalReviewSection: some View {
        section(title: "Professional Review", subtitle: "Production coaching categories for this trade") {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        AICoachScoreRing(
                            score: viewModel.overallScore,
                            tint: scoreColor(viewModel.overallScore),
                            animate: didAppear
                        )
                        .frame(width: 94, height: 94)
                        .scaleEffect(0.8)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(viewModel.grade)
                                    .font(.title.bold())
                                    .foregroundStyle(scoreColor(viewModel.overallScore))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(scoreColor(viewModel.overallScore).opacity(0.14), in: Capsule())

                                Text(viewModel.confidenceLevel)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(JPColors.warning)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(JPColors.warning.opacity(0.13), in: Capsule())
                            }

                            Text("Overall Score")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.secondaryText)
                                .textCase(.uppercase)

                            Text(viewModel.gradeSummary)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JPColors.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    LazyVGrid(columns: twoColumns, spacing: 12) {
                        professionalMetric("Execution Quality", viewModel.scoreValue(named: "Execution"), icon: "scope", tint: JPColors.accent)
                        professionalMetric("Risk Management", viewModel.scoreValue(named: "Risk Management"), icon: "shield.lefthalf.filled", tint: JPColors.profit)
                        professionalMetric("Psychology", viewModel.scoreValue(named: "Psychology"), icon: "brain.head.profile", tint: JPColors.purple)
                        professionalMetric("Patience", viewModel.patienceScore(for: trade), icon: "hourglass", tint: JPColors.warning)
                        professionalMetric("Discipline", viewModel.disciplineScore(for: trade), icon: "checkmark.seal.fill", tint: JPColors.blue)
                        professionalMetric("Journal Quality", viewModel.scoreValue(named: "Journal Quality"), icon: "book.pages.fill", tint: JPColors.secondaryText)
                    }
                }
            }
        }
    }

    private var tradeSummarySection: some View {
        section(title: "Trade Summary", subtitle: "Automatically assembled from this trade") {
            GlassCard {
                LazyVGrid(columns: twoColumns, spacing: 12) {
                    summaryTile("Direction", trade.direction.rawValue, icon: "arrow.left.arrow.right", tint: directionColor)
                    summaryTile("Risk %", trade.riskPercent == 0 ? "--" : "\(number(trade.riskPercent))%", icon: "percent", tint: JPColors.purple)
                    summaryTile("Reward Ratio", "1:\(number(trade.riskReward))", icon: "scale.3d", tint: JPColors.warning)
                    summaryTile("Session", trade.session.rawValue, icon: "clock", tint: JPColors.blue)
                    summaryTile("Strategy", trade.strategy.rawValue, icon: "point.topleft.down.curvedto.point.bottomright.up", tint: JPColors.accent)
                    summaryTile("Result", trade.status.rawValue, icon: "checkmark.seal", tint: outcomeColor)
                    summaryTile("Duration", viewModel.durationText(for: trade), icon: "timer", tint: JPColors.secondaryText)
                    summaryTile("Journal Length", "\(viewModel.journalLength(for: trade)) chars", icon: "text.alignleft", tint: JPColors.accent)
                    summaryTile("Screenshots", "\(viewModel.screenshotCount(for: trade)) uploaded", icon: "photo.on.rectangle", tint: JPColors.warning)
                }
            }
        }
    }

    private var chartAnalysisSection: some View {
        section(title: "Chart Analysis", subtitle: "Backend-ready vision review from uploaded screenshots") {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(JPColors.accent)
                            .frame(width: 52, height: 52)
                            .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Trade Review + Chart Review")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(JPColors.primaryText)

                            Text(chartAnalysis?.finalVerdict ?? "Preparing local chart context for future AI Vision.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        if viewModel.isAnalyzingVision {
                            ProgressView()
                                .tint(JPColors.accent)
                        } else {
                            Text("\(chartAnalysis?.confidence ?? 0)%")
                                .font(.title3.weight(.black))
                                .foregroundStyle(chartConfidenceColor)
                        }
                    }

                    LazyVGrid(columns: twoColumns, spacing: 12) {
                        chartMetric("Market Structure", chartAnalysis?.marketStructure, icon: "point.topleft.down.curvedto.point.bottomright.up", tint: JPColors.blue)
                        chartMetric("Entry Quality", chartAnalysis?.entryQuality, icon: "scope", tint: JPColors.accent)
                        chartMetric("Risk Placement", chartAnalysis?.riskPlacement, icon: "shield.lefthalf.filled", tint: JPColors.profit)
                        chartMetric("Trade Timing", chartAnalysis?.tradeTiming, icon: "timer", tint: JPColors.warning)
                        chartMetric("Trend Alignment", chartAnalysis?.trendAlignment, icon: "arrow.up.right", tint: JPColors.purple)
                        chartMetric("Liquidity", chartAnalysis?.liquidity, icon: "drop.fill", tint: JPColors.blue)
                        chartMetric("FVG", chartAnalysis?.fairValueGap, icon: "rectangle.split.3x1", tint: JPColors.warning)
                        chartMetric("Order Blocks", chartAnalysis?.orderBlocks, icon: "square.stack.3d.up.fill", tint: JPColors.accent)
                        chartMetric("BOS", chartAnalysis?.breakOfStructure, icon: "arrow.triangle.branch", tint: JPColors.profit)
                        chartMetric("CHOCH", chartAnalysis?.changeOfCharacter, icon: "arrow.left.arrow.right", tint: JPColors.secondaryText)
                        chartMetric("Momentum", chartAnalysis?.momentum, icon: "bolt.fill", tint: JPColors.warning)
                        chartMetric("Confidence", "\(chartAnalysis?.confidence ?? 0)/100", icon: "checkmark.seal.fill", tint: chartConfidenceColor)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var coachEmptyState: some View {
        if viewModel.journalLength(for: trade) < 80 || viewModel.screenshotCount(for: trade) == 0 {
            GlassCard {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(JPColors.accent)
                        .frame(width: 58, height: 58)
                        .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Smarter reviews start with richer journals.")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text("The AI Coach becomes more accurate when trades include detailed notes and screenshots.")
                            .font(.subheadline)
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : 18)
        }
    }

    private var strengthsSection: some View {
        section(title: "What You Did Well", subtitle: "Positive signals found in this trade") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.strengths, id: \.self) { strength in
                    bulletRow(strength, icon: "checkmark.circle.fill", tint: JPColors.profit)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [JPColors.profit.opacity(0.18), JPColors.elevatedSurface.opacity(0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(JPColors.profit.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private var improvementsSection: some View {
        section(title: "Improve Next Time", subtitle: "Coaching prompts for the next trade") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.improvements, id: \.self) { improvement in
                    bulletRow(improvement, icon: "arrow.up.forward.circle.fill", tint: orange)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [orange.opacity(0.18), JPColors.elevatedSurface.opacity(0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(orange.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private var mistakesSection: some View {
        section(title: "Mistakes", subtitle: "What the coach would correct first") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.mistakes, id: \.self) { mistake in
                    bulletRow(mistake, icon: "exclamationmark.triangle.fill", tint: JPColors.warning)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [JPColors.warning.opacity(0.16), JPColors.elevatedSurface.opacity(0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(JPColors.warning.opacity(0.24), lineWidth: 1)
            )
        }
    }

    private var nextTradeFocusCard: some View {
        section(title: "Next Trade Focus", subtitle: "One action to carry into the next setup") {
            GlassCard {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "scope")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(JPColors.accent)
                        .frame(width: 54, height: 54)
                        .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coach Focus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                            .textCase(.uppercase)

                        Text(viewModel.nextTradeFocus)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var weeklyMonthlySummarySection: some View {
        section(title: "AI Coaching Summary", subtitle: "Weekly and monthly coaching from saved trades") {
            VStack(spacing: 12) {
                coachingSummaryCard(period: "Weekly AI Summary", trades: tradesWithin(days: 7), icon: "calendar.badge.clock", tint: JPColors.blue)
                coachingSummaryCard(period: "Monthly AI Summary", trades: tradesWithin(days: 30), icon: "calendar", tint: JPColors.purple)
            }
        }
    }

    private var coachingTimelineSection: some View {
        section(title: "Coach Timeline", subtitle: "How this review becomes a lesson") {
            GlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    let steps = coachingTimelineSteps
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        coachingTimelineRow(
                            title: step.title,
                            detail: step.detail,
                            icon: step.icon,
                            tint: step.tint,
                            isLast: index == steps.count - 1
                        )
                    }
                }
            }
        }
    }

    private var coachMessageSection: some View {
        section(title: "Final Verdict", subtitle: "Combined trade review and chart review") {
            GlassCard {
                HStack(alignment: .top, spacing: 14) {
                    Text("✨")
                        .font(.system(size: 30))
                        .frame(width: 52, height: 52)
                        .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.gradeSummary)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text("\(viewModel.psychologyNotes)\n\nChart: \(chartAnalysis?.finalVerdict ?? "Vision backend is not connected yet. Showing offline chart preview.")\n\nRisk: \(viewModel.riskFeedback)\n\nNext focus: \(viewModel.nextTradeFocus)")
                            .font(.subheadline)
                            .foregroundStyle(JPColors.secondaryText)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var screenshotReviewSection: some View {
        section(title: "Screenshot Review", subtitle: "Visual journal preview for future AI analysis") {
            VStack(spacing: 14) {
                ForEach(Trade.ScreenshotSlot.allCases) { slot in
                    if let data = screenshotData(for: slot) {
                        AICoachScreenshotCard(slot: slot, imageData: data) {
                            activeScreenshot = AICoachScreenshotItem(slot: slot, imageData: data)
                        }
                    }
                }

                if viewModel.screenshotCount(for: trade) == 0 {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(JPColors.warning)

                            Text("No screenshots attached")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(JPColors.primaryText)

                            Text("Add before, during, and after screenshots from the Trade Workspace to unlock richer future AI reviews.")
                                .font(.subheadline)
                                .foregroundStyle(JPColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var nextTradeChecklistSection: some View {
        section(title: "Next Trade Checklist", subtitle: "Repeatable actions for your next setup") {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.nextTradeChecklist(for: trade), id: \.self) { item in
                        bulletRow(item, icon: "checklist.checked", tint: JPColors.accent)
                    }
                }
            }
        }
    }

    private var generatedInsightsSection: some View {
        section(title: "Connected Insights", subtitle: "Signals the coach can reference") {
            let related = insightViewModel.insights(for: trade)
            if related.isEmpty {
                GlassCard {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(JPColors.accent)
                            .frame(width: 52, height: 52)
                            .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Text("Analyze, replay, and review more trades to connect this trade to wider journal patterns.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(related.prefix(3)) { insight in
                        InsightCard(insight: insight)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var warningsSection: some View {
        if !viewModel.patternWarnings.isEmpty {
            section(title: "Pattern Warnings", subtitle: "Potential issues to watch") {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.patternWarnings, id: \.self) { warning in
                            bulletRow(warning, icon: "exclamationmark.triangle.fill", tint: JPColors.warning)
                        }
                    }
                }
            }
        }
    }

    private var overallGradeSection: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 18) {
                VStack(spacing: 4) {
                    Text(viewModel.grade)
                        .font(.system(size: 50, weight: .black, design: .rounded))
                        .foregroundStyle(scoreColor(viewModel.overallScore))

                    Text("Trade Grade")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                        .textCase(.uppercase)
                }
                .frame(width: 108, height: 108)
                .background(scoreColor(viewModel.overallScore).opacity(0.14), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Overall Grade")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text(viewModel.gradeSummary)
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
    }

    private var saveReportButton: some View {
        Button {
            JPHaptics.impact(.medium)
            viewModel.saveReview(for: trade)
        } label: {
            Label("Save Review to History", systemImage: "tray.and.arrow.down.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(JPColors.background)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: JPColors.accent.opacity(0.26), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(ScalingButtonStyle())
        .accessibilityLabel("Save review to AI history")
        .accessibilityHint("Stores this coaching review locally for future history.")
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
    }

    private var twoColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
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

    private var directionColor: Color {
        trade.direction == .buy ? JPColors.profit : JPColors.loss
    }

    private var orange: Color {
        Color(red: 1.0, green: 0.48, blue: 0.20)
    }

    private var chartAnalysis: VisionAnalysisResponse? {
        viewModel.visionAnalysis
    }

    private var chartConfidenceColor: Color {
        scoreColor(chartAnalysis?.confidence ?? 0)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private func section<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle)
            content()
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
    }

    private func summaryTile(_ title: String, _ value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                    .textCase(.uppercase)

                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(14)
        .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(JPColors.border, lineWidth: 1)
        )
    }

    private func professionalMetric(_ title: String, _ score: Int, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                Text("\(score)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(JPColors.graphite)
                    Capsule()
                        .fill(tint)
                        .frame(width: didAppear ? proxy.size.width * CGFloat(score) / 100 : 0)
                        .animation(.spring(response: 0.7, dampingFraction: 0.86), value: didAppear)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func chartMetric(_ title: String, _ value: String?, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                if viewModel.isAnalyzingVision {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(JPColors.border.opacity(0.8))
                        .frame(width: 38, height: 8)
                        .shimmer()
                }
            }

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.primaryText)
                .textCase(.uppercase)

            Text(value ?? "Offline preview loading.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
        .padding(14)
        .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func bulletRow(_ text: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .padding(.top, 1)

            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JPColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func categoryScoreRow(title: String, score: Int, icon: String, tint: Color, note: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text(note)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text("\(score)")
                    .font(.title3.weight(.black))
                    .foregroundStyle(scoreColor(score))
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(JPColors.graphite.opacity(0.9))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.75), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: didAppear ? proxy.size.width * CGFloat(score) / 100 : 0)
                        .animation(.spring(response: 0.72, dampingFraction: 0.86), value: didAppear)
                        .animation(.spring(response: 0.5, dampingFraction: 0.88), value: score)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(JPColors.graphite.opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private var coachingTimelineSteps: [(title: String, detail: String, icon: String, tint: Color)] {
        [
            (
                "Context Reviewed",
                "\(trade.pair.isEmpty ? "Trade" : trade.pair) \(trade.direction.rawValue.lowercased()) in the \(trade.session.rawValue) session.",
                "doc.text.magnifyingglass",
                JPColors.blue
            ),
            (
                "Scores Generated",
                "Execution, risk, psychology, and discipline were scored against the journal data.",
                "gauge.with.dots.needle.67percent",
                JPColors.accent
            ),
            (
                "Mistakes Identified",
                viewModel.mistakes.first ?? "No major mistake detected. Protect this process.",
                "exclamationmark.triangle.fill",
                JPColors.warning
            ),
            (
                "Focus Assigned",
                viewModel.nextTradeFocus,
                "scope",
                JPColors.profit
            ),
            (
                viewModel.hasSavedReview ? "Saved to AI History" : "Ready to Save",
                viewModel.hasSavedReview ? "This review is stored locally and available in AI Review History." : "Save this review to build your coaching timeline.",
                viewModel.hasSavedReview ? "checkmark.seal.fill" : "tray.and.arrow.down.fill",
                viewModel.hasSavedReview ? JPColors.profit : JPColors.secondaryText
            )
        ]
    }

    private func coachingTimelineRow(title: String, detail: String, icon: String, tint: Color, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14), in: Circle())

                if !isLast {
                    Rectangle()
                        .fill(tint.opacity(0.22))
                        .frame(width: 2, height: 34)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)

                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(.bottom, isLast ? 0 : 10)
    }

    private func coachingSummaryCard(period: String, trades: [Trade], icon: String, tint: Color) -> some View {
        let summary = coachingSummary(for: trades)

        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 46, height: 46)
                        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(period)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text(summary.headline)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Text("\(summary.score)")
                        .font(.title2.weight(.black))
                        .foregroundStyle(scoreColor(summary.score))
                }

                Text(summary.detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JPColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    miniSummaryValue("Trades", "\(trades.count)", tint: tint)
                    miniSummaryValue("Win Rate", "\(Int(summary.winRate.rounded()))%", tint: JPColors.profit)
                    miniSummaryValue("Net P/L", currency(summary.netProfit), tint: summary.netProfit >= 0 ? JPColors.profit : JPColors.loss)
                }
            }
        }
    }

    private func miniSummaryValue(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
                .textCase(.uppercase)

            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func tradesWithin(days: Int) -> [Trade] {
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }

        return allTrades.filter { $0.date >= startDate }
    }

    private func coachingSummary(for trades: [Trade]) -> (headline: String, detail: String, score: Int, winRate: Double, netProfit: Double) {
        guard !trades.isEmpty else {
            return (
                "No saved trades in this period yet.",
                "Log and review trades consistently so the coach can identify your current performance patterns.",
                0,
                0,
                0
            )
        }

        let netProfit = trades.reduce(0) { $0 + $1.profitLoss }
        let wins = trades.filter { $0.status == .win }.count
        let winRate = Double(wins) / Double(trades.count) * 100
        let averageRR = trades.reduce(0) { $0 + $1.riskReward } / Double(trades.count)
        let followedPlanRate = Double(trades.filter(\.followedPlan).count) / Double(trades.count) * 100
        let score = min(100, max(0, Int((winRate * 0.35) + (min(max(averageRR, 0), 3) / 3 * 35) + (followedPlanRate * 0.30))))

        let commonMistake = mostCommonMistake(in: trades)
        let headline = netProfit >= 0 ? "Profitable period with \(Int(winRate.rounded()))% win rate." : "Red period with clear coaching data."
        let detail: String

        if let commonMistake {
            detail = "Focus on reducing \(commonMistake.lowercased()). Average RR is \(number(averageRR))R and plan adherence is \(Int(followedPlanRate.rounded()))%."
        } else if followedPlanRate >= 80 {
            detail = "Strong discipline period. Keep protecting risk and repeat the setups with the cleanest execution."
        } else {
            detail = "Your next edge is process quality: complete the plan, document the setup, and review every exit."
        }

        return (headline, detail, score, winRate, netProfit)
    }

    private func mostCommonMistake(in trades: [Trade]) -> String? {
        let tags = trades
            .flatMap(\.mistakeTags)
            .filter { $0 != .goodDiscipline }

        let counts = Dictionary(grouping: tags, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key.rawValue
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.0f", abs(value)))"
    }

    private func screenshotData(for slot: Trade.ScreenshotSlot) -> Data? {
        switch slot {
        case .beforeEntry:
            return trade.beforeEntryImageData
        case .duringTrade:
            return trade.duringTradeImageData
        case .afterExit:
            return trade.afterExitImageData
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...100:
            return JPColors.profit
        case 70...84:
            return JPColors.warning
        case 55...69:
            return orange
        default:
            return JPColors.loss
        }
    }

    private func number(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.2f", value)
    }
}

private struct AICoachScoreRing: View {
    let score: Int
    let tint: Color
    let animate: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(JPColors.graphite, lineWidth: 12)

            Circle()
                .trim(from: 0, to: animate ? CGFloat(score) / 100 : 0)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.35), radius: 12, x: 0, y: 0)
                .animation(.spring(response: 0.85, dampingFraction: 0.82).delay(0.08), value: animate)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(JPColors.primaryText)

                Text("/ 100")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
            }
        }
        .frame(width: 118, height: 118)
    }
}

private struct AICoachBreakdownCard: View {
    let item: AITradeScoreBreakdown
    let tint: Color
    let animate: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(tint)
                        .frame(width: 42, height: 42)
                        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text(item.explanation)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Text("\(item.score)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(JPColors.graphite)

                        Capsule()
                            .fill(tint)
                            .frame(width: animate ? proxy.size.width * CGFloat(item.score) / 100 : 0)
                            .shadow(color: tint.opacity(0.22), radius: 8, x: 0, y: 0)
                    }
                }
                .frame(height: 8)
                .animation(.spring(response: 0.7, dampingFraction: 0.84).delay(0.12), value: animate)
            }
        }
    }
}

private struct AICoachScreenshotItem: Identifiable {
    let id = UUID()
    let slot: Trade.ScreenshotSlot
    let imageData: Data
}

private struct AICoachScreenshotCard: View {
    let slot: Trade.ScreenshotSlot
    let imageData: Data
    let onView: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.rawValue)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text("AI Review")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()

                    Text("Coming Soon")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.warning)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(JPColors.warning.opacity(0.13), in: Capsule())
                }

                if let image = UIImage(data: imageData) {
                    Button {
                        onView()
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                                .clipped()
                                .overlay(
                                    LinearGradient(
                                        colors: [Color.clear, Color.black.opacity(0.48)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )
                                )

                            Label("Tap to View", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.primaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(12)
                        }
                        .background(JPColors.graphite)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(JPColors.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AIReviewHistoryView: View {
    @Query(sort: \AITradeReview.updatedAt, order: .reverse) private var reviews: [AITradeReview]
    @Query(sort: \Trade.date, order: .reverse) private var trades: [Trade]
    @State private var searchText = ""
    @State private var sortOption = AIReviewHistorySort.newest
    @State private var didAppear = false

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    progressSection
                    sortControls

                    if visibleReviews.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(visibleReviews.enumerated()), id: \.element.id) { index, review in
                            AIReviewHistoryRow(review: review, trade: trade(for: review))
                                .premiumEntrance(active: didAppear, delay: Double(index) * 0.035)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }
        }
        .navigationTitle("AI History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search pair, session, or summary")
        .onAppear {
            debugPrint("AI REVIEW HISTORY UPDATED")
            withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                didAppear = true
            }
        }
    }

    private var progressSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Progress")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)

                        Text("Your saved coaching history across every analyzed trade.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()

                    Text("\(averageScore)")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(scoreColor(averageScore))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    progressTile("Average AI Score", "\(averageScore)", icon: "chart.line.uptrend.xyaxis", tint: scoreColor(averageScore))
                    progressTile("Score Trend", scoreTrendText, icon: "arrow.triangle.2.circlepath", tint: scoreTrend >= 0 ? JPColors.profit : JPColors.loss)
                    progressTile("Most Common Mistake", mostCommonMistake, icon: "exclamationmark.triangle.fill", tint: JPColors.warning)
                    progressTile("Most Improved", mostImprovedCategory, icon: "sparkles", tint: JPColors.accent)
                    progressTile("Worst Category", worstCategory, icon: "target", tint: JPColors.loss)
                    progressTile("Saved Reviews", "\(reviews.count)", icon: "tray.full.fill", tint: JPColors.blue)
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.02)
    }

    private var sortControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AIReviewHistorySort.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                            sortOption = option
                        }
                        JPHaptics.selection()
                    } label: {
                        Text(option.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(sortOption == option ? JPColors.background : JPColors.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(sortOption == option ? JPColors.accent : JPColors.graphite, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(JPColors.border, lineWidth: sortOption == option ? 0 : 1)
                            )
                    }
                    .buttonStyle(ScalingButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
        .premiumEntrance(active: didAppear, delay: 0.05)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "sparkles.square.filled.on.square")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(JPColors.accent)
                    .frame(width: 66, height: 66)
                    .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Text(reviews.isEmpty ? "Your AI history starts with the first saved review." : "No reviews match this search.")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)

                Text("Analyze a trade, save the review, and Journaling Pips will build a searchable coaching timeline that works offline.")
                    .font(.subheadline)
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .premiumEntrance(active: didAppear, delay: 0.08)
    }

    private var visibleReviews: [AITradeReview] {
        let filtered = reviews.filter { review in
            guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return true
            }

            let query = searchText.lowercased()
            let trade = trade(for: review)
            return review.summary.lowercased().contains(query)
                || review.grade.lowercased().contains(query)
                || (trade?.pair.lowercased().contains(query) ?? false)
                || (trade?.session.rawValue.lowercased().contains(query) ?? false)
        }

        switch sortOption {
        case .newest:
            return filtered.sorted { $0.updatedAt > $1.updatedAt }
        case .highestScore:
            return filtered.sorted { $0.overallScore > $1.overallScore }
        case .lowestScore:
            return filtered.sorted { $0.overallScore < $1.overallScore }
        case .pair:
            return filtered.sorted { (trade(for: $0)?.pair ?? "") < (trade(for: $1)?.pair ?? "") }
        case .session:
            return filtered.sorted { (trade(for: $0)?.session.rawValue ?? "") < (trade(for: $1)?.session.rawValue ?? "") }
        }
    }

    private var averageScore: Int {
        guard !reviews.isEmpty else { return 0 }
        return Int((Double(reviews.reduce(0) { $0 + $1.overallScore }) / Double(reviews.count)).rounded())
    }

    private var scoreTrend: Int {
        let sorted = reviews.sorted { $0.updatedAt > $1.updatedAt }
        guard let latest = sorted.first, sorted.count > 1 else { return 0 }
        let previous = sorted.dropFirst()
        let previousAverage = Double(previous.reduce(0) { $0 + $1.overallScore }) / Double(previous.count)
        return Int((Double(latest.overallScore) - previousAverage).rounded())
    }

    private var scoreTrendText: String {
        scoreTrend == 0 ? "Flat" : "\(scoreTrend > 0 ? "+" : "")\(scoreTrend)"
    }

    private var mostCommonMistake: String {
        let tags = reviews.compactMap { trade(for: $0) }.flatMap(\.mistakeTags).map(\.rawValue)
        let grouped = Dictionary(grouping: tags, by: { $0 }).mapValues(\.count)
        return grouped.max { $0.value < $1.value }?.key ?? "None logged"
    }

    private var mostImprovedCategory: String {
        guard let best = categoryAverages.max(by: { $0.value < $1.value }) else {
            return "Not enough data"
        }
        return best.key
    }

    private var worstCategory: String {
        guard let worst = categoryAverages.min(by: { $0.value < $1.value }) else {
            return "Not enough data"
        }
        return worst.key
    }

    private var categoryAverages: [String: Int] {
        guard !reviews.isEmpty else { return [:] }
        let count = Double(reviews.count)
        return [
            "Execution": Int((Double(reviews.reduce(0) { $0 + $1.executionScore }) / count).rounded()),
            "Risk": Int((Double(reviews.reduce(0) { $0 + $1.riskManagementScore }) / count).rounded()),
            "Psychology": Int((Double(reviews.reduce(0) { $0 + $1.psychologyScore }) / count).rounded()),
            "Journal": Int((Double(reviews.reduce(0) { $0 + $1.journalQualityScore }) / count).rounded()),
            "Discipline": Int((Double(reviews.reduce(0) { $0 + $1.strategyDisciplineScore }) / count).rounded())
        ]
    }

    private func trade(for review: AITradeReview) -> Trade? {
        trades.first { $0.id == review.tradeID }
    }

    private func progressTile(_ title: String, _ value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
                .textCase(.uppercase)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(14)
        .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...100:
            return JPColors.profit
        case 70...84:
            return JPColors.warning
        case 55...69:
            return Color(red: 1.0, green: 0.48, blue: 0.20)
        default:
            return JPColors.loss
        }
    }
}

private enum AIReviewHistorySort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case highestScore = "Highest Score"
    case lowestScore = "Lowest Score"
    case pair = "Pair"
    case session = "Session"

    var id: String { rawValue }
}

private struct AIReviewHistoryRow: View {
    let review: AITradeReview
    let trade: Trade?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(trade?.pair.isEmpty == false ? trade?.pair ?? "Unknown Trade" : "Unknown Trade")
                            .font(.title3.weight(.black))
                            .foregroundStyle(JPColors.primaryText)

                        Text("\(trade?.session.rawValue ?? "Session Unknown") • \(review.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(review.grade)
                            .font(.title2.weight(.black))
                            .foregroundStyle(scoreColor(review.overallScore))

                        Text("\(review.overallScore)/100")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                }

                Text(review.summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JPColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    capsule("Execution \(review.executionScore)", tint: JPColors.accent)
                    capsule("Risk \(review.riskManagementScore)", tint: JPColors.profit)
                    capsule("Psych \(review.psychologyScore)", tint: JPColors.purple)
                }
            }
        }
    }

    private func capsule(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...100:
            return JPColors.profit
        case 70...84:
            return JPColors.warning
        case 55...69:
            return Color(red: 1.0, green: 0.48, blue: 0.20)
        default:
            return JPColors.loss
        }
    }
}

private struct AICoachScreenshotViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    let item: AICoachScreenshotItem

    var body: some View {
        ZStack(alignment: .topTrailing) {
            JPColors.background
                .ignoresSafeArea()

            if let image = UIImage(data: item.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnificationGesture.simultaneously(with: dragGesture))
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                            if scale > 1 {
                                scale = 1
                                lastScale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.2
                                lastScale = 2.2
                            }
                        }
                    }
                    .ignoresSafeArea()
            }

            VStack(alignment: .trailing, spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(ScalingButtonStyle())

                Text(item.slot.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.top, 18)
            .padding(.trailing, 18)
        }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if scale <= 1.05, abs(value.translation.height) > 120 {
                        dismiss()
                    }
                }
        )
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
}
