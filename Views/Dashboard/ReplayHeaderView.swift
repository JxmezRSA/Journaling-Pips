import SwiftUI
import UIKit

struct ReplayHeaderView: View {
    let trade: Trade
    let viewModel: ReplayViewModel
    let progress: Double

    private var heroImage: UIImage? {
        [trade.beforeEntryImageData, trade.duringTradeImageData, trade.afterExitImageData].compactMap { $0 }.compactMap(UIImage.init(data:)).first
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(LinearGradient(colors: [JPColors.elevatedSurface, JPColors.surface.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))

            if let heroImage {
                Image(uiImage: heroImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 380)
                    .clipped()
                    .overlay(Color.black.opacity(0.50))
                    .overlay(LinearGradient(colors: [.clear, JPColors.background.opacity(0.95)], startPoint: .top, endPoint: .bottom))
            } else {
                Circle()
                    .fill(outcomeTint.opacity(0.22))
                    .frame(width: 280, height: 280)
                    .blur(radius: 72)
                    .offset(x: 160, y: -120)
            }

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trade Replay Studio")
                            .font(.caption.weight(.black))
                            .foregroundStyle(JPColors.secondaryText)
                            .textCase(.uppercase)

                        Text(trade.pair)
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        HStack(spacing: 8) {
                            badge(trade.direction.rawValue, trade.direction == .buy ? JPColors.profit : JPColors.loss)
                            badge(trade.status.rawValue, outcomeTint)
                            badge(trade.session.rawValue, JPColors.blue)
                        }
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Text("\(viewModel.localAIScore(for: trade))")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(outcomeTint)
                        Text("AI Score")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                    .frame(width: 94, height: 94)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(outcomeTint.opacity(0.28), lineWidth: 1))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    heroMetric("Date", trade.date.formatted(.dateTime.day().month().year()), "calendar")
                    heroMetric("RR", String(format: "%.2fR", trade.riskReward), "scale.3d")
                    heroMetric("Pips", viewModel.pips(for: trade), "point.3.connected.trianglepath.dotted")
                    heroMetric("Profit", currency(trade.profitLoss), "banknote.fill")
                    heroMetric("Holding", viewModel.holdingTime(for: trade), "timer")
                    heroMetric("Execution", "\(viewModel.executionScore(for: trade))", "bolt.fill")
                    heroMetric("Discipline", "\(viewModel.disciplineScore(for: trade))", "checkmark.seal.fill")
                    heroMetric("AI", viewModel.aiReview.map { "\($0.overallScore)" } ?? "\(viewModel.localAIScore(for: trade))", "sparkles")
                }

                ReplayProgressView(progress: progress, tint: outcomeTint)
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(JPColors.border, lineWidth: 1))
        .shadow(color: outcomeTint.opacity(0.16), radius: 28, x: 0, y: 18)
    }

    private var outcomeTint: Color {
        switch trade.status {
        case .win: return JPColors.profit
        case .loss: return JPColors.loss
        case .breakeven: return JPColors.warning
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.black))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(color.opacity(0.16), in: Capsule())
    }

    private func heroMetric(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.caption.weight(.black))
                .foregroundStyle(outcomeTint)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption.weight(.black))
                    .foregroundStyle(JPColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(JPColors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func currency(_ value: Double) -> String {
        "\(value >= 0 ? "+" : "-")$\(Int(abs(value)).formatted())"
    }
}
