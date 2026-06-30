import Foundation
import SwiftData
import Supabase
#if canImport(UIKit)
import UIKit
#endif

struct CloudSyncResult {
    let state: SyncState
    let message: String
    let syncedItems: Int
}

struct CloudTradePayload: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let pair: String
    let direction: String
    let entryPrice: Double
    let stopLoss: Double
    let takeProfit: Double
    let profitLoss: Double
    let notes: String
    let exitPrice: Double
    let lotSize: Double
    let riskPercent: Double
    let date: Date
    let status: String
    let riskReward: Double
    let session: String
    let strategy: String
    let mistakeTags: [String]
    let confidence: Double
    let emotion: String
    let executionScore: Int
    let followedPlan: Bool
    let tradeThesis: String
    let marketContext: String
    let executionReview: String
    let lessonsLearned: String
    let screenshotCount: Int
    let remoteUpdatedAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case pair
        case direction
        case entryPrice = "entry_price"
        case stopLoss = "stop_loss"
        case takeProfit = "take_profit"
        case profitLoss = "profit_loss"
        case notes
        case exitPrice = "exit_price"
        case lotSize = "lot_size"
        case riskPercent = "risk_percent"
        case date
        case status
        case riskReward = "risk_reward"
        case session
        case strategy
        case mistakeTags = "mistake_tags"
        case confidence
        case emotion
        case executionScore = "execution_score"
        case followedPlan = "followed_plan"
        case tradeThesis = "trade_thesis"
        case marketContext = "market_context"
        case executionReview = "execution_review"
        case lessonsLearned = "lessons_learned"
        case screenshotCount = "screenshot_count"
        case remoteUpdatedAt = "remote_updated_at"
        case updatedAt = "updated_at"
    }
}

struct CloudScreenshotAssetPayload: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let tradeId: UUID
    let slot: String
    let storagePath: String
    let byteCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case tradeId = "trade_id"
        case slot
        case storagePath = "storage_path"
        case byteCount = "byte_count"
        case createdAt = "created_at"
    }
}

struct CloudAIReviewPayload: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let tradeId: UUID
    let overallScore: Int
    let grade: String
    let summary: String
    let strengths: [String]
    let improvements: [String]
    let executionScore: Int
    let riskScore: Int
    let psychologyScore: Int
    let journalQualityScore: Int
    let strategyDisciplineScore: Int
    let payload: [String: String]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case tradeId = "trade_id"
        case overallScore = "overall_score"
        case grade
        case summary
        case strengths
        case improvements
        case executionScore = "execution_score"
        case riskScore = "risk_score"
        case psychologyScore = "psychology_score"
        case journalQualityScore = "journal_quality_score"
        case strategyDisciplineScore = "strategy_discipline_score"
        case payload
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum CloudTradeMapper {
    static func payload(from trade: Trade, userID: UUID) -> CloudTradePayload {
        CloudTradePayload(
            id: trade.id,
            userId: userID,
            pair: trade.pair,
            direction: trade.direction.rawValue,
            entryPrice: trade.entryPrice,
            stopLoss: trade.stopLoss,
            takeProfit: trade.takeProfit,
            profitLoss: trade.profitLoss,
            notes: trade.notes,
            exitPrice: trade.exitPrice,
            lotSize: trade.lotSize,
            riskPercent: trade.riskPercent,
            date: trade.date,
            status: trade.status.rawValue,
            riskReward: trade.riskReward,
            session: trade.session.rawValue,
            strategy: trade.strategy.rawValue,
            mistakeTags: trade.mistakeTags.map(\.rawValue),
            confidence: trade.confidence,
            emotion: trade.emotion,
            executionScore: trade.executionScore,
            followedPlan: trade.followedPlan,
            tradeThesis: trade.tradeThesis,
            marketContext: trade.marketContext,
            executionReview: trade.executionReview,
            lessonsLearned: trade.lessonsLearned,
            screenshotCount: [trade.beforeEntryImageData, trade.duringTradeImageData, trade.afterExitImageData].compactMap { $0 }.count,
            remoteUpdatedAt: trade.updatedAt,
            updatedAt: trade.updatedAt
        )
    }

    static func trade(from payload: CloudTradePayload) -> Trade {
        Trade(
            id: payload.id,
            pair: payload.pair,
            direction: Trade.Direction(rawValue: payload.direction) ?? .buy,
            entryPrice: payload.entryPrice,
            stopLoss: payload.stopLoss,
            takeProfit: payload.takeProfit,
            profitLoss: payload.profitLoss,
            notes: payload.notes,
            exitPrice: payload.exitPrice,
            lotSize: payload.lotSize,
            riskPercent: payload.riskPercent,
            date: payload.date,
            status: Trade.Status(rawValue: payload.status) ?? .breakeven,
            riskReward: payload.riskReward,
            session: Trade.Session(rawValue: payload.session) ?? .london,
            strategy: Trade.Strategy(rawValue: payload.strategy) ?? .other,
            mistakeTags: payload.mistakeTags.compactMap(Trade.MistakeTag.init(rawValue:)),
            confidence: payload.confidence,
            emotion: payload.emotion,
            executionScore: payload.executionScore,
            followedPlan: payload.followedPlan,
            tradeThesis: payload.tradeThesis,
            marketContext: payload.marketContext,
            executionReview: payload.executionReview,
            lessonsLearned: payload.lessonsLearned,
            remoteId: payload.id.uuidString,
            syncStatus: .synced,
            lastSyncedAt: Date(),
            updatedAt: payload.remoteUpdatedAt
        )
    }
}

