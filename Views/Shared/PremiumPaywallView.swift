import StoreKit
import SwiftUI

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedProductID = SubscriptionManager.yearlyProductID
    @State private var didAppear = false

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    featureComparison
                    productOptions
                    trialButton
                    restoreAndLinks
                    dismissButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 42)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            selectedProductID = subscriptionManager.yearlyProduct?.id ?? subscriptionManager.monthlyProduct?.id ?? SubscriptionManager.yearlyProductID
            subscriptionManager.configure()
            withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                didAppear = true
            }
        }
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(LinearGradient(colors: [JPColors.accent, JPColors.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 78, height: 78)
                            .shadow(color: JPColors.accent.opacity(0.3), radius: 24, x: 0, y: 12)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(JPColors.background)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Journaling Pips Premium")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Unlock the full trading performance platform.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                }

                HStack(spacing: 10) {
                    statusPill(subscriptionManager.status.rawValue, tint: subscriptionManager.isPremiumUnlocked ? JPColors.profit : JPColors.warning)
                    statusPill(subscriptionManager.trialRemainingText, tint: JPColors.blue)
                }
            }
        }
        .premiumEntrance(active: didAppear)
    }

    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "What Premium Unlocks", subtitle: "Free keeps you started. Premium removes the ceiling.")

            GlassCard {
                VStack(spacing: 12) {
                    paywallFeature("Unlimited trades", free: "100 trades", premium: "Unlimited", icon: "infinity", tint: JPColors.accent)
                    paywallFeature("AI Coach", free: "Locked", premium: "Included", icon: "sparkles", tint: JPColors.warning)
                    paywallFeature("AI Vision", free: "Locked", premium: "Included", icon: "eye.fill", tint: JPColors.blue)
                    paywallFeature("Replay Studio", free: "Locked", premium: "Included", icon: "play.rectangle.fill", tint: JPColors.purple)
                    paywallFeature("Analytics Dashboard", free: "Basic", premium: "Professional", icon: "chart.bar.xaxis", tint: JPColors.profit)
                    paywallFeature("Cloud Sync & PDF Export", free: "Locked", premium: "Included", icon: "icloud.and.arrow.up.fill", tint: JPColors.blue)
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.04)
    }

    private var productOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Choose Your Plan", subtitle: "StoreKit 2 products are loaded from App Store Connect or StoreKit Test.")

            if subscriptionManager.isLoadingProducts {
                PremiumLoadingBlock(title: "Loading plans", subtitle: "Checking StoreKit products for this device.", symbolName: "cart")
            } else {
                VStack(spacing: 12) {
                    productOption(subscriptionManager.monthlyProduct, fallbackTitle: "Premium Monthly", fallbackPrice: "$9.99 / month")
                    productOption(subscriptionManager.yearlyProduct, fallbackTitle: "Premium Annual", fallbackPrice: "$79.99 / year")
                }
            }
        }
        .premiumEntrance(active: didAppear, delay: 0.08)
    }

    private var trialButton: some View {
        Button {
            if let selected = selectedProduct {
                subscriptionManager.purchase(selected)
            } else {
                subscriptionManager.startLocalTrialIfNeeded()
            }
        } label: {
            HStack {
                if subscriptionManager.isPurchasing {
                    ProgressView()
                        .tint(JPColors.background)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.headline.weight(.black))
                }

                Text(subscriptionManager.isPurchasing ? "Starting..." : "Start 7-Day Free Trial")
                    .font(.headline.weight(.black))
            }
            .foregroundStyle(JPColors.background)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                LinearGradient(colors: [JPColors.accent, JPColors.profit], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: JPColors.accent.opacity(0.28), radius: 22, x: 0, y: 12)
        }
        .buttonStyle(ScalingButtonStyle())
        .disabled(subscriptionManager.isPurchasing)
        .premiumEntrance(active: didAppear, delay: 0.12)
    }

    private var restoreAndLinks: some View {
        GlassCard {
            VStack(spacing: 12) {
                Button {
                    subscriptionManager.restorePurchases()
                } label: {
                    Label(subscriptionManager.isRestoring ? "Restoring..." : "Restore Purchases", systemImage: "arrow.clockwise.circle.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(JPColors.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(ScalingButtonStyle())

                HStack {
                    Link("Privacy Policy", destination: URL(string: "https://journalingpips.app/privacy")!)
                    Spacer()
                    Link("Terms of Service", destination: URL(string: "https://journalingpips.app/terms")!)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.accent)

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
        .premiumEntrance(active: didAppear, delay: 0.16)
    }

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Continue with Free")
                .font(.headline.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(ScalingButtonStyle())
        .premiumEntrance(active: didAppear, delay: 0.2)
    }

    private var selectedProduct: Product? {
        subscriptionManager.products.first { $0.id == selectedProductID }
    }

    private func productOption(_ product: Product?, fallbackTitle: String, fallbackPrice: String) -> some View {
        let id = product?.id ?? (fallbackTitle.contains("Annual") ? SubscriptionManager.yearlyProductID : SubscriptionManager.monthlyProductID)
        let isSelected = selectedProductID == id

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                selectedProductID = id
            }
            JPHaptics.selection()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? JPColors.accent : JPColors.secondaryText)

                VStack(alignment: .leading, spacing: 5) {
                    Text(product?.displayName ?? fallbackTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text(product?.displayPrice ?? fallbackPrice)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }

                Spacer()

                if id == SubscriptionManager.yearlyProductID {
                    Text("Best Value")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(JPColors.warning, in: Capsule())
                }
            }
            .padding(16)
            .background(isSelected ? JPColors.accent.opacity(0.13) : JPColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? JPColors.accent.opacity(0.55) : JPColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(ScalingButtonStyle())
    }

    private func paywallFeature(_ title: String, free: String, premium: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(JPColors.primaryText)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Free: \(free)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
                Text("Premium: \(premium)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(JPColors.accent)
            }
        }
    }

    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.black))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(tint.opacity(0.13), in: Capsule())
    }
}

struct PremiumGateLink<Destination: View, Label: View>: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false
    private let destination: Destination
    private let label: Label

    init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {
        self.destination = destination()
        self.label = label()
    }

    var body: some View {
        Group {
            if subscriptionManager.isPremiumUnlocked {
                NavigationLink {
                    destination
                } label: {
                    label
                }
            } else {
                Button {
                    showPaywall = true
                    JPHaptics.notify(.warning)
                } label: {
                    label
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView()
                .environmentObject(subscriptionManager)
        }
    }
}
