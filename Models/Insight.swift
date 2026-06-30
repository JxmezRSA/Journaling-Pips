import Foundation
import SwiftData

@Model
final class Insight {
    enum Category: String, CaseIterable, Identifiable {
        case performance = "Performance"
        case psychology = "Psychology"
        case risk = "Risk"
        case discipline = "Discipline"
        case execution = "Execution"
        case planning = "Planning"
        case replay = "Replay"

        var id: String { rawValue }
    }

    var id: UUID = UUID()
    var title: String = ""
    var subtitle: String = ""
    var icon: String = "sparkles"
    var priority: Int = 0
    var date: Date = Date()
    private var categoryRawValue: String = Category.performance.rawValue
    var confidence: Double = 0
    var relatedTradeID: UUID?
    var isRead: Bool = false
    var fingerprint: String = ""

    var category: Category {
        get { Category(rawValue: categoryRawValue) ?? .performance }
        set { categoryRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        icon: String,
        priority: Int,
        date: Date = Date(),
        category: Category,
        confidence: Double,
        relatedTradeID: UUID? = nil,
        isRead: Bool = false,
        fingerprint: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.priority = priority
        self.date = date
        self.categoryRawValue = category.rawValue
        self.confidence = confidence
        self.relatedTradeID = relatedTradeID
        self.isRead = isRead
        self.fingerprint = fingerprint
    }
}