@MainActor
final class CloudSyncService {
    private var client: SupabaseClient? { SupabaseClientManager.shared.client }

    var isConfigured: Bool {
        client != nil
    }

    func enqueue(context: ModelContext, entityID: UUID, entityType: SyncQueueItem.EntityType, operation: SyncQueueItem.Operation) {
        let existingItems = (try? context.fetch(FetchDescriptor<SyncQueueItem>())) ?? []
        let duplicate = existingItems.contains { item in
            item.entityID == entityID && item.entityType == entityType && item.operation == operation
        }
        guard duplicate == false else {
            debugPrint("skipped duplicate:", entityID.uuidString, entityType.rawValue, operation.rawValue)
            return
        }

        context.insert(SyncQueueItem(entityID: entityID, entityType: entityType, operation: operation))
        try? context.save()
    }

    func syncNow(context: ModelContext) async -> CloudSyncResult {
        debugPrint("BEGIN TRADE SYNC")
        defer { debugPrint("END TRADE SYNC") }

        guard let client else {
            debugPrint("SYNC FAILED:", "Supabase client is not configured")
            return CloudSyncResult(state: .offline, message: "Offline Mode. Your data is safely stored locally.", syncedItems: 0)
        }

        do {
            return try await withJPTimeout(seconds: 8) {
                try await self.performTradeSync(context: context, client: client)
            }
        } catch JPAsyncTimeoutError.timedOut {
            handleSyncFailure(context: context)
            debugPrint("SYNC TIMEOUT")
            return CloudSyncResult(state: .failed, message: "Sync timed out. Your local data is safe.", syncedItems: 0)
        } catch {
            handleSyncFailure(context: context)
            debugPrint("SYNC FAILED:", String(describing: error))
            debugPrint("sync failed localized:", error.localizedDescription)
            return CloudSyncResult(state: .failed, message: "Sync failed. Retrying later while your data stays local.", syncedItems: 0)
        }
    }

    func deleteCloudData(context: ModelContext) async -> CloudSyncResult {
        guard client != nil else {
            return CloudSyncResult(state: .offline, message: "Offline Mode. No cloud data was deleted.", syncedItems: 0)
        }

        return CloudSyncResult(state: .synced, message: "Delete Cloud Data is prepared for a future confirmed destructive flow.", syncedItems: 0)
    }

