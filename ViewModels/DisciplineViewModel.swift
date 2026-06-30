import Combine
import Foundation
import SwiftData
import SwiftUI

struct DisciplineHistoryItem: Identifiable {
    let id: UUID
    let date: Date
    let score: Int
    let planProgress: Double
    let riskProgress: Double
    let journalProgress: Double
    let xp: Int
}

@MainActor
final class DisciplineViewModel: ObservableObject {
    @Published private(set) var score = 0
    @Published private(set) var planRing = 0.0
    @Published private(set) var riskRing = 0.0
    @Published private(set) var journalRing = 0.0
    @Published private(set) var currentDisciplineStreak = 0
    @Published private(set) var longestDisciplineStreak = 0
    @Published private(set) var greenDayStreak = 0
    @Published private(set) var journalStreak = 0
    @Published private(set) var planStreak = 0
    @Published private(set) var totalXP = 0
    @Published private(set) var level = 1
    @Published private(set) var progressToNextLevel = 0.0
    @Published private(set) var achievements: [Achievement] = []
    @Published private(set) var history: [DisciplineHistoryItem] = []
    @Published var errorMessage: String?

    private var tracker: DisciplineTracker?

    func configure(context: ModelContext) {
        tracker = DisciplineTracker(context: context)
        refresh()
    }

    func refresh() {
        guard let tracker else {
            return
        }

        do {
            let snapshot = try tracker.snapshot()
            score = snapshot.score
            planRing = snapshot.rings.plan
            riskRing = snapshot.rings.risk
            journalRing = snapshot.rings.journal
            currentDisciplineStreak = snapshot.currentDisciplineStreak
            longestDisciplineStreak = snapshot.longestDisciplineStreak
            greenDayStreak = snapshot.greenDayStreak
            journalStreak = snapshot.journalStreak
            planStreak = snapshot.planStreak
            totalXP = snapshot.totalXP
            level = snapshot.level
            progressToNextLevel = snapshot.progressToNextLevel
            achievements = snapshot.achievements
            history = snapshot.recentDays.map {
                DisciplineHistoryItem(
                    id: $0.id,
                    date: $0.date,
                    score: $0.disciplineScore,
                    planProgress: $0.planProgress,
                    riskProgress: $0.riskProgress,
                    journalProgress: $0.journalProgress,
                    xp: $0.xpEarned
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load discipline progress."
        }
    }

    func completeDailyMission() {
        tracker?.recordDailyMissionCompleted()
        refresh()
        JPHaptics.notify(.success)
    }

    var scoreRating: String {
        switch score {
        case 90...:
            return "Locked In"
        case 75..<90:
            return "Disciplined"
        case 50..<75:
            return "Building"
        default:
            return "Needs Prep"
        }
    }

    var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    var ringItems: [DisciplineRingItem] {
        [
            DisciplineRingItem(
                title: "Plan Ring",
                progress: planRing,
                color: JPColors.blue,
                symbolName: "checklist.checked",
                explanation: "Morning plan and checklist completion."
            ),
            DisciplineRingItem(
                title: "Risk Ring",
                progress: riskRing,
                color: JPColors.accent,
                symbolName: "shield.lefthalf.filled",
                explanation: "Trades kept within your risk limits."
            ),
            DisciplineRingItem(
                title: "Journal Ring",
                progress: journalRing,
                color: JPColors.warning,
                symbolName: "book.pages.fill",
                explanation: "Trades reviewed with useful journal notes."
            )
        ]
    }
}
