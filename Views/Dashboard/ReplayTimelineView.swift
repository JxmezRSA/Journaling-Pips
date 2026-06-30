import SwiftUI
import UIKit

struct ReplayTimelineView: View {
    let stages: [ReplayStage]
    let isComplete: Bool
    let onScreenshotTap: (ReplayScreenshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Trade Film Timeline", subtitle: "Before entry to lessons learned")

            VStack(spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(stage.tint)
                                    .frame(width: 40, height: 40)
                                    .shadow(color: stage.tint.opacity(index == stages.count - 1 ? 0.4 : 0.18), radius: index == stages.count - 1 ? 16 : 8, x: 0, y: 6)
                                Image(systemName: stage.icon)
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(JPColors.background)
                            }

                            if index < stages.count - 1 {
                                Rectangle()
                                    .fill(JPColors.border)
                                    .frame(width: 2, height: 62)
                            }
                        }

                        GlassCard(padding: 15, cornerRadius: 22) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stage.title)
                                            .font(.headline.weight(.black))
                                            .foregroundStyle(JPColors.primaryText)
                                        Text(stage.time?.formatted(.dateTime.hour().minute()) ?? "Replay")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(JPColors.secondaryText)
                                    }
                                    Spacer()
                                    if stage.screenshotData != nil, let slot = stage.screenshotSlot {
                                        Button {
                                            onScreenshotTap(ReplayScreenshot(title: stage.title, subtitle: stage.subtitle, slot: slot, data: stage.screenshotData))
                                        } label: {
                                            Image(systemName: "photo.fill")
                                                .font(.caption.weight(.black))
                                                .foregroundStyle(stage.tint)
                                                .frame(width: 34, height: 34)
                                                .background(stage.tint.opacity(0.14), in: Circle())
                                        }
                                        .buttonStyle(ScalingButtonStyle())
                                    }
                                }

                                Text(stage.subtitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(JPColors.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let data = stage.screenshotData, let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 142)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(stage.tint.opacity(0.26), lineWidth: 1))
                                }
                            }
                        }
                        .scaleEffect(index == stages.count - 1 && !isComplete ? 1.012 : 1)
                        .animation(JPDesign.quickSpring, value: stages.count)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98)))
                }
            }
        }
    }
}
