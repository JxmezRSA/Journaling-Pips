import SwiftUI

struct AddTradeView: View {
    enum TradeFormMode {
        case create
        case edit(Trade)
        case duplicate(Trade)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tradeViewModel: TradeViewModel
    private let mode: TradeFormMode
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
    @State private var tradeThesis = ""
    @State private var marketContext = ""
    @State private var executionReview = ""
    @State private var lessonsLearned = ""
    @State private var tradeOpenTime = Date()
    @State private var tradeCloseTime = Date()
    @State private var hasCloseTime = false
    @State private var showSavedConfirmation = false
    @State private var didAttemptSave = false

    init(mode: TradeFormMode = .create) {
        self.mode = mode

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
            _tradeThesis = State(initialValue: trade.tradeThesis.isEmpty ? trade.notes : trade.tradeThesis)
            _marketContext = State(initialValue: trade.marketContext)
            _executionReview = State(initialValue: trade.executionReview)
            _lessonsLearned = State(initialValue: trade.lessonsLearned)
            _tradeOpenTime = State(initialValue: trade.tradeOpenTime ?? trade.date)
            _tradeCloseTime = State(initialValue: trade.tradeCloseTime ?? trade.date)
            _hasCloseTime = State(initialValue: trade.tradeCloseTime != nil)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JPColors.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        marketSection
                        riskSection
                        tradeInformationSection
                        reviewSection
                        timelineSection
                        journalSection
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle(navigationTitle)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert(successTitle, isPresented: $showSavedConfirmation) {
                Button("Done", role: .cancel) {
                    if closesAfterSave {
                        dismiss()
                    }
                }
            } message: {
                Text(successMessage)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headerTitle)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(JPColors.primaryText)

            Text("Capture the setup, risk, result, and execution quality.")
                .font(.subheadline)
                .foregroundStyle(JPColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var marketSection: some View {
        formSection(title: "Market", subtitle: "Instrument and direction") {
            tradeTextField(title: "Pair", placeholder: "EUR/USD", text: $pair, keyboard: .default, isRequired: true)
            segmentedSelector(title: "Direction", selection: $direction, options: Trade.Direction.allCases)
            segmentedSelector(title: "Outcome", selection: $outcome, options: Trade.Status.allCases)
        }
    }

    private var riskSection: some View {
        formSection(title: "Risk", subtitle: "Prices, result, and automatic R:R") {
            tradeTextField(title: "Entry Price", placeholder: "1.0832", text: $entryPrice, keyboard: .decimalPad, isRequired: true)
            tradeTextField(title: "Stop Loss", placeholder: "1.0790", text: $stopLoss, keyboard: .decimalPad, isRequired: true)
            tradeTextField(title: "Take Profit", placeholder: "1.0910", text: $takeProfit, keyboard: .decimalPad, isRequired: true)
            tradeTextField(title: "Profit / Loss", placeholder: "420", text: $profitLoss, keyboard: .numbersAndPunctuation, isRequired: true)

            riskRewardCard
        }
    }

    private var tradeInformationSection: some View {
        formSection(title: "Trade Information", subtitle: "Optional sizing and exit details") {
            tradeTextField(title: "Exit Price", placeholder: "1.0875", text: $exitPrice, keyboard: .decimalPad, isRequired: false)
            tradeTextField(title: "Lot Size", placeholder: "0.50", text: $lotSize, keyboard: .decimalPad, isRequired: false)
            tradeTextField(title: "Risk %", placeholder: "1.0", text: $riskPercent, keyboard: .decimalPad, isRequired: false)
        }
    }

    private var reviewSection: some View {
        formSection(title: "Review", subtitle: "Session, setup, and behavior") {
            menuSelector(title: "Session", selection: $session, options: Trade.Session.allCases)
            menuSelector(title: "Strategy", selection: $strategy, options: Trade.Strategy.allCases)
            mistakeTagsSelector
        }
    }

    private var timelineSection: some View {
        formSection(title: "Timeline", subtitle: "Open, close, and duration") {
            DatePicker("Trade Opened", selection: $tradeOpenTime)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JPColors.primaryText)
                .tint(JPColors.accent)

            Toggle("Trade Closed", isOn: $hasCloseTime)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JPColors.primaryText)
                .tint(JPColors.accent)

            if hasCloseTime {
                DatePicker("Trade Closed", selection: $tradeCloseTime)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(JPColors.primaryText)
                    .tint(JPColors.accent)
            }
        }
    }

