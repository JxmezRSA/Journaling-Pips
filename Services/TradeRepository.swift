import Foundation
import SwiftData

@MainActor
final class TradeRepository {
    let context: ModelContext

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
        debugPrint("BEGIN LOCAL TRADE SAVE")
        trade.updatedAt = Date()
        trade.syncStatus = .pending
        context.insert(trade)
        enqueueSyncItem(entityID: trade.id, entityType: .trade, operation: .upload)
        do {
            try context.save()
            debugPrint("LOCAL TRADE SAVE SUCCESS")
            checkScreenshotsAndQueueUpload(for: trade)
            syncInBackgroundIfEnabled()
        } catch {
            debugPrint("LOCAL TRADE SAVE FAILED:", String(describing: error))
            throw error
        }
    }

    func updateTrade(_ trade: Trade) throws {
        trade.updatedAt = Date()
        trade.syncStatus = .pending
        enqueueSyncItem(entityID: trade.id, entityType: .trade, operation: .update)
        try context.save()
        checkScreenshotsAndQueueUpload(for: trade)
        syncInBackgroundIfEnabled()
    }

    func deleteTrade(_ trade: Trade) throws {
        let tradeID = trade.id
        context.delete(trade)
        enqueueSyncItem(entityID: tradeID, entityType: .trade, operation: .delete)
        try context.save()
        syncInBackgroundIfEnabled()
    }

    private func syncInBackgroundIfEnabled() {
        let autoSync = UserDefaults.standard.object(forKey: "jp.autoSync") as? Bool ?? true
        guard autoSync, SupabaseClientManager.shared.isConfigured else { return }

        Task { @MainActor in
            debugPrint("BEGIN BACKGROUND TRADE SYNC")
            try? await Task.sleep(nanoseconds: 750_000_000)
            let result = await CloudSyncService().syncNow(context: context)
            if result.state != .synced {
                debugPrint("BACKGROUND TRADE SYNC FAILED:", result.message)
            }
        }
    }

    private func checkScreenshotsAndQueueUpload(for trade: Trade) {
        debugPrint("BEGIN SCREENSHOT CHECK")
        defer { debugPrint("END SCREENSHOT CHECK") }

        let screenshots: [(label: String, exists: Bool)] = [
            ("before", trade.beforeEntryImageData != nil),
            ("during", trade.duringTradeImageData != nil),
            ("after", trade.afterExitImageData != nil)
        ]

        for screenshot in screenshots {
            debugPrint("\(screenshot.label) screenshot exists:", screenshot.exists)
            if screenshot.exists {
                debugPrint("SCREENSHOT FOUND:", screenshot.label)
            } else {
                debugPrint("SCREENSHOT NOT FOUND:", screenshot.label)
            }
        }

        guard screenshots.contains(where: \.exists) else { return }

        if trade.remoteId == nil {
            debugPrint("SCREENSHOT QUEUED WAITING FOR REMOTE ID:", trade.id.uuidString)
        } else {
            debugPrint("SCREENSHOT FOUND:", trade.id.uuidString, "remoteId:", trade.remoteId ?? "")
        }

        enqueueScreenshotUploadIfNeeded(for: trade)
    }

    private func enqueueScreenshotUploadIfNeeded(for trade: Trade) {
        let descriptor = FetchDescriptor<SyncQueueItem>()
        let existingItems = (try? context.fetch(descriptor)) ?? []
        let alreadyQueued = existingItems.contains { item in
            item.entityID == trade.id && item.entityType == .screenshot
        }

        guard alreadyQueued == false else {
            debugPrint("SCREENSHOT QUEUED:", trade.id.uuidString, "existing pending upload")
            return
        }

        context.insert(SyncQueueItem(entityID: trade.id, entityType: .screenshot, operation: .upload))
        do {
            try context.save()
            debugPrint("SCREENSHOT QUEUED:", trade.id.uuidString)
        } catch {
            debugPrint("SCREENSHOT UPLOAD FAILED:", "Unable to queue screenshot upload:", String(describing: error))
        }
    }

    private func enqueueSyncItem(entityID: UUID, entityType: SyncQueueItem.EntityType, operation: SyncQueueItem.Operation) {
        let existingItems = (try? context.fetch(FetchDescriptor<SyncQueueItem>())) ?? []
        let alreadyQueued = existingItems.contains { item in
            item.entityID == entityID && item.entityType == entityType && item.operation == operation
        }

        guard alreadyQueued == false else {
            debugPrint("skipped duplicate:", entityID.uuidString, entityType.rawValue, operation.rawValue)
            return
        }

        context.insert(SyncQueueItem(entityID: entityID, entityType: entityType, operation: operation))
    }
}
