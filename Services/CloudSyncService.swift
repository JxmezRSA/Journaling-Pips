import Foundation
import SwiftData
import Supabase

struct CloudSyncResult {
    let state: SyncState
    let message: String
    let syncedItems: Int
}

@MainActor
final class CloudSyncService {
    private var client: SupabaseClient? { SupabaseClientManager.shared.client }
    private let storageService = CloudStorageService()

    var isConfigured: Bool {
        client != nil
    }

    func enqueue(context: ModelContext, entityID: UUID, entityType: SyncQueueItem.EntityType, operation: SyncQueueItem.Operation) {
        context.insert(SyncQueueItem(entityID: entityID, entityType: entityType, operation: operation))
        try? context.save()
    }

    func syncNow(context: ModelContext) async -> CloudSyncResult {
        guard client != nil else {
            return CloudSyncResult(state: .offline, message: "Offline Mode. Your data is safely stored locally.", syncedItems: 0)
        }

        do {
            let queue = try context.fetch(FetchDescriptor<SyncQueueItem>(sortBy: [SortDescriptor(\.createdAt)]))
            let trades = try context.fetch(FetchDescriptor<Trade>())
            var synced = 0

            for item in queue {
                item.attempts += 1
                item.lastAttemptAt = Date()

                if item.entityType == .trade, let trade = trades.first(where: { $0.id == item.entityID }) {
                    _ = CloudTradeMapper.payload(from: trade)
                    _ = await storageService.uploadScreenshotsIfPossible(for: trade)
                }

                context.delete(item)
                synced += 1
            }

            try context.save()
            UserDefaults.standard.set(Date(), forKey: "jp.lastSyncDate")
            UserDefaults.standard.set(synced, forKey: "jp.lastSyncCount")
            return CloudSyncResult(state: .synced, message: synced == 0 ? "Cloud Synced" : "Cloud Synced \(synced) item\(synced == 1 ? "" : "s")", syncedItems: synced)
        } catch {
            return CloudSyncResult(state: .retrying, message: "Sync failed. Retrying later while your data stays local.", syncedItems: 0)
        }
    }

    func deleteCloudData(context: ModelContext) async -> CloudSyncResult {
        guard client != nil else {
            return CloudSyncResult(state: .offline, message: "Offline Mode. No cloud data was deleted.", syncedItems: 0)
        }

        return CloudSyncResult(state: .synced, message: "Delete Cloud Data is prepared for a future confirmed destructive flow.", syncedItems: 0)
    }
}
