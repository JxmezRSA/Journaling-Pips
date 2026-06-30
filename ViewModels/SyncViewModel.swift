import Combine
import Foundation
import SwiftData

@MainActor
final class SyncViewModel: ObservableObject {
    @Published var state: SyncState = .offline
    @Published var lastSyncText = "Never"
    @Published var autoSync = true
    @Published var wifiOnly = true
    @Published var storageUsed = "--"
    @Published var bannerMessage: String?
    @Published var pendingItemsText = "0"

    private let syncService = SyncService()

    func configure(context: ModelContext) {
        syncService.configure(context: context)
        autoSync = UserDefaults.standard.object(forKey: "jp.autoSync") as? Bool ?? true
        wifiOnly = UserDefaults.standard.object(forKey: "jp.wifiOnlySync") as? Bool ?? true
        refreshStatus()
    }

    func syncNow() {
        Task {
            debugPrint("FORCE SYNC START")
            state = .uploading
            state = await syncService.syncNow()
            refreshStatus()
            bannerMessage = banner(for: state)
            debugPrint("FORCE SYNC COMPLETE:", state.rawValue)
        }
    }

    func deleteCloudData() {
        Task {
            state = await syncService.deleteCloudData()
            bannerMessage = banner(for: state)
        }
    }

    func deleteLocalData() {
        bannerMessage = "Local delete requires confirmation in a future safety pass."
    }

    func persistSettings() {
        UserDefaults.standard.set(autoSync, forKey: "jp.autoSync")
        UserDefaults.standard.set(wifiOnly, forKey: "jp.wifiOnlySync")
    }

    private func refreshStatus() {
        if let date = UserDefaults.standard.object(forKey: "jp.lastSyncDate") as? Date {
            lastSyncText = date.formatted(.relative(presentation: .named))
        } else {
            lastSyncText = "Never"
        }
        storageUsed = syncService.estimatedStorageUsed()
        pendingItemsText = "\(syncService.pendingItemsCount())"
    }

    private func banner(for state: SyncState) -> String {
        switch state {
        case .synced:
            return "Cloud Synced"
        case .uploading:
            return "Uploading..."
        case .offline:
            return "Offline Mode. Your data is safely stored locally."
        case .failed:
            return "Sync Failed. Your local data is safe."
        case .retrying:
            return "Retrying sync in the background."
        case .waiting:
            return "Waiting to sync."
        case .conflictResolved:
            return "Conflict resolved. Local changes won."
        }
    }
}
