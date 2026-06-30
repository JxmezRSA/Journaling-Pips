import SwiftData
import SwiftUI
import UIKit

struct TradeReplayView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = TradeReplayViewModel()
    @StateObject private var insightViewModel = InsightViewModel()
    @State private var didAppear = false
    @State private var activeScreenshot: ReplayScreenshotItem?
    @State private var didRecordReplayOpen = false
    @State private var showReplayCelebration = false

    let trade: Trade

    var body: some View {
        ZStack {
            replayBackground

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        playbackControls
                        timeline(proxy: proxy)
                        journalStory
                        aiCoachStory

                        if viewModel.isComplete {
                            lessonsLearnedSection
                            resultHero
                                .transition(.opacity.combined(with: .scale(scale: 0.96)).combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 112)
                }
                .onChange(of: viewModel.visibleEventCount) { _, _ in
                    guard let last = viewModel.visibleEvents.last?.id else { return }
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                        proxy.scrollTo(last, anchor: .center)
                    }
                }
            }
        }
        .navigationTitle("Trade Replay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(item: $activeScreenshot) { item in
            ReplayScreenshotViewer(item: item)
        }
        .overlay {
            if showReplayCelebration {
                CelebrationOverlay(
                    title: "Replay Complete",
                    subtitle: "Lessons learned are now connected to this trade.",
                    symbolName: "play.rectangle.fill",
                    tint: outcomeColor
                )
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        showReplayCelebration = false
                    }
                }
            }
        }
        .onAppear {
            viewModel.configure(context: modelContext, trade: trade)
            insightViewModel.configure(context: modelContext)
            if !didRecordReplayOpen {
                DisciplineTracker(context: modelContext).recordReplayViewed(for: trade)
                didRecordReplayOpen = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84)) {
                didAppear = true
            }
        }
        .onDisappear {
            viewModel.pause()
        }
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete {
                insightViewModel.refresh(event: .replayCompleted)
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    showReplayCelebration = true
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    withAnimation(.easeInOut(duration: 0.26)) {
                        showReplayCelebration = false
                    }
                }
            }
        }
    }

    private var replayBackground: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            Circle()
                .fill(outcomeColor.opacity(0.18))
                .frame(width: 340, height: 340)
                .blur(radius: 82)
                .offset(x: 160, y: -220)

            Circle()
                .fill(JPColors.accent.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 76)
                .offset(x: -170, y: 260)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trade Replay")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)

                    Text("\(trade.pair) • \(trade.direction.rawValue) • \(trade.session.rawValue)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                }

                Spacer()

                Text("\(Int((viewModel.progress * 100).rounded()))%")
                    .font(.headline.weight(.black))
                    .foregroundStyle(JPColors.background)
                    .frame(width: 62, height: 62)
                    .background(outcomeColor, in: Circle())
                    .shadow(color: outcomeColor.opacity(0.32), radius: 18, x: 0, y: 10)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(JPColors.graphite)
                    Capsule()
                        .fill(outcomeColor)
                        .frame(width: max(10, proxy.size.width * viewModel.progress))
                        .shadow(color: outcomeColor.opacity(0.28), radius: 10, x: 0, y: 0)
                }
            }
            .frame(height: 8)
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 16)
    }

    private var playbackControls: some View {
        GlassCard {
            HStack(spacing: 12) {
                replayButton(icon: "backward.end.fill", title: "Back") {
                    JPHaptics.selection()
                    viewModel.stepBackward()
                }

                replayButton(icon: viewModel.isPlaying ? "pause.fill" : "play.fill", title: viewModel.isPlaying ? "Pause" : "Play", isPrimary: true) {
                    JPHaptics.impact(.medium)
                    viewModel.isPlaying ? viewModel.pause() : viewModel.play()
                }

                replayButton(icon: "forward.end.fill", title: "Next") {
                    JPHaptics.selection()
                    viewModel.stepForward()
                }

                replayButton(icon: "arrow.counterclockwise", title: "Restart") {
                    JPHaptics.selection()
                    viewModel.restart()
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 16)
    }

    private func timeline(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Visual Timeline", subtitle: "A cinematic story of the trade")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.visibleEvents.enumerated()), id: \.element.id) { index, event in
                    ReplayEventCard(
                        event: event,
                        isCurrent: index == viewModel.visibleEvents.count - 1,
                        isLast: index == viewModel.visibleEvents.count - 1 && viewModel.isComplete,
                        onScreenshotTap: { data, slot in
                            activeScreenshot = ReplayScreenshotItem(slot: slot, imageData: data)
                        }
                    )
                    .id(event.id)
                    .transition(.opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98)))
                }
            }
        }
    }

    private var journalStory: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Journal Story", subtitle: "The thinking behind the trade")

            VStack(spacing: 12) {
                quoteCard("Trade Thesis", trade.tradeThesis.isEmpty ? trade.notes : trade.tradeThesis)
                quoteCard("Market Context", trade.marketContext)
                quoteCard("Execution Review", trade.executionReview)
                quoteCard("Lessons Learned", trade.lessonsLearned)
            }
        }
        .opacity(viewModel.visibleEventCount >= journalEventIndex ? 1 : 0.25)
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: viewModel.visibleEventCount)
    }

    private var aiCoachStory: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "AI Coach Review", subtitle: "Placeholder coaching recap")

            GlassCard {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(JPColors.warning)
                        .frame(width: 52, height: 52)
                        .background(JPColors.warning.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.savedAIReview == nil ? "Generate an AI review from the Trade Detail screen." : viewModel.savedAIReview?.summary ?? "")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if let review = viewModel.savedAIReview {
                            Text("Grade \(review.grade) • Score \(review.overallScore)/100")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.warning)
                        } else {
                            Text("No real AI API is connected yet.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)
                        }
                    }
                }
            }
        }
        .opacity(viewModel.isComplete ? 1 : 0.28)
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: viewModel.isComplete)
    }

    private var lessonsLearnedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Lessons Learned", subtitle: "Generated after replay completion")

            let insights = insightViewModel.insights(for: trade).filter { $0.category == .replay }
            if let lesson = insights.first {
                InsightCard(insight: lesson)
            } else {
                GlassCard {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "lightbulb.max.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(JPColors.warning)
                            .frame(width: 52, height: 52)
                            .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Replay complete.")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(JPColors.primaryText)

                            Text("Capture one lesson from this replay before the next trade.")
                                .font(.subheadline)
                                .foregroundStyle(JPColors.secondaryText)
                        }
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var resultHero: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(trade.pair)
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)

                        HStack(spacing: 8) {
                            badge(trade.direction.rawValue, color: trade.direction == .buy ? JPColors.profit : JPColors.loss)
                            badge(trade.status.rawValue, color: outcomeColor)
                            badge("Grade \(viewModel.tradeGrade(for: trade))", color: JPColors.warning)
                        }
                    }

                    Spacer()

                    Text(currency(trade.profitLoss))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(outcomeColor)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    resultTile("Risk:Reward", riskRewardText, "scale.3d", JPColors.warning)
                    resultTile("Session", trade.session.rawValue, "clock", JPColors.blue)
                    resultTile("Strategy", trade.strategy.rawValue, "point.topleft.down.curvedto.point.bottomright.up", JPColors.accent)
                    resultTile("Execution", trade.executionScore == 0 ? "--" : "\(trade.executionScore)/5", "star.fill", JPColors.warning)
                }
            }
        }
        .shadow(color: outcomeColor.opacity(0.18), radius: 28, x: 0, y: 16)
    }

    private var journalEventIndex: Int {
        max(1, viewModel.events.firstIndex { $0.kind == .journalReview }.map { $0 + 1 } ?? viewModel.events.count)
    }

    private var outcomeColor: Color {
        switch trade.status {
        case .win: return JPColors.profit
        case .loss: return JPColors.loss
        case .breakeven: return JPColors.warning
        }
    }

    private var riskRewardText: String {
        String(format: "1:%.2f", trade.riskReward)
    }

    private func replayButton(icon: String, title: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 22 : 18, weight: .bold))
                    .frame(width: isPrimary ? 58 : 48, height: isPrimary ? 48 : 42)
                    .foregroundStyle(isPrimary ? JPColors.background : JPColors.primaryText)
                    .background(isPrimary ? JPColors.accent : JPColors.graphite, in: RoundedRectangle(cornerRadius: isPrimary ? 20 : 17, style: .continuous))

                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isPrimary ? JPColors.accent : JPColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ScalingButtonStyle())
    }

    private func quoteCard(_ title: String, _ text: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.accent)
                    .textCase(.uppercase)

                Text(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No entry added yet." : "“\(text)”")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? JPColors.secondaryText : JPColors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func resultTile(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(JPColors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(14)
        .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(JPColors.border, lineWidth: 1)
        )
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }
}

