import SwiftUI

struct DisciplineRingItem: Identifiable {
    let id = UUID()
    let title: String
    let progress: Double
    let color: Color
    let symbolName: String
    let explanation: String
}

struct RingProgressView: View {
    let item: DisciplineRingItem
    var size: CGFloat = 118
    var lineWidth: CGFloat = 13

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(JPColors.graphite.opacity(0.95), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: min(1, max(0, item.progress)))
                    .stroke(
                        AngularGradient(
                            colors: [item.color.opacity(0.7), item.color, JPColors.warning.opacity(0.9), item.color.opacity(0.7)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: item.color.opacity(0.28), radius: 12, x: 0, y: 4)
                    .animation(.spring(response: 0.6, dampingFraction: 0.86), value: item.progress)

                VStack(spacing: 4) {
                    Image(systemName: item.symbolName)
                        .font(.system(size: size * 0.18, weight: .bold))
                        .foregroundStyle(item.color)

                    Text("\(Int((item.progress * 100).rounded()))%")
                        .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .contentTransition(.numericText())
                }
            }
            .frame(width: size, height: size)

            VStack(spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(JPColors.primaryText)
                    .multilineTextAlignment(.center)

                Text(item.explanation)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(JPColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: item.progress)
    }
}
