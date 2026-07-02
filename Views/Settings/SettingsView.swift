import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var reportViewModel = ReportViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var syncViewModel = SyncViewModel()
    @State private var didAppear = false
    @State private var showDiagnostics = false
    @State private var showPaywall = false
    @State private var showProfileDetails = false
    @State private var showPreferenceDetails = false
    @State private var showAdvancedSettings = false

    var body: some View {
        settingsNavigation
            .modifier(SettingsPresentationModifier(viewModel: viewModel, reportViewModel: reportViewModel))
            .modifier(SettingsLifecycleModifier(
                viewModel: viewModel,
                reportViewModel: reportViewModel,
                authViewModel: authViewModel,
                syncViewModel: syncViewModel,
                didAppear: $didAppear
            ))
    }

    private var settingsNavigation: some View {
        NavigationStack {
            ZStack {
                JPColors.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        accountSection
                        subscriptionSection
                        cloudSyncSummarySection
                        preferencesSummarySection
                        dataDiagnosticsSummarySection
                        supportFeedbackSection
                        advancedSettingsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 112)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView()
                .environmentObject(subscriptionManager)
        }
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
            profileFields
        }
    }

    private var profileFields: some View {
        Group {
            SettingsTextField(title: "Name", placeholder: "Your name", text: $viewModel.name, keyboard: .default)
            SettingsMenuPicker(title: "Trading Experience", selection: $viewModel.tradingExperience, options: UserProfile.TradingExperience.allCases)
            SettingsMenuPicker(title: "Trading Style", selection: $viewModel.tradingStyle, options: UserProfile.TradingStyle.allCases)
            SettingsTextField(title: "Preferred Markets", placeholder: "EUR/USD, NAS100, XAU/USD", text: $viewModel.preferredMarkets, keyboard: .default)
            SettingsTextField(title: "Account Size", placeholder: "10000", text: $viewModel.accountSize, keyboard: .decimalPad)
            SettingsMenuPicker(title: "Account Type", selection: $viewModel.accountType, options: UserProfile.AccountType.allCases)
            SettingsMenuPicker(title: "Base Currency", selection: $viewModel.baseCurrency, options: UserProfile.BaseCurrency.allCases)
        }
    }

    private var accountSection: some View {
        settingsSection(title: "Account", subtitle: authViewModel.isCloudAuthenticated ? "Cloud profile connected" : "Offline trader profile") {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [JPColors.accent.opacity(0.90), JPColors.blue.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))

                    Text(initials)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.background)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your Trading Profile" : viewModel.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .lineLimit(2)

                    Text("\(viewModel.tradingExperience.rawValue) • \(viewModel.tradingStyle.rawValue)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)

                    Text(authViewModel.isCloudAuthenticated ? authViewModel.cloudUser?.email ?? "Cloud account" : "Offline Trader")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.accent)
                }

                Spacer(minLength: 0)
            }

            DisclosureGroup(isExpanded: $showProfileDetails) {
                VStack(spacing: 16) {
                    profileFields
                }
                .padding(.top, 10)
            } label: {
                SettingsDisclosureLabel(title: "Profile Details", subtitle: "Name, markets, account type", icon: "person.text.rectangle")
            }
            .tint(JPColors.accent)
        }
    }

    private var cloudProfileSection: some View {
        settingsSection(title: "Cloud Account", subtitle: authViewModel.isCloudAuthenticated ? syncViewModel.state.rawValue : SyncState.offline.rawValue) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [JPColors.accent, JPColors.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 68, height: 68)

                    if let data = authViewModel.cloudUser?.profileImage, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 68, height: 68)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(JPColors.background)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(authViewModel.isCloudAuthenticated && authViewModel.cloudUser?.displayName.isEmpty == false ? authViewModel.cloudUser?.displayName ?? "Offline Trader" : "Offline Trader")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text(authViewModel.isCloudAuthenticated && authViewModel.cloudUser?.email.isEmpty == false ? authViewModel.cloudUser?.email ?? "No cloud account" : "No cloud account")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)

                    Text("Subscription: \(authViewModel.cloudUser?.subscriptionTier.rawValue ?? CloudUser.SubscriptionTier.free.rawValue)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.accent)
                }

                Spacer()
            }

            SettingsInfoRow(title: "Cloud Status", value: authViewModel.isCloudAuthenticated ? syncViewModel.state.rawValue : SyncState.offline.rawValue, icon: "icloud")
            SettingsInfoRow(title: "Last Sync", value: syncViewModel.lastSyncText, icon: "clock.arrow.circlepath")
            SettingsInfoRow(title: "Pending Items", value: syncViewModel.pendingItemsText, icon: "tray.and.arrow.up")
            SettingsInfoRow(title: "Storage Used", value: syncViewModel.storageUsed, icon: "externaldrive")

            SettingsActionButton(title: "Sync Now", icon: "arrow.triangle.2.circlepath.icloud", tint: JPColors.accent) {
                runPremiumAction {
                    syncViewModel.syncNow()
                }
            }

            if authViewModel.isCloudAuthenticated {
                Button {
                    authViewModel.logout()
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(JPColors.loss)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(JPColors.loss.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(ScalingButtonStyle())
            } else {
                Text("Offline Mode. Your data is safely stored locally.")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var subscriptionSection: some View {
        settingsSection(title: "Subscription", subtitle: subscriptionManager.status.rawValue) {
            HStack(spacing: 14) {
                Image(systemName: subscriptionManager.isPremiumUnlocked ? "crown.fill" : "crown")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(subscriptionManager.isPremiumUnlocked ? JPColors.warning : JPColors.accent)
                    .frame(width: 54, height: 54)
                    .background((subscriptionManager.isPremiumUnlocked ? JPColors.warning : JPColors.accent).opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(subscriptionManager.isPremiumUnlocked ? "Premium Active" : "Free Plan")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text(subscriptionManager.isTrialActive ? subscriptionManager.trialRemainingText : "Upgrade for AI Coach, Vision, Replay, Analytics, Cloud Sync, and Reports.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            SettingsInfoRow(title: "Current Plan", value: subscriptionManager.status.rawValue, icon: "person.badge.key.fill")
            SettingsInfoRow(title: "Subscription Renewal", value: renewalText, icon: "calendar.badge.clock")

            SettingsActionButton(title: "Upgrade", icon: "sparkles", tint: JPColors.accent) {
                showPaywall = true
            }

            SettingsActionButton(title: "Restore Purchases", icon: "arrow.clockwise.circle", tint: JPColors.blue, isLoading: subscriptionManager.isRestoring) {
                subscriptionManager.restorePurchases()
            }

            SettingsActionButton(title: "Manage Subscription", icon: "creditcard", tint: JPColors.warning) {
                subscriptionManager.openManageSubscriptions()
            }

            if let message = subscriptionManager.purchaseMessage {
                Text(message)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.profit)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = subscriptionManager.errorMessage {
                Text(error)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var aiPreferencesSection: some View {
        settingsSection(title: "AI Preferences", subtitle: "Backend-ready coaching") {
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

                    Text(viewModel.aiBackendStatus)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(viewModel.aiBackendStatus == "Connected" ? JPColors.profit : JPColors.warning)
                }

                Spacer()
            }

            SettingsInfoRow(
                title: "AI Backend Status",
                value: viewModel.aiBackendStatus,
                icon: viewModel.aiBackendStatus == "Connected" ? "checkmark.icloud.fill" : "icloud.slash"
            )
            SettingsMenuPicker(title: "Coaching Style", selection: $viewModel.coachingStyle, options: UserProfile.CoachingStyle.allCases)
            SettingsActionButton(title: "Test AI Connection", icon: "antenna.radiowaves.left.and.right", tint: JPColors.accent, isLoading: viewModel.isTestingAIConnection) {
                viewModel.testAIConnection()
            }
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

    private var smartCoachingSection: some View {
        settingsSection(title: "Smart Coaching", subtitle: "Local intelligence controls") {
            SettingsToggleRow(title: "Enable Insights", icon: "sparkles", isOn: $viewModel.smartInsightsEnabled)
            SettingsToggleRow(title: "Enable Daily Coaching", icon: "sun.max.fill", isOn: $viewModel.dailyCoachingEnabled)
            SettingsToggleRow(title: "Enable Weekly Summary", icon: "calendar.badge.clock", isOn: $viewModel.weeklySummaryEnabled)
        }
    }

    private var cloudSyncSummarySection: some View {
        settingsSection(title: "Cloud Sync", subtitle: authViewModel.isCloudAuthenticated ? syncViewModel.state.rawValue : SyncState.offline.rawValue) {
            SettingsInfoRow(title: "Cloud Status", value: authViewModel.isCloudAuthenticated ? syncViewModel.state.rawValue : SyncState.offline.rawValue, icon: "icloud")
            SettingsInfoRow(title: "Last Sync", value: syncViewModel.lastSyncText, icon: "clock.arrow.circlepath")
            SettingsInfoRow(title: "Pending Items", value: syncViewModel.pendingItemsText, icon: "tray.and.arrow.up")

            SettingsActionButton(title: "Sync Now", icon: "arrow.triangle.2.circlepath.icloud", tint: JPColors.accent) {
                runPremiumAction {
                    syncViewModel.syncNow()
                }
            }

            if authViewModel.isCloudAuthenticated {
                Button {
                    authViewModel.logout()
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(JPColors.loss)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(JPColors.loss.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(ScalingButtonStyle())
            } else {
                Text("Offline Mode. Your data is safely stored locally.")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var preferencesSummarySection: some View {
        settingsSection(title: "Preferences", subtitle: "AI coaching, theme, reminders") {
            SettingsMenuPicker(title: "Coaching Style", selection: $viewModel.coachingStyle, options: UserProfile.CoachingStyle.allCases)
            SettingsSegmentedPicker(title: "Theme", selection: $viewModel.themePreference, options: UserProfile.ThemePreference.allCases)

            DisclosureGroup(isExpanded: $showPreferenceDetails) {
                VStack(spacing: 16) {
                    SettingsToggleRow(title: "Morning preparation reminder", icon: "sunrise.fill", isOn: $viewModel.morningPreparationReminder)
                    SettingsToggleRow(title: "Trade review reminder", icon: "checkmark.seal.fill", isOn: $viewModel.tradeReviewReminder)
                    SettingsToggleRow(title: "Weekly performance review", icon: "calendar.badge.clock", isOn: $viewModel.weeklyPerformanceReview)
                    SettingsToggleRow(title: "Enable Insights", icon: "sparkles", isOn: $viewModel.smartInsightsEnabled)
                    SettingsToggleRow(title: "Enable Daily Coaching", icon: "sun.max.fill", isOn: $viewModel.dailyCoachingEnabled)
                    SettingsToggleRow(title: "Enable Weekly Summary", icon: "calendar.badge.clock", isOn: $viewModel.weeklySummaryEnabled)
                }
                .padding(.top, 10)
            } label: {
                SettingsDisclosureLabel(title: "More Preferences", subtitle: "Notifications and smart coaching", icon: "slider.horizontal.3")
            }
            .tint(JPColors.accent)
        }
    }

    private var dataDiagnosticsSummarySection: some View {
        settingsSection(title: "Data & Diagnostics", subtitle: "Reports, cache, and health checks") {
            if reportViewModel.isGenerating {
                PremiumLoadingBlock(title: "Generating report", subtitle: "Rendering charts, performance metrics, and trade history into a polished PDF.", symbolName: "doc.richtext")
            }

            SettingsActionButton(title: "Export All-Time Report", icon: "chart.line.uptrend.xyaxis", tint: JPColors.purple, isLoading: reportViewModel.isGenerating) {
                runPremiumAction { reportViewModel.export(.allTime) }
            }
            SettingsActionButton(title: "Clear Image Cache", icon: "photo.badge.checkmark", tint: JPColors.warning) {
                viewModel.clearImageCache()
            }
            SettingsActionButton(title: "Export Diagnostics", icon: "doc.badge.gearshape", tint: JPColors.purple) {
                viewModel.exportDiagnostics()
            }
        }
    }

    private var supportFeedbackSection: some View {
        settingsSection(title: "Support & Feedback", subtitle: "Help improve Journaling Pips") {
            SettingsActionButton(title: "⭐ Rate Journaling Pips", icon: "star.fill", tint: JPColors.warning) {
                supportFeedbackAction("Rate Journaling Pips")
            }
            SettingsActionButton(title: "💬 Send Feedback", icon: "bubble.left.and.bubble.right.fill", tint: JPColors.accent) {
                supportFeedbackAction("Send Feedback")
            }
            SettingsActionButton(title: "🐞 Report a Bug", icon: "ladybug.fill", tint: JPColors.loss) {
                supportFeedbackAction("Report a Bug")
            }
            SettingsActionButton(title: "💡 Suggest a Feature", icon: "lightbulb.fill", tint: JPColors.warning) {
                supportFeedbackAction("Suggest a Feature")
            }
            SettingsActionButton(title: "📧 Contact Support", icon: "envelope.fill", tint: JPColors.blue) {
                supportFeedbackAction("Contact Support")
            }
            SettingsActionButton(title: "📜 Privacy Policy", icon: "hand.raised.fill", tint: JPColors.purple) {
                supportFeedbackAction("Privacy Policy")
            }
            SettingsActionButton(title: "📄 Terms of Service", icon: "doc.text.fill", tint: JPColors.secondaryText) {
                supportFeedbackAction("Terms of Service")
            }
            SettingsInfoRow(title: "ℹ️ Version", value: "Version 1.0.0", icon: "info.circle.fill")
        }
    }

    private var advancedSettingsSection: some View {
        settingsSection(title: "Advanced", subtitle: "Developer, sync, and export controls") {
            DisclosureGroup(isExpanded: $showAdvancedSettings) {
                VStack(alignment: .leading, spacing: 22) {
                    developerTestingSection
                    aiPreferencesSection
                    syncSettingsSection
                    productionReadinessSection
                    dataManagementSection
                    appInfoSection
                }
                .padding(.top, 10)
            } label: {
                SettingsDisclosureLabel(title: "Show Advanced", subtitle: "Cloud controls, diagnostics, exports, app info", icon: "gearshape.2.fill")
            }
            .tint(JPColors.accent)
        }
    }

    private var developerTestingSection: some View {
        settingsSection(title: "Developer Testing", subtitle: "Local-only TestFlight controls") {
            SettingsToggleRow(title: "Developer: Unlock Premium", icon: "hammer.fill", isOn: $subscriptionManager.developerPremiumOverride)

            Text("Development/testing only. This local toggle does not validate purchases, change StoreKit products, or affect App Store subscription status.")
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.warning)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(JPColors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var syncSettingsSection: some View {
        settingsSection(title: "Sync Settings", subtitle: "Local-first cloud controls") {
            SettingsToggleRow(title: "Auto Sync", icon: "icloud.and.arrow.up.fill", isOn: $syncViewModel.autoSync)
            SettingsToggleRow(title: "WiFi Only", icon: "wifi", isOn: $syncViewModel.wifiOnly)
            SettingsActionButton(title: "Export Local Backup", icon: "externaldrive.badge.plus", tint: JPColors.blue) {
                viewModel.showComingSoon("Export Local Backup")
            }
            SettingsActionButton(title: "Delete Cloud Data", icon: "trash.slash", tint: JPColors.loss) {
                syncViewModel.deleteCloudData()
            }
            SettingsActionButton(title: "Delete Local Data", icon: "trash", tint: JPColors.warning) {
                syncViewModel.deleteLocalData()
            }

            if let banner = syncViewModel.bannerMessage {
                Text(banner)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(syncViewModel.state == .synced ? JPColors.profit : JPColors.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var productionReadinessSection: some View {
        settingsSection(title: "Production Tools", subtitle: "Diagnostics, recovery, and local health") {
            if let report = viewModel.diagnosticsReport {
                SettingsInfoRow(title: "Database Size", value: report.databaseSize, icon: "internaldrive")
                SettingsInfoRow(title: "Pending Sync", value: "\(report.pendingSyncCount)", icon: "tray.and.arrow.up")
                SettingsInfoRow(title: "Screenshots Pending", value: "\(report.pendingScreenshotUploads)", icon: "photo.stack")
                SettingsInfoRow(title: "AI Reviews Pending", value: "\(report.pendingAIReviews)", icon: "sparkles")
                SettingsInfoRow(title: "Current User", value: report.currentUser, icon: "person.crop.circle")
                SettingsInfoRow(title: "Supabase", value: report.supabaseStatus, icon: "icloud")
            }

            SettingsActionButton(title: "Clear Image Cache", icon: "photo.badge.checkmark", tint: JPColors.warning) {
                viewModel.clearImageCache()
            }
            SettingsActionButton(title: "Clear Local Cache", icon: "folder.badge.gearshape", tint: JPColors.warning) {
                viewModel.clearLocalCache()
            }
            SettingsActionButton(title: "Reset Local Database", icon: "externaldrive.badge.xmark", tint: JPColors.loss) {
                viewModel.resetLocalDatabase()
            }
            SettingsActionButton(title: "Rebuild Local Store", icon: "arrow.triangle.2.circlepath.doc.on.clipboard", tint: JPColors.purple) {
                viewModel.rebuildLocalStore()
            }
            SettingsActionButton(title: "Force Sync Now", icon: "arrow.triangle.2.circlepath", tint: JPColors.accent) {
                runPremiumAction {
                    syncViewModel.syncNow()
                    viewModel.refreshDiagnostics()
                }
            }
            SettingsActionButton(title: "Rebuild Analytics", icon: "chart.line.uptrend.xyaxis", tint: JPColors.blue) {
                viewModel.rebuildAnalytics()
            }
            SettingsActionButton(title: "Export Diagnostics", icon: "doc.badge.gearshape", tint: JPColors.purple) {
                viewModel.exportDiagnostics()
            }

            if let message = viewModel.healthMessage {
                Text(message)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var dataManagementSection: some View {
        settingsSection(title: "Data Management", subtitle: "Export and backup tools") {
            if reportViewModel.isGenerating {
                PremiumLoadingBlock(title: "Generating report", subtitle: "Rendering charts, performance metrics, and trade history into a polished PDF.", symbolName: "doc.richtext")
            }
            SettingsActionButton(title: "Export CSV", icon: "tablecells", tint: JPColors.accent) {
                viewModel.showComingSoon("Export CSV")
            }
            SettingsActionButton(title: "Export Daily Report", icon: "doc.richtext", tint: JPColors.profit, isLoading: reportViewModel.isGenerating) {
                runPremiumAction { reportViewModel.export(.daily) }
            }
            SettingsActionButton(title: "Export Weekly Report", icon: "calendar.badge.clock", tint: JPColors.warning, isLoading: reportViewModel.isGenerating) {
                runPremiumAction { reportViewModel.export(.weekly) }
            }
            SettingsActionButton(title: "Export Monthly Report", icon: "chart.bar.doc.horizontal", tint: JPColors.blue, isLoading: reportViewModel.isGenerating) {
                runPremiumAction { reportViewModel.export(.monthly) }
            }
            SettingsActionButton(title: "Export All-Time Report", icon: "chart.line.uptrend.xyaxis", tint: JPColors.purple, isLoading: reportViewModel.isGenerating) {
                runPremiumAction { reportViewModel.export(.allTime) }
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
        .onLongPressGesture {
            JPHaptics.impact(.medium)
            viewModel.refreshDiagnostics()
            showDiagnostics = true
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsDeveloperView(report: viewModel.diagnosticsReport) {
                viewModel.exportDiagnostics()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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

    private var renewalText: String {
        guard let renewalDate = subscriptionManager.renewalDate else {
            return subscriptionManager.isPremiumUnlocked ? "Managed by App Store" : "Not active"
        }

        return renewalDate.formatted(date: .abbreviated, time: .omitted)
    }

    private func supportFeedbackAction(_ title: String) {
        JPHaptics.selection()
        debugPrint("SUPPORT FEEDBACK:", title)
    }

    private func runPremiumAction(_ action: () -> Void) {
        guard subscriptionManager.isPremiumUnlocked else {
            showPaywall = true
            JPHaptics.notify(.warning)
            return
        }

        action()
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

private struct SettingsPresentationModifier: ViewModifier {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var reportViewModel: ReportViewModel

    func body(content: Content) -> some View {
        content
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
            .sheet(item: $viewModel.diagnosticsShareItem) { item in
                ReportShareSheet(url: item.url)
            }
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

private struct SettingsLifecycleModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var reportViewModel: ReportViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var syncViewModel: SyncViewModel
    @Binding var didAppear: Bool

    func body(content: Content) -> some View {
        content
            .onAppear(perform: configure)
            .modifier(SettingsProfilePersistenceModifier(viewModel: viewModel))
            .modifier(SettingsCoachingPersistenceModifier(viewModel: viewModel))
            .modifier(SettingsSyncPersistenceModifier(syncViewModel: syncViewModel))
    }

    private func configure() {
        viewModel.configure(context: modelContext)
        reportViewModel.configure(context: modelContext)
        authViewModel.configure(context: modelContext)
        syncViewModel.configure(context: modelContext)

        withAnimation(.easeOut(duration: 0.45)) {
            didAppear = true
        }
    }
}

private struct SettingsProfilePersistenceModifier: ViewModifier {
    @ObservedObject var viewModel: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.name) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.tradingExperience) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.tradingStyle) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.preferredMarkets) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.accountSize) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.accountType) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.baseCurrency) { _, _ in viewModel.saveProfile() }
    }
}

private struct SettingsCoachingPersistenceModifier: ViewModifier {
    @ObservedObject var viewModel: SettingsViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.coachingStyle) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.themePreference) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.morningPreparationReminder) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.tradeReviewReminder) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.weeklyPerformanceReview) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.smartInsightsEnabled) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.dailyCoachingEnabled) { _, _ in viewModel.saveProfile() }
            .onChange(of: viewModel.weeklySummaryEnabled) { _, _ in viewModel.saveProfile() }
    }
}

private struct SettingsSyncPersistenceModifier: ViewModifier {
    @ObservedObject var syncViewModel: SyncViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: syncViewModel.autoSync) { _, _ in syncViewModel.persistSettings() }
            .onChange(of: syncViewModel.wifiOnly) { _, _ in syncViewModel.persistSettings() }
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
                    PremiumInlineLoader(title: "Working", tint: tint)
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

private struct SettingsDisclosureLabel: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(JPColors.accent)
                .frame(width: 42, height: 42)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(JPColors.primaryText)

                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(JPColors.border, lineWidth: 1)
        )
    }
}

private struct DiagnosticsDeveloperView: View {
    let report: DiagnosticsReport?
    let onExport: () -> Void

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Developer Diagnostics")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)

                        Text("Local health report for beta support.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }

                    if let report {
                        GlassCard {
                            VStack(spacing: 14) {
                                diagnosticRow("Generated", report.generatedAt.formatted(.dateTime.month().day().hour().minute()), "clock")
                                diagnosticRow("App Version", report.appVersion, "number.circle")
                                diagnosticRow("Database Size", report.databaseSize, "internaldrive")
                                diagnosticRow("Storage Usage", report.storageUsage, "externaldrive")
                                diagnosticRow("Pending Sync", "\(report.pendingSyncCount)", "tray.and.arrow.up")
                                diagnosticRow("Pending Screenshots", "\(report.pendingScreenshotUploads)", "photo.stack")
                                diagnosticRow("Pending AI Reviews", "\(report.pendingAIReviews)", "sparkles")
                                diagnosticRow("Current User", report.currentUser, "person.crop.circle")
                                diagnosticRow("Supabase", report.supabaseStatus, "icloud")
                                diagnosticRow("Trades", "\(report.tradeCount)", "number")
                                diagnosticRow("AI Reviews", "\(report.aiReviewCount)", "doc.text.magnifyingglass")
                            }
                        }
                    } else {
                        PremiumEmptyStateCard(
                            symbolName: "stethoscope",
                            title: "Diagnostics unavailable",
                            subtitle: "Open Settings again to rebuild the local health report.",
                            buttonTitle: nil,
                            tint: JPColors.warning
                        )
                    }

                    Button(action: onExport) {
                        Label("Export Diagnostics JSON", systemImage: "square.and.arrow.up.fill")
                            .font(.headline.weight(.black))
                            .foregroundStyle(JPColors.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(LinearGradient(colors: [JPColors.accent, JPColors.blue], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    }
                    .buttonStyle(ScalingButtonStyle())
                }
                .padding(20)
            }
        }
    }

    private func diagnosticRow(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.black))
                .foregroundStyle(JPColors.accent)
                .frame(width: 32, height: 32)
                .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JPColors.secondaryText)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.black))
                .foregroundStyle(JPColors.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
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
