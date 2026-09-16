import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Hashable {
    case chest, back, shoulders, biceps, triceps, forearms
    case quads, hamstrings, glutes, calves, abs

    var label: String {
        switch self {
        case .chest: return "胸"
        case .back: return "背"
        case .shoulders: return "肩"
        case .biceps: return "二头"
        case .triceps: return "三头"
        case .forearms: return "前臂"
        case .quads: return "股四头"
        case .hamstrings: return "腘绳肌"
        case .glutes: return "臀"
        case .calves: return "小腿"
        case .abs: return "腹"
        }
    }

    var isLarge: Bool {
        switch self {
        case .chest, .back, .quads, .hamstrings, .glutes: return true
        default: return false
        }
    }
}

enum EquipmentType: String, Codable, CaseIterable, Hashable {
    case barbell, dumbbell, machine, cable, smithMachine, kettlebell, bodyweight, band, other

    var label: String {
        switch self {
        case .barbell: return "杠铃"
        case .dumbbell: return "哑铃"
        case .machine: return "固定器械"
        case .cable: return "绳索"
        case .smithMachine: return "史密斯机"
        case .kettlebell: return "壶铃"
        case .bodyweight: return "自重"
        case .band: return "弹力带"
        case .other: return "其他"
        }
    }

    var isLoadable: Bool { self != .bodyweight && self != .band }
}

enum Laterality: String, Codable, CaseIterable, Hashable {
    case bilateral, unilateral, alternating

    var label: String {
        switch self {
        case .bilateral: return "双侧"
        case .unilateral: return "单侧"
        case .alternating: return "交替"
        }
    }
}

enum SetType: String, Codable, Hashable {
    case warmup, working
}

enum SessionStatus: String, Codable, Hashable {
    case inProgress, completed, discarded
}

enum CardioType: String, Codable, CaseIterable, Hashable {
    case treadmill, elliptical, bike, rowing, stairs, outdoorRun, jumpRope, other

    var label: String {
        switch self {
        case .treadmill: return "跑步机"
        case .elliptical: return "椭圆机"
        case .bike: return "单车"
        case .rowing: return "划船机"
        case .stairs: return "登山机"
        case .outdoorRun: return "户外跑"
        case .jumpRope: return "跳绳"
        case .other: return "其他"
        }
    }
}

enum WeightUnit: String, Codable, CaseIterable, Hashable {
    case kg, lb

    var label: String { rawValue }
}

enum Weight {
    static let lbPerKg = 2.20462262

    static func toDisplay(_ kg: Double, _ unit: WeightUnit) -> Double {
        unit == .kg ? kg : kg * lbPerKg
    }

    static func toKg(_ value: Double, _ unit: WeightUnit) -> Double {
        unit == .kg ? value : value / lbPerKg
    }

    static func text(_ kg: Double, _ unit: WeightUnit, withUnit: Bool = true) -> String {
        let v = toDisplay(kg, unit)
        let rounded = unit == .lb ? (v * 2).rounded() / 2 : (v * 100).rounded() / 100
        let s = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
        return withUnit ? "\(s) \(unit.label)" : s
    }
}
