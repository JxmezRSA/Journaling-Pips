import SwiftUI
import UIKit

enum JPHaptics {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        debugPrint("HAPTIC SELECTION")
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        debugPrint("HAPTIC IMPACT:", "\(style)")
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
        switch type {
        case .success:
            debugPrint("HAPTIC SUCCESS")
        case .warning:
            debugPrint("HAPTIC WARNING")
        case .error:
            debugPrint("HAPTIC ERROR")
        @unknown default:
            debugPrint("HAPTIC NOTIFICATION")
        }
    }
}

struct PremiumEntranceModifier: ViewModifier {
    let isActive: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .offset(y: isActive ? 0 : 18)
            .scaleEffect(isActive ? 1 : 0.985)
            .animation(JPDesign.smoothSpring.delay(delay), value: isActive)
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase = -0.8

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.16),
                            Color.white.opacity(0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: proxy.size.width * 0.72)
                    .offset(x: proxy.size.width * phase)
                }
                .mask(content)
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

extension View {
    func premiumEntrance(active: Bool, delay: Double = 0) -> some View {
        modifier(PremiumEntranceModifier(isActive: active, delay: delay))
    }

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func premiumPress() -> some View {
        buttonStyle(ScalingButtonStyle())
    }
}

struct SkeletonCard: View {
    var height: CGFloat = 150

    var body: some View {
        RoundedRectangle(cornerRadius: JPDesign.cardRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [JPColors.elevatedSurface.opacity(0.82), JPColors.surface.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: JPDesign.cardRadius, style: .continuous)
                    .stroke(JPColors.border, lineWidth: 1)
            )
            .frame(height: height)
            .shimmer()
    }
}

struct SkeletonStack: View {
    var count = 3
    var height: CGFloat = 150

    var body: some View {
        VStack(spacing: JPDesign.cardSpacing) {
            ForEach(0..<count, id: \.self) { index in
                SkeletonCard(height: height)
                    .opacity(1 - Double(index) * 0.08)
                    .premiumEntrance(active: true, delay: Double(index) * 0.04)
            }
        }
        .accessibilityLabel("Loading content")
        .onAppear { debugPrint("SKELETON START") }
        .onDisappear { debugPrint("SKELETON END") }
    }
}

struct BrandedLaunchSplash: View {
    @State private var glow = false
    @State private var reveal = false

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            Circle()
                .fill(JPColors.accent.opacity(glow ? 0.28 : 0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .scaleEffect(glow ? 1.18 : 0.82)

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .fill(LinearGradient(colors: [JPColors.accent, JPColors.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 118, height: 118)
                        .shadow(color: JPColors.accent.opacity(0.34), radius: 34, x: 0, y: 18)

                    Text("JP")
                        .font(.system(size: 45, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.background)
                }
                .scaleEffect(reveal ? 1 : 0.82)

                VStack(spacing: 6) {
                    Text("Journaling Pips")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Discipline compounds.")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal ? 0 : 10)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.74)) {
                reveal = true
            }
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

struct PremiumSuccessBanner: View {
    let title: String
    let message: String
    var icon = "checkmark.seal.fill"
    var tint: Color = JPColors.accent

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)

                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.18), radius: 22, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.28), radius: 26, x: 0, y: 16)
        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.98)))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

struct PremiumToastBanner: View {
    enum Style {
        case success
        case warning
        case error
        case info

        var tint: Color {
            switch self {
            case .success: return JPColors.accent
            case .warning: return JPColors.warning
            case .error: return JPColors.loss
            case .info: return JPColors.blue
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.seal.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    let title: String
    let message: String
    var style: Style = .info

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: style.icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(style.tint)
                .frame(width: 40, height: 40)
                .background(style.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JPColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(style.tint.opacity(0.24), lineWidth: 1))
        .shadow(color: style.tint.opacity(0.16), radius: 18, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.24), radius: 22, x: 0, y: 14)
        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.98)))
        .accessibilityElement(children: .combine)
    }
}

