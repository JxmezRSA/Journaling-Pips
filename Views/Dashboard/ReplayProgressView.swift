import SwiftUI

struct ReplayProgressView: View {
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Replay Progress")
                    .font(.caption.weight(.black))
                    .foregroundStyle(JPColors.secondaryText)
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.weight(.black))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(JPColors.graphite.opacity(0.92))
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.72), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(12, proxy.size.width * min(max(progress, 0), 1)))
                        .shadow(color: tint.opacity(0.28), radius: 10, x: 0, y: 0)
                }
            }
            .frame(height: 9)
        }
        .animation(JPDesign.smoothSpring, value: progress)
    }
}
