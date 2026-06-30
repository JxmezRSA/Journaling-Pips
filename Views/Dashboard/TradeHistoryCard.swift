import SwiftUI
import UIKit

struct TradeHistoryCard: View {
    let trade: Trade
    let isFavorite: Bool
    let aiScore: Int?
    let screenshotCount: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    thumbnail

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(trade.pair)
                                        .font(.title3.weight(.black))
                                        .foregroundStyle(JPColors.primaryText)

                                    if isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.caption.weight(.black))
                                            .foregroundStyle(JPColors.warning)
                                    }
                                }

                                Text(trade.date.formatted(date: .omitted, time: .shortened))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(JPColors.secondaryText)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 5) {
                                Text(currency(trade.profitLoss))
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(resultColor)
                                    .contentTransition(.numericText())

                                Text("RR \(String(format: "%.2f", trade.riskReward))")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(JPColors.warning)
                            }
                        }

                        HStack(spacing: 7) {
                            badge(trade.direction.rawValue, tint: trade.direction == .buy ? JPColors.profit : JPColors.loss)
                            badge(trade.status.rawValue, tint: resultColor)
                            badge(trade.session.rawValue, tint: JPColors.blue)
                        }

                        Text(trade.strategy.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                            .lineLimit(1)
                    }
                }

                if !notePreview.isEmpty {
                    Text(notePreview)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !trade.mistakeTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(trade.mistakeTags.prefix(4)) { tag in
                                Text(tag.rawValue)
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(tag == .goodDiscipline ? JPColors.profit : JPColors.warning)
                                    .padding(.horizontal, 9)
                                    .frame(height: 28)
                                    .background((tag == .goodDiscipline ? JPColors.profit : JPColors.warning).opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }

                Divider().overlay(JPColors.border)

                HStack(spacing: 10) {
                    footerMetric("\(screenshotCount)", "Shots", "photo.stack.fill", JPColors.accent)
                    footerMetric(aiScoreText, "AI", "sparkles", JPColors.warning)
                    footerMetric(trade.followedPlan ? "Yes" : "No", "Plan", "checklist.checked", trade.followedPlan ? JPColors.profit : JPColors.loss)

                    Spacer(minLength: 0)

                    Image(systemName: "play.rectangle.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.accent)
                        .padding(9)
                        .background(JPColors.accentSoft, in: Circle())
                        .accessibilityLabel("Replay available")
                }
            }
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(resultColor)
                .frame(width: 4)
                .padding(.vertical, 26)
                .shadow(color: resultColor.opacity(0.48), radius: 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trade.pair), \(trade.direction.rawValue), \(trade.status.rawValue), profit loss \(currency(trade.profitLoss)), risk reward \(String(format: "%.2f", trade.riskReward))")
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(resultColor.opacity(0.12))
                .frame(width: 78, height: 86)

            if let data = firstImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 78, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        LinearGradient(colors: [.clear, Color.black.opacity(0.34)], startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    )
            } else {
                Image(systemName: trade.status == .win ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(resultColor)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(resultColor.opacity(0.24), lineWidth: 1))
    }

    private var firstImageData: Data? {
        trade.beforeEntryImageData ?? trade.duringTradeImageData ?? trade.afterExitImageData
    }

    private var notePreview: String {
        [trade.tradeThesis, trade.notes, trade.lessonsLearned]
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var aiScoreText: String {
        guard let aiScore else { return "--" }
        return "\(aiScore)"
    }

    private var resultColor: Color {
        switch trade.status {
        case .win: return JPColors.profit
        case .loss: return JPColors.loss
        case .breakeven: return JPColors.warning
        }
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.black))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(tint.opacity(0.13), in: Capsule())
    }

    private func footerMetric(_ value: String, _ title: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .foregroundStyle(JPColors.primaryText)
            Text(title)
                .foregroundStyle(JPColors.secondaryText)
        }
        .font(.caption2.weight(.black))
    }

    private func currency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(Int(abs(value)).formatted())"
    }
}
