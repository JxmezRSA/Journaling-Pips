import SwiftUI
import UIKit

struct ReplayScreenshotCarousel: View {
    let screenshots: [ReplayScreenshot]
    let onTap: (ReplayScreenshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Screenshot Story", subtitle: "Before, during, and after the trade")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(screenshots) { item in
                        Button {
                            if item.data != nil {
                                onTap(item)
                            } else {
                                JPHaptics.selection()
                            }
                        } label: {
                            screenshotCard(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func screenshotCard(_ item: ReplayScreenshot) -> some View {
        GlassCard(padding: 14, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline.weight(.black))
                            .foregroundStyle(JPColors.primaryText)
                        Text(item.subtitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: item.data == nil ? "camera.viewfinder" : "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.black))
                        .foregroundStyle(JPColors.accent)
                        .frame(width: 34, height: 34)
                        .background(JPColors.accentSoft, in: Circle())
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(JPColors.graphite)
                        .frame(width: 258, height: 176)

                    if let data = item.data, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 258, height: 176)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        VStack(spacing: 9) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(JPColors.secondaryText)
                            Text("No screenshot yet")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(JPColors.secondaryText)
                        }
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JPColors.border, lineWidth: 1))
            }
            .frame(width: 286)
        }
    }
}
