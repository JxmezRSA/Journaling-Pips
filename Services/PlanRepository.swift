import Foundation
import SwiftData

@MainActor
final class PlanRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchPlan(for date: Date, calendar: Calendar = .current) throws -> MorningPlan? {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let descriptor = FetchDescriptor<MorningPlan>(
            predicate: #Predicate { plan in
                plan.date >= startOfDay && plan.date < endOfDay
            },
            sortBy: [SortDescriptor(\MorningPlan.date, order: .reverse)]
        )

        return try context.fetch(descriptor).first
    }

    func createPlan(for date: Date, calendar: Calendar = .current) throws -> MorningPlan {
        let plan = MorningPlan(date: calendar.startOfDay(for: date))
        context.insert(plan)
        try context.save()
        return plan
    }

    func save() throws {
        try context.save()
    }
}