private struct ReplayEventCard: View {
    let event: ReplayEvent
    let isCurrent: Bool
    let isLast: Bool
    let onScreenshotTap: (Data, Trade.ScreenshotSlot) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: event.icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(event.tint)
                    .frame(width: 42, height: 42)
                    .background(event.tint.opacity(0.16), in: Circle())
                    .overlay(Circle().stroke(event.tint.opacity(0.35), lineWidth: 1))
                    .shadow(color: isCurrent ? event.tint.opacity(0.55) : Color.clear, radius: 16, x: 0, y: 0)
                    .scaleEffect(isCurrent ? 1.08 : 1)
                    .animation(.spring(response: 0.36, dampingFraction: 0.78), value: isCurrent)

                if !isLast {
                    Rectangle()
                        .fill(event.tint.opacity(0.30))
                        .frame(width: 2, height: event.screenshotSlot == nil ? 150 : 236)
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(timeText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(event.tint)

                        Spacer()

                        Text(event.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Text(event.description)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(event.detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    screenshotPreview
                }
            }
        }
        .padding(.bottom, 12)
        .shadow(color: isCurrent ? event.tint.opacity(0.10) : Color.clear, radius: 20, x: 0, y: 10)
    }

    @ViewBuilder
    private var screenshotPreview: some View {
        if let slot = event.screenshotSlot {
            if let data = event.screenshotData, let image = UIImage(data: data) {
                Button {
                    onScreenshotTap(data, slot)
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipped()
                            .overlay(
                                LinearGradient(colors: [.clear, .black.opacity(0.42)], startPoint: .center, endPoint: .bottom)
                            )

                        Label("View", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(12)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(JPColors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(JPColors.mutedText)

                    Text(slot.emptyActionTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Replay still works. Add a screenshot later to complete this scene.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 176)
                .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(JPColors.border, lineWidth: 1)
                )
            }
        }
    }

    private var timeText: String {
        event.time?.formatted(.dateTime.hour().minute()) ?? "—"
    }
}

private struct ReplayScreenshotItem: Identifiable {
    let id = UUID()
    let slot: Trade.ScreenshotSlot
    let imageData: Data
}

private struct ReplayScreenshotViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    let item: ReplayScreenshotItem

    var body: some View {
        ZStack(alignment: .topTrailing) {
            JPColors.background.ignoresSafeArea()

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
