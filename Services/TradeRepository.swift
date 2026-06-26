import Foundation
import SwiftData

@MainActor
final class TradeRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchTrades() throws -> [Trade] {
        var descriptor = FetchDescriptor<Trade>(
            sortBy: [SortDescriptor(\Trade.date, order: .reverse)]
        )
        descriptor.includePendingChanges = true

        return try context.fetch(descriptor)
    }

    func saveTrade(_ trade: Trade) throws {
        context.insert(trade)
        try context.save()
    }

    func updateTrade(_ trade: Trade) throws {
        try context.save()
    }

    func deleteTrade(_ trade: Trade) throws {
        context.delete(trade)
        try context.save()
    }
}
