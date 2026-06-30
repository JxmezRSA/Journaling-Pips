import Foundation
import SwiftData

struct DiagnosticsReport: Codable {
    let generatedAt: Date
    let appVersion: String
    let databaseSize: String
    let pendingSyncCount: Int
    let pendingScreenshotUploads: Int
    let pendingAIReviews: Int
    let currentUser: String
    let storageUsage: String
    let supabaseStatus: String
    let tradeCount: Int
    let aiReviewCount: Int
}

@MainActor
final class ProductionHealthService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func runStartupRecovery() {
        debugPrint("APP HEALTH CHECK")
        verifyDatabase()
        cleanupLocalCache()
        resumePendingWorkIfNeeded()
    }

    func verifyDatabase() {
        do {
            _ = try context.fetch(FetchDescriptor<Trade>())
            _ = try context.fetch(FetchDescriptor<SyncQueueItem>())
            debugPrint("DATABASE VERIFIED")
        } catch {
            debugPrint("DATABASE VERIFIED:", "failed", String(describing: error))
        }
    }

    @discardableResult
    func cleanupLocalCache() -> Int {
        var removed = 0

        do {
            let trades = try context.fetch(FetchDescriptor<Trade>())
            let tradeIDs = Set(trades.map(\.id))
            let reviews = try context.fetch(FetchDescriptor<AITradeReview>())
            let queue = try context.fetch(FetchDescriptor<SyncQueueItem>())

            for review in reviews where !tradeIDs.contains(review.tradeID) {
                context.delete(review)
                removed += 1
            }

            var seenQueueKeys = Set<String>()
            for item in queue {
                let key = "\(item.entityID.uuidString)-\(item.entityType.rawValue)-\(item.operation.rawValue)"
                if seenQueueKeys.contains(key) {
                    context.delete(item)
                    removed += 1
                } else {
                    seenQueueKeys.insert(key)
                }

                if item.entityType == .aiReview, reviews.contains(where: { $0.id == item.entityID }) == false {
                    context.delete(item)
                    removed += 1
                }
            }

            try context.save()
        } catch {
            debugPrint("CACHE CLEANED:", "partial failure", String(describing: error))
        }

        cleanupTempDirectory()
        debugPrint("CACHE CLEANED:", removed, "records")
        return removed
    }

    func makeDiagnosticsReport() -> DiagnosticsReport {
        let trades = (try? context.fetch(FetchDescriptor<Trade>())) ?? []
        let reviews = (try? context.fetch(FetchDescriptor<AITradeReview>())) ?? []
        let queue = (try? context.fetch(FetchDescriptor<SyncQueueItem>())) ?? []
        let currentUser = UserDefaults.standard.string(forKey: "jp.currentUserEmail") ?? "Offline Trader"
        let storageBytes = trades.reduce(0) { total, trade in
            total
            + (trade.beforeEntryImageData?.count ?? 0)
            + (trade.duringTradeImageData?.count ?? 0)
            + (trade.afterExitImageData?.count ?? 0)
        }

        return DiagnosticsReport(
            generatedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.5",
            databaseSize: approximateDatabaseSize(),
            pendingSyncCount: queue.count,
            pendingScreenshotUploads: queue.filter { $0.entityType == .screenshot }.count,
            pendingAIReviews: queue.filter { $0.entityType == .aiReview }.count,
            currentUser: currentUser,
            storageUsage: byteText(storageBytes),
            supabaseStatus: SupabaseClientManager.shared.isConfigured ? "Configured" : "Offline Mode",
            tradeCount: trades.count,
            aiReviewCount: reviews.count
        )
    }

    func exportDiagnosticsReport() throws -> URL {
        let report = makeDiagnosticsReport()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("JournalingPips_Diagnostics_\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func resumePendingWorkIfNeeded() {
        let pending = (try? context.fetch(FetchDescriptor<SyncQueueItem>())) ?? []
        guard pending.isEmpty == false else { return }
        guard UserDefaults.standard.object(forKey: "jp.autoSync") as? Bool ?? true else { return }
        guard SupabaseClientManager.shared.isConfigured else {
            debugPrint("FORCE SYNC COMPLETE:", "offline recovery queued", pending.count)
            return
        }

        Task { @MainActor in
            debugPrint("FORCE SYNC START")
            let result = await CloudSyncService().syncNow(context: context)
            debugPrint("FORCE SYNC COMPLETE:", result.message)
        }
    }

    private func cleanupTempDirectory() {
        let fileManager = FileManager.default
        let tempURL = fileManager.temporaryDirectory
        guard let files = try? fileManager.contentsOfDirectory(at: tempURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        for file in files where file.lastPathComponent.hasPrefix("JournalingPips_") || file.pathExtension.lowercased() == "tmp" {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            if modified < cutoff {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    private func approximateDatabaseSize() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let appSupport else { return "--" }

        let files = (try? FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])) ?? []
        let bytes = files.reduce(0) { partial, url in
            partial + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return byteText(bytes)
    }

    private func byteText(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        }
        return "\(max(0, bytes / 1024)) KB"
    }
}
