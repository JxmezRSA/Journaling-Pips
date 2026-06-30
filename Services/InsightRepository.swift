import Foundation
import SwiftData

@MainActor
final class InsightRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchInsights() throws -> [Insight] {
        try context.fetch(FetchDescriptor<Insight>(sortBy: [
            SortDescriptor(\.date, order: .reverse),
            SortDescriptor(\.priority, order: .reverse)
        ]))
    }

    func fetchInsights(for tradeID: UUID) throws -> [Insight] {
        let descriptor = FetchDescriptor<Insight>(
            predicate: #Predicate { insight in
                insight.relatedTradeID == tradeID
            },
            sortBy: [
                SortDescriptor(\.priority, order: .reverse),
                SortDescriptor(\.date, order: .reverse)
            ]
        )
        return try context.fetch(descriptor)
    }

    func upsert(_ drafts: [InsightDraft]) throws {
        let existing = try fetchInsights()
        var existingByFingerprint: [String: Insight] = [:]
        for insight in existing {
            existingByFingerprint[insight.fingerprint] = insight
        }

        for draft in drafts {
            if let insight = existingByFingerprint[draft.fingerprint] {
                insight.title = draft.title
                insight.subtitle = draft.subtitle
                insight.icon = draft.icon
                insight.priority = draft.priority
                insight.category = draft.category
                insight.confidence = draft.confidence
                insight.relatedTradeID = draft.relatedTradeID
                insight.date = Date()
            } else {
                context.insert(Insight(
                    title: draft.title,
                    subtitle: draft.subtitle,
                    icon: draft.icon,
                    priority: draft.priority,
                    category: draft.category,
                    confidence: draft.confidence,
                    relatedTradeID: draft.relatedTradeID,
                    fingerprint: draft.fingerprint
                ))
            }
        }

        try context.save()
    }

    func markRead(_ insight: Insight) throws {
        insight.isRead = true
        try context.save()
    }
}
