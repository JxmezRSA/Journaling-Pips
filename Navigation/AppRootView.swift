import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var tradeViewModel = TradeViewModel()
    @State private var selectedTab = AppTab.dashboard

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedView
                .environmentObject(tradeViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

            FloatingTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
        }
        .background(JPColors.backgroundGradient.ignoresSafeArea())
        .tint(JPColors.accent)
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: selectedTab)
        .onAppear {
            tradeViewModel.configure(context: modelContext)
        }
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView {
                selectedTab = .addTrade
            }
        case .calendar:
            CalendarView()
        case .addTrade:
            AddTradeView()
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
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    tabItem(tab)
                }
                .buttonStyle(ScalingButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.38), radius: 28, x: 0, y: 18)
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
                    RoundedRectangle(cornerRadius: isCenter ? 22 : 18, style: .continuous)
                        .fill(isSelected ? JPColors.accent : Color.white.opacity(isCenter ? 0.11 : 0.04))
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
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
    }
}

struct ScalingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
