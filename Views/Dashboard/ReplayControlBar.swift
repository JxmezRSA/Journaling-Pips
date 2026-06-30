import SwiftUI

struct ReplayControlBar: View {
    let isPlaying: Bool
    let canStepBackward: Bool
    let canStepForward: Bool
    let onBack: () -> Void
    let onPlayPause: () -> Void
    let onForward: () -> Void
    let onRestart: () -> Void

    var body: some View {
        GlassCard(padding: 14, cornerRadius: 30) {
            HStack(spacing: 12) {
                control("backward.end.fill", "Back", isEnabled: canStepBackward, action: onBack)
                control(isPlaying ? "pause.fill" : "play.fill", isPlaying ? "Pause" : "Play", isPrimary: true, action: onPlayPause)
                control("forward.end.fill", "Next", isEnabled: canStepForward, action: onForward)
                control("arrow.counterclockwise", "Restart", action: onRestart)
            }
        }
    }

    private func control(_ icon: String, _ title: String, isPrimary: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.headline.weight(.black))
                Text(title)
                    .font(.caption2.weight(.black))
            }
            .foregroundStyle(isPrimary ? JPColors.background : (isEnabled ? JPColors.primaryText : JPColors.mutedText))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(isPrimary ? JPColors.accent : JPColors.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(isPrimary ? JPColors.accent.opacity(0.3) : JPColors.border, lineWidth: 1))
            .shadow(color: isPrimary ? JPColors.accent.opacity(0.22) : .clear, radius: 14, x: 0, y: 8)
        }
        .buttonStyle(ScalingButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}
