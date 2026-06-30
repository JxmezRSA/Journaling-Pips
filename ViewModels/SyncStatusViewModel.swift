import Combine
import Foundation
import SwiftData

@MainActor
final class SyncStatusViewModel: ObservableObject {
    @Published var state: SyncState = .waiting
    @Published var message = "Waiting"
    @Published var lastSyncText = "Never"

    private let syncService = CloudSyncService()
    private var modelContext: ModelContext?

    func configure(context: ModelContext) {
        modelContext = context
        refresh()
    }

    func syncNow() {
        guard let modelContext else { return }
        state = .uploading
        message = "Syncing..."
        Task {
            let result = await syncService.syncNow(context: modelContext)
            state = result.state
            message = result.message
            refresh()
        }
    }

    func refresh() {
        if !syncService.isConfigured {
            state = .offline
            message = "Offline Mode. Your data is safely stored locally."
        }
        if let date = UserDefaults.standard.object(forKey: "jp.lastSyncDate") as? Date {
            lastSyncText = date.formatted(.relative(presentation: .named))
        }
    }
}
