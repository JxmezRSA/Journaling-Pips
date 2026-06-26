import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var reportViewModel = ReportViewModel()
    @State private var didAppear = false

    var body: some View {
        NavigationStack {
            ZStack {
                JPColors.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        profileHero
                        profileSection
                        aiPreferencesSection
                        themeSection
                        notificationSection
                        dataManagementSection
                        appInfoSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 112)
                }
            }
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .alert("Coming Soon", isPresented: comingSoonBinding) {
            Button("Done", role: .cancel) {
                viewModel.comingSoonMessage = nil
            }
        } message: {
            Text(viewModel.comingSoonMessage ?? "This feature is coming soon.")
        }
        .alert("Export Failed", isPresented: reportErrorBinding) {
            Button("Done", role: .cancel) {
                reportViewModel.errorMessage = nil
            }
        } message: {
            Text(reportViewModel.errorMessage ?? "The report could not be generated.")
        }
        .sheet(item: $reportViewModel.shareItem) { item in
            ReportShareSheet(url: item.url)
        }
        .onAppear {
            viewModel.configure(context: modelContext)
            reportViewModel.configure(context: modelContext)

            withAnimation(.easeOut(duration: 0.45)) {
                didAppear = true
            }
        }
        .onChange(of: viewModel.name) { _, _ in viewModel.saveProfile() }
        .onChange(of: viewModel.tradingExperience) { _, _ in viewModel.saveProfile() }
        .onChange(of: viewModel.tradingStyle) { _, _ in viewModel.saveProfile() }
        .onChange(of: viewModel.preferredMarkets) { _, _ in viewModel.saveProfile() }
        .onChange(of: viewModel.accountSize) { _, _ in viewModel.saveProfile() }
        .onChange(of: viewModel.accountType) { _, _ in viewModel.saveProfile() }
        .onChange(of: viewModel.baseCurrency) { _, _ in viewModel.saveProfile() }
        .onChange(of: viewModel.coachingStyle) { _, _ in viewModel.saveProfile() }
        .onChange(of: viewModel.themePreference) { _, _ in viewModel.saveProfile() }
        .onChange(of: viewModel.morningPreparationReminder) { _, _ in viewModel.saveProfile() }
        .onChange(of: viewModel.tradeReviewReminder) { _, _ in viewModel.saveProfile() }
        .onChange(of: viewModel.weeklyPerformanceReview) { _, _ in viewModel.saveProfile() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile & Preferences")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(JPColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tune Journaling Pips around your trading identity.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 10)
    }

    private var profileHero: some View {
        GlassCard {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [JPColors.accent.opacity(0.90), JPColors.blue.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(initials)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.background)
                }
                .frame(width: 82, height: 82)
                .shadow(color: JPColors.accent.opacity(0.22), radius: 22, x: 0, y: 10)

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your Trading Profile" : viewModel.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)

                    Text("\(viewModel.tradingExperience.rawValue) • \(viewModel.tradingStyle.rawValue)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)

                    Text("\(viewModel.accountType.rawValue) account • \(viewModel.baseCurrency.rawValue)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.accent)
                }

                Spacer(minLength: 0)
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 16)
    }

    private var profileSection: some View {
        settingsSection(title: "User Profile", subtitle: "Stored locally on this device") {
            SettingsTextField(title: "Name", placeholder: "Your name", text: $viewModel.name, keyboard: .default)
            SettingsMenuPicker(title: "Trading Experience", selection: $viewModel.tradingExperience, options: UserProfile.TradingExperience.allCases)
            SettingsMenuPicker(title: "Trading Style", selection: $viewModel.tradingStyle, options: UserProfile.TradingStyle.allCases)
            SettingsTextField(title: "Preferred Markets", placeholder: "EUR/USD, NAS100, XAU/USD", text: $viewModel.preferredMarkets, keyboard: .default)
            SettingsTextField(title: "Account Size", placeholder: "10000", text: $viewModel.accountSize, keyboard: .decimalPad)
            SettingsMenuPicker(title: "Account Type", selection: $viewModel.accountType, options: UserProfile.AccountType.allCases)
            SettingsMenuPicker(title: "Base Currency", selection: $viewModel.baseCurrency, options: UserProfile.BaseCurrency.allCases)
        }
    }

    private var aiPreferencesSection: some View {
        settingsSection(title: "AI Preferences", subtitle: "Prepared for future coaching") {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(JPColors.warning)
                    .frame(width: 52, height: 52)
                    .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Trade Coach")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Coming Soon")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.warning)
                }

                Spacer()
            }

            SettingsMenuPicker(title: "Coaching Style", selection: $viewModel.coachingStyle, options: UserProfile.CoachingStyle.allCases)
        }
    }

    private var themeSection: some View {
        settingsSection(title: "Theme Preferences", subtitle: "Stored now, full theme switching later") {
            SettingsSegmentedPicker(title: "Theme", selection: $viewModel.themePreference, options: UserProfile.ThemePreference.allCases)
        }
    }

    private var notificationSection: some View {
        settingsSection(title: "Notification Preferences", subtitle: "Placeholders only, no notifications yet") {
            SettingsToggleRow(title: "Morning preparation reminder", icon: "sunrise.fill", isOn: $viewModel.morningPreparationReminder)
            SettingsToggleRow(title: "Trade review reminder", icon: "checkmark.seal.fill", isOn: $viewModel.tradeReviewReminder)
            SettingsToggleRow(title: "Weekly performance review", icon: "calendar.badge.clock", isOn: $viewModel.weeklyPerformanceReview)
        }
    }

    private var dataManagementSection: some View {
        settingsSection(title: "Data Management", subtitle: "Export and backup tools") {
            SettingsActionButton(title: "Export CSV", icon: "tablecells", tint: JPColors.accent) {
                viewModel.showComingSoon("Export CSV")
            }
            SettingsActionButton(title: "Export Daily Report", icon: "doc.richtext", tint: JPColors.profit, isLoading: reportViewModel.isGenerating) {
                reportViewModel.export(.daily)
            }
            SettingsActionButton(title: "Export Weekly Report", icon: "calendar.badge.clock", tint: JPColors.warning, isLoading: reportViewModel.isGenerating) {
                reportViewModel.export(.weekly)
            }
            SettingsActionButton(title: "Export Monthly Report", icon: "chart.bar.doc.horizontal", tint: JPColors.blue, isLoading: reportViewModel.isGenerating) {
                reportViewModel.export(.monthly)
            }
            SettingsActionButton(title: "Export All-Time Report", icon: "chart.line.uptrend.xyaxis", tint: JPColors.purple, isLoading: reportViewModel.isGenerating) {
                reportViewModel.export(.allTime)
            }
            SettingsActionButton(title: "Backup Data", icon: "externaldrive.badge.plus", tint: JPColors.blue) {
                viewModel.showComingSoon("Backup Data")
            }
            SettingsActionButton(title: "Restore Data", icon: "arrow.counterclockwise.circle", tint: JPColors.warning) {
                viewModel.showComingSoon("Restore Data")
            }
        }
    }

    private var appInfoSection: some View {
        settingsSection(title: "App Info", subtitle: "Built for disciplined traders") {
            SettingsInfoRow(title: "App Name", value: "Journaling Pips", icon: "app.badge")
            SettingsInfoRow(title: "Version", value: "0.5", icon: "number.circle")
            SettingsInfoRow(title: "Purpose", value: "Built for disciplined traders", icon: "target")
        }
    }

    private func settingsSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle)

            GlassCard {
                VStack(spacing: 16) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
        .animation(.spring(response: 0.44, dampingFraction: 0.88).delay(0.08), value: didAppear)
    }

    private var initials: String {
        let parts = viewModel.name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)

        let value = String(parts).uppercased()
        return value.isEmpty ? "JP" : value
    }

    private var comingSoonBinding: Binding<Bool> {
        Binding(
            get: { viewModel.comingSoonMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.comingSoonMessage = nil
                }
            }
        )
    }

    private var reportErrorBinding: Binding<Bool> {
        Binding(
            get: { reportViewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    reportViewModel.errorMessage = nil
                }
            }
        )
    }
}

