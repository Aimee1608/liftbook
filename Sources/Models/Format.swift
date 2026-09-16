import Foundation

enum Format {
    static func weight(_ kg: Double, _ unit: WeightUnit, withUnit: Bool = true) -> String {
        Weight.text(kg, unit, withUnit: withUnit)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        if s < 3600 { return String(format: "%02d:%02d", s / 60, s % 60) }
        return "\(s / 3600)小时\(String(format: "%02d", s % 3600 / 60))分"
    }

    static func minutes(_ seconds: TimeInterval) -> String {
        let m = max(1, Int((seconds / 60).rounded()))
        return m < 60 ? "\(m)分钟" : "\(m / 60)小时\(String(format: "%02d", m % 60))分"
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }

    static func relativeDay(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return "今天"
        case 1: return "昨天"
        case 2: return "前天"
        default:
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = calendar.isDate(date, equalTo: now, toGranularity: .year) ? "M月d日" : "yyyy年M月d日"
            return f.string(from: date)
        }
    }

    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func month(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }

    static func daysSince(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let date else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day
    }

    static func lastTrainedText(_ date: Date?, now: Date = Date()) -> String {
        guard let days = daysSince(date, now: now) else { return "还没练过" }
        return days == 0 ? "今天刚练过" : "距上次训练 \(days) 天"
    }

    static func distance(_ meters: Double) -> String {
        meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters)) m"
    }

    static func pace(seconds: Int, meters: Double) -> String? {
        guard meters > 0 else { return nil }
        let perKm = Double(seconds) / (meters / 1000)
        let m = Int(perKm) / 60
        let s = Int(perKm) % 60
        return "\(m)'\(String(format: "%02d", s))\" / km"
    }
}