struct PremiumErrorCard: View {
    let title: String
    let message: String
    var retryTitle = "Try Again"
    var action: (() -> Void)?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(JPColors.warning)
                        .frame(width: 50, height: 50)
                        .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: JPDesign.controlRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text(message)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let action {
                    Button {
                        JPHaptics.selection()
                        action()
                    } label: {
                        Text(retryTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(JPColors.warning, in: Capsule())
                    }
                    .premiumPress()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct CelebrationOverlay: View {
    let title: String
    let subtitle: String
    var symbolName = "sparkles"
    var tint: Color = JPColors.warning
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 132, height: 132)
                        .scaleEffect(pulse ? 1.18 : 0.86)
                        .blur(radius: 8)

                    Image(systemName: symbolName)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 102, height: 102)
                        .background(JPColors.elevatedSurface, in: Circle())
                        .shadow(color: tint.opacity(0.32), radius: 28, x: 0, y: 12)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.82).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct AnimatedNumberText: View {
    let value: Int
    var suffix = ""
    var font: Font = .system(size: 34, weight: .bold, design: .rounded)
    var color: Color = JPColors.primaryText

    var body: some View {
        Text("\(value)\(suffix)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.46, dampingFraction: 0.84), value: value)
    }
}

struct PremiumLoadingBlock: View {
    let title: String
    let subtitle: String
    var symbolName = "sparkles"

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: symbolName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(JPColors.accent)
                    .frame(width: 50, height: 50)
                    .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shimmer()

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }

                Spacer()
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .combine)
        .onAppear {
            debugPrint("SKELETON START:", title)
        }
        .onDisappear {
            debugPrint("SKELETON END:", title)
        }
    }
}

struct PremiumInlineLoader: View {
    let title: String
    var tint: Color = JPColors.accent
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.22), lineWidth: 2)
                    .frame(width: 18, height: 18)

                Circle()
                    .trim(from: 0.12, to: 0.82)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(pulse ? 360 : 0))
            }

            Text(title)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .accessibilityLabel(title)
        .onAppear {
            debugPrint("SKELETON START:", title)
            withAnimation(.linear(duration: 0.92).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .onDisappear {
            debugPrint("SKELETON END:", title)
        }
    }
}

struct PremiumEmptyStateCard: View {
    let symbolName: String
    let title: String
    let subtitle: String
    let buttonTitle: String?
    var tint: Color = JPColors.accent
    var action: (() -> Void)?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: symbolName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 70, height: 70)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 23, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let buttonTitle, let action {
                    Button {
                        JPHaptics.selection()
                        action()
                    } label: {
                        Text(buttonTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(tint, in: RoundedRectangle(cornerRadius: JPDesign.controlRadius, style: .continuous))
                    }
                    .premiumPress()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct DailyMissionCard: View {
    let title: String
    let subtitle: String
    let xp: Int
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(JPColors.graphite, lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: isComplete ? 1 : 0.42)
                        .stroke(JPColors.warning, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: isComplete)
                    Image(systemName: isComplete ? "checkmark" : "flag.checkered")
                        .font(.headline.weight(.black))
                        .foregroundStyle(isComplete ? JPColors.background : JPColors.warning)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Daily Mission")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.secondaryText)
                        .textCase(.uppercase)

                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: action) {
                    Text(isComplete ? "Done" : "+\(xp) XP")
                        .font(.caption.weight(.black))
                        .foregroundStyle(isComplete ? JPColors.background : JPColors.warning)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(isComplete ? JPColors.warning : JPColors.warning.opacity(0.14), in: Capsule())
                }
                .disabled(isComplete)
                .premiumPress()
            }
        }
    }
}

struct ConsistencyHeatmapView: View {
    let days: [DisciplineHistoryItem]
    var weekCount = 4

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = (0..<(weekCount * 7)).compactMap {
            calendar.date(byAdding: .day, value: -((weekCount * 7) - 1 - $0), to: today)
        }

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<weekCount, id: \.self) { week in
                    VStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { weekday in
                            let date = dates[min(week * 7 + weekday, dates.count - 1)]
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(color(for: date))
                                .frame(width: 18, height: 18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                                .scaleEffect(score(for: date) >= 100 ? 1.06 : 1)
                                .animation(.spring(response: 0.38, dampingFraction: 0.82).delay(Double(week * 7 + weekday) * 0.008), value: days.count)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                heatmapLegend("Missed", JPColors.loss.opacity(0.78))
                heatmapLegend("Disciplined", JPColors.profit.opacity(0.82))
                heatmapLegend("Perfect", JPColors.warning.opacity(0.90))
            }
        }
    }

    private func heatmapLegend(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
                .font(.caption2.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)
        }
    }

    private func color(for date: Date) -> Color {
        let value = score(for: date)
        if value >= 100 { return JPColors.warning.opacity(0.90) }
        if value >= 80 { return JPColors.profit.opacity(0.82) }
        if value > 0 { return JPColors.loss.opacity(0.78) }
        return JPColors.graphite.opacity(0.78)
    }

    private func score(for date: Date) -> Int {
        days.first { Calendar.current.isDate($0.date, inSameDayAs: date) }?.score ?? 0
    }
}
