import SwiftUI

struct PlaceholderScreen: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        NavigationStack {
            ZStack {
                JPColors.background.ignoresSafeArea()

                VStack(spacing: 18) {
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(JPColors.accent)
                        .frame(width: 68, height: 68)
                        .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(spacing: 8) {
                        Text(title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(JPColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                    }
                }
                .padding(24)
            }
            .navigationTitle(title)
            .toolbarBackground(JPColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
