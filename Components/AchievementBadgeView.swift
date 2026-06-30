import SwiftUI

struct AchievementBadgeView: View {
    let achievement: Achievement

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: achievement.symbolName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(achievement.isUnlocked ? JPColors.warning : JPColors.secondaryText)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(achievement.isUnlocked ? JPColors.warning.opacity(0.15) : JPColors.graphite.opacity(0.72))
                        )

                    Spacer()

                    Image(systemName: achievement.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(achievement.isUnlocked ? JPColors.accent : JPColors.mutedText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(achievement.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(achievement.isUnlocked ? JPColors.primaryText : JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(achievement.achievementDescription)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let date = achievement.unlockedDate {
                    Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(JPColors.warning)
                } else {
                    Text("Locked")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(JPColors.mutedText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        }
        .opacity(achievement.isUnlocked ? 1 : 0.62)
        .scaleEffect(achievement.isUnlocked ? 1 : 0.97)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: achievement.isUnlocked)
    }
}
