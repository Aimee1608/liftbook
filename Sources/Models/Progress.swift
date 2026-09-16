import Foundation

struct ExerciseProgress: Codable, Hashable {
    var exerciseId: String
    var currentWeightKg: Double?
    var currentTargetReps: Int
    var consecutiveFailures = 0
    var lastTrainedAt: Date?
    var incrementOverrideKg: Double?
    var lastDecayAppliedAt: Date?
    var updatedAt = Date()
}

struct PersonalRecord: Hashable {
    var maxWeightKg: Double
    var maxReps: Int
    var maxVolumeSingleSet: Double
    var estimated1RM: Double

    static func epley(weightKg: Double, reps: Int) -> Double {
        reps <= 1 ? weightKg : weightKg * (1 + Double(reps) / 30)
    }

    static func compute(_ sets: [SetRecord]) -> PersonalRecord? {
        let valid = sets.filter { $0.type == .working && $0.isCompleted && $0.reps >= 1 }
        guard !valid.isEmpty else { return nil }
        return PersonalRecord(
            maxWeightKg: valid.map(\.weightKg).max() ?? 0,
            maxReps: valid.map(\.reps).max() ?? 0,
            maxVolumeSingleSet: valid.map { $0.weightKg * Double($0.reps) }.max() ?? 0,
            estimated1RM: valid.map { epley(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? 0
        )
    }

    func beaten(by other: PersonalRecord) -> [String] {
        var kinds: [String] = []
        if other.maxWeightKg > maxWeightKg + 1e-9 { kinds.append("最大重量") }
        if other.maxReps > maxReps { kinds.append("单组次数") }
        if other.maxVolumeSingleSet > maxVolumeSingleSet + 1e-9 { kinds.append("单组容量") }
        return kinds
    }
}
