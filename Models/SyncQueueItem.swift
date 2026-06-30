import Foundation
import SwiftData

@Model
final class SyncQueueItem {
    enum EntityType: String, CaseIterable {
        case trade = "Trade"
        case morningPlan = "MorningPlan"
        case aiReport = "AIReport"
        case aiReview = "AIReview"
        case dailyReview = "DailyReview"
        case insight = "Insight"
        case userProfile = "UserProfile"
        case settings = "Settings"
        case screenshot = "TradeScreenshot"
    }

    enum Operation: String, CaseIterable {
        case upload = "Upload"
        case update = "Update"
        case delete = "Delete"
    }

    var id: UUID = UUID()
    var entityID: UUID = UUID()
    private var entityTypeRawValue: String = EntityType.trade.rawValue
    private var operationRawValue: String = Operation.upload.rawValue
    var attempts: Int = 0
    var createdAt: Date = Date()
    var lastAttemptAt: Date?

    var entityType: EntityType {
        get { EntityType(rawValue: entityTypeRawValue) ?? .trade }
        set { entityTypeRawValue = newValue.rawValue }
    }

    var operation: Operation {
        get { Operation(rawValue: operationRawValue) ?? .upload }
        set { operationRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        entityID: UUID,
        entityType: EntityType,
        operation: Operation,
        attempts: Int = 0,
        createdAt: Date = Date(),
        lastAttemptAt: Date? = nil
    ) {
        self.id = id
        self.entityID = entityID
        self.entityTypeRawValue = entityType.rawValue
        self.operationRawValue = operation.rawValue
        self.attempts = attempts
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
    }
}