    private func performTradeSync(context: ModelContext, client: SupabaseClient) async throws -> CloudSyncResult {
        let user = try await client.auth.session.user
        debugPrint("trade sync user:", user.id.uuidString)
        try await processPendingScreenshotDeletes(client: client)

        let queue = try context.fetch(FetchDescriptor<SyncQueueItem>(sortBy: [SortDescriptor(\.createdAt)]))
        let trades = try context.fetch(FetchDescriptor<Trade>())
        let reviews = try context.fetch(FetchDescriptor<AITradeReview>())
        var synced = 0
        var hadNonFatalFailure = false

        for item in queue where item.entityType == .trade || item.entityType == .screenshot || item.entityType == .aiReview {
            guard shouldRetry(item) else {
                debugPrint("skipped duplicate:", item.entityID.uuidString, "waiting for retry backoff")
                hadNonFatalFailure = true
                continue
            }

            item.attempts += 1
            item.lastAttemptAt = Date()

            if item.entityType == .aiReview {
                guard let review = reviews.first(where: { $0.id == item.entityID }) else {
                    context.delete(item)
                    continue
                }

                guard let trade = trades.first(where: { $0.id == review.tradeID }) else {
                    debugPrint("AI REVIEW FAILED:", "local trade missing for review", review.id.uuidString)
                    hadNonFatalFailure = true
                    continue
                }

                guard let payload = aiReviewPayload(from: review, trade: trade, userID: user.id) else {
                    debugPrint("AI REVIEW FAILED:", "trade remote ID missing for review", review.id.uuidString)
                    hadNonFatalFailure = true
                    continue
                }

                try await client
                    .from("ai_reviews")
                    .upsert(payload, onConflict: "id")
                    .execute()

                debugPrint("uploaded ai review:", review.id.uuidString)
                context.delete(item)
                synced += 1
                continue
            }

            if item.entityType == .screenshot {
                guard let trade = trades.first(where: { $0.id == item.entityID }) else {
                    debugPrint("skipped duplicate:", item.entityID.uuidString, "local trade missing for screenshot queue item")
                    context.delete(item)
                    continue
                }

                guard trade.remoteId != nil else {
                    debugPrint("SCREENSHOT QUEUED:", trade.id.uuidString, "waiting for synced trade remoteId")
                    hadNonFatalFailure = true
                    continue
                }

                if await uploadScreenshotsIfReady(for: trade, userID: user.id, client: client) {
                    context.delete(item)
                    synced += 1
                } else {
                    hadNonFatalFailure = true
                }
                continue
            }

            switch item.operation {
            case .upload, .update:
                guard let trade = trades.first(where: { $0.id == item.entityID }) else {
                    debugPrint("skipped duplicate:", item.entityID.uuidString, "local trade missing for upload/update queue item")
                    context.delete(item)
                    continue
                }

                let payload = CloudTradeMapper.payload(from: trade, userID: user.id)
                try await client
                    .from("trades")
                    .upsert(payload, onConflict: "id")
                    .execute()

                trade.remoteId = payload.id.uuidString
                trade.syncStatus = .synced
                trade.lastSyncedAt = Date()
                debugPrint("uploaded trade:", trade.id.uuidString, trade.pair)
                if await uploadScreenshotsIfReady(for: trade, userID: user.id, client: client) {
                    deleteScreenshotQueueItems(for: trade.id, context: context)
                } else {
                    hadNonFatalFailure = true
                }
                context.delete(item)
                synced += 1

            case .delete:
                try await client
                    .from("trades")
                    .delete()
                    .eq("id", value: item.entityID.uuidString)
                    .eq("user_id", value: user.id.uuidString)
                    .execute()

                debugPrint("uploaded trade delete:", item.entityID.uuidString)
                context.delete(item)
                synced += 1
            }
        }

        let remoteTrades: [CloudTradePayload] = try await client
            .from("trades")
            .select()
            .eq("user_id", value: user.id.uuidString)
            .execute()
            .value

        let refreshedTrades = try context.fetch(FetchDescriptor<Trade>())
        var localByID = Dictionary(uniqueKeysWithValues: refreshedTrades.map { ($0.id, $0) })
        let localByRemoteID = Dictionary(uniqueKeysWithValues: refreshedTrades.compactMap { trade -> (String, Trade)? in
            guard let remoteId = trade.remoteId else { return nil }
            return (remoteId, trade)
        })

        for remoteTrade in remoteTrades {
            if let local = localByID[remoteTrade.id] ?? localByRemoteID[remoteTrade.id.uuidString] {
                if local.updatedAt > remoteTrade.remoteUpdatedAt && local.syncStatus != .synced {
                    debugPrint("skipped duplicate:", remoteTrade.id.uuidString, "local changes win")
                    continue
                }

                apply(remoteTrade, to: local)
                debugPrint("downloaded trade:", remoteTrade.id.uuidString, remoteTrade.pair)
            } else {
                let trade = CloudTradeMapper.trade(from: remoteTrade)
                context.insert(trade)
                localByID[trade.id] = trade
                debugPrint("downloaded trade:", remoteTrade.id.uuidString, remoteTrade.pair)
            }
            synced += 1
        }

        for trade in refreshedTrades where trade.beforeEntryImageData != nil || trade.duringTradeImageData != nil || trade.afterExitImageData != nil {
            if await uploadScreenshotsIfReady(for: trade, userID: user.id, client: client) {
                deleteScreenshotQueueItems(for: trade.id, context: context)
            } else {
                hadNonFatalFailure = true
            }
        }

        try context.save()
        UserDefaults.standard.set(Date(), forKey: "jp.lastSyncDate")
        UserDefaults.standard.set(synced, forKey: "jp.lastSyncCount")
        let pendingCount = ((try? context.fetch(FetchDescriptor<SyncQueueItem>())) ?? [])
            .filter { $0.entityType == .trade || $0.entityType == .screenshot || $0.entityType == .aiReview }
            .count
        UserDefaults.standard.set(pendingCount, forKey: "jp.pendingSyncCount")
        if hadNonFatalFailure {
            return CloudSyncResult(state: .failed, message: "Cloud sync finished with pending screenshot uploads.", syncedItems: synced)
        }
        return CloudSyncResult(state: .synced, message: "Cloud Synced", syncedItems: synced)
    }

