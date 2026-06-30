import Foundation
import Supabase

struct CloudScreenshotAsset: Codable, Identifiable {
    let id: UUID
    let tradeID: UUID
    let slot: String
    let storagePath: String
    let byteCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tradeID = "trade_id"
        case slot
        case storagePath = "storage_path"
        case byteCount = "byte_count"
        case createdAt = "created_at"
    }
}

@MainActor
final class CloudStorageService {
    private var client: SupabaseClient? { SupabaseClientManager.shared.client }

    var isConfigured: Bool {
        client != nil
    }

    func preparedAssets(for trade: Trade) -> [CloudScreenshotAsset] {
        let screenshots: [(Trade.ScreenshotSlot, Data?)] = [
            (.beforeEntry, trade.beforeEntryImageData),
            (.duringTrade, trade.duringTradeImageData),
            (.afterExit, trade.afterExitImageData)
        ]

        return screenshots.compactMap { slot, data in
            guard let data else { return nil }
            return CloudScreenshotAsset(
                id: UUID(),
                tradeID: trade.id,
                slot: slot.rawValue,
                storagePath: storagePath(tradeID: trade.id, slot: slot),
                byteCount: data.count,
                createdAt: Date()
            )
        }
    }

    func uploadScreenshotsIfPossible(for trade: Trade) async -> [CloudScreenshotAsset] {
        guard client != nil else {
            return preparedAssets(for: trade)
        }

        // Foundation only for now: the storage paths and metadata are prepared here.
        // Actual Supabase Storage upload can be enabled after buckets and size rules are configured.
        return preparedAssets(for: trade)
    }

    private func storagePath(tradeID: UUID, slot: Trade.ScreenshotSlot) -> String {
        "trade-screenshots/\(tradeID.uuidString)/\(slot.id.replacingOccurrences(of: " ", with: "-").lowercased()).jpg"
    }
}
