import Combine
import Foundation
import SwiftData

enum InsightSort: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case performance = "Performance"
    case psychology = "Psychology"
    case risk = "Risk"
    case discipline = "Discipline"
    case execution = "Execution"

    var id: String { rawValue }
}

@MainActor
final class InsightViewModel: ObservableObject {
    @Published private(set) var insights: [Insight] = []
    @Published var selectedSort = InsightSort.newest
    @Published var errorMessage: String?

    private var repository: InsightRepository?
    private var engine: IntelligenceEngine?

    func configure(context: ModelContext) {
        repository = InsightRepository(context: context)
        engine = IntelligenceEngine(context: context)
        refresh()
    }

    func refresh(event: IntelligenceEvent = .analyticsUpdated) {
        do {
            try engine?.refreshInsights(trigger: event)
            insights = try repository?.fetchInsights() ?? []
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load smart insights."
        }
    }

    func insights(for trade: Trade) -> [Insight] {
        guard let repository else { return [] }
        return (try? repository.fetchInsights(for: trade.id)) ?? []
    }

    var sortedInsights: [Insight] {
        switch selectedSort {
        case .newest:
            return insights.sorted { $0.date > $1.date }
        case .performance:
            return filtered(.performance)
        case .psychology:
            return filtered(.psychology)
        case .risk:
            return filtered(.risk)
        case .discipline:
            return filtered(.discipline)
        case .execution:
            return filtered(.execution)
        }
    }

    var rotatingInsights: [Insight] {
        Array(insights.shuffled().prefix(6))
    }

    private func filtered(_ category: Insight.Category) -> [Insight] {
        insights
            .filter { $0.category == category }
            .sorted {
                if $0.priority == $1.priority {
                    return $0.date > $1.date
                }
                return $0.priority > $1.priority
            }
    }
}
