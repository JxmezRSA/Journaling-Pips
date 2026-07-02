import Combine
import Foundation
import StoreKit
import SwiftUI
import UIKit

enum PremiumStatus: String, Codable, CaseIterable, Identifiable {
    case free = "Free"
    case trial = "Trial"
    case premium = "Premium"
    case expired = "Expired"
    case unknown = "Unknown"

    var id: String { rawValue }
}

struct SubscriptionEntitlements {
    let maxTrades: Int?
    let analytics: String
    let cloudSync: Bool
    let aiCoach: Bool
    let aiVision: Bool
    let replayStudio: Bool
    let reports: Bool
    let futureFeatures: Bool
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let monthlyProductID = "com.journalingpips.premium.monthly"
    static let yearlyProductID = "com.journalingpips.premium.yearly"

    @Published private(set) var products: [Product] = []
    @Published private(set) var status: PremiumStatus = .unknown
    @Published private(set) var renewalDate: Date?
    @Published private(set) var trialStartDate: Date?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var developerPremiumOverride: Bool {
        didSet {
            UserDefaults.standard.set(developerPremiumOverride, forKey: developerPremiumOverrideKey)
            debugPrint("ENTITLEMENT UPDATED:", developerPremiumOverride ? "Developer Premium Override Enabled" : "Developer Premium Override Disabled")
        }
    }
    @Published var errorMessage: String?
    @Published var purchaseMessage: String?

