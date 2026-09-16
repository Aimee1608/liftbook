import Foundation

#if DEBUG
enum DemoSeed {
    // 上架截图用的演示数据，只在 DEBUG 构建里存在；空数据的首页说明不了产品在干什么
    @MainActor
    static func populate(_ store: WorkoutStore, now: Date = Date()) {
        guard store.plans.isEmpty, let template = store.templates.first(where: { $0.id == "four-day-split" }) else { return }
        let plan = store.createPlan(from: template)
        let cal = Calendar.current
        var weights: [String: Double] = [:]
        var reps: [String: Int] = [:]
        let sessionsBack = 24
        for i in 0..<sessionsBack {
            let day = plan.days[i % plan.days.count]
            let daysAgo = Double(sessionsBack - i) * 1.9 + 2
            guard let start = cal.date(bySettingHour: 19, minute: 10 + (i * 7) % 40, second: 0, of: now.addingTimeInterval(-daysAgo * 86_400)) else { continue }
            var exercises: [SessionExercise] = []
            for item in day.items {
                guard let def = store.exercise(item.exerciseId) else { continue }
                let inc = def.defaultIncrementKg
                var w = weights[def.id] ?? startWeight(def)
                var r = reps[def.id] ?? item.repRangeMin
                if weights[def.id] != nil {
                    if r >= item.repRangeMax, inc > 0 { w += inc; r = item.repRangeMin } else { r = min(r + 1, item.repRangeMax) }
                }
                weights[def.id] = w
                reps[def.id] = r
                let sets = (0..<item.targetSets).map { k in
                    SetRecord(weightKg: w, reps: k == item.targetSets - 1 && (i + k) % 3 == 1 ? max(r - 1, item.repRangeMin) : r,
                              isCompleted: true, completedAt: start.addingTimeInterval(Double(exercises.count * 480 + k * 150)))
                }
                exercises.append(SessionExercise(exerciseId: def.id, exerciseNameSnapshot: def.nameZh, plannedSets: item.targetSets,
                                                 plannedRepMin: item.repRangeMin, plannedRepMax: item.repRangeMax, plannedReps: r,
                                                 plannedWeightKg: w, restSeconds: def.defaultRestSeconds, isFromPlan: true, sets: sets))
            }
            let cardio = i % 5 == 3 ? [CardioEntry(type: .treadmill, durationSeconds: 1200, distanceMeters: 2600, performedAt: start.addingTimeInterval(3600))] : []
            store.backfillSession(startedAt: start, name: day.name, exercises: exercises, cardio: cardio)
        }
        for (id, w) in weights {
            store.setCurrentWeight(id, kg: w)
            if let r = reps[id] { store.setCurrentTargetReps(id, reps: r) }
        }
    }

    private static func startWeight(_ def: ExerciseDefinition) -> Double {
        guard def.equipment.isLoadable else { return 0 }
        let m = def.primaryMuscle
        let base: Double
        switch (def.equipment, def.isCompound) {
        case (.barbell, true): base = [.quads, .glutes, .hamstrings].contains(m) ? 70 : (m == .shoulders ? 35 : 55)
        case (.barbell, false): base = 20
        case (.smithMachine, _): base = 50
        case (.dumbbell, true): base = m == .shoulders ? 16 : 22.5
        case (.dumbbell, false): base = [.shoulders, .biceps].contains(m) ? 10 : 12.5
        case (.machine, true): base = [.quads, .glutes, .hamstrings].contains(m) ? 110 : 50
        case (.machine, false): base = m.isLarge ? 45 : 30
        case (.cable, true): base = 45
        case (.cable, false): base = m == .abs ? 30 : 17.5
        case (.kettlebell, _): base = 16
        default: base = 20
        }
        let jitter = Double(abs(def.id.hashValue) % 3) * def.defaultIncrementKg
        return base + jitter
    }
}
#endif
