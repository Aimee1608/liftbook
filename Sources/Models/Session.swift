import Foundation

struct SetRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var type: SetType = .working
    var weightKg: Double
    var reps: Int
    var isCompleted = false
    var isFailure = false
    var completedAt: Date?
    var note: String?
}

enum ProgressionKind: String, Codable, Hashable {
    case hold, increaseReps, increaseWeight, suggestDeload
}

struct ProgressionOutcome: Codable, Hashable {
    var exerciseId: String
    var kind: ProgressionKind
    var fromWeightKg: Double
    var fromReps: Int
    var fromFailures: Int
    var toWeightKg: Double
    var toReps: Int
    var toFailures: Int
    var reason: String
    var accepted = true
}

struct SessionExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseId: String
    var exerciseNameSnapshot: String
    var plannedSets: Int
    var plannedRepMin: Int
    var plannedRepMax: Int
    var plannedReps: Int
    var plannedWeightKg: Double?
    var restSeconds: Int
    var isFromPlan: Bool
    var isSkipped = false
    var decayReason: String?
    var decayFromWeightKg: Double?
    var progression: ProgressionOutcome?
    var note: String?
    var sets: [SetRecord]

    var workingSets: [SetRecord] { sets.filter { $0.type == .working } }
    var completedWorkingSets: [SetRecord] { workingSets.filter(\.isCompleted) }
    var allWorkingCompleted: Bool { !workingSets.isEmpty && workingSets.allSatisfy(\.isCompleted) }
    var hasAnyCompleted: Bool { sets.contains(where: \.isCompleted) }
}

struct CardioEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var type: CardioType
    var durationSeconds: Int
    var distanceMeters: Double?
    var note: String?
    var performedAt = Date()
}

struct WorkoutSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date?
    var status: SessionStatus = .inProgress
    var planDayId: UUID?
    var planDayNameSnapshot: String
    var note: String?
    var exercises: [SessionExercise]
    var cardioEntries: [CardioEntry] = []

    var lastActivityAt: Date {
        let latest = exercises.flatMap(\.sets).compactMap(\.completedAt).max()
        return max(startedAt, latest ?? startedAt)
    }

    var duration: TimeInterval { (endedAt ?? lastActivityAt).timeIntervalSince(startedAt) }

    var completedWorkingSetCount: Int { exercises.reduce(0) { $0 + $1.completedWorkingSets.count } }

    func exerciseIndex(_ exerciseEntryId: UUID) -> Int? {
        exercises.firstIndex { $0.id == exerciseEntryId }
    }
}
