import Foundation
import SwiftData

@Model
final class AITradeReview {
    var id: UUID
    var tradeID: UUID
    var overallScore: Int
    var grade: String
    var summary: String
    var strengthsRawValue: String
    var improvementsRawValue: String
    var executionScore: Int
    var riskManagementScore: Int
    var psychologyScore: Int
    var journalQualityScore: Int
    var strategyDisciplineScore: Int
    var createdAt: Date
    var updatedAt: Date

    var strengths: [String] {
        get {
            strengthsRawValue
                .split(separator: "|")
                .map { String($0) }
        }
        set {
            strengthsRawValue = newValue.joined(separator: "|")
        }
    }

    var improvements: [String] {
        get {
            improvementsRawValue
                .split(separator: "|")
                .map { String($0) }
        }
        set {
            improvementsRawValue = newValue.joined(separator: "|")
        }
    }

    init(
        id: UUID = UUID(),
        tradeID: UUID,
        overallScore: Int,
        grade: String,
        summary: String,
        strengths: [String],
        improvements: [String],
        executionScore: Int,
        riskManagementScore: Int,
        psychologyScore: Int,
        journalQualityScore: Int,
        strategyDisciplineScore: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.tradeID = tradeID
        self.overallScore = overallScore
        self.grade = grade
        self.summary = summary
        self.strengthsRawValue = strengths.joined(separator: "|")
        self.improvementsRawValue = improvements.joined(separator: "|")
        self.executionScore = executionScore
        self.riskManagementScore = riskManagementScore
        self.psychologyScore = psychologyScore
        self.journalQualityScore = journalQualityScore
        self.strategyDisciplineScore = strategyDisciplineScore
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
