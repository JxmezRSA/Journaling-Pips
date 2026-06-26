import Combine
import Foundation
import SwiftData

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
    @Published var coachingStyle = UserProfile.CoachingStyle.balanced
    @Published var themePreference = UserProfile.ThemePreference.midnight
    @Published var morningPreparationReminder = false
    @Published var tradeReviewReminder = false
    @Published var weeklyPerformanceReview = false
    @Published var comingSoonMessage: String?
    @Published var errorMessage: String?

    private var modelContext: ModelContext?
    private var isApplyingProfile = false

    func configure(context: ModelContext) {
        guard modelContext == nil else {
            return
        }

        modelContext = context
        loadProfile()
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
