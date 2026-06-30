import SwiftUI

struct ReplayLessonsView: View {
    let trade: Trade

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Lessons", subtitle: "What this trade teaches")

            VStack(spacing: 12) {
                lesson("What went well", wentWell, "checkmark.seal.fill", JPColors.profit)
                lesson("What went wrong", wentWrong, "exclamationmark.triangle.fill", JPColors.warning)
                lesson("What would you repeat", repeatAction, "repeat.circle.fill", JPColors.accent)
                lesson("Biggest lesson", biggestLesson, "lightbulb.fill", JPColors.warning)
                lesson("Journal Notes", notes, "book.pages.fill", JPColors.blue)
                placeholder
            }
        }
    }

    private var wentWell: String {
        if trade.followedPlan { return "You followed the plan and protected process quality." }
        if trade.status == .win { return "The trade produced a positive outcome worth reviewing." }
        return "The journal creates a clear review trail for improvement."
    }

    private var wentWrong: String {
        if !trade.mistakeTags.isEmpty {
            return trade.mistakeTags.map(\.rawValue).joined(separator: ", ")
        }
        return trade.status == .loss ? "Loss needs a structured review to isolate the cause." : "No major mistake tags were logged."
    }

    private var repeatAction: String {
        trade.riskReward >= 2 ? "Keep prioritizing setups with strong reward relative to risk." : "Repeat the preparation, but demand cleaner reward potential."
    }

    private var biggestLesson: String {
        trade.lessonsLearned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add one clear lesson after each replay." : trade.lessonsLearned
    }

    private var notes: String {
        let text = [trade.tradeThesis, trade.marketContext, trade.executionReview, trade.notes].first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
        return text.isEmpty ? "No journal notes were added yet." : text
    }

    private func lesson(_ title: String, _ text: String, _ icon: String, _ tint: Color) -> some View {
        GlassCard(padding: 16, cornerRadius: 24) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(JPColors.primaryText)
                    Text(text)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
    }

    private var placeholder: some View {
        GlassCard(padding: 16, cornerRadius: 24) {
            HStack(spacing: 13) {
                Image(systemName: "waveform.circle.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(JPColors.purple)
                    .frame(width: 42, height: 42)
                    .background(JPColors.purple.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Voice Note")
                        .font(.headline.weight(.black))
                        .foregroundStyle(JPColors.primaryText)
                    Text("Coming soon. Replay Studio is ready for voice reflections.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                }
                Spacer()
            }
        }
    }
}
