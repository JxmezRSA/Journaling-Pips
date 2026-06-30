import SwiftUI
import SwiftData

@main
struct Journaling_PipsApp: App {
    private let modelContainer = SwiftDataStoreManager.makeContainer()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(modelContainer)
    }
}
