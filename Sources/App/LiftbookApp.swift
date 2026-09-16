import SwiftUI

@main
struct LiftbookApp: App {
    init() {
        #if DEBUG
        if CommandLine.arguments.contains("-resetData") {
            try? FileManager.default.removeItem(at: WorkoutStore.appDirectory())
            if let domain = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: domain) }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
