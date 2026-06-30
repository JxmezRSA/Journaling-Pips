import SwiftUI

enum JPColors {
    static let background = Color(red: 0.015, green: 0.018, blue: 0.026)
    static let surface = Color(red: 0.065, green: 0.072, blue: 0.090)
    static let elevatedSurface = Color(red: 0.105, green: 0.115, blue: 0.140)
    static let graphite = Color(red: 0.125, green: 0.135, blue: 0.160)
    static let border = Color.white.opacity(0.12)
    static let primaryText = Color(red: 0.94, green: 0.96, blue: 0.98)
    static let secondaryText = Color(red: 0.58, green: 0.63, blue: 0.70)
    static let mutedText = Color(red: 0.38, green: 0.43, blue: 0.50)
    static let accent = Color(red: 0.18, green: 0.86, blue: 0.67)
    static let accentSoft = Color(red: 0.18, green: 0.86, blue: 0.67).opacity(0.16)
    static let profit = Color(red: 0.20, green: 0.88, blue: 0.48)
    static let loss = Color(red: 1.00, green: 0.32, blue: 0.39)
    static let warning = Color(red: 1.00, green: 0.72, blue: 0.28)
    static let blue = Color(red: 0.28, green: 0.56, blue: 1.00)
    static let purple = Color(red: 0.58, green: 0.44, blue: 1.00)

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.025, green: 0.030, blue: 0.042),
            background,
            Color(red: 0.018, green: 0.026, blue: 0.030)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum JPDesign {
    static let cardRadius: CGFloat = 28
    static let controlRadius: CGFloat = 18
    static let compactRadius: CGFloat = 14
    static let cardPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let cardSpacing: CGFloat = 14
    static let iconSize: CGFloat = 44
    static let minimumTouchTarget: CGFloat = 44

    static let cardShadow = Color.black.opacity(0.34)
    static let accentShadow = JPColors.accent.opacity(0.08)

    static let quickSpring = Animation.spring(response: 0.26, dampingFraction: 0.78)
    static let smoothSpring = Animation.spring(response: 0.46, dampingFraction: 0.86)
    static let slowSpring = Animation.spring(response: 0.62, dampingFraction: 0.86)
}
