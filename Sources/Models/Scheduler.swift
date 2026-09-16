import Foundation

struct RankedDay: Hashable {
    var day: PlanDay
    var lastTrainedAt: Date?
}

enum Scheduler {
    static func lastTrained(muscle: MuscleGroup, sessions: [WorkoutSession], library: ExerciseLibrary) -> Date? {
        sessions
            .filter { $0.status == .completed }
            .filter { session in
                session.exercises.contains { ex in
                    !ex.completedWorkingSets.isEmpty
                        && (library[ex.exerciseId]?.primaryMuscles.contains(muscle) ?? false)
                }
            }
            .map(\.startedAt)
            .max()
    }

    // 取 max 而不是 min：该日任一肌群刚练过，整天就算不新鲜，避免恢复不足
    static func lastTrained(day: PlanDay, sessions: [WorkoutSession], library: ExerciseLibrary) -> Date? {
        day.targetMuscles.compactMap { lastTrained(muscle: $0, sessions: sessions, library: library) }.max()
    }

    static func ranked(plan: WorkoutPlan, sessions: [WorkoutSession], library: ExerciseLibrary) -> [RankedDay] {
        let completed = sessions.filter { $0.status == .completed }
        let ranked = plan.days.enumerated().map { index, day in
            (index, RankedDay(day: day, lastTrainedAt: lastTrained(day: day, sessions: completed, library: library)))
        }
        return ranked.sorted { l, r in
            let lt = l.1.lastTrainedAt ?? .distantPast
            let rt = r.1.lastTrainedAt ?? .distantPast
            if lt == rt { return l.0 < r.0 }
            return lt < rt
        }.map(\.1)
    }

    static func recommended(plan: WorkoutPlan, sessions: [WorkoutSession], library: ExerciseLibrary) -> RankedDay? {
        ranked(plan: plan, sessions: sessions, library: library).first
    }
}
