import Combine
import Foundation
import SwiftData
import UIKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published var name = ""
    @Published var tradingExperience = UserProfile.TradingExperience.beginner
    @Published var tradingStyle = UserProfile.TradingStyle.dayTrader
    @Published var preferredMarkets = ""
    @Published var accountSize = ""
    @Published var accountType = UserProfile.AccountType.personal
    @Published var baseCurrency = UserProfile.BaseCurrency.usd
    @Published var coachingStyle = UserProfile.CoachingStyle.professionalMentor
    @Published var themePreference = UserProfile.ThemePreference.midnight
    @Published var morningPreparationReminder = false
    @Published var tradeReviewReminder = false
    @Published var weeklyPerformanceReview = false
    @Published var smartInsightsEnabled = true
    @Published var dailyCoachingEnabled = true
    @Published var weeklySummaryEnabled = true
    @Published private(set) var aiBackendStatus = "Not Connected"
    @Published private(set) var isTestingAIConnection = false
    @Published private(set) var diagnosticsReport: DiagnosticsReport?
    @Published var diagnosticsShareItem: ShareExportItem?
    @Published var healthMessage: String?
    @Published var comingSoonMessage: String?
    @Published var errorMessage: String?

    private var modelContext: ModelContext?
    private var isApplyingProfile = false
    private let aiService = AIService()

    func configure(context: ModelContext) {
        guard modelContext == nil else {
            return
        }

        modelContext = context
        aiBackendStatus = aiService.isBackendConfigured ? "Configured" : "Not Connected"
        loadProfile()
        refreshDiagnostics()
    }

    func loadProfile() {
        guard let modelContext else {
            return
        }

        do {
            let descriptor = FetchDescriptor<UserProfile>(
                sortBy: [SortDescriptor(\UserProfile.createdAt)]
            )
            let existingProfile = try modelContext.fetch(descriptor).first
            let resolvedProfile: UserProfile

            if let existingProfile {
                resolvedProfile = existingProfile
            } else {
                resolvedProfile = UserProfile()
                modelContext.insert(resolvedProfile)
                try modelContext.save()
            }

            profile = resolvedProfile
            apply(resolvedProfile)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load profile settings."
        }
    }

    func saveProfile() {
        guard !isApplyingProfile, let profile, let modelContext else {
            return
        }

        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.tradingExperience = tradingExperience
        profile.tradingStyle = tradingStyle
        profile.preferredMarkets = preferredMarkets.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.accountSize = numericValue(accountSize)
        profile.accountType = accountType
        profile.baseCurrency = baseCurrency
        profile.coachingStyle = coachingStyle
        profile.themePreference = themePreference
        profile.morningPreparationReminder = morningPreparationReminder
        profile.tradeReviewReminder = tradeReviewReminder
        profile.weeklyPerformanceReview = weeklyPerformanceReview
        profile.smartInsightsEnabled = smartInsightsEnabled
        profile.dailyCoachingEnabled = dailyCoachingEnabled
        profile.weeklySummaryEnabled = weeklySummaryEnabled
        profile.updatedAt = Date()

        do {
            try modelContext.save()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save profile settings."
        }
    }

    func showComingSoon(_ feature: String) {
        comingSoonMessage = "\(feature) is coming soon."
    }

    func testAIConnection() {
        Task {
            isTestingAIConnection = true
            aiBackendStatus = await aiService.testConnection() ? "Connected" : "Not Connected"
            isTestingAIConnection = false
            JPHaptics.notify(aiBackendStatus == "Connected" ? .success : .warning)
        }
    }

    func refreshDiagnostics() {
        guard let modelContext else { return }
        diagnosticsReport = ProductionHealthService(context: modelContext).makeDiagnosticsReport()
    }

    func clearImageCache() {
        guard let modelContext else { return }
        let removed = ProductionHealthService(context: modelContext).cleanupLocalCache()
        refreshDiagnostics()
        healthMessage = removed == 0 ? "Image cache is already clean." : "Cleaned \(removed) stale records."
        JPHaptics.notify(.success)
    }

    func clearLocalCache() {
        let removed = SwiftDataStoreManager.clearLocalCacheFiles()
        refreshDiagnostics()
        healthMessage = removed == 0 ? "Local cache is already clean." : "Cleared \(removed) local cache files."
        JPHaptics.notify(.success)
    }

    func resetLocalDatabase() {
        SwiftDataStoreManager.requestStoreRecovery(reason: "manual-reset")
        healthMessage = "Local database backed up and reset. Restart Journaling Pips to rebuild the local store."
        JPHaptics.notify(.warning)
    }

    func rebuildLocalStore() {
        SwiftDataStoreManager.requestStoreRecovery(reason: "manual-rebuild")
        healthMessage = "Local store rebuild queued. Restart Journaling Pips to create a clean local database."
        JPHaptics.notify(.warning)
    }

    func rebuildAnalytics() {
        guard let modelContext else { return }
        do {
            try IntelligenceEngine(context: modelContext).refreshInsights(trigger: .analyticsUpdated)
            healthMessage = "Analytics rebuilt from local trades."
            debugPrint("DATABASE VERIFIED")
            JPHaptics.notify(.success)
        } catch {
            healthMessage = "Unable to rebuild analytics right now."
            JPHaptics.notify(.error)
        }
    }

    func exportDiagnostics() {
        guard let modelContext else { return }
        do {
            let url = try ProductionHealthService(context: modelContext).exportDiagnosticsReport()
            diagnosticsShareItem = ShareExportItem(url: url)
            healthMessage = "Diagnostics report generated."
            JPHaptics.notify(.success)
        } catch {
            healthMessage = "Unable to export diagnostics."
            JPHaptics.notify(.error)
        }
    }

    private func apply(_ profile: UserProfile) {
        isApplyingProfile = true
        name = profile.name
        tradingExperience = profile.tradingExperience
        tradingStyle = profile.tradingStyle
        preferredMarkets = profile.preferredMarkets
        accountSize = profile.accountSize == 0 ? "" : numberText(profile.accountSize)
        accountType = profile.accountType
        baseCurrency = profile.baseCurrency
        coachingStyle = profile.coachingStyle
        themePreference = profile.themePreference
        morningPreparationReminder = profile.morningPreparationReminder
        tradeReviewReminder = profile.tradeReviewReminder
        weeklyPerformanceReview = profile.weeklyPerformanceReview
        smartInsightsEnabled = profile.smartInsightsEnabled
        dailyCoachingEnabled = profile.dailyCoachingEnabled
        weeklySummaryEnabled = profile.weeklySummaryEnabled
        isApplyingProfile = false
    }

    private func numericValue(_ text: String) -> Double {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private func numberText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(value)
    }
}
