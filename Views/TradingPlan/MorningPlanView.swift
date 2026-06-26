import SwiftData
import SwiftUI

struct MorningPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PlanViewModel()
    @State private var didAppear = false
    @State private var symbolText = ""
    @State private var goalText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                JPColors.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        greeting

                        if !viewModel.hasConfiguredAnything {
                            onboardingHint
                        }

                        marketBiasSection
                        watchlistSection
                        riskPlanSection
                        checklistSection
                        readinessSection
                        notesSection
                        goalsSection
                        summarySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 112)
                }
            }
            .navigationTitle("Plan")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            viewModel.configure(context: modelContext)

            withAnimation(.easeOut(duration: 0.45)) {
                didAppear = true
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.greeting)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(JPColors.primaryText)

                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
            }

            Text("\"\(viewModel.quote)\"")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(JPColors.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(JPColors.border, lineWidth: 1)
                )
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 10)
    }

    private var onboardingHint: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(JPColors.warning)
                    .frame(width: 64, height: 64)
                    .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Prepare before you trade.")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Set your bias, risk limits, watchlist, and checklist before the session begins.")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 14)
    }

    private var marketBiasSection: some View {
        formSection(title: "Today's Market Bias", subtitle: "Choose the stance you will trade from") {
            Picker("Market Bias", selection: Binding(
                get: { viewModel.bias },
                set: { viewModel.setBias($0) }
            )) {
                ForEach(MorningPlan.MarketBias.allCases) { bias in
                    Text(bias.rawValue).tag(bias)
                }
            }
            .pickerStyle(.segmented)
            .tint(JPColors.accent)
        }
    }

    private var watchlistSection: some View {
        formSection(title: "Watchlist", subtitle: "Symbols you are willing to trade today") {
            HStack(spacing: 10) {
                TextField("EUR/USD", text: $symbolText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(JPColors.primaryText)
                    .tint(JPColors.accent)
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(JPColors.border, lineWidth: 1)
                    )

                Button {
                    viewModel.addSymbol(symbolText)
                    symbolText = ""
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.background)
                        .frame(width: 52, height: 52)
                        .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(ScalingButtonStyle())
            }

            if viewModel.watchlist.isEmpty {
                hintRow(icon: "binoculars.fill", title: "No symbols yet", message: "Add pairs or indices you are actively watching.")
            } else {
                PlanFlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(viewModel.watchlist, id: \.self) { symbol in
                        HStack(spacing: 8) {
                            Text(symbol)
                                .font(.caption.weight(.bold))

                            Button {
                                viewModel.deleteSymbol(symbol)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(JPColors.primaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(JPColors.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var riskPlanSection: some View {
        formSection(title: "Daily Risk Plan", subtitle: "Define today's hard limits before execution") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                riskInput(title: "Maximum Risk %", value: $viewModel.maximumRiskPercent, icon: "percent", tint: JPColors.warning)
                riskInput(title: "Maximum Daily Loss", value: $viewModel.maximumDailyLoss, icon: "arrow.down.right", tint: JPColors.loss)
                riskInput(title: "Maximum Trades", value: $viewModel.maximumTrades, icon: "number", tint: JPColors.blue)
                riskInput(title: "Daily Profit Goal", value: $viewModel.dailyProfitGoal, icon: "arrow.up.right", tint: JPColors.profit)
            }
        }
        .onChange(of: viewModel.maximumRiskPercent) { _, _ in viewModel.updateRiskPlan() }
        .onChange(of: viewModel.maximumDailyLoss) { _, _ in viewModel.updateRiskPlan() }
        .onChange(of: viewModel.maximumTrades) { _, _ in viewModel.updateRiskPlan() }
        .onChange(of: viewModel.dailyProfitGoal) { _, _ in viewModel.updateRiskPlan() }
    }

    private var checklistSection: some View {
        formSection(title: "Trading Checklist", subtitle: "\(viewModel.completionPercentage)% complete") {
            ForEach(viewModel.checklist) { item in
                Button {
                    viewModel.toggleChecklist(item)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(item.isComplete ? JPColors.accent : JPColors.secondaryText)

                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.primaryText)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var readinessSection: some View {
        let progress = Double(viewModel.completionPercentage) / 100

        return GlassCard {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(JPColors.graphite, lineWidth: 13)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [JPColors.accent, JPColors.warning, JPColors.profit, JPColors.accent],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 13, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.55, dampingFraction: 0.86), value: progress)

                    Text("\(viewModel.completionPercentage)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                }
                .frame(width: 116, height: 116)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trading Readiness")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)

                    Text(viewModel.readinessRating)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(readinessColor)

                    Text("Calculated from your completed pre-market checklist.")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
    }

    private var notesSection: some View {
        formSection(title: "Daily Notes", subtitle: "Your calm plan for the session") {
            ZStack(alignment: .topLeading) {
                if viewModel.dailyNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("What is today's plan?")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.mutedText)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 20)
                }

                TextEditor(text: Binding(
                    get: { viewModel.dailyNotes },
                    set: { viewModel.updateNotes($0) }
                ))
                .frame(minHeight: 150)
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
    }

    private var goalsSection: some View {
        formSection(title: "Daily Goals", subtitle: "Specific commitments for today's session") {
            HStack(spacing: 10) {
                TextField("Take only London trades.", text: $goalText)
                    .foregroundStyle(JPColors.primaryText)
                    .tint(JPColors.accent)
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(JPColors.border, lineWidth: 1)
                    )

                Button {
                    viewModel.addGoal(goalText)
                    goalText = ""
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.background)
                        .frame(width: 52, height: 52)
                        .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(ScalingButtonStyle())
            }

            if viewModel.goals.isEmpty {
                hintRow(icon: "scope", title: "No goals yet", message: "Add one rule that will make today a cleaner trading day.")
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.goals) { goal in
                        HStack(spacing: 12) {
                            Button {
                                viewModel.toggleGoal(goal)
                            } label: {
                                Image(systemName: goal.isComplete ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(goal.isComplete ? JPColors.accent : JPColors.secondaryText)
                            }
                            .buttonStyle(.plain)

                            Text(goal.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(JPColors.primaryText)
                                .strikethrough(goal.isComplete, color: JPColors.secondaryText)

                            Spacer()

                            Button {
                                viewModel.deleteGoal(goal)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(JPColors.loss)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Morning Briefing", subtitle: "Your command-center summary")

            GlassCard {
                VStack(spacing: 14) {
                    summaryRow("Today's Bias", viewModel.bias.rawValue, icon: "arrow.triangle.branch")
                    summaryRow("Current Risk", "\(viewModel.maximumRiskPercent)%", icon: "shield.lefthalf.filled")
                    summaryRow("Watchlist Count", "\(viewModel.watchlistCount)", icon: "binoculars.fill")
                    summaryRow("Checklist", "\(viewModel.completionPercentage)%", icon: "checklist")
                    summaryRow("Readiness Score", viewModel.readinessRating, icon: "gauge.with.dots.needle.bottom.50percent")
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
    }

    private func formSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle)

            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
        .animation(.spring(response: 0.44, dampingFraction: 0.88).delay(0.08), value: didAppear)
    }

    private func riskInput(title: String, value: Binding<String>, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .foregroundStyle(JPColors.primaryText)
                .tint(JPColors.accent)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
        .background(JPColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(JPColors.border, lineWidth: 1)
        )
    }

    private func hintRow(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(JPColors.accent)
                .frame(width: 46, height: 46)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)

                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryRow(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.accent)
                .frame(width: 30, height: 30)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(JPColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var readinessColor: Color {
        switch viewModel.completionPercentage {
        case 100:
            return JPColors.accent
        case 75..<100:
            return JPColors.profit
        case 40..<75:
            return JPColors.warning
        default:
            return JPColors.loss
        }
    }
}

private struct PlanFlowLayout: Layout {
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
