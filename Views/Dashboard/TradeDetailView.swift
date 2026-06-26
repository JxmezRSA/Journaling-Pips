import CoreTransferable
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct TradeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    @StateObject private var viewModel: TradeDetailViewModel
    @State private var activeForm: TradeDetailForm?
    @State private var showDeleteConfirmation = false
    @State private var screenshotToDelete: Trade.ScreenshotSlot?
    @State private var activeScreenshot: ScreenshotViewerItem?
    @State private var didAppear = false

    let trade: Trade

    init(trade: Trade) {
        self.trade = trade
        _viewModel = StateObject(wrappedValue: TradeDetailViewModel(trade: trade))
    }

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    tradeInformationSection
                    executionReviewSection
                    strategyReviewSection
                    journalSection
                    screenshotsSection
                    timelineSection
                    aiCoachSection
                    bottomActions
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }
        }
        .navigationTitle("Trade Workspace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $activeForm) { form in
            AddTradeView(mode: form.mode)
                .environmentObject(tradeViewModel)
        }
        .alert("Delete Trade?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                tradeViewModel.deleteTrade(trade)
                dismiss()
            }
        } message: {
            Text("This removes the trade from Dashboard, Calendar, and saved local history.")
        }
        .confirmationDialog("Delete Screenshot?", isPresented: deleteScreenshotBinding, titleVisibility: .visible) {
            Button("Delete Screenshot", role: .destructive) {
                if let screenshotToDelete {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        _ = tradeViewModel.updateScreenshot(trade, slot: screenshotToDelete, imageData: nil)
                    }
                    self.screenshotToDelete = nil
                }
            }

            Button("Cancel", role: .cancel) {
                screenshotToDelete = nil
            }
        } message: {
            Text("This removes the image from this trade only.")
        }
        .fullScreenCover(item: $activeScreenshot) { item in
            ScreenshotFullscreenViewer(item: item)
        }
        .alert("Review Saved", isPresented: $viewModel.showSavedConfirmation) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("Your execution review has been updated.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                didAppear = true
            }
        }
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(trade.pair)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        HStack(spacing: 8) {
                            badge(trade.direction.rawValue, color: trade.direction == .buy ? JPColors.profit : JPColors.loss)
                            badge(trade.status.rawValue, color: outcomeColor)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text(currency(trade.profitLoss))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(outcomeColor)
                            .minimumScaleFactor(0.66)
                            .lineLimit(1)

                        Text("R:R \(riskRewardText)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.warning)
                    }
                }

                Divider()
                    .overlay(JPColors.border)

                VStack(spacing: 12) {
                    detailRow("Trade Date", trade.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()), icon: "calendar")
                    detailRow("Session", trade.session.rawValue, icon: "clock")
                    detailRow("Strategy", trade.strategy.rawValue, icon: "point.topleft.down.curvedto.point.bottomright.up")
                }
            }
        }
        .shadow(color: outcomeColor.opacity(0.14), radius: 24, x: 0, y: 16)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
    }

    private var tradeInformationSection: some View {
        section(title: "Trade Information", subtitle: "Core price, risk, and sizing details") {
            LazyVGrid(columns: twoColumns, spacing: 12) {
                infoTile("Entry Price", number(trade.entryPrice), icon: "arrow.right.circle", tint: JPColors.accent)
                infoTile("Stop Loss", number(trade.stopLoss), icon: "xmark.octagon", tint: JPColors.loss)
                infoTile("Take Profit", number(trade.takeProfit), icon: "checkmark.seal", tint: JPColors.profit)
                infoTile("Exit Price", trade.exitPrice == 0 ? "--" : number(trade.exitPrice), icon: "flag", tint: JPColors.warning)
                infoTile("Lot Size", trade.lotSize == 0 ? "--" : number(trade.lotSize), icon: "square.stack.3d.up", tint: JPColors.blue)
                infoTile("Risk %", trade.riskPercent == 0 ? "--" : "\(number(trade.riskPercent))%", icon: "percent", tint: JPColors.purple)
                infoTile("Profit / Loss", currency(trade.profitLoss), icon: "dollarsign.circle", tint: outcomeColor)
                infoTile("Risk Reward", riskRewardText, icon: "scale.3d", tint: JPColors.warning)
            }
        }
    }

    private var executionReviewSection: some View {
        section(title: "Execution Review", subtitle: "Score the quality behind the outcome") {
            GlassCard {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Execution Score")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)

                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { score in
                                Button {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                                        viewModel.executionScore = score
                                    }
                                } label: {
                                    Image(systemName: score <= viewModel.executionScore ? "star.fill" : "star")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(JPColors.warning)
                                }
                                .buttonStyle(ScalingButtonStyle())
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Confidence")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)

                            Spacer()

                            Text("\(Int(viewModel.confidence.rounded())) / 10")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(JPColors.accent)
                        }

                        Slider(value: $viewModel.confidence, in: 1...10, step: 1)
                            .tint(JPColors.accent)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Emotion")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)

                        chipGrid(items: TradeDetailViewModel.emotions, selected: viewModel.emotion) { emotion in
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                viewModel.emotion = emotion
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Did I Follow My Plan?")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)

                        Picker("Did I Follow My Plan?", selection: $viewModel.followedPlan) {
                            Text("Yes").tag(true)
                            Text("No").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .tint(JPColors.accent)
                    }

                    Button {
                        viewModel.saveReview(for: trade, using: tradeViewModel)
                    } label: {
                        Label("Save Review", systemImage: "checkmark.circle.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(JPColors.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(ScalingButtonStyle())
                }
            }
        }
    }

    private var strategyReviewSection: some View {
        section(title: "Strategy Review", subtitle: "Setup, session, and behavior patterns") {
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    detailRow("Strategy", trade.strategy.rawValue, icon: "point.topleft.down.curvedto.point.bottomright.up")
                    detailRow("Session", trade.session.rawValue, icon: "clock")

                    Divider()
                        .overlay(JPColors.border)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mistake Tags")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(Trade.MistakeTag.allCases) { tag in
                                let isSelected = viewModel.selectedMistakeTags.contains(tag)

                                Button {
                                    if isSelected {
                                        viewModel.selectedMistakeTags.remove(tag)
                                    } else {
                                        viewModel.selectedMistakeTags.insert(tag)
                                    }
                                } label: {
                                    Text(tag.rawValue)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(isSelected ? JPColors.background : JPColors.secondaryText)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 36)
                                        .background(isSelected ? JPColors.accent : JPColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(isSelected ? JPColors.accent.opacity(0.52) : JPColors.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var journalSection: some View {
        section(title: "Journal", subtitle: "Expand each area into a richer trade story") {
            VStack(spacing: 14) {
                journalCard(title: "Trade Thesis", text: $viewModel.tradeThesis)
                journalCard(title: "Market Context", text: $viewModel.marketContext)
                journalCard(title: "Execution Review", text: $viewModel.executionReview)
                journalCard(title: "Lessons Learned", text: $viewModel.lessonsLearned)
            }
        }
    }

    private var screenshotsSection: some View {
        section(title: "Trade Timeline", subtitle: "Screenshots before, during, and after the trade") {
            VStack(spacing: 16) {
                if !hasScreenshots {
                    ScreenshotEmptyState { data in
                        saveScreenshot(data, for: .beforeEntry)
                    }
                }

                ForEach(Trade.ScreenshotSlot.allCases) { slot in
                    ScreenshotTimelineCard(
                        slot: slot,
                        imageData: screenshotData(for: slot),
                        onImageSelected: { data in
                            saveScreenshot(data, for: slot)
                        },
                        onDelete: {
                            screenshotToDelete = slot
                        },
                        onView: { data in
                            activeScreenshot = ScreenshotViewerItem(slot: slot, imageData: data)
                        }
                    )
                }
            }
        }
    }

    private var timelineSection: some View {
        section(title: "Trade Events", subtitle: "Key moments from this journal entry") {
            GlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(timelineEvents.enumerated()), id: \.element.id) { index, event in
                        TimelineEventRow(event: event, isLast: index == timelineEvents.count - 1)
                    }
                }
            }
        }
    }

    private var aiCoachSection: some View {
        NavigationLink {
            AITradeCoachView(trade: trade)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(JPColors.warning)
                    .frame(width: 50, height: 50)
                    .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: JPColors.warning.opacity(0.22), radius: 16, x: 0, y: 8)

                VStack(alignment: .leading, spacing: 5) {
                    Text("AI Trade Coach")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Open placeholder review workspace")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(JPColors.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(JPColors.graphite, in: Circle())
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [JPColors.elevatedSurface.opacity(0.96), JPColors.surface.opacity(0.90)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(JPColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(ScalingButtonStyle())
    }

    private var bottomActions: some View {
        VStack(spacing: 12) {
            Button {
                activeForm = TradeDetailForm(mode: .edit(trade))
            } label: {
                actionLabel("Edit Trade", icon: "square.and.pencil", foreground: JPColors.background, background: JPColors.accent)
            }
            .buttonStyle(ScalingButtonStyle())

            Button {
                activeForm = TradeDetailForm(mode: .duplicate(trade))
            } label: {
                actionLabel("Duplicate Trade", icon: "plus.square.on.square", foreground: JPColors.primaryText, background: JPColors.graphite)
            }
            .buttonStyle(ScalingButtonStyle())

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                actionLabel("Delete Trade", icon: "trash", foreground: JPColors.loss, background: JPColors.loss.opacity(0.12))
            }
            .buttonStyle(ScalingButtonStyle())
        }
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

    private var riskRewardText: String {
        String(format: "1:%.2f", trade.riskReward)
    }

    private var hasScreenshots: Bool {
        Trade.ScreenshotSlot.allCases.contains { screenshotData(for: $0) != nil }
    }

    private var deleteScreenshotBinding: Binding<Bool> {
        Binding(
            get: { screenshotToDelete != nil },
            set: { isPresented in
                if !isPresented {
                    screenshotToDelete = nil
                }
            }
        )
    }

    private var timelineEvents: [TradeTimelineEvent] {
        var events = [
            TradeTimelineEvent(time: trade.date, title: "Trade Created", icon: "doc.badge.plus"),
            TradeTimelineEvent(time: trade.tradeOpenTime ?? trade.date, title: "Entry Executed", icon: "play.circle")
        ]

        if hasScreenshots {
            events.append(TradeTimelineEvent(time: Date(), title: "Screenshot Added", icon: "camera.viewfinder"))
        }

        if let closeTime = trade.tradeCloseTime {
            events.append(TradeTimelineEvent(time: closeTime, title: "Trade Closed", icon: "stop.circle"))
        }

        if !trade.tradeThesis.isEmpty || !trade.marketContext.isEmpty || !trade.executionReview.isEmpty || !trade.lessonsLearned.isEmpty {
            events.append(TradeTimelineEvent(time: Date(), title: "Journal Updated", icon: "square.and.pencil"))
        }

        events.append(TradeTimelineEvent(time: nil, title: "Duration \(viewModel.durationText(for: trade))", icon: "timer"))

        return events
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

    private func saveScreenshot(_ data: Data, for slot: Trade.ScreenshotSlot) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            _ = tradeViewModel.updateScreenshot(trade, slot: slot, imageData: data)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func section<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle)
            content()
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
    }

    private func infoTile(_ title: String, _ value: String, icon: String, tint: Color) -> some View {
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
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        }
    }

    private func journalCard(title: String, text: Binding<String>) -> some View {
        DisclosureGroup {
            TextEditor(text: text)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .foregroundStyle(JPColors.primaryText)
                .padding(12)
                .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(JPColors.border, lineWidth: 1)
                )
                .padding(.top, 12)
        } label: {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(JPColors.primaryText)
        }
        .padding(18)
        .background(JPColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(JPColors.border, lineWidth: 1)
        )
    }

    private func chipGrid(items: [String], selected: String, action: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    action(item)
                } label: {
                    Text(item)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selected == item ? JPColors.background : JPColors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(selected == item ? JPColors.accent : JPColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selected == item ? JPColors.accent.opacity(0.52) : JPColors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
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

    private func actionLabel(_ title: String, icon: String, foreground: Color, background: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.headline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(JPColors.border, lineWidth: 1)
            )
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }

    private func number(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.4f", value)
    }
}

private struct TradeDetailForm: Identifiable {
    let id = UUID()
    let mode: AddTradeView.TradeFormMode
}

private struct ScreenshotViewerItem: Identifiable {
    let id = UUID()
    let slot: Trade.ScreenshotSlot
    let imageData: Data
}

private struct PickedScreenshot: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            PickedScreenshot(data: data)
        }
    }
}

