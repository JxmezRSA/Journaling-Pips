import SwiftData
import SwiftUI
import UIKit

struct ReplayStudioView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ReplayViewModel()
    @State private var didAppear = false
    @State private var activeScreenshot: ReplayScreenshot?

    let trade: Trade

    var body: some View {
        ZStack {
            background

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        ReplayHeaderView(trade: trade, viewModel: viewModel, progress: viewModel.progress)
                            .premiumEntrance(active: didAppear)

                        ReplayControlBar(
                            isPlaying: viewModel.isPlaying,
                            canStepBackward: viewModel.visibleStageCount > 1,
                            canStepForward: viewModel.visibleStageCount < viewModel.stages.count,
                            onBack: viewModel.stepBackward,
                            onPlayPause: { viewModel.isPlaying ? viewModel.pause() : viewModel.play() },
                            onForward: viewModel.stepForward,
                            onRestart: viewModel.restart
                        )
                        .premiumEntrance(active: didAppear, delay: 0.04)

                        ReplayTimelineView(stages: viewModel.visibleStages, isComplete: viewModel.isComplete) { screenshot in
                            activeScreenshot = screenshot
                        }
                        .premiumEntrance(active: didAppear, delay: 0.08)

                        ReplayScreenshotCarousel(screenshots: viewModel.screenshots(for: trade)) { screenshot in
                            activeScreenshot = screenshot
                        }
                        .premiumEntrance(active: didAppear, delay: 0.12)

                        ReplayPsychologyView(metrics: viewModel.psychology(for: trade))
                            .premiumEntrance(active: didAppear, delay: 0.16)

                        ReplayAICommentaryView(commentary: viewModel.commentary, activeIndex: viewModel.commentaryIndex)
                            .premiumEntrance(active: didAppear, delay: 0.20)

                        ReplayLessonsView(trade: trade)
                            .premiumEntrance(active: didAppear, delay: 0.24)

                        ReplayStatisticsView(stats: viewModel.statistics(for: trade))
                            .premiumEntrance(active: didAppear, delay: 0.28)

                        favoriteActions
                            .premiumEntrance(active: didAppear, delay: 0.32)

                        compareAndExport
                            .premiumEntrance(active: didAppear, delay: 0.36)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 112)
                }
                .onChange(of: viewModel.visibleStageCount) { _, _ in
                    guard let id = viewModel.visibleStages.last?.id else { return }
                    withAnimation(JPDesign.smoothSpring) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .navigationTitle("Replay Studio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(item: $activeScreenshot) { screenshot in
            ReplayStudioImageViewer(screenshot: screenshot)
        }
        .alert("Export Replay PDF", isPresented: $viewModel.didShowExportPlaceholder) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("Replay PDF export is coming soon. This placeholder keeps the export workflow ready.")
        }
        .onAppear {
            viewModel.configure(context: modelContext, trade: trade)
            withAnimation(JPDesign.smoothSpring) {
                didAppear = true
            }
        }
        .onDisappear {
            viewModel.pause()
        }
    }

    private var background: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()
            Circle()
                .fill(outcomeTint.opacity(0.15))
                .frame(width: 340, height: 340)
                .blur(radius: 84)
                .offset(x: 150, y: -240)
            Circle()
                .fill(JPColors.accent.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 76)
                .offset(x: -160, y: 360)
        }
    }

    private var favoriteActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Replay Library", subtitle: "Save this film for later review")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                libraryButton("Favorite Replay", "star.fill", JPColors.warning, viewModel.isFavorite, viewModel.toggleFavorite)
                libraryButton("Best Trades", "crown.fill", JPColors.profit, viewModel.isBestTrade, viewModel.toggleBestTrade)
                libraryButton("Mistakes", "exclamationmark.triangle.fill", JPColors.loss, viewModel.isMistake, viewModel.toggleMistake)
                libraryButton("Review Later", "bookmark.fill", JPColors.blue, viewModel.isReviewLater, viewModel.toggleReviewLater)
            }
        }
    }

    private var compareAndExport: some View {
        VStack(spacing: 14) {
            GlassCard {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.2.swap")
                        .font(.title3.weight(.black))
                        .foregroundStyle(JPColors.secondaryText)
                        .frame(width: 52, height: 52)
                        .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Compare this trade")
                            .font(.headline.weight(.black))
                            .foregroundStyle(JPColors.primaryText)
                        Text("Coming soon. Compare against similar setups and outcomes.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(JPColors.warning)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(JPColors.warning.opacity(0.14), in: Capsule())
                }
            }

            Button {
                viewModel.exportPlaceholder()
            } label: {
                Label("Export Replay PDF", systemImage: "doc.richtext.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(JPColors.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(colors: [JPColors.accent, JPColors.profit], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: JPColors.accent.opacity(0.24), radius: 18, x: 0, y: 10)
            }
            .buttonStyle(ScalingButtonStyle())
        }
    }

    private var outcomeTint: Color {
        switch trade.status {
        case .win: return JPColors.profit
        case .loss: return JPColors.loss
        case .breakeven: return JPColors.warning
        }
    }

    private func libraryButton(_ title: String, _ icon: String, _ tint: Color, _ isActive: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption.weight(.black))
                    .foregroundStyle(isActive ? JPColors.background : tint)
                    .frame(width: 34, height: 34)
                    .background(isActive ? tint : tint.opacity(0.14), in: Circle())
                Text(title)
                    .font(.caption.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(isActive ? tint.opacity(0.16) : JPColors.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(isActive ? tint.opacity(0.32) : JPColors.border, lineWidth: 1))
        }
        .buttonStyle(ScalingButtonStyle())
    }
}

private struct ReplayStudioImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    let screenshot: ReplayScreenshot

    var body: some View {
        ZStack(alignment: .topTrailing) {
            JPColors.background.ignoresSafeArea()

            if let data = screenshot.data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnify.simultaneously(with: drag))
                    .onTapGesture(count: 2) {
                        withAnimation(JPDesign.quickSpring) {
                            if scale > 1 {
                                scale = 1
                                lastScale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.25
                                lastScale = 2.25
                            }
                        }
                    }
                    .ignoresSafeArea()
            }

            VStack(alignment: .trailing, spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(ScalingButtonStyle())

                Text(screenshot.title)
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
            DragGesture(minimumDistance: 24).onEnded { value in
                if scale <= 1.05, abs(value.translation.height) > 120 {
                    dismiss()
                }
            }
        )
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { scale = min(max(lastScale * $0, 1), 4) }
            .onEnded { _ in lastScale = scale }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }
}
