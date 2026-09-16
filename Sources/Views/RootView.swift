import SwiftUI

@MainActor
final class SessionCoordinator: ObservableObject {
    @Published var presentedSessionId: UUID?
    @Published var summarySessionId: UUID?
    @Published var autoClosed: WorkoutSession?

    var isPresenting: Bool {
        get { presentedSessionId != nil }
        set { if !newValue { presentedSessionId = nil; summarySessionId = nil } }
    }

    func open(_ id: UUID) { summarySessionId = nil; presentedSessionId = id }
    func finish(_ id: UUID) { summarySessionId = id }
    func close() { presentedSessionId = nil; summarySessionId = nil }
}

struct RootView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = WorkoutStore(
        directory: WorkoutStore.appDirectory(),
        builtinURL: Bundle.main.url(forResource: "exercises", withExtension: "json")!,
        templatesURL: Bundle.main.url(forResource: "templates", withExtension: "json")!
    )
    @StateObject private var coordinator = SessionCoordinator()

    var body: some View {
        Group {
            if settings.disclaimerAcceptedAt == nil {
                DisclaimerView(requiresAcceptance: true) { settings.disclaimerAcceptedAt = Date() }
            } else if store.plans.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .environmentObject(settings)
        .environmentObject(store)
        .environmentObject(coordinator)
        .onAppear { coordinator.autoClosed = store.autoCloseStaleSessions().first }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var coordinator: SessionCoordinator

    init() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Theme.tabBar)
        tab.shadowColor = UIColor(Theme.separator)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    var body: some View {
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("训练", systemImage: "figure.strengthtraining.traditional") }
                .badge(store.activeSession == nil ? nil : Text("进行中"))
            NavigationStack { HistoryView() }
                .tabItem { Label("历史", systemImage: "calendar") }
            NavigationStack { ExerciseLibraryView() }
                .tabItem { Label("动作", systemImage: "list.bullet.rectangle") }
            NavigationStack { SettingsView() }
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .fullScreenCover(isPresented: $coordinator.isPresenting) {
            if let summaryId = coordinator.summarySessionId {
                SessionSummaryView(sessionId: summaryId)
            } else if let id = coordinator.presentedSessionId {
                WorkoutSessionView(sessionId: id)
            }
        }
    }
}
