import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @Published var unit: WeightUnit { didSet { defaults.set(unit.rawValue, forKey: "unit") } }
    @Published var restTimerEnabled: Bool { didSet { defaults.set(restTimerEnabled, forKey: "restTimerEnabled") } }
    @Published var restTimerHapticsEnabled: Bool { didSet { defaults.set(restTimerHapticsEnabled, forKey: "restTimerHapticsEnabled") } }
    @Published var restTimerSoundEnabled: Bool { didSet { defaults.set(restTimerSoundEnabled, forKey: "restTimerSoundEnabled") } }
    @Published var keepScreenAwake: Bool { didSet { defaults.set(keepScreenAwake, forKey: "keepScreenAwake") } }
    @Published var notesEnabled: Bool { didSet { defaults.set(notesEnabled, forKey: "notesEnabled") } }
    @Published var defaultRestSeconds: Int { didSet { defaults.set(defaultRestSeconds, forKey: "defaultRestSeconds") } }
    @Published var disclaimerAcceptedAt: Date? { didSet { defaults.set(disclaimerAcceptedAt, forKey: "disclaimerAcceptedAt") } }

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            "unit": WeightUnit.kg.rawValue,
            "restTimerEnabled": true,
            "restTimerHapticsEnabled": true,
            "restTimerSoundEnabled": false,
            "keepScreenAwake": true,
            "notesEnabled": true,
            "defaultRestSeconds": 90,
        ])
        unit = WeightUnit(rawValue: defaults.string(forKey: "unit") ?? "kg") ?? .kg
        restTimerEnabled = defaults.bool(forKey: "restTimerEnabled")
        restTimerHapticsEnabled = defaults.bool(forKey: "restTimerHapticsEnabled")
        restTimerSoundEnabled = defaults.bool(forKey: "restTimerSoundEnabled")
        keepScreenAwake = defaults.bool(forKey: "keepScreenAwake")
        notesEnabled = defaults.bool(forKey: "notesEnabled")
        defaultRestSeconds = defaults.integer(forKey: "defaultRestSeconds")
        disclaimerAcceptedAt = defaults.object(forKey: "disclaimerAcceptedAt") as? Date
    }
}
