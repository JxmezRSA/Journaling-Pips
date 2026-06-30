import Foundation
import SwiftData

@Model
final class DisciplineDay {
    var id: UUID = UUID()
    var date: Date = Date()
    var disciplineScore: Int = 0
    var planProgress: Double = 0
    var riskProgress: Double = 0
    var journalProgress: Double = 0
    var checklistCompletion: Double = 0
    var tradesLogged: Int = 0
    var reviewsCompleted: Int = 0
    var followedPlanTrades: Int = 0
    var majorMistakes: Int = 0
    var aiReviewsSaved: Int = 0
    var replaysViewed: Int = 0
    var reportsExported: Int = 0
    var xpEarned: Int = 0
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        date: Date,
        disciplineScore: Int = 0,
        planProgress: Double = 0,
        riskProgress: Double = 0,
        journalProgress: Double = 0,
        checklistCompletion: Double = 0,
        tradesLogged: Int = 0,
        reviewsCompleted: Int = 0,
        followedPlanTrades: Int = 0,
        majorMistakes: Int = 0,
        aiReviewsSaved: Int = 0,
        replaysViewed: Int = 0,
        reportsExported: Int = 0,
        xpEarned: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.disciplineScore = disciplineScore
        self.planProgress = planProgress
        self.riskProgress = riskProgress
        self.journalProgress = journalProgress
        self.checklistCompletion = checklistCompletion
        self.tradesLogged = tradesLogged
        self.reviewsCompleted = reviewsCompleted
        self.followedPlanTrades = followedPlanTrades
        self.majorMistakes = majorMistakes
        self.aiReviewsSaved = aiReviewsSaved
        self.replaysViewed = replaysViewed
        self.reportsExported = reportsExported
        self.xpEarned = xpEarned
        self.updatedAt = updatedAt
    }
}
