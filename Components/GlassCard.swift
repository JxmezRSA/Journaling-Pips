import SwiftUI

struct GlassCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    private let cornerRadius: CGFloat

    init(
        padding: CGFloat = JPDesign.cardPadding,
        cornerRadius: CGFloat = JPDesign.cardRadius,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                JPColors.elevatedSurface.opacity(0.98),
                                JPColors.surface.opacity(0.90),
                                JPColors.background.opacity(0.62)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        JPColors.border,
                                        JPColors.accent.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: JPDesign.accentShadow, radius: 18, x: 0, y: 6)
                    .shadow(color: JPDesign.cardShadow, radius: 26, x: 0, y: 18)
            )
            .accessibilityElement(children: .contain)
    }
}
