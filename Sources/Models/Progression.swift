import Foundation

enum RoundDirection { case up, down }

enum Increment {
    static func defaultKg(equipment: EquipmentType, muscle: MuscleGroup) -> Double {
        switch equipment {
        case .barbell, .dumbbell, .smithMachine, .cable: return 2.5
        case .machine: return muscle.isLarge ? 5.0 : 2.5
        case .kettlebell: return 4.0
        case .bodyweight, .band: return 0
        case .other: return 2.5
        }
    }

    // 0.95 这类因子在二进制里略小于真值，50×0.95 会落在 47.4999…，不加 epsilon 会被 floor 吸到 45
    static func round(_ w: Double, to inc: Double, _ direction: RoundDirection) -> Double {
        guard inc > 0 else { return w }
        let q = w / inc
        switch direction {
        case .up: return (q - 1e-9).rounded(.up) * inc
        case .down: return (q + 1e-9).rounded(.down) * inc
        }
    }
}

struct ProgressionResult: Hashable {
    var kind: ProgressionKind
    var weightKg: Double
    var reps: Int
    var failures: Int
    var reason: String
}

enum ProgressionEngine {
    static func evaluate(workingSets: [SetRecord], targetWeightKg: Double, targetReps: Int,
                         consecutiveFailures: Int, repMin: Int, repMax: Int, incrementKg: Double,
                         unit: WeightUnit = .kg) -> ProgressionResult {
        let sets = workingSets.filter(\.isCompleted)
        let allMet = !sets.isEmpty && sets.allSatisfy {
            $0.reps >= targetReps && $0.weightKg >= targetWeightKg - 1e-9
        }

        if !allMet {
            let failures = consecutiveFailures + 1
            if failures >= 2 {
                let deload = Increment.round(targetWeightKg * 0.9, to: incrementKg, .down)
                return ProgressionResult(kind: .suggestDeload, weightKg: deload, reps: repMin, failures: 0,
                                         reason: "连续两次未达标，建议减重 10% 至 \(Weight.text(deload, unit))，次数回到 \(repMin) 次重新爬升")
            }
            return ProgressionResult(kind: .hold, weightKg: targetWeightKg, reps: targetReps, failures: failures,
                                     reason: "本次未达标，下次保持 \(Weight.text(targetWeightKg, unit)) × \(targetReps) 次再试一次")
        }

        if targetReps < repMax {
            return ProgressionResult(kind: .increaseReps, weightKg: targetWeightKg, reps: targetReps + 1, failures: 0,
                                     reason: "全部达标，下次每组多做 1 次（\(targetReps + 1) 次）")
        }

        if incrementKg <= 0 {
            return ProgressionResult(kind: .increaseReps, weightKg: targetWeightKg, reps: targetReps + 1, failures: 0,
                                     reason: "已达次数上限，自重动作继续加次数至 \(targetReps + 1)，也可考虑负重带或更难的变式")
        }

        let next = Increment.round(targetWeightKg + incrementKg, to: incrementKg, .up)
        return ProgressionResult(kind: .increaseWeight, weightKg: next, reps: repMin, failures: 0,
                                 reason: "全部达到 \(repMax) 次，下次加重至 \(Weight.text(next, unit))，次数回到 \(repMin) 次")
    }
}

struct DecaySuggestion: Hashable {
    var weightKg: Double
    var days: Int
    var needsRetest: Bool
    var reason: String
}

enum Detraining {
    static func suggestion(lastTrainedAt: Date?, lastDecayAppliedAt: Date?, currentWeightKg: Double?,
                           incrementKg: Double, now: Date, unit: WeightUnit = .kg) -> DecaySuggestion? {
        guard let last = lastTrainedAt, let weight = currentWeightKg, weight > 0 else { return nil }
        if let applied = lastDecayAppliedAt, applied > last { return nil }
        let days = Int(now.timeIntervalSince(last) / 86_400)
        let factor: Double
        switch days {
        case ..<14: return nil
        case 14..<30: factor = 0.95
        case 30..<60: factor = 0.90
        default: factor = 0.80
        }
        let suggested = Increment.round(weight * factor, to: incrementKg, .down)
        let reason = days >= 60
            ? "距上次训练已 \(days) 天，建议从 \(Weight.text(suggested, unit)) 起用探底组重新确定重量"
            : "距上次训练 \(days) 天，建议本次降至 \(Weight.text(suggested, unit)) 作为过渡"
        return DecaySuggestion(weightKg: suggested, days: days, needsRetest: days >= 60, reason: reason)
    }
}