    private func apply(_ payload: CloudTradePayload, to trade: Trade) {
        trade.pair = payload.pair
        trade.direction = Trade.Direction(rawValue: payload.direction) ?? trade.direction
        trade.entryPrice = payload.entryPrice
        trade.stopLoss = payload.stopLoss
        trade.takeProfit = payload.takeProfit
        trade.profitLoss = payload.profitLoss
        trade.notes = payload.notes
        trade.exitPrice = payload.exitPrice
        trade.lotSize = payload.lotSize
        trade.riskPercent = payload.riskPercent
        trade.date = payload.date
        trade.status = Trade.Status(rawValue: payload.status) ?? trade.status
        trade.riskReward = payload.riskReward
        trade.session = Trade.Session(rawValue: payload.session) ?? trade.session
        trade.strategy = Trade.Strategy(rawValue: payload.strategy) ?? trade.strategy
        trade.mistakeTags = payload.mistakeTags.compactMap(Trade.MistakeTag.init(rawValue:))
        trade.confidence = payload.confidence
        trade.emotion = payload.emotion
        trade.executionScore = payload.executionScore
        trade.followedPlan = payload.followedPlan
        trade.tradeThesis = payload.tradeThesis
        trade.marketContext = payload.marketContext
        trade.executionReview = payload.executionReview
        trade.lessonsLearned = payload.lessonsLearned
        trade.remoteId = payload.id.uuidString
        trade.syncStatus = .synced
        trade.lastSyncedAt = Date()
        trade.updatedAt = payload.remoteUpdatedAt
    }

    private func handleSyncFailure(context: ModelContext) {
        let pendingCount = (try? context.fetch(FetchDescriptor<SyncQueueItem>()).filter { $0.entityType == .trade || $0.entityType == .screenshot || $0.entityType == .aiReview }.count) ?? 0
        UserDefaults.standard.set(pendingCount, forKey: "jp.pendingSyncCount")
        markPendingTradesFailed(context: context)
        try? context.save()
    }

    private func shouldRetry(_ item: SyncQueueItem) -> Bool {
        guard let lastAttemptAt = item.lastAttemptAt else {
            return true
        }

        let attemptPower = min(max(item.attempts, 0), 6)
        let delay = pow(2.0, Double(attemptPower)) * 30
        return Date().timeIntervalSince(lastAttemptAt) >= delay
    }

    private func markPendingTradesFailed(context: ModelContext) {
        let trades = (try? context.fetch(FetchDescriptor<Trade>())) ?? []
        trades
            .filter { $0.syncStatus == .pending }
            .forEach { $0.syncStatus = .failed }
    }

