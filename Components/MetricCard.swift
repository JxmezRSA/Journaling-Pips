import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        ZStack(alignment: .leading) {
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(tint)
                            .frame(width: 42, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(tint.opacity(0.16))
                            )

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)

                        Text(value)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)
                            .minimumScaleFactor(0.66)
                            .lineLimit(1)

                        Text(detail)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(JPColors.mutedText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 142)
            }

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(tint)
                .frame(width: 4)
                .padding(.vertical, 28)
                .shadow(color: tint.opacity(0.55), radius: 12, x: 0, y: 0)
        }
        .shadow(color: tint.opacity(0.08), radius: 18, x: 0, y: 8)
    }
}
