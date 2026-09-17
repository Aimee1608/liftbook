import SwiftUI
import UserNotifications
import AudioToolbox

@MainActor
final class RestTimer: ObservableObject {
    @Published private(set) var endsAt: Date?
    @Published private(set) var finishedAt: Date?
    private(set) var total = 0

    var isRunning: Bool { endsAt != nil }

    func remaining(at now: Date) -> Int {
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
    }

    func start(seconds: Int) {
        guard seconds > 0 else { return }
        total = seconds
        finishedAt = nil
        endsAt = Date().addingTimeInterval(TimeInterval(seconds))
        NotificationManager.scheduleRestEnd(after: seconds)
    }

    func adjust(by delta: Int) {
        guard let e = endsAt else { return }
        let remaining = e.timeIntervalSinceNow + TimeInterval(delta)
        if remaining <= 0 { skip(); return }
        endsAt = Date().addingTimeInterval(remaining)
        total = max(total + delta, Int(remaining))
        NotificationManager.scheduleRestEnd(after: Int(remaining))
    }

    func skip() {
        endsAt = nil
        finishedAt = nil
        NotificationManager.cancelRestEnd()
    }

    func tick(now: Date, haptics: Bool, sound: Bool) {
        guard let e = endsAt, now >= e else { return }
        endsAt = nil
        finishedAt = now
        if haptics { Haptics.success() }
        if sound { AudioServicesPlaySystemSound(1016) }
    }

    func clearFinished(now: Date) {
        if let f = finishedAt, now.timeIntervalSince(f) >= 3 { finishedAt = nil }
    }
}

enum NotificationManager {
    static let restId = "rest-end"

    static func requestIfNeeded() {
        #if DEBUG
        // 演示模式（截图/录屏）不能弹系统权限框，会盖住画面
        if CommandLine.arguments.contains("-demoData") { return }
        #endif
        UNUserNotificationCenter.current().getNotificationSettings { s in
            guard s.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    static func scheduleRestEnd(after seconds: Int) {
        cancelRestEnd()
        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = "该做下一组了"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: restId, content: content, trigger: trigger))
    }

    static func cancelRestEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restId])
    }

    static func isDenied(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { completion(s.authorizationStatus == .denied) }
        }
    }
}