private struct ScreenshotEmptyState: View {
    @State private var selectedItem: PhotosPickerItem?
    let onImageSelected: (Data) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(JPColors.accent)
                    .frame(width: 68, height: 68)
                    .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Build your visual journal")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Capture before, during and after every trade to improve your execution.")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Add First Screenshot", systemImage: "photo.badge.plus")
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
        .onChange(of: selectedItem) { _, newItem in
            importImage(from: newItem)
        }
    }

    private func importImage(from item: PhotosPickerItem?) {
        guard let item else {
            return
        }

        Task {
            guard
                let picked = try? await item.loadTransferable(type: PickedScreenshot.self),
                let compressed = Self.compressedImageData(from: picked.data)
            else {
                await MainActor.run {
                    selectedItem = nil
                }
                return
            }

            await MainActor.run {
                onImageSelected(compressed)
                selectedItem = nil
            }
        }
    }

    private static func compressedImageData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        let maxDimension: CGFloat = 1800
        let longestSide = max(image.size.width, image.size.height)
        let targetImage: UIImage

        if longestSide > maxDimension {
            let scale = maxDimension / longestSide
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        } else {
            targetImage = image
        }

        return targetImage.jpegData(compressionQuality: 0.78)
    }
}

private struct ScreenshotTimelineCard: View {
    @State private var selectedItem: PhotosPickerItem?

