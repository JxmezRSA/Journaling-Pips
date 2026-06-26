import SwiftData
import SwiftUI
import UIKit

struct AITradeCoachView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = AITradeCoachViewModel()
    @State private var didAppear = false
    @State private var activeScreenshot: AICoachScreenshotItem?

    let trade: Trade

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    scoreBreakdownSection
                    tradeSummarySection
                    coachEmptyState
                    strengthsSection
                    improvementsSection
                    coachMessageSection
                    screenshotReviewSection
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
            Text("Your placeholder AI Trade Coach report was saved locally.")
        }
        .alert("Unable to Save", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
        .onAppear {
            viewModel.configure(context: modelContext, trade: trade)

            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                didAppear = true
            }
        }
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

                        Text("Placeholder score from journal data, risk behavior, execution, and screenshots.")
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

    private var scoreBreakdownSection: some View {
        section(title: "Score Breakdown", subtitle: "Placeholder scoring ready for future AI reports") {
            VStack(spacing: 12) {
                ForEach(viewModel.breakdown) { item in
                    AICoachBreakdownCard(item: item, tint: scoreColor(item.score), animate: didAppear)
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
        section(title: "Improve Next Time", subtitle: "Coaching prompts from placeholder logic") {
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

    private var coachMessageSection: some View {
        section(title: "Coach Message", subtitle: "Future AI response preview") {
            GlassCard {
                HStack(alignment: .top, spacing: 14) {
                    Text("✨")
                        .font(.system(size: 30))
                        .frame(width: 52, height: 52)
                        .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Great discipline on this trade.")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text("Your execution was strong, but your exit could have captured more of the move.\n\nFocus on allowing high-quality trades enough room before closing them.\n\nThis is placeholder text for now.")
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
            viewModel.saveReview(for: trade)
        } label: {
            Label("Save Review", systemImage: "tray.and.arrow.down.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(JPColors.background)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: JPColors.accent.opacity(0.26), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(ScalingButtonStyle())
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
