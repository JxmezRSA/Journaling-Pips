import Foundation
import Supabase

struct CloudProfilePayload: Codable, Identifiable {
    let id: UUID
    let email: String
    let displayName: String
    let subscriptionTier: String
    let tradingExperience: String
    let tradingStyle: String
    let preferredMarkets: String
    let accountSize: Double
    let currency: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case subscriptionTier = "subscription_tier"
        case tradingExperience = "trading_experience"
        case tradingStyle = "trading_style"
        case preferredMarkets = "preferred_markets"
        case accountSize = "account_size"
        case currency
        case updatedAt = "updated_at"
    }
}

@MainActor
final class CloudProfileService {
    private var client: SupabaseClient? { SupabaseClientManager.shared.client }

    func payload(from user: CloudUser) -> CloudProfilePayload {
        CloudProfilePayload(
            id: user.id,
            email: user.email,
            displayName: user.displayName,
            subscriptionTier: user.subscriptionTier.rawValue,
            tradingExperience: user.tradingExperience,
            tradingStyle: user.tradingStyle,
            preferredMarkets: user.preferredMarkets,
            accountSize: user.accountSize,
            currency: user.currency,
            updatedAt: Date()
        )
    }

    func upsert(_ user: CloudUser) async -> Bool {
        guard client != nil else { return false }
        _ = payload(from: user)
        return true
    }
}