    private let productIDs = [monthlyProductID, yearlyProductID]
    private var updatesTask: Task<Void, Never>?
    private let developerPremiumOverrideKey = "jp.developerPremiumOverride"
    private let statusKey = "jp.subscription.status"
    private let renewalDateKey = "jp.subscription.renewalDate"
    private let trialStartDateKey = "jp.subscription.trialStartDate"
    private let entitlementCheckedAtKey = "jp.subscription.entitlementCheckedAt"

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductID }
    }

    var isPremiumUnlocked: Bool {
        developerPremiumOverride || status == .premium || isTrialActive
    }

    var isTrialActive: Bool {
        guard let trialStartDate else { return false }
        return Calendar.current.date(byAdding: .day, value: 7, to: trialStartDate).map { $0 > Date() } ?? false
    }

    var trialExpirationDate: Date? {
        guard let trialStartDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: 7, to: trialStartDate)
    }

    var trialRemainingText: String {
        guard let trialExpirationDate, trialExpirationDate > Date() else {
            return "No active trial"
        }

        let days = Calendar.current.dateComponents([.day], from: Date(), to: trialExpirationDate).day ?? 0
        return "\(max(1, days + 1)) days remaining"
    }

    init() {
        developerPremiumOverride = UserDefaults.standard.bool(forKey: developerPremiumOverrideKey)
        loadCachedEntitlement()
        updatesTask = listenForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    func configure() {
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func entitlements(for tier: CloudUser.SubscriptionTier) -> SubscriptionEntitlements {
        switch tier {
        case .free:
            return SubscriptionEntitlements(maxTrades: 100, analytics: "Basic analytics", cloudSync: false, aiCoach: false, aiVision: false, replayStudio: false, reports: false, futureFeatures: false)
        case .pro:
            return premiumEntitlements
        case .elite:
            return premiumEntitlements
        }
    }

    func currentEntitlements() -> SubscriptionEntitlements {
        isPremiumUnlocked ? premiumEntitlements : freeEntitlements
    }

    func loadProducts() async {
        guard isLoadingProducts == false else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: productIDs)
            products = loaded.sorted { $0.price < $1.price }
            debugPrint("SUBSCRIPTIONS LOADED")
        } catch {
            errorMessage = "Unable to load subscriptions. Premium status is using the offline cache."
            debugPrint("PURCHASE FAILED:", String(describing: error))
        }
    }

    func purchase(_ product: Product) {
        Task {
            await purchaseProduct(product)
        }
    }

    func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil
        debugPrint("PURCHASE STARTED:", product.id)

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                purchaseMessage = "Premium unlocked."
                debugPrint("PURCHASE SUCCESS:", product.id)
                JPHaptics.notify(.success)
            case .userCancelled:
                purchaseMessage = nil
            case .pending:
                purchaseMessage = "Purchase pending approval."
            @unknown default:
                purchaseMessage = "Purchase state is pending."
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
            debugPrint("PURCHASE FAILED:", String(describing: error))
            JPHaptics.notify(.error)
        }

        isPurchasing = false
    }

    func restorePurchases() {
        Task {
            await restore()
        }
    }

    func restore() async {
        isRestoring = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseMessage = isPremiumUnlocked ? "Purchases restored." : "No active premium purchase found."
            debugPrint("RESTORE SUCCESS")
            JPHaptics.notify(isPremiumUnlocked ? .success : .warning)
        } catch {
            errorMessage = "Unable to restore purchases right now."
            debugPrint("PURCHASE FAILED:", String(describing: error))
            JPHaptics.notify(.error)
        }

        isRestoring = false
    }

    func startLocalTrialIfNeeded() {
        guard trialStartDate == nil, status != .premium else { return }
        let now = Date()
        trialStartDate = now
        status = .trial
        cache(status: .trial, renewalDate: Calendar.current.date(byAdding: .day, value: 7, to: now), trialStartDate: now)
        debugPrint("ENTITLEMENT UPDATED:", PremiumStatus.trial.rawValue)
        JPHaptics.notify(.success)
    }

    func refreshEntitlements() async {
        var hasPremium = false
        var latestExpiration: Date?

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard productIDs.contains(transaction.productID) else { continue }

                if transaction.revocationDate == nil {
                    hasPremium = true
                    if let expirationDate = transaction.expirationDate {
                        latestExpiration = max(latestExpiration ?? expirationDate, expirationDate)
                    }
                }
            } catch {
                debugPrint("PURCHASE FAILED:", "Unverified entitlement", String(describing: error))
            }
        }

        if hasPremium {
            status = .premium
            renewalDate = latestExpiration
        } else if isTrialActive {
            status = .trial
            renewalDate = trialExpirationDate
        } else if status == .premium || status == .trial {
            status = .expired
        } else if status == .unknown {
            status = .free
        }

        cache(status: status, renewalDate: renewalDate, trialStartDate: trialStartDate)
        debugPrint("ENTITLEMENT UPDATED:", status.rawValue)
    }

    func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }

    private var freeEntitlements: SubscriptionEntitlements {
        SubscriptionEntitlements(
            maxTrades: 100,
            analytics: "Basic analytics",
            cloudSync: false,
            aiCoach: false,
            aiVision: false,
            replayStudio: false,
            reports: false,
            futureFeatures: false
        )
    }

    private var premiumEntitlements: SubscriptionEntitlements {
        SubscriptionEntitlements(
            maxTrades: nil,
            analytics: "Advanced analytics",
            cloudSync: true,
            aiCoach: true,
            aiVision: true,
            replayStudio: true,
            reports: true,
            futureFeatures: true
        )
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    guard let self else { return }
                    let transaction = try await self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    debugPrint("PURCHASE FAILED:", "Transaction update unverified", String(describing: error))
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.notAvailableInStorefront
        case .verified(let safe):
            return safe
        }
    }

    private func loadCachedEntitlement() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: statusKey), let cachedStatus = PremiumStatus(rawValue: raw) {
            status = cachedStatus
        } else {
            status = .free
        }

        if let renewalTimestamp = defaults.object(forKey: renewalDateKey) as? Double {
            renewalDate = Date(timeIntervalSince1970: renewalTimestamp)
        }

        if let trialTimestamp = defaults.object(forKey: trialStartDateKey) as? Double {
            trialStartDate = Date(timeIntervalSince1970: trialTimestamp)
        }

        if status == .trial, !isTrialActive {
            status = .expired
        }
    }

    private func cache(status: PremiumStatus, renewalDate: Date?, trialStartDate: Date?) {
        let defaults = UserDefaults.standard
        defaults.set(status.rawValue, forKey: statusKey)
        defaults.set(Date().timeIntervalSince1970, forKey: entitlementCheckedAtKey)

        if let renewalDate {
            defaults.set(renewalDate.timeIntervalSince1970, forKey: renewalDateKey)
        } else {
            defaults.removeObject(forKey: renewalDateKey)
        }

        if let trialStartDate {
            defaults.set(trialStartDate.timeIntervalSince1970, forKey: trialStartDateKey)
        }
    }
}
