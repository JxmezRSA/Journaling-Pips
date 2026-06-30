import SwiftUI

struct ReplayAICommentaryView: View {
    let commentary: [ReplayCommentary]
    let activeIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "AI Commentary", subtitle: "Coaching notes revealed through the replay")

            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 13) {
                        Text("✨")
                            .font(.system(size: 34))
                            .frame(width: 58, height: 58)
                            .background(JPColors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Replay Coach")
                                .font(.headline.weight(.black))
                                .foregroundStyle(JPColors.primaryText)
                            Text("Local commentary now. AI-ready later.")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.secondaryText)
                        }
                    }

                    if commentary.isEmpty {
                        Text("Add journal notes or save an AI review to unlock richer commentary.")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        let item = commentary[min(max(activeIndex, 0), commentary.count - 1)]
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.headline.weight(.black))
                                .foregroundStyle(item.tint)
                            Text(item.text)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(JPColors.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .id(item.id)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(JPDesign.smoothSpring, value: item.id)
                    }
                }
            }
        }
    }
}