    private func uploadScreenshotsIfReady(for trade: Trade, userID: UUID?, client: SupabaseClient) async -> Bool {
        debugPrint("BEGIN SCREENSHOT CHECK")
        defer { debugPrint("END SCREENSHOT CHECK") }

        let screenshots: [(slot: Trade.ScreenshotSlot, label: String, data: Data?)] = [
            (.beforeEntry, "before", trade.beforeEntryImageData),
            (.duringTrade, "during", trade.duringTradeImageData),
            (.afterExit, "after", trade.afterExitImageData)
        ]

        for screenshot in screenshots {
            let exists = screenshot.data != nil
            debugPrint("\(screenshot.label) screenshot exists:", exists)
            if exists {
                debugPrint("SCREENSHOT FOUND:", screenshot.label)
            } else {
                debugPrint("SCREENSHOT NOT FOUND:", screenshot.label)
            }
        }

        guard screenshots.contains(where: { $0.data != nil }) else {
            return true
        }

        guard let userID else {
            debugPrint("SCREENSHOT QUEUED WAITING FOR USER ID:", trade.id.uuidString)
            return false
        }

        guard let remoteId = trade.remoteId else {
            debugPrint("SCREENSHOT QUEUED WAITING FOR REMOTE ID:", trade.id.uuidString)
            return false
        }

        guard let remoteTradeID = UUID(uuidString: remoteId) else {
            debugPrint("SCREENSHOT QUEUED WAITING FOR REMOTE ID:", trade.id.uuidString, "invalid remoteId")
            return false
        }

        debugPrint("BEGIN SCREENSHOT UPLOAD")
        defer { debugPrint("END SCREENSHOT UPLOAD") }

        var allUploaded = true
        for screenshot in screenshots {
            guard let data = screenshot.data else { continue }
            do {
                let compressed = compressedScreenshotData(data)
                let path = storagePath(userID: userID, tradeRemoteID: remoteId, slot: screenshot.slot)
                debugPrint("SCREENSHOT STORAGE PATH:", path)
                try await withJPTimeout(seconds: 8) {
                    try await client.storage
                        .from("trade-screenshots")
                        .upload(path, data: compressed, options: FileOptions(contentType: "image/jpeg", upsert: true))
                }

                let asset = CloudScreenshotAssetPayload(
                    id: UUID(),
                    userId: userID,
                    tradeId: remoteTradeID,
                    slot: screenshot.slot.rawValue,
                    storagePath: path,
                    byteCount: compressed.count,
                    createdAt: Date()
                )

                try await withJPTimeout(seconds: 8) {
                    try await client
                        .from("screenshot_assets")
                        .upsert(asset, onConflict: "user_id,trade_id,slot")
                        .execute()
                }

                debugPrint("SCREENSHOT UPLOADED:", path)
            } catch {
                allUploaded = false
                debugPrint("SCREENSHOT UPLOAD FAILED:", friendlyStorageError(error))
                debugPrint("SCREENSHOT QUEUED:", trade.id.uuidString, screenshot.slot.rawValue)
            }
        }

        return allUploaded
    }

    private func deleteScreenshotQueueItems(for tradeID: UUID, context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<SyncQueueItem>())) ?? []
        for item in items where item.entityID == tradeID && item.entityType == .screenshot {
            context.delete(item)
        }
    }

    private func processPendingScreenshotDeletes(client: SupabaseClient) async throws {
        let pending = PendingScreenshotDelete.loadPending()
        guard pending.isEmpty == false else { return }

        var remaining: [PendingScreenshotDelete] = []
        for request in pending {
            do {
                try await client.storage
                    .from("trade-screenshots")
                    .remove(paths: [request.storagePath])

                try await client
                    .from("screenshot_assets")
                    .delete()
                    .eq("trade_id", value: request.tradeID)
                    .eq("slot", value: request.slot)
                    .execute()

                debugPrint("SCREENSHOT DELETE SUCCESS:", request.storagePath)
            } catch {
                remaining.append(request)
                debugPrint("SCREENSHOT DELETE FAILED:", String(describing: error))
            }
        }

        PendingScreenshotDelete.savePending(remaining)
    }

    private func aiReviewPayload(from review: AITradeReview, trade: Trade, userID: UUID) -> CloudAIReviewPayload? {
        guard let remoteId = trade.remoteId, let remoteTradeID = UUID(uuidString: remoteId) else {
            return nil
        }

        return CloudAIReviewPayload(
            id: review.id,
            userId: userID,
            tradeId: remoteTradeID,
            overallScore: review.overallScore,
            grade: review.grade,
            summary: review.summary,
            strengths: review.strengths,
            improvements: review.improvements,
            executionScore: review.executionScore,
            riskScore: review.riskManagementScore,
            psychologyScore: review.psychologyScore,
            journalQualityScore: review.journalQualityScore,
            strategyDisciplineScore: review.strategyDisciplineScore,
            payload: [
                "source": "ios",
                "mode": "backend-ready",
                "tradeLocalId": trade.id.uuidString
            ],
            createdAt: review.createdAt,
            updatedAt: review.updatedAt
        )
    }

    private func storagePath(userID: UUID, tradeRemoteID: String, slot: Trade.ScreenshotSlot) -> String {
        "\(userID.uuidString.lowercased())/\(tradeRemoteID.lowercased())/\(slotFileName(slot))"
    }

    private func slotFileName(_ slot: Trade.ScreenshotSlot) -> String {
        switch slot {
        case .beforeEntry:
            return "before-entry.jpg"
        case .duringTrade:
            return "during-trade.jpg"
        case .afterExit:
            return "after-exit.jpg"
        }
    }

    private func compressedScreenshotData(_ data: Data) -> Data {
        #if canImport(UIKit)
        if let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.78) {
            return jpeg
        }
        #endif
        return data
    }

    private func friendlyStorageError(_ error: Error) -> String {
        let description = error.localizedDescription
        if description.localizedCaseInsensitiveContains("bucket") || description.localizedCaseInsensitiveContains("not found") {
            return "Supabase Storage bucket trade-screenshots is unavailable. Screenshot remains local."
        }
        return String(describing: error)
    }
}

