import Foundation
import SwiftData

enum SwiftDataStoreManager {
    private static let pendingRecoveryReasonKey = "jp.pendingStoreRecoveryReason"

    static let schema = Schema([
        Trade.self,
        MorningPlan.self,
        UserProfile.self,
        AITradeReview.self,
        CloudUser.self,
        SyncQueueItem.self,
        DisciplineDay.self,
        Achievement.self,
        Insight.self
    ])

    @MainActor
    static func makeContainer() -> ModelContainer {
        performPendingRecoveryIfNeeded()
        debugPrint("SWIFTDATA MIGRATION START")

        do {
            let container = try persistentContainer()
            debugPrint("SWIFTDATA MIGRATION SUCCESS")
            return container
        } catch {
            debugPrint("SWIFTDATA MIGRATION FAILED", String(describing: error))
            debugPrint("LOCAL STORE RECOVERY START")
            backupPersistentStore(reason: "migration-failed")

            do {
                let container = try persistentContainer()
                debugPrint("LOCAL STORE RECOVERY COMPLETE")
                return container
            } catch {
                debugPrint("SWIFTDATA MIGRATION FAILED", "fresh store unavailable", String(describing: error))
                return inMemoryContainer()
            }
        }
    }

    static func requestStoreRecovery(reason: String) {
        UserDefaults.standard.set(reason, forKey: pendingRecoveryReasonKey)
        UserDefaults.standard.synchronize()
        debugPrint("LOCAL STORE RECOVERY START", reason, "queued")
        debugPrint("LOCAL STORE RECOVERY COMPLETE", reason, "queued")
    }

    static func backupPersistentStore(reason: String) {
        let fileManager = FileManager.default
        guard let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let backupDirectory = supportURL.appendingPathComponent("StoreRecovery-\(reason)-\(timestamp)", isDirectory: true)
        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        for filename in persistentStoreFilenames {
            let source = supportURL.appendingPathComponent(filename)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let destination = backupDirectory.appendingPathComponent(filename)
            do {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.moveItem(at: source, to: destination)
            } catch {
                debugPrint("LOCAL STORE RECOVERY START", "backup failed for \(filename)", String(describing: error))
            }
        }
    }

    static func clearLocalCacheFiles() -> Int {
        let fileManager = FileManager.default
        var removed = 0
        let candidates = [
            fileManager.temporaryDirectory,
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        for directory in candidates {
            let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.lastPathComponent.hasPrefix("JournalingPips_") || file.pathExtension.lowercased() == "tmp" {
                do {
                    try fileManager.removeItem(at: file)
                    removed += 1
                } catch {
                    debugPrint("CACHE CLEANED:", "failed", file.lastPathComponent, String(describing: error))
                }
            }
        }

        debugPrint("CACHE CLEANED:", removed, "files")
        return removed
    }

    private static func performPendingRecoveryIfNeeded() {
        guard let reason = UserDefaults.standard.string(forKey: pendingRecoveryReasonKey) else {
            return
        }

        debugPrint("LOCAL STORE RECOVERY START", reason)
        backupPersistentStore(reason: reason)
        UserDefaults.standard.removeObject(forKey: pendingRecoveryReasonKey)
        UserDefaults.standard.synchronize()
        debugPrint("LOCAL STORE RECOVERY COMPLETE", reason)
    }

    private static func persistentContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func inMemoryContainer() -> ModelContainer {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            debugPrint("LOCAL STORE RECOVERY COMPLETE", "using in-memory fallback")
            return container
        } catch {
            preconditionFailure("Unable to create SwiftData in-memory fallback: \(error)")
        }
    }

    private static var persistentStoreFilenames: [String] {
        [
            "default.store",
            "default.store-shm",
            "default.store-wal",
            "default.store.sqlite",
            "default.store.sqlite-shm",
            "default.store.sqlite-wal"
        ]
    }
}