    let slot: Trade.ScreenshotSlot
    let imageData: Data?
    let onImageSelected: (Data) -> Void
    let onDelete: () -> Void
    let onView: (Data) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: slot.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(JPColors.accent)
                        .frame(width: 46, height: 46)
                        .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(slot.rawValue)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text(slot.subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()
                }

                imagePreview

                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label(imageData == nil ? slot.emptyActionTitle : "Replace Screenshot", systemImage: "photo.badge.plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(ScalingButtonStyle())

                    if imageData != nil {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(JPColors.loss)
                                .frame(width: 48, height: 42)
                                .background(JPColors.loss.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .buttonStyle(ScalingButtonStyle())
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            importImage(from: newItem)
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Button {
                onView(imageData)
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 230)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.42)],
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
                .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 12)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(JPColors.mutedText)

                Text(slot.emptyActionTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)

                Text("Import a chart screenshot from Photos.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(JPColors.border, lineWidth: 1)
            )
        }
    }

    private func importImage(from item: PhotosPickerItem?) {
        guard let item else {
            return
        }

        Task {
            guard
                let picked = try? await item.loadTransferable(type: PickedScreenshot.self),
                let compressed = Self.compressedImageData(from: picked.data)
            else {
                await MainActor.run {
                    selectedItem = nil
                }
                return
            }

            await MainActor.run {
                onImageSelected(compressed)
                selectedItem = nil
            }
        }
    }

    private static func compressedImageData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        let maxDimension: CGFloat = 1800
        let longestSide = max(image.size.width, image.size.height)
        let targetImage: UIImage

        if longestSide > maxDimension {
            let scale = maxDimension / longestSide
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        } else {
            targetImage = image
        }

        return targetImage.jpegData(compressionQuality: 0.78)
    }
}

private struct ScreenshotFullscreenViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    let item: ScreenshotViewerItem

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
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
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

private struct TradeTimelineEvent: Identifiable {
    let id = UUID()
    let time: Date?
    let title: String
    let icon: String
}

private struct TimelineEventRow: View {
    let event: TradeTimelineEvent
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: event.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.accent)
                    .frame(width: 34, height: 34)
                    .background(JPColors.accentSoft, in: Circle())

                if !isLast {
                    Rectangle()
                        .fill(JPColors.border)
                        .frame(width: 1, height: 34)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.time?.formatted(.dateTime.hour().minute()) ?? "—")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)

                Text(event.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
            }
            .padding(.top, 4)

            Spacer()
        }
    }
}