private struct SettingsTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboard: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)

            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .foregroundStyle(JPColors.primaryText)
                .tint(JPColors.accent)
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

private struct SettingsMenuPicker<Value: RawRepresentable & CaseIterable & Identifiable & Hashable>: View where Value.RawValue == String {
    let title: String
    @Binding var selection: Value
    let options: [Value]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)

            Menu {
                ForEach(options) { option in
                    Button(option.rawValue) {
                        selection = option
                    }
                }
            } label: {
                HStack {
                    Text(selection.rawValue)
                        .foregroundStyle(JPColors.primaryText)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                }
                .font(.subheadline.weight(.semibold))
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
}

private struct SettingsSegmentedPicker<Value: RawRepresentable & CaseIterable & Identifiable & Hashable>: View where Value.RawValue == String {
    let title: String
    @Binding var selection: Value
    let options: [Value]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)

            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .tint(JPColors.accent)
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JPColors.primaryText)
        }
        .tint(JPColors.accent)
        .padding(14)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SettingsActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(JPColors.primaryText)

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(tint)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.mutedText)
                }
            }
            .padding(14)
            .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(JPColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(ScalingButtonStyle())
        .disabled(isLoading)
    }
}

private struct ReportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

private struct SettingsInfoRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.accent)
                .frame(width: 34, height: 34)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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
}
