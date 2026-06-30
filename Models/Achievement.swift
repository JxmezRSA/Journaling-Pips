import Foundation
import SwiftData

@Model
final class Achievement {
    var id: UUID = UUID()
    var kindRawValue: String = AchievementKind.firstTradeLogged.rawValue
    var title: String = ""
    var achievementDescription: String = ""
    var symbolName: String = "seal.fill"
    var unlockedDate: Date?

    var kind: AchievementKind {
        get { AchievementKind(rawValue: kindRawValue) ?? .firstTradeLogged }
        set { kindRawValue = newValue.rawValue }
    }

    var isUnlocked: Bool {
        unlockedDate != nil
    }

    init(
        id: UUID = UUID(),
        kind: AchievementKind,
        title: String,
        achievementDescription: String,
        symbolName: String,
        unlockedDate: Date? = nil
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.title = title
        self.achievementDescription = achievementDescription
        self.symbolName = symbolName
        self.unlockedDate = unlockedDate
    }
}

enum AchievementKind: String, CaseIterable, Identifiable {
    case firstTradeLogged
    case firstGreenDay
    case firstGreenWeek
    case tenTradesLogged
    case twentyFiveTradesLogged
    case fiftyTradesLogged
    case hundredTradesLogged
    case sevenDayDisciplineStreak
    case thirtyDayDisciplineStreak
    case zeroRuleBreakDay
    case perfectRiskWeek
    case firstPDFReportExported
    case firstTradeReplayViewed
    case firstAIReviewSaved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstTradeLogged:
            return "First Trade Logged"
        case .firstGreenDay:
            return "First Green Day"
        case .firstGreenWeek:
            return "First Green Week"
        case .tenTradesLogged:
            return "10 Trades Logged"
        case .twentyFiveTradesLogged:
            return "25 Trades Logged"
        case .fiftyTradesLogged:
            return "50 Trades Logged"
        case .hundredTradesLogged:
            return "100 Trades Logged"
        case .sevenDayDisciplineStreak:
            return "7 Day Discipline Streak"
        case .thirtyDayDisciplineStreak:
            return "30 Day Discipline Streak"
        case .zeroRuleBreakDay:
            return "Zero Rule Break Day"
        case .perfectRiskWeek:
            return "Perfect Risk Week"
        case .firstPDFReportExported:
            return "First PDF Report Exported"
        case .firstTradeReplayViewed:
            return "First Trade Replay Viewed"
        case .firstAIReviewSaved:
            return "First AI Review Saved"
        }
    }

    var description: String {
        switch self {
        case .firstTradeLogged:
            return "Your journal started with the first saved trade."
        case .firstGreenDay:
            return "Finish a trading day in profit."
        case .firstGreenWeek:
            return "Finish a trading week in profit."
        case .tenTradesLogged:
            return "Log 10 trades with discipline."
        case .twentyFiveTradesLogged:
            return "Build a 25-trade review sample."
        case .fiftyTradesLogged:
            return "Reach 50 logged trades."
        case .hundredTradesLogged:
            return "Create a 100-trade performance base."
        case .sevenDayDisciplineStreak:
            return "Maintain discipline for 7 trading days."
        case .thirtyDayDisciplineStreak:
            return "Maintain discipline for 30 trading days."
        case .zeroRuleBreakDay:
            return "Complete a day without major rule breaks."
        case .perfectRiskWeek:
            return "Keep every trade within risk for a week."
        case .firstPDFReportExported:
            return "Generate your first performance report."
        case .firstTradeReplayViewed:
            return "Review your first trade replay."
        case .firstAIReviewSaved:
            return "Save your first AI Coach placeholder review."
        }
    }

    var symbolName: String {
        switch self {
        case .firstTradeLogged:
            return "plus.circle.fill"
        case .firstGreenDay:
            return "arrow.up.circle.fill"
        case .firstGreenWeek:
            return "calendar.badge.checkmark"
        case .tenTradesLogged:
            return "10.circle.fill"
        case .twentyFiveTradesLogged:
            return "25.circle.fill"
        case .fiftyTradesLogged:
            return "50.circle.fill"
        case .hundredTradesLogged:
            return "100.circle.fill"
        case .sevenDayDisciplineStreak:
            return "flame.fill"
        case .thirtyDayDisciplineStreak:
            return "crown.fill"
        case .zeroRuleBreakDay:
            return "checkmark.shield.fill"
        case .perfectRiskWeek:
            return "shield.lefthalf.filled"
        case .firstPDFReportExported:
            return "doc.richtext.fill"
        case .firstTradeReplayViewed:
            return "play.rectangle.fill"
        case .firstAIReviewSaved:
            return "sparkles"
        }
    }
}