enum SyncState: String {
    case synced = "Synced"
    case uploading = "Uploading..."
    case offline = "Offline Mode"
    case failed = "Sync Failed"
    case retrying = "Retrying..."
    case waiting = "Waiting"
    case conflictResolved = "Conflict Resolved"
}

@MainActor
final class SyncService {
    private var modelContext: ModelContext?
    private let cloudSyncService = CloudSyncService()
    private var client: SupabaseClient? { SupabaseClientManager.shared.client }

    func configure(context: ModelContext) {
        modelContext = context
    }

    func queue(entityID: UUID, entityType: SyncQueueItem.EntityType, operation: SyncQueueItem.Operation) {
        guard let modelContext else { return }
        cloudSyncService.enqueue(context: modelContext, entityID: entityID, entityType: entityType, operation: operation)
    }

    func syncNow() async -> SyncState {
        guard let modelContext else {
            return .failed
        }

        guard client != nil else {
            return .offline
        }

        return await cloudSyncService.syncNow(context: modelContext).state
    }

    func deleteCloudData() async -> SyncState {
        guard let modelContext else {
            return .failed
        }

        guard client != nil else {
            return .offline
        }

        return await cloudSyncService.deleteCloudData(context: modelContext).state
    }

    func estimatedStorageUsed() -> String {
        guard let modelContext else { return "--" }
        let trades = (try? modelContext.fetch(FetchDescriptor<Trade>())) ?? []
        var screenshotBytes = 0
        for trade in trades {
            screenshotBytes += trade.beforeEntryImageData?.count ?? 0
            screenshotBytes += trade.duringTradeImageData?.count ?? 0
            screenshotBytes += trade.afterExitImageData?.count ?? 0
        }
        let mb = Double(screenshotBytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    func pendingItemsCount() -> Int {
        guard let modelContext else { return 0 }
        return ((try? modelContext.fetch(FetchDescriptor<SyncQueueItem>())) ?? [])
            .filter { $0.entityType == .trade || $0.entityType == .screenshot || $0.entityType == .aiReview }
            .count
    }
}

private struct PendingScreenshotDelete: Codable, Equatable {
    let tradeID: String
    let slot: String
    let storagePath: String

    private static let storageKey = "jp.pendingScreenshotDeletes"

    static func loadPending() -> [PendingScreenshotDelete] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([PendingScreenshotDelete].self, from: data)) ?? []
    }

    static func savePending(_ requests: [PendingScreenshotDelete]) {
        let data = try? JSONEncoder().encode(requests)
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

enum JPAsyncTimeoutError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        "The request timed out."
    }
}

func withJPTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            let nanoseconds = UInt64(max(seconds, 0.1) * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
            throw JPAsyncTimeoutError.timedOut
        }

        guard let result = try await group.next() else {
            throw JPAsyncTimeoutError.timedOut
        }

        group.cancelAll()
        return result
    }
}
