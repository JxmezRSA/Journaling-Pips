import PhotosUI
import SwiftUI
import UIKit

struct AddTradeView: View {
    enum TradeFormMode {
        case create
        case edit(Trade)
        case duplicate(Trade)
    }

    private enum TradeSection: String, CaseIterable, Identifiable {
        case basics = "Basics"
        case risk = "Risk"
        case execution = "Execution"
        case psychology = "Psychology"
        case checklist = "Checklist"
        case chartJournal = "Charts"
        case lessons = "Lessons"
        case coach = "AI Preview"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .basics: return "rectangle.and.pencil.and.ellipsis"
            case .risk: return "shield.lefthalf.filled"
            case .execution: return "bolt.fill"
            case .psychology: return "brain.head.profile"
            case .checklist: return "checklist.checked"
            case .chartJournal: return "photo.on.rectangle.angled"
            case .lessons: return "book.pages.fill"
            case .coach: return "sparkles"
            }
        }
    }

    private enum Field: Hashable {
        case pair
        case accountSize
        case riskPercent
        case dollarRisk
        case lotSize
        case stopLoss
        case takeProfit
        case entryPrice
        case exitPrice
        case profitLoss
        case partialClose
        case commission
        case spread
        case swap
        case wentWell
        case wentWrong
        case repeatAction
        case biggestLesson
    }

    private struct ChecklistItem: Identifiable, Codable, Equatable {
        let id: UUID
        var title: String
        var isComplete: Bool

        init(id: UUID = UUID(), title: String, isComplete: Bool = false) {
            self.id = id
            self.title = title
            self.isComplete = isComplete
        }
    }

    private struct Draft: Codable {
        var pair: String
        var direction: String
        var outcome: String
        var session: String
        var strategy: String
        var entryPrice: String
        var stopLoss: String
        var takeProfit: String
        var profitLoss: String
        var exitPrice: String
        var lotSize: String
        var riskPercent: String
        var accountSize: String
        var dollarRisk: String
        var partialClose: String
        var commission: String
        var spread: String
        var swap: String
        var confidence: Double
        var fear: Double
        var patience: Double
        var discipline: Double
        var mood: String
        var tradeThesis: String
        var marketContext: String
        var executionReview: String
        var lessonsLearned: String
    }

    private struct PreviewImage: Identifiable {
        let id = UUID()
        let slot: Trade.ScreenshotSlot
        let data: Data
    }

    private enum ScreenshotStatus: String {
        case empty = "Empty"
        case selected = "Selected"
        case uploading = "Uploading..."
        case uploaded = "Uploaded"
        case failed = "Upload failed"
        case queued = "Queued for sync"

        var icon: String {
            switch self {
            case .empty: return "circle"
            case .selected: return "checkmark.circle.fill"
            case .uploading: return "arrow.triangle.2.circlepath"
            case .uploaded: return "checkmark.icloud.fill"
            case .failed: return "exclamationmark.triangle.fill"
            case .queued: return "clock.badge.checkmark"
            }
        }

        var tint: Color {
            switch self {
            case .empty: return JPColors.secondaryText
            case .selected: return JPColors.accent
            case .uploading: return JPColors.warning
            case .uploaded: return JPColors.profit
            case .failed: return JPColors.loss
            case .queued: return JPColors.warning
            }
        }
    }

    private enum AddTradeStartupError: LocalizedError {
        case invalidDraftData

        var errorDescription: String? {
            switch self {
            case .invalidDraftData:
                return "Stored Add Trade draft could not be read."
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    @StateObject private var subscriptionManager = SubscriptionManager()
    @AppStorage("jp.addTradeDraft") private var draftStorage = ""
    @FocusState private var focusedField: Field?

    private let mode: TradeFormMode
    private let onSaveComplete: () -> Void

    @State private var pair = ""
    @State private var direction = Trade.Direction.buy
    @State private var outcome = Trade.Status.win
    @State private var session = Trade.Session.london
    @State private var strategy = Trade.Strategy.liquiditySweep
    @State private var selectedMistakeTags: Set<Trade.MistakeTag> = []
    @State private var entryPrice = ""
    @State private var stopLoss = ""
    @State private var takeProfit = ""
    @State private var profitLoss = ""
    @State private var exitPrice = ""
    @State private var lotSize = ""
    @State private var riskPercent = ""
    @State private var accountSize = ""
    @State private var dollarRisk = ""
    @State private var partialClose = ""
    @State private var commission = ""
    @State private var spread = ""
    @State private var swap = ""
    @State private var confidence = 7.0
    @State private var fear = 2.0
    @State private var patience = 7.0
    @State private var discipline = 8.0
    @State private var selectedMood = "Calm"
    @State private var checklist: [ChecklistItem] = Self.defaultChecklist
    @State private var tradeThesis = ""
    @State private var marketContext = ""
    @State private var executionReview = ""
    @State private var lessonsLearned = ""
    @State private var tradeOpenTime = Date()
    @State private var tradeCloseTime = Date()
    @State private var hasCloseTime = false
    @State private var beforeEntryImageData: Data?
    @State private var duringTradeImageData: Data?
    @State private var afterExitImageData: Data?
    @State private var beforePhotoItem: PhotosPickerItem?
    @State private var duringPhotoItem: PhotosPickerItem?
    @State private var afterPhotoItem: PhotosPickerItem?
    @State private var beforeScreenshotStatus = ScreenshotStatus.empty
    @State private var duringScreenshotStatus = ScreenshotStatus.empty
    @State private var afterScreenshotStatus = ScreenshotStatus.empty
    @State private var activePreview: PreviewImage?
    @State private var expandedSections = Set(TradeSection.allCases)
    @State private var selectedSection = TradeSection.basics
    @State private var didAppear = false
    @State private var didAttemptSave = false
    @State private var isSaving = false
    @State private var saveSucceeded = false
    @State private var showSuccessBanner = false
    @State private var showErrorToast = false
    @State private var showSavedConfirmation = false
    @State private var showDiscardDraftAlert = false
    @State private var showLeaveConfirmation = false
    @State private var showPaywall = false
    @State private var draftLoaded = false
    @State private var highlightedField: Field?
    @Namespace private var saveBarNamespace

    init(mode: TradeFormMode = .create, onSaveComplete: @escaping () -> Void = {}) {
        self.mode = mode
        self.onSaveComplete = onSaveComplete

        let sourceTrade: Trade?
        switch mode {
        case .create:
            sourceTrade = nil
        case .edit(let trade), .duplicate(let trade):
            sourceTrade = trade
        }

        if let trade = sourceTrade {
            _pair = State(initialValue: trade.pair)
            _direction = State(initialValue: trade.direction)
            _outcome = State(initialValue: trade.status)
            _session = State(initialValue: trade.session)
            _strategy = State(initialValue: trade.strategy)
            _selectedMistakeTags = State(initialValue: Set(trade.mistakeTags))
            _entryPrice = State(initialValue: Self.numberText(trade.entryPrice))
            _stopLoss = State(initialValue: Self.numberText(trade.stopLoss))
            _takeProfit = State(initialValue: Self.numberText(trade.takeProfit))
            _profitLoss = State(initialValue: Self.numberText(trade.profitLoss))
            _exitPrice = State(initialValue: trade.exitPrice == 0 ? "" : Self.numberText(trade.exitPrice))
            _lotSize = State(initialValue: trade.lotSize == 0 ? "" : Self.numberText(trade.lotSize))
            _riskPercent = State(initialValue: trade.riskPercent == 0 ? "" : Self.numberText(trade.riskPercent))
            let derivedDollarRisk = abs(trade.entryPrice - trade.stopLoss) * trade.lotSize
            _dollarRisk = State(initialValue: derivedDollarRisk == 0 ? "" : Self.numberText(derivedDollarRisk))
            _confidence = State(initialValue: trade.confidence)
            _selectedMood = State(initialValue: trade.emotion)
            _discipline = State(initialValue: trade.followedPlan ? 8 : 4)
            _checklist = State(initialValue: trade.followedPlan ? Self.defaultChecklist.map { ChecklistItem(id: $0.id, title: $0.title, isComplete: true) } : Self.defaultChecklist)
            _tradeThesis = State(initialValue: trade.tradeThesis.isEmpty ? trade.notes : trade.tradeThesis)
            _marketContext = State(initialValue: trade.marketContext)
            _executionReview = State(initialValue: trade.executionReview)
            _lessonsLearned = State(initialValue: trade.lessonsLearned)
            _tradeOpenTime = State(initialValue: trade.tradeOpenTime ?? trade.date)
            _tradeCloseTime = State(initialValue: trade.tradeCloseTime ?? trade.date)
            _hasCloseTime = State(initialValue: trade.tradeCloseTime != nil)
            _beforeEntryImageData = State(initialValue: trade.beforeEntryImageData)
            _duringTradeImageData = State(initialValue: trade.duringTradeImageData)
            _afterExitImageData = State(initialValue: trade.afterExitImageData)
        }

        debugPrint("ADD TRADE VIEW INIT")
        debugPrint("ADD TRADE INIT SUCCESS")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JPColors.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        heroHeader
                        basicsSection
                        riskSection
                        executionSection
                        psychologySection
                        checklistSection
                        chartJournalSection
                        lessonsSection
                        aiCoachPreviewSection
                        readyToSaveSection
                        simpleSaveSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 176)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    private var heroHeader: some View {
        let _ = debugPrint("ADD TRADE HERO HEADER START")
        let title: String = {
            switch mode {
            case .create: return "Create Trade"
            case .edit: return "Edit Trade"
            case .duplicate: return "Duplicate Trade"
            }
        }()
        let quote = "Every trade is another lesson."
        let journalCountText = "\(max(0, min(7, weeklyJournalCount))) of 7"
        let completionText = "\(Int(max(0, min(1, overallProgress)) * 100))%"
        let _ = debugPrint("ADD TRADE HERO HEADER READY")

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Build a clean, complete trade journal.")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "plus.forwardslash.minus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(JPColors.background)
                    .frame(width: 58, height: 58)
                    .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            Text("\"\(quote)\"")
                .font(.headline.weight(.bold))
                .foregroundStyle(JPColors.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(JPColors.graphite.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            HStack(spacing: 12) {
                progressPill(journalCountText, "journal entries this week", JPColors.warning)
                progressPill(completionText, "trade complete", JPColors.accent)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    JPColors.elevatedSurface,
                    JPColors.surface.opacity(0.92),
                    JPColors.graphite.opacity(0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        .shadow(color: JPColors.accent.opacity(0.08), radius: 22, x: 0, y: 14)
    }

    private func progressPill(_ value: String, _ title: String, _ tint: Color) -> some View {
        HStack(spacing: 9) {
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var sectionRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(TradeSection.allCases) { section in
                    Button {
                        JPHaptics.selection()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                            selectedSection = section
                            expandedSections.insert(section)
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: section.icon)
                            Text(section.rawValue)
                        }
                        .font(.caption.weight(.black))
                        .foregroundStyle(selectedSection == section ? JPColors.background : JPColors.secondaryText)
                        .padding(.horizontal, 13)
                        .frame(height: 38)
                        .background(selectedSection == section ? JPColors.accent : JPColors.graphite, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .premiumEntrance(active: didAppear, delay: 0.03)
    }

    private func premiumSection<Content: View>(_ section: TradeSection, progress: Double, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                JPHaptics.selection()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    if expandedSections.contains(section) {
                        expandedSections.remove(section)
                    } else {
                        expandedSections.insert(section)
                    }
                    selectedSection = section
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(JPColors.graphite, lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: min(1, max(0, progress)))
                            .stroke(sectionTint(section), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: section.icon)
                            .font(.caption.weight(.black))
                            .foregroundStyle(sectionTint(section))
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.rawValue)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)
                        Text("\(Int((progress * 100).rounded()))% complete")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: expandedSections.contains(section) ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.secondaryText)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JPColors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if expandedSections.contains(section) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        content()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.985)))
            }
        }
        .id(section.id)
        .premiumEntrance(active: didAppear, delay: Double(TradeSection.allCases.firstIndex(of: section) ?? 0) * 0.025)
    }

    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            premiumTextField("Instrument", placeholder: "EUR/USD", text: $pair, field: .pair, keyboard: .default, required: true)
            premiumSegmented("Direction", selection: $direction, options: Trade.Direction.allCases)
            menuSelector("Session", selection: $session, options: Trade.Session.allCases)
            menuSelector("Favorite Setup", selection: $strategy, options: Trade.Strategy.allCases)

            DatePicker("Trade Date", selection: $tradeOpenTime, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .tint(JPColors.accent)

            DatePicker("Trade Time", selection: $tradeOpenTime, displayedComponents: [.hourAndMinute])
                .datePickerStyle(.compact)
                .tint(JPColors.accent)

            quickSetupChips
        }
    }

    private var riskSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: twoColumns, spacing: 12) {
                premiumTextField("Account Size", placeholder: "10000", text: $accountSize, field: .accountSize, keyboard: .decimalPad)
                premiumTextField("Risk %", placeholder: "1.0", text: $riskPercent, field: .riskPercent, keyboard: .decimalPad, required: true)
                premiumTextField("Dollar Risk", placeholder: "100", text: $dollarRisk, field: .dollarRisk, keyboard: .decimalPad)
                premiumTextField("Lot Size", placeholder: "0.50", text: $lotSize, field: .lotSize, keyboard: .decimalPad, required: true)
                premiumTextField("Stop Loss", placeholder: "1.0790", text: $stopLoss, field: .stopLoss, keyboard: .decimalPad, required: true)
                premiumTextField("Take Profit", placeholder: "1.0910", text: $takeProfit, field: .takeProfit, keyboard: .decimalPad, required: true)
            }

            rrCalculatorCard
        }
    }

    private var executionSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            simpleExecutionTextField("Entry Price", placeholder: "1.0832", text: $entryPrice, keyboard: .decimalPad, required: true)
            simpleExecutionTextField("Exit Price", placeholder: "1.0875", text: $exitPrice, keyboard: .decimalPad)
            simpleExecutionTextField("Gross P/L", placeholder: "420", text: $profitLoss, keyboard: .decimalPad, required: true)
            simpleExecutionTextField("Partial Close", placeholder: "0", text: $partialClose, keyboard: .decimalPad)
            simpleExecutionTextField("Commission", placeholder: "0", text: $commission, keyboard: .decimalPad)
            simpleExecutionTextField("Spread", placeholder: "0", text: $spread, keyboard: .decimalPad)
            simpleExecutionTextField("Swap", placeholder: "0", text: $swap, keyboard: .decimalPad)

            Toggle("Trade Closed", isOn: $hasCloseTime)
                .font(.headline.weight(.semibold))
                .foregroundStyle(JPColors.primaryText)
                .tint(JPColors.accent)
                .padding(14)
                .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JPColors.border, lineWidth: 1))

            if hasCloseTime {
                DatePicker("Close Time", selection: $tradeCloseTime)
                    .tint(JPColors.accent)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(JPColors.primaryText)
                    .padding(14)
                    .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JPColors.border, lineWidth: 1))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            executionSummaryCard
        }
    }

    private var psychologySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            psychologySlider("Confidence", value: $confidence, tint: JPColors.accent)
            psychologySlider("Fear", value: $fear, tint: JPColors.loss)
            psychologySlider("Patience", value: $patience, tint: JPColors.warning)
            psychologySlider("Discipline", value: $discipline, tint: JPColors.profit)

            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(Self.moods, id: \.self) { mood in
                    chip(mood, isSelected: selectedMood == mood, tint: moodTint(mood)) {
                        selectedMood = mood
                    }
                }
            }
        }
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(JPColors.graphite, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: checklistCompletion)
                        .stroke(JPColors.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.84), value: checklistCompletion)
                    Text("\(Int((checklistCompletion * 100).rounded()))%")
                        .font(.headline.weight(.black))
                        .foregroundStyle(JPColors.primaryText)
                }
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Execution checklist")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                    Text("Complete this before saving to reinforce disciplined execution.")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                ForEach($checklist) { $item in
                    Button {
                        JPHaptics.selection()
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            item.isComplete.toggle()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(item.isComplete ? JPColors.accent : JPColors.secondaryText)
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JPColors.primaryText)
                            Spacer()
                        }
                        .padding(14)
                        .background(item.isComplete ? JPColors.accent.opacity(0.10) : JPColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var chartJournalSection: some View {
        VStack(spacing: 16) {
            screenshotCard(.beforeEntry, data: beforeEntryImageData, item: $beforePhotoItem)
            screenshotCard(.duringTrade, data: duringTradeImageData, item: $duringPhotoItem)
            screenshotCard(.afterExit, data: afterExitImageData, item: $afterPhotoItem)

            HStack(spacing: 10) {
                Image(systemName: "pencil.and.outline")
                    .foregroundStyle(JPColors.warning)
                Text("Drawing tools and captions are prepared as placeholders for the next chart markup sprint.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(JPColors.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            journalEditor("What went well?", text: $tradeThesis, field: .wentWell)
            journalEditor("What went wrong?", text: $marketContext, field: .wentWrong)
            journalEditor("What would you repeat?", text: $executionReview, field: .repeatAction)
            journalEditor("Biggest lesson?", text: $lessonsLearned, field: .biggestLesson)

            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.accent)
                    .frame(width: 44, height: 44)
                    .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Voice note")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                    Text("Coming soon. The journal is ready for future audio reflections.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }
            }
            .padding(14)
            .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var aiCoachPreviewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle().stroke(JPColors.graphite, lineWidth: 13)
                    Circle()
                        .trim(from: 0, to: aiPreviewScore / 100)
                        .stroke(aiPreviewColor, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\(Int(aiPreviewScore.rounded()))")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(aiPreviewColor)
                            .contentTransition(.numericText())
                        Text("score")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                }
                .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Coach Preview")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                    Text("Generated locally before saving. No backend or OpenAI call is made.")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            previewList("Likely Strengths", items: aiStrengths, tint: JPColors.profit, icon: "checkmark.circle.fill")
            previewList("Potential Improvements", items: aiImprovements, tint: JPColors.warning, icon: "arrow.up.forward.circle.fill")
        }
    }

    private var readyToSaveSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: isFormValid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(isFormValid ? JPColors.profit : JPColors.warning)
                        .frame(width: 58, height: 58)
                        .background((isFormValid ? JPColors.profit : JPColors.warning).opacity(0.14), in: RoundedRectangle(cornerRadius: 21, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trade Ready")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)

                        Text("Your journal is \(Int((overallProgress * 100).rounded()))% complete.")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)

                        Divider()
                            .overlay(JPColors.border)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Expected AI Discipline Score")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(JPColors.secondaryText)
                                    .textCase(.uppercase)

                                Text("\(Int(aiPreviewScore.rounded()))")
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                                    .foregroundStyle(aiPreviewColor)
                                    .contentTransition(.numericText())
                            }

                            Spacer()

                            Text(isFormValid ? "Everything looks ready." : "Complete the required fields.")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(isFormValid ? JPColors.profit : JPColors.warning)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 132, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.22)
    }

    private var simpleSaveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                didAttemptSave = true
                saveTrade()
            } label: {
                Text(simpleSaveButtonTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(simpleSaveButtonColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .disabled(isSaving || saveSucceeded)

            Text(simpleSaveStatusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(simpleSaveStatusColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(JPColors.border, lineWidth: 1))
    }

    private var simpleSaveButtonTitle: String {
        if isSaving { return "Saving..." }
        if saveSucceeded { return successTitle }
        return saveButtonTitle
    }

    private var simpleSaveButtonColor: Color {
        if isSaving { return JPColors.secondaryText }
        if saveSucceeded { return JPColors.profit }
        return isFormValid ? JPColors.accent : JPColors.warning
    }

    private var simpleSaveStatusText: String {
        if isSaving { return "Saving..." }
        if saveSucceeded { return "Trade saved" }
        if showErrorToast { return "Couldn't save trade. Please check your fields." }
        if didAttemptSave && !isFormValid { return "Please complete the required fields before saving." }
        return isFormValid ? "Ready to save." : "Required fields are still missing."
    }

    private var simpleSaveStatusColor: Color {
        if saveSucceeded { return JPColors.profit }
        if showErrorToast { return JPColors.loss }
        if didAttemptSave && !isFormValid { return JPColors.warning }
        return JPColors.secondaryText
    }

    private var bottomSaveSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                didAttemptSave = true
                guard isFormValid else {
                    JPHaptics.notify(.warning)
                    expandInvalidSections()
                    return
                }
                saveTrade()
            } label: {
                HStack(spacing: 12) {
                    if isSaving {
                        ProgressView()
                            .tint(JPColors.background)
                    } else if saveSucceeded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline.weight(.black))
                            .symbolEffect(.bounce, value: saveSucceeded)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.black))
                    }

                    Text(bottomSaveButtonTitle)
                        .font(.headline.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundStyle(JPColors.background)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 58)
                .background(bottomSaveButtonBackground, in: Capsule())
                .shadow(color: bottomSaveButtonShadow, radius: 18, x: 0, y: 10)
            }
            .buttonStyle(ScalingButtonStyle())
            .disabled(isSaving || saveSucceeded)
            .accessibilityLabel(bottomSaveAccessibilityLabel)

            if saveSucceeded {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Trade saved")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(JPColors.profit)
                    Text("Your journal is saved locally. Screenshots will sync in the background when available.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if showErrorToast {
                Text("Couldn't save trade. Please check your fields.")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.loss)
                    .transition(.opacity)
            } else if didAttemptSave && !isFormValid {
                Text("Complete the required fields before saving. \(remainingRequiredFieldCount) item\(remainingRequiredFieldCount == 1 ? "" : "s") still need attention.")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.warning)
                    .transition(.opacity)
            } else {
                Text(isFormValid ? "Ready to save. Local storage happens first; cloud sync can finish later." : "Complete the required fields to unlock Save Trade.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(isFormValid ? JPColors.accent.opacity(0.28) : JPColors.border, lineWidth: 1)
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: isSaving)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: saveSucceeded)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: isFormValid)
    }

    private var bottomSaveButtonTitle: String {
        if isSaving { return "Saving..." }
        if saveSucceeded { return "Trade saved" }
        return "Save Trade"
    }

    private var bottomSaveButtonBackground: LinearGradient {
        if saveSucceeded {
            return LinearGradient(colors: [JPColors.profit, JPColors.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if isFormValid {
            return LinearGradient(colors: [JPColors.profit.opacity(0.98), JPColors.accent.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [JPColors.graphite.opacity(0.92), JPColors.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var bottomSaveButtonShadow: Color {
        if saveSucceeded { return JPColors.profit.opacity(0.34) }
        return isFormValid ? JPColors.accent.opacity(0.24) : Color.black.opacity(0.24)
    }

    private var bottomSaveAccessibilityLabel: String {
        if isSaving { return "Saving trade" }
        if saveSucceeded { return "Trade saved" }
        if isFormValid { return "Save trade" }
        return "Save trade unavailable. Required fields are missing."
    }

    private var stickySaveActionBar: some View {
        VStack(spacing: 0) {
            floatingSaveCapsule
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 96)
        }
        .background(
            LinearGradient(
                colors: [
                    JPColors.background.opacity(0),
                    JPColors.background.opacity(0.62),
                    JPColors.background.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var floatingSaveCapsule: some View {
        Button {
            handleFloatingSaveTap()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(JPColors.graphite.opacity(0.9), lineWidth: 4)

                    Circle()
                        .trim(from: 0, to: requiredFieldProgress)
                        .stroke(saveAccentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .matchedGeometryEffect(id: "saveProgress", in: saveBarNamespace)

                    Text("\(Int((requiredFieldProgress * 100).rounded()))")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .contentTransition(.numericText())
                }
                .frame(width: 46, height: 46)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Trade Ready")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                        .textCase(.uppercase)

                    Text(saveProgressText)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    if isSaving {
                        PremiumInlineLoader(title: "Saving", tint: JPColors.background)
                            .transition(.scale.combined(with: .opacity))
                    } else if saveSucceeded {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .black))
                            .symbolEffect(.bounce, value: saveSucceeded)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Text(saveButtonText)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .contentTransition(.opacity)
                }
                .foregroundStyle(JPColors.background)
                .frame(minWidth: 112)
                .frame(height: 52)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(saveButtonBackground)
                        .matchedGeometryEffect(id: "saveButtonBackground", in: saveBarNamespace)
                )
                .shadow(color: saveButtonGlow, radius: 18, x: 0, y: 8)
            }
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                JPColors.border,
                                saveAccentColor.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: saveAccentColor.opacity(0.14), radius: 22, x: 0, y: 12)
            .shadow(color: Color.black.opacity(0.36), radius: 24, x: 0, y: 16)
        }
        .disabled(isSaving || saveSucceeded)
        .buttonStyle(ScalingButtonStyle())
        .accessibilityLabel(saveAccessibilityLabel)
        .accessibilityHint(isFormValid ? "Saves this trade." : "Moves to the first required field that needs attention.")
        .animation(.spring(response: 0.44, dampingFraction: 0.84), value: requiredFieldProgress)
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.82), value: isFormValid)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isSaving)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: saveSucceeded)
    }

    private var saveButtonText: String {
        if isSaving { return "Saving Trade..." }
        if saveSucceeded { return "Saved" }
        return isFormValid ? "Save Trade" : "Continue"
    }

    private var saveButtonBackground: LinearGradient {
        if saveSucceeded {
            return LinearGradient(colors: [JPColors.profit, JPColors.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if isFormValid {
            return LinearGradient(colors: [JPColors.profit.opacity(0.98), JPColors.accent.opacity(0.94)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(
            colors: [JPColors.warning.opacity(0.98), JPColors.warning.opacity(0.76)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var saveButtonGlow: Color {
        if saveSucceeded { return JPColors.profit.opacity(0.42) }
        return isFormValid ? JPColors.profit.opacity(0.30) : JPColors.warning.opacity(0.18)
    }

    private var saveAccentColor: Color {
        if saveSucceeded || isFormValid { return JPColors.accent }
        return JPColors.warning
    }

    private var saveProgressText: String {
        if isFormValid {
            return "\(Int((requiredFieldProgress * 100).rounded()))%"
        }
        if remainingRequiredFieldCount == 0 {
            return "Check Fields"
        }
        return "\(remainingRequiredFieldCount) Remaining"
    }

    private var saveAccessibilityLabel: String {
        if isFormValid {
            return "Trade ready. Save trade."
        }

        if remainingRequiredFieldCount == 0 {
            return "Trade details need attention. Continue."
        }

        return "Trade not ready. \(remainingRequiredFieldCount) required fields remaining. Continue."
    }

    private var rrCalculatorCard: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Live Risk : Reward")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                    .textCase(.uppercase)

                Text(riskRewardDisplay)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(rrColor)
                    .contentTransition(.numericText())

                Text(rrLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(rrColor)
            }

            Spacer()

            Image(systemName: "scale.3d")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(rrColor)
                .frame(width: 68, height: 68)
                .background(rrColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(18)
        .background(rrColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.spring(response: 0.44, dampingFraction: 0.82), value: riskReward)
    }

    private var executionSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pips")
                    .foregroundStyle(JPColors.secondaryText)
                Spacer()
                Text(pipsDisplay)
                    .foregroundStyle(JPColors.primaryText)
            }

            HStack {
                Text("Holding")
                    .foregroundStyle(JPColors.secondaryText)
                Spacer()
                Text(holdingTimeText)
                    .foregroundStyle(JPColors.primaryText)
            }

            HStack {
                Text("Net Profit")
                    .foregroundStyle(JPColors.secondaryText)
                Spacer()
                Text(currency(netProfit))
                    .foregroundStyle(JPColors.primaryText)
            }

            HStack {
                Text("R Multiple")
                    .foregroundStyle(JPColors.secondaryText)
                Spacer()
                Text(riskRewardDisplay)
                    .foregroundStyle(JPColors.primaryText)
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(14)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JPColors.border, lineWidth: 1))
    }

    private var quickSetupChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick setup tags")
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)

            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(Trade.MistakeTag.allCases) { tag in
                    chip(tag.rawValue, isSelected: selectedMistakeTags.contains(tag), tint: tag == .goodDiscipline ? JPColors.profit : JPColors.warning) {
                        if selectedMistakeTags.contains(tag) {
                            selectedMistakeTags.remove(tag)
                        } else {
                            selectedMistakeTags.insert(tag)
                        }
                    }
                }
            }
        }
    }

    private func premiumTextField(_ title: String, placeholder: String, text: Binding<String>, field: Field, keyboard: UIKeyboardType, required: Bool = false) -> some View {
        let baseError = validationMessage(for: text.wrappedValue, requiredOnly: title == "Instrument", isRequired: required)
        let error = field == .entryPrice ? (baseError ?? entryStopValidationMessage) : baseError

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                if required {
                    Text("*")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.loss)
                }
            }

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(title == "Instrument" ? .characters : .never)
                .autocorrectionDisabled()
                .foregroundStyle(JPColors.primaryText)
                .tint(JPColors.accent)
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(error == nil ? JPColors.border : JPColors.loss.opacity(0.8), lineWidth: 1)
                )

            if let error {
                Text(error)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.loss)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(required ? "\(title), required" : title)
    }

    private func fieldBackground(for field: Field) -> Color {
        if highlightedField == field {
            return JPColors.warning.opacity(0.14)
        }

        if focusedField == field {
            return JPColors.accent.opacity(0.12)
        }

        return JPColors.surface
    }

    private func simpleExecutionTextField(_ title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType, required: Bool = false) -> some View {
        let hasError = required && didAttemptSave && text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                if required {
                    Text("*")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.loss)
                }
            }

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(JPColors.primaryText)
                .tint(JPColors.accent)
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(hasError ? JPColors.loss.opacity(0.8) : JPColors.border, lineWidth: 1)
                )

            if hasError {
                Text("\(title) is required.")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.loss)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(required ? "\(title), required" : title)
    }

    private func journalEditor(_ title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)

            TextEditor(text: text)
                .focused($focusedField, equals: field)
                .frame(minHeight: 132)
                .scrollContentBackground(.hidden)
                .foregroundStyle(JPColors.primaryText)
                .padding(12)
                .background(focusedField == field ? JPColors.accent.opacity(0.10) : JPColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(focusedField == field ? JPColors.accent.opacity(0.6) : JPColors.border, lineWidth: 1))
        }
    }

    private func premiumSegmented<Value: RawRepresentable & CaseIterable & Identifiable & Hashable>(_ title: String, selection: Binding<Value>, options: [Value]) -> some View where Value.RawValue == String {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)

            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .tint(JPColors.accent)
        }
    }

    private func menuSelector<Value: RawRepresentable & CaseIterable & Identifiable & Hashable>(_ title: String, selection: Binding<Value>, options: [Value]) -> some View where Value.RawValue == String {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)

            Menu {
                ForEach(options) { option in
                    Button(option.rawValue) {
                        JPHaptics.selection()
                        selection.wrappedValue = option
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.rawValue)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(JPColors.primaryText)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.secondaryText)
                }
                .padding(.horizontal, 14)
                .frame(height: 56)
                .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(JPColors.border, lineWidth: 1))
            }
        }
    }

    private func chip(_ title: String, isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            JPHaptics.selection()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                action()
            }
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? JPColors.background : JPColors.secondaryText)
                .padding(.horizontal, 13)
                .frame(height: 38)
                .background(isSelected ? tint : JPColors.surface, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? tint.opacity(0.5) : JPColors.border, lineWidth: 1))
                .scaleEffect(isSelected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
    }

    private func psychologySlider(_ title: String, value: Binding<Double>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))/10")
                    .font(.caption.weight(.black))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }

            Slider(value: value, in: 1...10, step: 1) {
                Text(title)
            }
            .tint(tint)
        }
        .padding(14)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func screenshotCard(_ slot: Trade.ScreenshotSlot, data: Data?, item: Binding<PhotosPickerItem?>) -> some View {
        let selectedItemKey = String(describing: item.wrappedValue)
        let currentStatus: ScreenshotStatus = {
            switch slot {
            case .beforeEntry:
                return beforeScreenshotStatus
            case .duringTrade:
                return duringScreenshotStatus
            case .afterExit:
                return afterScreenshotStatus
            }
        }()
        let hasLocalImage = data != nil || item.wrappedValue != nil
        let statusText: String = {
            if currentStatus == .uploaded { return "Uploaded" }
            if currentStatus == .queued { return "Queued for sync" }
            return hasLocalImage ? "Image selected" : "No image selected"
        }()
        let _ = {
            switch slot {
            case .beforeEntry:
                debugPrint("SCREENSHOT STATUS BEFORE:", statusText)
            case .duringTrade:
                debugPrint("SCREENSHOT STATUS DURING:", statusText)
            case .afterExit:
                debugPrint("SCREENSHOT STATUS AFTER:", statusText)
            }
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(slot.rawValue)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                    Text(slot.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }
                Spacer()
                Image(systemName: slot.icon)
                    .foregroundStyle(JPColors.accent)
            }

            Button {
                if let data {
                    activePreview = PreviewImage(slot: slot, data: data)
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(JPColors.graphite)
                        .frame(height: 190)

                    if let data, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(JPColors.accent)
                            Text(slot.emptyActionTitle)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(JPColors.primaryText)
                            Text("Tap import to build a visual journal.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(JPColors.secondaryText)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(data == nil)

            HStack(spacing: 10) {
                PhotosPicker(selection: item, matching: .images) {
                    Label(data == nil ? "Add Screenshot" : "Replace", systemImage: "photo.badge.plus")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.background)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(JPColors.accent, in: Capsule())
                }

                if data != nil {
                    Button {
                        JPHaptics.notify(.warning)
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            setImageData(nil, for: slot)
                            setScreenshotStatus(.empty, for: slot)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption.weight(.black))
                            .foregroundStyle(JPColors.loss)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(JPColors.loss.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(currentStatus == .queued ? JPColors.warning : JPColors.secondaryText)
        }
        .padding(14)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .task(id: selectedItemKey) {
            loadPhoto(item.wrappedValue, for: slot)
        }
    }

    private func summaryTile(_ title: String, _ value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func previewList(_ title: String, items: [String], tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(JPColors.primaryText)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: icon)
                        .foregroundStyle(tint)
                    Text(item)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Button("Previous") { moveFocus(-1) }
                .disabled(focusedField == focusOrder.first)
            Button("Next") { moveFocus(1) }
                .disabled(focusedField == focusOrder.last)
            Spacer()
            Button("Done") { focusedField = nil }
                .fontWeight(.bold)
        }
    }

    private var twoColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private var isFormValid: Bool {
        fieldError(for: pair, requiredOnly: true) == nil
            && fieldError(for: entryPrice) == nil
            && fieldError(for: stopLoss) == nil
            && fieldError(for: takeProfit) == nil
            && fieldError(for: profitLoss) == nil
            && fieldError(for: lotSize) == nil
            && fieldError(for: riskPercent) == nil
            && entryStopValidationMessage == nil
            && optionalNumberError(for: exitPrice) == nil
            && optionalNumberError(for: accountSize) == nil
            && optionalNumberError(for: dollarRisk) == nil
            && optionalNumberError(for: partialClose) == nil
            && optionalNumberError(for: commission) == nil
            && optionalNumberError(for: spread) == nil
            && optionalNumberError(for: swap) == nil
    }

    private var requiredFieldProgress: Double {
        let checks = requiredFieldChecks.map(\.isComplete)
        guard !checks.isEmpty else { return 0 }
        return Double(checks.filter { $0 }.count) / Double(checks.count)
    }

    private var remainingRequiredFieldCount: Int {
        requiredFieldChecks.filter { !$0.isComplete }.count
    }

    private var firstInvalidField: Field? {
        if fieldError(for: pair, requiredOnly: true) != nil { return .pair }
        if fieldError(for: stopLoss) != nil { return .stopLoss }
        if fieldError(for: takeProfit) != nil { return .takeProfit }
        if fieldError(for: entryPrice) != nil { return .entryPrice }
        if entryStopValidationMessage != nil { return .entryPrice }
        if fieldError(for: profitLoss) != nil { return .profitLoss }
        if optionalNumberError(for: accountSize) != nil { return .accountSize }
        if fieldError(for: riskPercent) != nil { return .riskPercent }
        if optionalNumberError(for: dollarRisk) != nil { return .dollarRisk }
        if fieldError(for: lotSize) != nil { return .lotSize }
        if optionalNumberError(for: exitPrice) != nil { return .exitPrice }
        if optionalNumberError(for: partialClose) != nil { return .partialClose }
        if optionalNumberError(for: commission) != nil { return .commission }
        if optionalNumberError(for: spread) != nil { return .spread }
        if optionalNumberError(for: swap) != nil { return .swap }
        return nil
    }

    private var requiredFieldChecks: [(field: Field, isComplete: Bool)] {
        [
            (.pair, fieldError(for: pair, requiredOnly: true) == nil),
            (.entryPrice, fieldError(for: entryPrice) == nil),
            (.stopLoss, fieldError(for: stopLoss) == nil),
            (.takeProfit, fieldError(for: takeProfit) == nil),
            (.profitLoss, fieldError(for: profitLoss) == nil),
            (.riskPercent, fieldError(for: riskPercent) == nil),
            (.lotSize, fieldError(for: lotSize) == nil),
            (.entryPrice, entryStopValidationMessage == nil)
        ]
    }

    private var entryStopValidationMessage: String? {
        guard let entry = decimalValue(entryPrice), let stop = decimalValue(stopLoss) else { return nil }
        return abs(entry - stop) <= 0.000_000_1 ? "Entry cannot equal stop loss" : nil
    }

    private var riskReward: Double? {
        guard let entry = decimalValue(entryPrice), let stop = decimalValue(stopLoss), let target = decimalValue(takeProfit) else {
            return nil
        }
        let risk = abs(entry - stop)
        let reward = abs(target - entry)
        guard risk > 0, reward > 0 else { return nil }
        return reward / risk
    }

    private var riskRewardDisplay: String {
        guard let riskReward else { return "--" }
        return "1:\(String(format: "%.2f", riskReward))"
    }

    private var rrColor: Color {
        guard let riskReward else { return JPColors.mutedText }
        if riskReward >= 2 { return JPColors.profit }
        if riskReward >= 1 { return JPColors.warning }
        return JPColors.loss
    }

    private var rrLabel: String {
        guard let riskReward else { return "Add entry, stop, and target" }
        if riskReward >= 2 { return "Excellent R:R" }
        if riskReward >= 1 { return "Average R:R" }
        return "Poor R:R"
    }

    private var netProfit: Double {
        (decimalValue(profitLoss) ?? 0) - abs(decimalValue(commission) ?? 0) - abs(decimalValue(spread) ?? 0) - abs(decimalValue(swap) ?? 0)
    }

    private var pipsDisplay: String {
        guard let entry = decimalValue(entryPrice), let exit = decimalValue(exitPrice), entry > 0, exit > 0 else {
            return "--"
        }
        let multiplier = pair.uppercased().contains("JPY") ? 100 : 10_000
        let pips = abs(exit - entry) * Double(multiplier)
        return String(format: "%.1f", pips)
    }

    private var holdingTimeText: String {
        guard hasCloseTime else { return "Open" }
        let seconds = max(0, Int(tradeCloseTime.timeIntervalSince(tradeOpenTime)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private var checklistCompletion: Double {
        guard !checklist.isEmpty else { return 0 }
        return Double(checklist.filter(\.isComplete).count) / Double(checklist.count)
    }

    private var basicsProgress: Double {
        progress([!pair.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, true, true, true])
    }

    private var riskProgress: Double {
        progress([decimalValue(stopLoss) != nil, decimalValue(takeProfit) != nil, riskReward != nil, decimalValue(riskPercent) != nil || decimalValue(dollarRisk) != nil])
    }

    private var executionProgress: Double {
        progress([decimalValue(entryPrice) != nil, decimalValue(profitLoss) != nil, decimalValue(exitPrice) != nil, hasCloseTime])
    }

    private var psychologyProgress: Double {
        progress([confidence > 0, patience > 0, discipline > 0, !selectedMood.isEmpty])
    }

    private var chartJournalProgress: Double {
        progress([beforeEntryImageData != nil, duringTradeImageData != nil, afterExitImageData != nil])
    }

    private var lessonsProgress: Double {
        progress([
            !tradeThesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !marketContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !executionReview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !lessonsLearned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ])
    }

    private var overallProgress: Double {
        [basicsProgress, riskProgress, executionProgress, psychologyProgress, checklistCompletion, chartJournalProgress, lessonsProgress].reduce(0, +) / 7
    }

    private var aiPreviewScore: Double {
        var score = 45.0
        score += (riskReward ?? 0) >= 2 ? 16 : ((riskReward ?? 0) >= 1 ? 8 : 0)
        score += checklistCompletion * 14
        score += (discipline / 10) * 10
        score += (confidence / 10) * 6
        score += chartJournalProgress * 5
        score += lessonsProgress * 4
        score -= fear > 7 ? 8 : 0
        return min(100, max(0, score))
    }

    private var aiPreviewColor: Color {
        if aiPreviewScore >= 80 { return JPColors.profit }
        if aiPreviewScore >= 60 { return JPColors.warning }
        return JPColors.loss
    }

    private var aiStrengths: [String] {
        var items: [String] = []
        if (riskReward ?? 0) >= 2 { items.append("Excellent RR") }
        if patience >= 7 { items.append("Good patience") }
        if discipline >= 8 { items.append("Strong discipline") }
        if checklistCompletion >= 0.75 { items.append("Checklist mostly complete") }
        return items.isEmpty ? ["Clearer structure is forming as you complete the trade plan."] : items
    }

    private var aiImprovements: [String] {
        var items: [String] = []
        if (riskReward ?? 0) < 1 { items.append("RR may be too low for a high-quality setup.") }
        if fear > 6 { items.append("Fear is elevated. Review whether position size is comfortable.") }
        if checklistCompletion < 0.75 { items.append("Complete the checklist before saving.") }
        if chartJournalProgress == 0 { items.append("Add at least one screenshot to strengthen the visual journal.") }
        return items.isEmpty ? ["Keep documenting the setup and let the trade play out according to plan."] : items
    }

    private var weeklyJournalCount: Int {
        Calendar.current.component(.weekday, from: Date()) - 1
    }

    private var tradingQuote: String {
        "Every trade is another lesson."
    }

    private var navigationTitle: String {
        switch mode {
        case .create: return "Add Trade"
        case .edit: return "Edit Trade"
        case .duplicate: return "Duplicate Trade"
        }
    }

    private var headerTitle: String {
        switch mode {
        case .create: return "Create Trade"
        case .edit: return "Edit Trade"
        case .duplicate: return "Duplicate Trade"
        }
    }

    private var saveButtonTitle: String {
        switch mode {
        case .create: return "Save Trade"
        case .edit: return "Update Trade"
        case .duplicate: return "Save Duplicate"
        }
    }

    private var successTitle: String {
        switch mode {
        case .create, .duplicate: return "Trade Saved"
        case .edit: return "Trade Updated"
        }
    }

    private var successMessage: String {
        switch mode {
        case .create: return "Your trade has been saved locally and added to your dashboard."
        case .edit: return "Your trade workspace has been updated."
        case .duplicate: return "Your duplicate trade has been saved locally."
        }
    }

    private var closesAfterSave: Bool {
        switch mode {
        case .create: return false
        case .edit, .duplicate: return true
        }
    }

    private var draftSignature: String {
        [
            pair, direction.rawValue, outcome.rawValue, session.rawValue, strategy.rawValue,
            entryPrice, stopLoss, takeProfit, profitLoss, exitPrice, lotSize, riskPercent,
            accountSize, dollarRisk, partialClose, commission, spread, swap, selectedMood,
            tradeThesis, marketContext, executionReview, lessonsLearned
        ].joined(separator: "|") + checklist.map { "\($0.title):\($0.isComplete)" }.joined(separator: "|")
    }

    private var focusOrder: [Field] {
        [.pair, .accountSize, .riskPercent, .dollarRisk, .lotSize, .stopLoss, .takeProfit, .entryPrice, .exitPrice, .profitLoss, .partialClose, .commission, .spread, .swap, .wentWell, .wentWrong, .repeatAction, .biggestLesson]
    }

    private func sectionTint(_ section: TradeSection) -> Color {
        switch section {
        case .basics, .coach: return JPColors.accent
        case .risk: return rrColor
        case .execution: return netProfit >= 0 ? JPColors.profit : JPColors.loss
        case .psychology: return JPColors.purple
        case .checklist, .lessons: return JPColors.warning
        case .chartJournal: return JPColors.blue
        }
    }

    private func moodTint(_ mood: String) -> Color {
        switch mood {
        case "Fearful", "Revenge", "Greedy": return JPColors.loss
        case "Overconfident": return JPColors.warning
        default: return JPColors.accent
        }
    }

    private func progress(_ checks: [Bool]) -> Double {
        guard !checks.isEmpty else { return 0 }
        return Double(checks.filter { $0 }.count) / Double(checks.count)
    }

    private func validationMessage(for text: String, requiredOnly: Bool, isRequired: Bool) -> String? {
        guard didAttemptSave else { return nil }
        if !isRequired { return optionalNumberError(for: text) }
        return fieldError(for: text, requiredOnly: requiredOnly)
    }

    private func handleFloatingSaveTap() {
        didAttemptSave = true
        focusedField = nil

        guard isFormValid else {
            JPHaptics.impact(.light)
            markFirstInvalidField()
            return
        }

        saveTrade()
    }

    private func markFirstInvalidField() {
        guard let field = firstInvalidField else { return }

        expandSections(containing: field)
        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.78)) {
            highlightedField = field
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard highlightedField == field else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                highlightedField = nil
            }
        }
    }

    private func expandSections(containing field: Field) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            switch field {
            case .pair:
                expandedSections.insert(.basics)
                selectedSection = .basics
            case .accountSize, .riskPercent, .dollarRisk, .lotSize, .stopLoss, .takeProfit:
                expandedSections.insert(.risk)
                selectedSection = .risk
            case .entryPrice, .exitPrice, .profitLoss, .partialClose, .commission, .spread, .swap:
                expandedSections.insert(.execution)
                selectedSection = .execution
            case .wentWell, .wentWrong, .repeatAction, .biggestLesson:
                expandedSections.insert(.lessons)
                selectedSection = .lessons
            }
        }
    }

    private func fieldError(for text: String, requiredOnly: Bool = false) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Required" }
        if !requiredOnly, decimalValue(text) == nil { return "Enter a valid number" }
        return nil
    }

    private func optionalNumberError(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return decimalValue(text) == nil ? "Enter a valid number" : nil
    }

    private func saveTrade() {
        guard !isSaving else { return }
        if shouldBlockFreeTradeLimit {
            showPaywall = true
            JPHaptics.notify(.warning)
            return
        }

        guard let entryPriceValue = decimalValue(entryPrice),
              let stopLossValue = decimalValue(stopLoss),
              let takeProfitValue = decimalValue(takeProfit),
              decimalValue(profitLoss) != nil else {
            JPHaptics.notify(.error)
            expandInvalidSections()
            return
        }

        isSaving = true
        saveSucceeded = false
        JPHaptics.impact(.medium)

        let exitPriceValue = decimalValue(exitPrice) ?? 0
        let lotSizeValue = decimalValue(lotSize) ?? 0
        let riskPercentValue = decimalValue(riskPercent) ?? 0
        let sortedTags = selectedMistakeTags.sorted { $0.rawValue < $1.rawValue }
        let closeTime = hasCloseTime ? tradeCloseTime : nil

        let didSave: Bool
        switch mode {
        case .create, .duplicate:
            didSave = tradeViewModel.addTrade(
                pair: pair,
                direction: direction,
                entryPrice: entryPriceValue,
                stopLoss: stopLossValue,
                takeProfit: takeProfitValue,
                profitLoss: netProfit,
                notes: tradeThesis,
                status: outcome,
                riskReward: riskReward ?? 0,
                session: session,
                strategy: strategy,
                mistakeTags: sortedTags,
                confidence: confidence,
                emotion: selectedMood,
                executionScore: Int(discipline.rounded()),
                followedPlan: checklistCompletion >= 1,
                exitPrice: exitPriceValue,
                lotSize: lotSizeValue,
                riskPercent: riskPercentValue,
                tradeThesis: tradeThesis,
                marketContext: marketContext,
                executionReview: executionReview,
                lessonsLearned: lessonsLearned,
                beforeEntryImageData: beforeEntryImageData,
                duringTradeImageData: duringTradeImageData,
                afterExitImageData: afterExitImageData,
                tradeOpenTime: tradeOpenTime,
                tradeCloseTime: closeTime
            )
        case .edit(let trade):
            didSave = tradeViewModel.applyTradeForm(
                to: trade,
                pair: pair,
                direction: direction,
                entryPrice: entryPriceValue,
                stopLoss: stopLossValue,
                takeProfit: takeProfitValue,
                profitLoss: netProfit,
                notes: tradeThesis,
                status: outcome,
                riskReward: riskReward ?? 0,
                session: session,
                strategy: strategy,
                mistakeTags: sortedTags,
                confidence: confidence,
                emotion: selectedMood,
                executionScore: Int(discipline.rounded()),
                followedPlan: checklistCompletion >= 1,
                exitPrice: exitPriceValue,
                lotSize: lotSizeValue,
                riskPercent: riskPercentValue,
                tradeThesis: tradeThesis,
                marketContext: marketContext,
                executionReview: executionReview,
                lessonsLearned: lessonsLearned,
                beforeEntryImageData: beforeEntryImageData,
                duringTradeImageData: duringTradeImageData,
                afterExitImageData: afterExitImageData,
                tradeOpenTime: tradeOpenTime,
                tradeCloseTime: closeTime
            )
        }

        if didSave {
            markScreenshotsQueuedForSync()
            JPHaptics.notify(.success)
            clearDraft()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                isSaving = false
                saveSucceeded = true
                showSuccessBanner = true
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                completeAfterSave()
            }
        } else {
            isSaving = false
            JPHaptics.notify(.error)
            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                showErrorToast = true
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                    showErrorToast = false
                }
            }
        }
    }

    private var shouldBlockFreeTradeLimit: Bool {
        guard !subscriptionManager.isPremiumUnlocked, tradeViewModel.trades.count >= 100 else {
            return false
        }

        switch mode {
        case .create, .duplicate:
            return true
        case .edit:
            return false
        }
    }

    private func completeAfterSave() {
        saveSucceeded = false
        showSuccessBanner = false
        if case .create = mode {
            resetForm()
            onSaveComplete()
        }
        if closesAfterSave {
            dismiss()
        }
    }

    private func attemptToLeave() {
        focusedField = nil
        if hasUnsavedChanges {
            showLeaveConfirmation = true
        } else {
            dismissOrComplete()
        }
    }

    private func dismissOrComplete() {
        if case .create = mode {
            onSaveComplete()
        } else {
            dismiss()
        }
    }

    private var hasUnsavedChanges: Bool {
        if case .create = mode {
            return hasMeaningfulDraft
        }
        return true
    }

    private var hasMeaningfulDraft: Bool {
        [
            pair,
            entryPrice,
            stopLoss,
            takeProfit,
            profitLoss,
            exitPrice,
            lotSize,
            riskPercent,
            accountSize,
            dollarRisk,
            partialClose,
            commission,
            spread,
            swap,
            tradeThesis,
            marketContext,
            executionReview,
            lessonsLearned
        ]
        .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        || beforeEntryImageData != nil
        || duringTradeImageData != nil
        || afterExitImageData != nil
        || checklist.contains(where: \.isComplete)
    }

    private func expandInvalidSections() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            expandedSections.insert(.basics)
            expandedSections.insert(.risk)
            expandedSections.insert(.execution)
        }
    }

    private func resetForm() {
        pair = ""
        direction = .buy
        outcome = .win
        session = .london
        strategy = .liquiditySweep
        selectedMistakeTags.removeAll()
        entryPrice = ""
        stopLoss = ""
        takeProfit = ""
        profitLoss = ""
        exitPrice = ""
        lotSize = ""
        riskPercent = ""
        accountSize = ""
        dollarRisk = ""
        partialClose = ""
        commission = ""
        spread = ""
        swap = ""
        confidence = 7
        fear = 2
        patience = 7
        discipline = 8
        selectedMood = "Calm"
        checklist = Self.defaultChecklist
        tradeThesis = ""
        marketContext = ""
        executionReview = ""
        lessonsLearned = ""
        beforeEntryImageData = nil
        duringTradeImageData = nil
        afterExitImageData = nil
        tradeOpenTime = Date()
        tradeCloseTime = Date()
        hasCloseTime = false
        didAttemptSave = false
    }

    private func autosaveDraft() {
        guard case .create = mode else { return }
        let draft = Draft(
            pair: pair,
            direction: direction.rawValue,
            outcome: outcome.rawValue,
            session: session.rawValue,
            strategy: strategy.rawValue,
            entryPrice: entryPrice,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            profitLoss: profitLoss,
            exitPrice: exitPrice,
            lotSize: lotSize,
            riskPercent: riskPercent,
            accountSize: accountSize,
            dollarRisk: dollarRisk,
            partialClose: partialClose,
            commission: commission,
            spread: spread,
            swap: swap,
            confidence: confidence,
            fear: fear,
            patience: patience,
            discipline: discipline,
            mood: selectedMood,
            tradeThesis: tradeThesis,
            marketContext: marketContext,
            executionReview: executionReview,
            lessonsLearned: lessonsLearned
        )
        if let data = try? JSONEncoder().encode(draft), let text = String(data: data, encoding: .utf8) {
            draftStorage = text
        }
    }

    private func loadDraft() throws {
        guard case .create = mode, !draftStorage.isEmpty else {
            return
        }

        guard let data = draftStorage.data(using: .utf8) else {
            throw AddTradeStartupError.invalidDraftData
        }

        let draft = try JSONDecoder().decode(Draft.self, from: data)
        pair = draft.pair
        direction = Trade.Direction(rawValue: draft.direction) ?? .buy
        outcome = Trade.Status(rawValue: draft.outcome) ?? .win
        session = Trade.Session(rawValue: draft.session) ?? .london
        strategy = Trade.Strategy(rawValue: draft.strategy) ?? .liquiditySweep
        entryPrice = draft.entryPrice
        stopLoss = draft.stopLoss
        takeProfit = draft.takeProfit
        profitLoss = draft.profitLoss
        exitPrice = draft.exitPrice
        lotSize = draft.lotSize
        riskPercent = draft.riskPercent
        accountSize = draft.accountSize
        dollarRisk = draft.dollarRisk
        partialClose = draft.partialClose
        commission = draft.commission
        spread = draft.spread
        swap = draft.swap
        confidence = draft.confidence
        fear = draft.fear
        patience = draft.patience
        discipline = draft.discipline
        selectedMood = draft.mood
        tradeThesis = draft.tradeThesis
        marketContext = draft.marketContext
        executionReview = draft.executionReview
        lessonsLearned = draft.lessonsLearned
    }

    private func clearDraft() {
        draftStorage = ""
    }

    private func loadPhoto(_ item: PhotosPickerItem?, for slot: Trade.ScreenshotSlot) {
        guard let item else { return }
        setScreenshotStatus(.uploading, for: slot)
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    setScreenshotStatus(.failed, for: slot)
                }
                return
            }
            let compressed = compressImageData(data) ?? data
            await MainActor.run {
                JPHaptics.notify(.success)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    setImageData(compressed, for: slot)
                    setScreenshotStatus(.selected, for: slot)
                }
            }
        }
    }

    private func setImageData(_ data: Data?, for slot: Trade.ScreenshotSlot) {
        switch slot {
        case .beforeEntry:
            beforeEntryImageData = data
            beforePhotoItem = nil
        case .duringTrade:
            duringTradeImageData = data
            duringPhotoItem = nil
        case .afterExit:
            afterExitImageData = data
            afterPhotoItem = nil
        }
    }

    private func screenshotStatus(for slot: Trade.ScreenshotSlot, data: Data?) -> ScreenshotStatus {
        let currentStatus: ScreenshotStatus
        switch slot {
        case .beforeEntry:
            currentStatus = beforeScreenshotStatus
        case .duringTrade:
            currentStatus = duringScreenshotStatus
        case .afterExit:
            currentStatus = afterScreenshotStatus
        }

        if data == nil, currentStatus != .failed, currentStatus != .uploading {
            return .empty
        }

        if data != nil, currentStatus == .empty {
            return .selected
        }

        return currentStatus
    }

    private func setScreenshotStatus(_ status: ScreenshotStatus, for slot: Trade.ScreenshotSlot) {
        switch slot {
        case .beforeEntry:
            beforeScreenshotStatus = status
        case .duringTrade:
            duringScreenshotStatus = status
        case .afterExit:
            afterScreenshotStatus = status
        }
    }

    private func markScreenshotsQueuedForSync() {
        if beforeEntryImageData != nil {
            setScreenshotStatus(.queued, for: .beforeEntry)
        }
        if duringTradeImageData != nil {
            setScreenshotStatus(.queued, for: .duringTrade)
        }
        if afterExitImageData != nil {
            setScreenshotStatus(.queued, for: .afterExit)
        }
    }

    private func compressImageData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 1800
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }

    private func moveFocus(_ offset: Int) {
        guard let focusedField, let index = focusOrder.firstIndex(of: focusedField) else {
            self.focusedField = focusOrder.first
            return
        }
        let nextIndex = min(max(index + offset, 0), focusOrder.count - 1)
        self.focusedField = focusOrder[nextIndex]
    }

    private func decimalValue(_ text: String) -> Double? {
        let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
        return Double(sanitized)
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.2f", abs(value)))"
    }

    private static func numberText(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(value)
    }

    private static let defaultChecklist = [
        ChecklistItem(title: "Waited for confirmation"),
        ChecklistItem(title: "Followed trading plan"),
        ChecklistItem(title: "Correct position size"),
        ChecklistItem(title: "No emotional entry"),
        ChecklistItem(title: "News checked"),
        ChecklistItem(title: "Liquidity sweep confirmed"),
        ChecklistItem(title: "Market structure confirmed"),
        ChecklistItem(title: "Trend aligned")
    ]

    private static let moods = ["Confident", "Calm", "Fearful", "Revenge", "Greedy", "Patient", "Focused", "Overconfident"]
}

private struct ScreenshotPreview: View {
    let imageData: Data
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in scale = max(1, min(value, 4)) }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            scale = scale > 1 ? 1 : 2
                        }
                    }
                    .padding()
            }

            VStack {
                HStack {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding()

                Spacer()
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        let rows = rows(in: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * rowSpacing
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(in: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func rows(in maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentItems: [RowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width
            if proposedWidth > maxWidth, !currentItems.isEmpty {
                rows.append(Row(items: currentItems, height: currentHeight))
                currentItems = [RowItem(subview: subview, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(RowItem(subview: subview, size: size))
                currentWidth = proposedWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(Row(items: currentItems, height: currentHeight))
        }
        return rows
    }

    private struct Row {
        let items: [RowItem]
        let height: CGFloat
    }

    private struct RowItem {
        let subview: LayoutSubview
        let size: CGSize
    }
}
