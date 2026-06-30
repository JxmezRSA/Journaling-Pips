import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("jp.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("jp.addTradeDraft") private var addTradeDraft = ""
    @StateObject private var tradeViewModel = TradeViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var selectedTab = AppTab.dashboard
    @State private var pendingTab: AppTab?
    @State private var showLeaveAddTradeConfirmation = false
    @State private var showLaunchSplash = true
    @State private var showPaywall = false

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedView
                .environmentObject(tradeViewModel)
                .environmentObject(subscriptionManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

            FloatingTabBar(selectedTab: selectedTab) { tab in
                handleTabSelection(tab)
            }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)

            if !hasCompletedOnboarding {
                OnboardingView(isComplete: $hasCompletedOnboarding)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(10)
            }

            if showLaunchSplash {
                BrandedLaunchSplash()
                    .transition(.opacity.combined(with: .scale(scale: 1.015)))
                    .zIndex(20)
            }
        }
        .background(JPColors.backgroundGradient.ignoresSafeArea())
        .tint(JPColors.accent)
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: selectedTab)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.42), value: showLaunchSplash)
        .confirmationDialog("You have unsaved changes.", isPresented: $showLeaveAddTradeConfirmation, titleVisibility: .visible) {
            Button("Save Draft") {
                if let pendingTab {
                    selectedTab = pendingTab
                }
                pendingTab = nil
            }
            Button("Discard Changes", role: .destructive) {
                addTradeDraft = ""
                if let pendingTab {
                    selectedTab = pendingTab
                }
                pendingTab = nil
            }
            Button("Cancel", role: .cancel) {
                pendingTab = nil
            }
        } message: {
            Text("Save your draft, discard changes, or keep editing this trade.")
        }
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView()
                .environmentObject(subscriptionManager)
        }
        .onAppear {
            debugPrint("UX LOADED")
            tradeViewModel.configure(context: modelContext)
            authViewModel.configure(context: modelContext)
            subscriptionManager.configure()
            ProductionHealthService(context: modelContext).runStartupRecovery()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_050_000_000)
                showLaunchSplash = false
            }
        }
    }

    private func handleTabSelection(_ tab: AppTab) {
        guard tab != selectedTab else { return }
        if tab == .addTrade {
            debugPrint("ADD TRADE TAP")
        }
        JPHaptics.selection()

        if tab == .analytics, !subscriptionManager.isPremiumUnlocked {
            showPaywall = true
            JPHaptics.notify(.warning)
            return
        }

        if selectedTab == .addTrade, !addTradeDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pendingTab = tab
            showLeaveAddTradeConfirmation = true
        } else {
            selectedTab = tab
        }
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView {
                selectedTab = .addTrade
            } onOpenPlan: {
                selectedTab = .plan
            } onOpenAnalytics: {
                if subscriptionManager.isPremiumUnlocked {
                    selectedTab = .analytics
                } else {
                    showPaywall = true
                    JPHaptics.notify(.warning)
                }
            } onOpenCalendar: {
                selectedTab = .calendar
            }
        case .calendar:
            CalendarView()
        case .addTrade:
            AddTradeView {
                selectedTab = .dashboard
            }
        case .plan:
            MorningPlanView()
        case .analytics:
            AnalyticsView {
                selectedTab = .addTrade
            }
        case .settings:
            SettingsView()
        }
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case calendar = "Calendar"
    case addTrade = "Add Trade"
    case plan = "Plan"
    case analytics = "Analytics"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:
            return "chart.xyaxis.line"
        case .calendar:
            return "calendar"
        case .addTrade:
            return "plus"
        case .plan:
            return "sunrise.fill"
        case .analytics:
            return "chart.bar.xaxis"
        case .settings:
            return "gearshape"
        }
    }
}

private struct FloatingTabBar: View {
    let selectedTab: AppTab
    let onSelect: (AppTab) -> Void
    @Namespace private var tabSelection

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    tabItem(tab)
                }
                .buttonStyle(ScalingButtonStyle())
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), JPColors.border, JPColors.accent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.38), radius: 28, x: 0, y: 18)
        .shadow(color: JPColors.accent.opacity(0.08), radius: 18, x: 0, y: 8)
        .accessibilityElement(children: .contain)
    }

    private func tabItem(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        let isCenter = tab == .addTrade

        return VStack(spacing: 5) {
            Image(systemName: tab.icon)
                .font(.system(size: isCenter ? 24 : 20, weight: .semibold))
                .frame(width: isCenter ? 56 : 46, height: isCenter ? 48 : 38)
                .foregroundStyle(isSelected ? JPColors.background : JPColors.primaryText)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: isCenter ? 22 : 18, style: .continuous)
                            .fill(Color.white.opacity(isCenter ? 0.11 : 0.04))

                        if isSelected {
                            RoundedRectangle(cornerRadius: isCenter ? 22 : 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [JPColors.accent, JPColors.profit],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .matchedGeometryEffect(id: "selectedTab", in: tabSelection)
                        }
                    }
                )
                .shadow(color: isSelected ? JPColors.accent.opacity(0.35) : Color.clear, radius: 14, x: 0, y: 6)
                .scaleEffect(isSelected ? 1.05 : 1)

            Text(tab.rawValue)
                .font(.system(size: 10, weight: isSelected ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(isSelected ? JPColors.accent : JPColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .animation(JPDesign.quickSpring, value: isSelected)
    }
}

struct ScalingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(JPDesign.quickSpring, value: configuration.isPressed)
    }
}
