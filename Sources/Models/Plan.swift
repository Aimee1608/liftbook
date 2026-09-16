import Foundation

struct PlanItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseId: String
    var targetSets: Int
    var repRangeMin: Int
    var repRangeMax: Int
    var restSecondsOverride: Int?
    var note: String?

    var repRange: ClosedRange<Int> { min(repRangeMin, repRangeMax)...max(repRangeMin, repRangeMax) }
}

struct PlanDay: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var targetMuscles: [MuscleGroup]
    var items: [PlanItem]
}

struct WorkoutPlan: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var createdAt = Date()
    var days: [PlanDay]
}

struct SplitTemplate: Codable, Identifiable {
    struct Day: Codable {
        struct Item: Codable {
            var exerciseId: String
            var targetSets: Int
            var repRangeMin: Int
            var repRangeMax: Int
        }
        var name: String
        var targetMuscles: [MuscleGroup]
        var items: [Item]
    }

    var id: String
    var name: String
    var summary: String
    var days: [Day]

    static func loadAll(from url: URL) throws -> [SplitTemplate] {
        try JSONDecoder().decode([SplitTemplate].self, from: Data(contentsOf: url))
    }

    func makePlan() -> WorkoutPlan {
        WorkoutPlan(name: name, days: days.map { day in
            PlanDay(name: day.name, targetMuscles: day.targetMuscles, items: day.items.map {
                PlanItem(exerciseId: $0.exerciseId, targetSets: $0.targetSets,
                         repRangeMin: $0.repRangeMin, repRangeMax: $0.repRangeMax)
            })
        })
    }
}
