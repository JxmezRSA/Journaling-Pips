import SwiftUI
import SwiftData

@main
struct Journaling_PipsApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [Trade.self, MorningPlan.self, UserProfile.self, AITradeReview.self])
    }
}
