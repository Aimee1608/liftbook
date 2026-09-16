import SwiftUI

@main
struct LiftbookApp: App {
    init() {
        #if DEBUG
        if CommandLine.arguments.contains("-resetData") {
            try? FileManager.default.removeItem(at: WorkoutStore.appDirectory())
            UserDefaults.standard.removeObject(forKey: "disclaimerAcceptedAt")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
