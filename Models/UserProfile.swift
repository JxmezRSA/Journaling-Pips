import Foundation
import SwiftData

@Model
final class UserProfile {
    enum TradingExperience: String, CaseIterable, Identifiable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case fundedTrader = "Funded Trader"

        var id: String { rawValue }
    }

    enum TradingStyle: String, CaseIterable, Identifiable {
        case scalper = "Scalper"
        case dayTrader = "Day Trader"
        case swingTrader = "Swing Trader"

        var id: String { rawValue }
    }

    enum AccountType: String, CaseIterable, Identifiable {
        case personal = "Personal"
        case propFirm = "Prop Firm"

        var id: String { rawValue }
    }

    enum BaseCurrency: String, CaseIterable, Identifiable {
        case usd = "USD"
        case zar = "ZAR"
        case gbp = "GBP"
        case eur = "EUR"

        var id: String { rawValue }
    }

    enum CoachingStyle: String, CaseIterable, Identifiable {
        case strict = "Strict"
        case balanced = "Balanced"
        case encouraging = "Encouraging"

        var id: String { rawValue }
    }

    enum ThemePreference: String, CaseIterable, Identifiable {
        case midnight = "Midnight"
        case emerald = "Emerald"
        case blue = "Blue"
        case gold = "Gold"

        var id: String { rawValue }
    }

    var id: UUID
    var name: String
    private var tradingExperienceRawValue: String
    private var tradingStyleRawValue: String
    var preferredMarkets: String
    var accountSize: Double
    private var accountTypeRawValue: String
    private var baseCurrencyRawValue: String
    private var coachingStyleRawValue: String
    private var themePreferenceRawValue: String
    var morningPreparationReminder: Bool
    var tradeReviewReminder: Bool
    var weeklyPerformanceReview: Bool
    var createdAt: Date
    var updatedAt: Date

    var tradingExperience: TradingExperience {
        get { TradingExperience(rawValue: tradingExperienceRawValue) ?? .beginner }
        set { tradingExperienceRawValue = newValue.rawValue }
    }

    var tradingStyle: TradingStyle {
        get { TradingStyle(rawValue: tradingStyleRawValue) ?? .dayTrader }
        set { tradingStyleRawValue = newValue.rawValue }
    }

    var accountType: AccountType {
        get { AccountType(rawValue: accountTypeRawValue) ?? .personal }
        set { accountTypeRawValue = newValue.rawValue }
    }

    var baseCurrency: BaseCurrency {
        get { BaseCurrency(rawValue: baseCurrencyRawValue) ?? .usd }
        set { baseCurrencyRawValue = newValue.rawValue }
    }

    var coachingStyle: CoachingStyle {
        get { CoachingStyle(rawValue: coachingStyleRawValue) ?? .balanced }
        set { coachingStyleRawValue = newValue.rawValue }
    }

    var themePreference: ThemePreference {
        get { ThemePreference(rawValue: themePreferenceRawValue) ?? .midnight }
        set { themePreferenceRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String = "James",
        tradingExperience: TradingExperience = .beginner,
        tradingStyle: TradingStyle = .dayTrader,
        preferredMarkets: String = "",
        accountSize: Double = 0,
        accountType: AccountType = .personal,
        baseCurrency: BaseCurrency = .usd,
        coachingStyle: CoachingStyle = .balanced,
        themePreference: ThemePreference = .midnight,
        morningPreparationReminder: Bool = false,
        tradeReviewReminder: Bool = false,
        weeklyPerformanceReview: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.tradingExperienceRawValue = tradingExperience.rawValue
        self.tradingStyleRawValue = tradingStyle.rawValue
        self.preferredMarkets = preferredMarkets
        self.accountSize = accountSize
        self.accountTypeRawValue = accountType.rawValue
        self.baseCurrencyRawValue = baseCurrency.rawValue
        self.coachingStyleRawValue = coachingStyle.rawValue
        self.themePreferenceRawValue = themePreference.rawValue
        self.morningPreparationReminder = morningPreparationReminder
        self.tradeReviewReminder = tradeReviewReminder
        self.weeklyPerformanceReview = weeklyPerformanceReview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
