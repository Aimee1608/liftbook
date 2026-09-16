import Foundation

enum Limits {
    static let weightKg = 0.0...999.75
    static let weightStepKg = 0.25
    static let reps = 1...100
    static let sets = 1...20
    static let defaultSets = 4
    static let repRangeMin = 1...99
    static let repRangeMax = 2...100
    static let restSeconds = 0...600
    static let restStep = 15
    static let cardioSeconds = 60...36_000
    static let cardioDistanceMeters = 0.0...200_000.0
    static let exerciseNameLength = 1...30
    static let exerciseNameEnLength = 0...50
    static let planNameLength = 1...20
    static let noteLength = 0...500
    static let itemsPerDay = 0...30
    static let daysPerPlan = 1...14

    static let deloadFactor = 0.90
    static let deloadFailureThreshold = 2
    static let decayTiers: [(days: Int, factor: Double)] = [(14, 0.95), (30, 0.90), (60, 0.80)]
    static let sessionAutoCloseInterval: TimeInterval = 6 * 3600
    static let recoveryWarningHours = 48.0
    static let restCompound = 150
    static let restIsolation = 90
    static let repRangeCompound = 8...12
    static let repRangeIsolation = 10...15
    static let timerAdjustStep = 30
    static let workSecondsPerSetEstimate = 45
}
