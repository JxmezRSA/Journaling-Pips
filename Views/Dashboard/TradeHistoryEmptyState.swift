import SwiftUI

struct TradeHistoryEmptyState: View {
    let hasTrades: Bool
    let action: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(JPColors.accentSoft)
                        .frame(width: 78, height: 78)

                    Image(systemName: hasTrades ? "line.3.horizontal.decrease.circle.fill" : "book.closed.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(JPColors.accent)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(hasTrades ? "No trades match this view." : "Your trading story starts here.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text(hasTrades ? "Try clearing search, changing filters, or selecting another day." : "Every great trader began with one journal entry.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    JPHaptics.selection()
                    action()
                } label: {
                    Label(hasTrades ? "Log Trade" : "Log Your First Trade", systemImage: "plus.circle.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(colors: [JPColors.accent, JPColors.profit], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .shadow(color: JPColors.accent.opacity(0.24), radius: 18, x: 0, y: 10)
                }
                .buttonStyle(ScalingButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
