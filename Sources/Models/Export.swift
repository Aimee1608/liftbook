import Foundation

struct BackupFile: Codable {
    var version = 1
    var exportedAt: Date
    var plans: [WorkoutPlan]
    var activePlanId: UUID?
    var progress: [String: ExerciseProgress]
    var customExercises: [ExerciseDefinition]
    var archivedExerciseIds: [String]
    var sessions: [WorkoutSession]
}

enum Export {
    static func backup(plans: [WorkoutPlan], activePlanId: UUID?, progress: [String: ExerciseProgress],
                       library: LibraryState, sessions: [WorkoutSession], now: Date = Date()) throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(BackupFile(exportedAt: now, plans: plans, activePlanId: activePlanId, progress: progress,
                                       customExercises: library.custom, archivedExerciseIds: Array(library.archivedIds).sorted(),
                                       sessions: sessions.filter { $0.status == .completed }.sorted { $0.startedAt < $1.startedAt }))
    }

    static func text(sessions: [WorkoutSession], library: ExerciseLibrary, unit: WeightUnit) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        var lines: [String] = ["力训笔记 训练记录", "导出时间 \(f.string(from: Date()))", ""]
        for s in sessions.filter({ $0.status == .completed }).sorted(by: { $0.startedAt < $1.startedAt }) {
            lines.append("## \(f.string(from: s.startedAt))  \(s.planDayNameSnapshot)  \(Format.minutes(s.duration))")
            if let note = s.note, !note.isEmpty { lines.append("备注：\(note)") }
            for ex in s.exercises {
                let def = library[ex.exerciseId]
                let sets = ex.sets.filter(\.isCompleted).map { set -> String in
                    var part = def?.equipment.isLoadable == false && set.weightKg == 0 ? "自重×\(set.reps)" : "\(Weight.text(set.weightKg, unit, withUnit: false))×\(set.reps)"
                    if set.type == .warmup { part += "(热身)" }
                    if set.isFailure { part += "(力竭)" }
                    return part
                }
                guard !sets.isEmpty else { continue }
                var line = "- \(ex.exerciseNameSnapshot)：\(sets.joined(separator: "  "))  \(unit.label)"
                if let p = ex.progression { line += "  → \(p.reason)" }
                lines.append(line)
            }
            for c in s.cardioEntries {
                lines.append("- 有氧 \(c.type.label) \(Format.minutes(TimeInterval(c.durationSeconds)))" + (c.distanceMeters.map { " \(Format.distance($0))" } ?? ""))
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    static func csv(sessions: [WorkoutSession], library: ExerciseLibrary) -> String {
        let f = ISO8601DateFormatter()
        var rows = ["日期,训练日,动作,组序,类型,重量kg,次数,力竭,备注"]
        for s in sessions.filter({ $0.status == .completed }).sorted(by: { $0.startedAt < $1.startedAt }) {
            for ex in s.exercises {
                for (i, set) in ex.sets.filter(\.isCompleted).enumerated() {
                    rows.append([f.string(from: s.startedAt), s.planDayNameSnapshot, ex.exerciseNameSnapshot, "\(i + 1)",
                                 set.type == .warmup ? "热身" : "正式", Weight.text(set.weightKg, .kg, withUnit: false), "\(set.reps)",
                                 set.isFailure ? "1" : "0", (set.note ?? "").replacingOccurrences(of: ",", with: "，")].joined(separator: ","))
                }
            }
        }
        return rows.joined(separator: "\n")
    }
}
