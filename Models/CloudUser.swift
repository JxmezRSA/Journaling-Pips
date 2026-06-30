import Foundation
import SwiftData

@Model
final class CloudUser {
    enum SubscriptionTier: String, CaseIterable, Identifiable {
        case free = "Free"
        case pro = "Pro"
        case elite = "Elite"

        var id: String { rawValue }
    }

    var id: UUID = UUID()
    var email: String = ""
    var displayName: String = ""
    var createdAt: Date = Date()
    private var subscriptionTierRawValue: String = SubscriptionTier.free.rawValue
    var profileImage: Data?
    var tradingExperience: String = ""
    var tradingStyle: String = ""
    var preferredMarkets: String = ""
    var accountSize: Double = 0
    var currency: String = "USD"

    var subscriptionTier: SubscriptionTier {
        get { SubscriptionTier(rawValue: subscriptionTierRawValue) ?? .free }
        set { subscriptionTierRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        email: String = "",
        displayName: String = "",
        createdAt: Date = Date(),
        subscriptionTier: SubscriptionTier = .free,
        profileImage: Data? = nil,
        tradingExperience: String = "",
        tradingStyle: String = "",
        preferredMarkets: String = "",
        accountSize: Double = 0,
        currency: String = "USD"
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.subscriptionTierRawValue = subscriptionTier.rawValue
        self.profileImage = profileImage
        self.tradingExperience = tradingExperience
        self.tradingStyle = tradingStyle
        self.preferredMarkets = preferredMarkets
        self.accountSize = accountSize
        self.currency = currency
    }
}
