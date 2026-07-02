import SwiftUI

enum JPColors {
    static let background = Color(red: 0.006, green: 0.018, blue: 0.040)
    static let surface = Color(red: 0.026, green: 0.060, blue: 0.112)
    static let elevatedSurface = Color(red: 0.040, green: 0.092, blue: 0.168)
    static let graphite = Color(red: 0.058, green: 0.120, blue: 0.205)
    static let border = Color(red: 0.22, green: 0.78, blue: 1.00).opacity(0.16)
    static let primaryText = Color(red: 0.94, green: 0.975, blue: 1.00)
    static let secondaryText = Color(red: 0.62, green: 0.72, blue: 0.84)
    static let mutedText = Color(red: 0.40, green: 0.50, blue: 0.64)
    static let accent = Color(red: 0.000, green: 0.455, blue: 1.000)
    static let accentSoft = Color(red: 0.000, green: 0.455, blue: 1.000).opacity(0.18)
    static let profit = Color(red: 0.000, green: 0.820, blue: 0.940)
    static let loss = Color(red: 1.000, green: 0.365, blue: 0.445)
    static let warning = Color(red: 1.000, green: 0.700, blue: 0.260)
    static let blue = Color(red: 0.190, green: 0.780, blue: 1.000)
    static let purple = Color(red: 0.430, green: 0.510, blue: 1.000)

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.018, green: 0.050, blue: 0.105),
            background,
            Color(red: 0.002, green: 0.012, blue: 0.030)
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

    static let cardShadow = Color.black.opacity(0.42)
    static let accentShadow = JPColors.blue.opacity(0.12)

    static let quickSpring = Animation.spring(response: 0.26, dampingFraction: 0.78)
    static let smoothSpring = Animation.spring(response: 0.46, dampingFraction: 0.86)
    static let slowSpring = Animation.spring(response: 0.62, dampingFraction: 0.86)
}