    private var journalSection: some View {
        formSection(title: "Journal", subtitle: "Thesis, context, execution, and lessons") {
            journalEditor(title: "Trade Thesis", text: $tradeThesis)
            journalEditor(title: "Market Context", text: $marketContext)
            journalEditor(title: "Execution Review", text: $executionReview)
            journalEditor(title: "Lessons Learned", text: $lessonsLearned)
        }
    }

    private var riskRewardCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Risk : Reward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)

                Text(riskRewardDisplay)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(riskReward == nil ? JPColors.mutedText : JPColors.accent)
            }

            Spacer()

            Image(systemName: "scale.3d")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(JPColors.accent)
                .frame(width: 44, height: 44)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(16)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(JPColors.border, lineWidth: 1)
        )
    }

    private var mistakeTagsSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mistake Tags")
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)

            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(Trade.MistakeTag.allCases) { tag in
                    tagButton(tag)
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            didAttemptSave = true
            saveTrade()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isFormValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                Text(saveButtonTitle)
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(JPColors.background)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(isFormValid ? JPColors.accent : JPColors.mutedText, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: isFormValid ? JPColors.accent.opacity(0.22) : Color.clear, radius: 18, x: 0, y: 8)
        }
        .disabled(!isFormValid)
        .buttonStyle(ScalingButtonStyle())
    }

    private var isFormValid: Bool {
        fieldError(for: pair, requiredOnly: true) == nil
            && fieldError(for: entryPrice) == nil
            && fieldError(for: stopLoss) == nil
            && fieldError(for: takeProfit) == nil
            && fieldError(for: profitLoss) == nil
            && optionalNumberError(for: exitPrice) == nil
            && optionalNumberError(for: lotSize) == nil
            && optionalNumberError(for: riskPercent) == nil
    }

    private var riskReward: Double? {
        guard
            let entry = decimalValue(entryPrice),
            let stop = decimalValue(stopLoss),
            let target = decimalValue(takeProfit)
        else {
            return nil
        }

        let risk = abs(entry - stop)
        let reward = abs(target - entry)

        guard risk > 0, reward > 0 else {
            return nil
        }

        return reward / risk
    }

    private var riskRewardDisplay: String {
        guard let riskReward else {
            return "--"
        }

        return "1:\(String(format: "%.2f", riskReward))"
    }

    private func formSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, subtitle: subtitle)

            GlassCard {
                VStack(spacing: 18) {
                    content()
                }
            }
        }
    }

    private func tradeTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        isRequired: Bool
    ) -> some View {
        let error = validationMessage(for: text.wrappedValue, requiredOnly: title == "Pair", isRequired: isRequired)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)

                if isRequired {
                    Text("*")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.loss)
                }
            }

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(JPColors.primaryText)
                .tint(JPColors.accent)
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(error == nil ? JPColors.border : JPColors.loss.opacity(0.75), lineWidth: 1)
                )

            if let error {
                Text(error)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(JPColors.loss)
            }
        }
    }

    private func journalEditor(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)

            TextEditor(text: text)
                .frame(minHeight: 104)
                .scrollContentBackground(.hidden)
                .foregroundStyle(JPColors.primaryText)
                .padding(12)
                .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(JPColors.border, lineWidth: 1)
                )
        }
    }

    private func segmentedSelector<Value: RawRepresentable & CaseIterable & Identifiable & Hashable>(
        title: String,
        selection: Binding<Value>,
        options: [Value]
    ) -> some View where Value.RawValue == String {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
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

    private func menuSelector<Value: RawRepresentable & CaseIterable & Identifiable & Hashable>(
        title: String,
        selection: Binding<Value>,
        options: [Value]
    ) -> some View where Value.RawValue == String {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)

            Menu {
                ForEach(options) { option in
                    Button(option.rawValue) {
                        selection.wrappedValue = option
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.rawValue)
                        .foregroundStyle(JPColors.primaryText)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                }
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(JPColors.border, lineWidth: 1)
                )
            }
        }
    }

    private func tagButton(_ tag: Trade.MistakeTag) -> some View {
        let isSelected = selectedMistakeTags.contains(tag)

        return Button {
            if isSelected {
                selectedMistakeTags.remove(tag)
            } else {
                selectedMistakeTags.insert(tag)
            }
        } label: {
            Text(tag.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? JPColors.background : JPColors.secondaryText)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(isSelected ? JPColors.accent : JPColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? JPColors.accent.opacity(0.5) : JPColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var navigationTitle: String {
        switch mode {
        case .create:
            return "Add Trade"
        case .edit:
            return "Edit Trade"
        case .duplicate:
            return "Duplicate Trade"
        }
    }

    private var headerTitle: String {
        switch mode {
        case .create:
            return "Log a Trade"
        case .edit:
            return "Edit Trade"
        case .duplicate:
            return "Duplicate Trade"
        }
    }

    private var saveButtonTitle: String {
        switch mode {
        case .create:
            return "Save Trade"
        case .edit:
            return "Update Trade"
        case .duplicate:
            return "Save Duplicate"
        }
    }

    private var successTitle: String {
        switch mode {
        case .create, .duplicate:
            return "Trade Saved"
        case .edit:
            return "Trade Updated"
        }
    }

    private var successMessage: String {
        switch mode {
        case .create:
            return "Your trade has been saved locally."
        case .edit:
            return "Your trade workspace has been updated."
        case .duplicate:
            return "Your duplicate trade has been saved locally."
        }
    }

    private var closesAfterSave: Bool {
        switch mode {
        case .create:
            return false
        case .edit, .duplicate:
            return true
        }
    }

    private func validationMessage(for text: String, requiredOnly: Bool, isRequired: Bool) -> String? {
        guard didAttemptSave else {
            return nil
        }

        if !isRequired {
            return optionalNumberError(for: text)
        }

        return fieldError(for: text, requiredOnly: requiredOnly)
    }

    private func fieldError(for text: String, requiredOnly: Bool = false) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return "Required"
        }

        if !requiredOnly, decimalValue(text) == nil {
            return "Enter a valid number"
        }

        return nil
    }

    private func optionalNumberError(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return decimalValue(text) == nil ? "Enter a valid number" : nil
    }

    private func saveTrade() {
        guard
            let entryPriceValue = decimalValue(entryPrice),
            let stopLossValue = decimalValue(stopLoss),
            let takeProfitValue = decimalValue(takeProfit),
            let profitLossValue = decimalValue(profitLoss)
        else {
            return
        }

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
                profitLoss: profitLossValue,
                notes: tradeThesis,
                status: outcome,
                riskReward: riskReward ?? 0,
                session: session,
                strategy: strategy,
                mistakeTags: sortedTags,
                exitPrice: exitPriceValue,
                lotSize: lotSizeValue,
                riskPercent: riskPercentValue,
                tradeThesis: tradeThesis,
                marketContext: marketContext,
                executionReview: executionReview,
                lessonsLearned: lessonsLearned,
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
                profitLoss: profitLossValue,
                notes: tradeThesis,
                status: outcome,
                riskReward: riskReward ?? 0,
                session: session,
                strategy: strategy,
                mistakeTags: sortedTags,
                exitPrice: exitPriceValue,
                lotSize: lotSizeValue,
                riskPercent: riskPercentValue,
                tradeThesis: tradeThesis,
                marketContext: marketContext,
                executionReview: executionReview,
                lessonsLearned: lessonsLearned,
                tradeOpenTime: tradeOpenTime,
                tradeCloseTime: closeTime
            )
        }

        if didSave {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if case .create = mode {
                resetForm()
            }
            showSavedConfirmation = true
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
        tradeThesis = ""
        marketContext = ""
        executionReview = ""
        lessonsLearned = ""
        tradeOpenTime = Date()
        tradeCloseTime = Date()
        hasCloseTime = false
        didAttemptSave = false
    }

    private func decimalValue(_ text: String) -> Double? {
        let sanitized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        return Double(sanitized)
    }

    private static func numberText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(value)
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
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
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
