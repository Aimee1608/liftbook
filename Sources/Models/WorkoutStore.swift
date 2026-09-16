import Foundation
import Combine

enum TargetState: Hashable {
    case normal
    case needsInitialWeight
    case decaySuggested(DecaySuggestion)
}

struct ExerciseTarget: Hashable {
    var item: PlanItem
    var exercise: ExerciseDefinition
    var sets: Int
    var reps: Int
    var weightKg: Double?
    var restSeconds: Int
    var state: TargetState
}

struct ExerciseHistoryPoint: Hashable {
    var date: Date
    var topWeightKg: Double
    var topReps: Int
    var volumeKg: Double
}

private struct PlansFile: Codable {
    var plans: [WorkoutPlan] = []
    var activePlanId: UUID?
}

@MainActor
final class WorkoutStore: ObservableObject {
    @Published private(set) var library: ExerciseLibrary
    @Published private(set) var plans: [WorkoutPlan] = []
    @Published private(set) var activePlanId: UUID?
    @Published private(set) var progress: [String: ExerciseProgress] = [:]
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published var saveError: String?
    let templates: [SplitTemplate]
    var now: () -> Date = Date.init

    private let directory: URL
    private var sessionsDir: URL { directory.appendingPathComponent("sessions", isDirectory: true) }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(directory: URL, builtinURL: URL, templatesURL: URL) {
        self.directory = directory
        library = ExerciseLibrary(builtin: (try? ExerciseLibrary.loadBuiltin(from: builtinURL)) ?? [])
        templates = (try? SplitTemplate.loadAll(from: templatesURL)) ?? []
        load()
    }

    // 必须落在 Application Support 且不排除备份，否则卸载前系统清理就会丢数据，而本 app 没有导出/同步兜底
    static func appDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("liftbook", isDirectory: true)
    }

    // MARK: - 计划

    var activePlan: WorkoutPlan? { plans.first { $0.id == activePlanId } ?? plans.first }

    func addPlan(_ plan: WorkoutPlan, activate: Bool = true) {
        plans.append(plan)
        if activate || activePlanId == nil { activePlanId = plan.id }
        savePlans()
    }

    @discardableResult
    func createPlan(from template: SplitTemplate) -> WorkoutPlan {
        let plan = template.makePlan()
        addPlan(plan)
        return plan
    }

    func updatePlan(_ plan: WorkoutPlan) {
        guard let i = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        plans[i] = plan
        savePlans()
    }

    func deletePlan(id: UUID) {
        plans.removeAll { $0.id == id }
        if activePlanId == id { activePlanId = plans.first?.id }
        savePlans()
    }

    func setActivePlan(id: UUID) {
        guard plans.contains(where: { $0.id == id }) else { return }
        activePlanId = id
        savePlans()
    }

    // MARK: - 动作库

    func exercise(_ id: String) -> ExerciseDefinition? { library[id] }

    func addCustomExercise(_ def: ExerciseDefinition) {
        library.add(def)
        saveLibrary()
    }

    func updateCustomExercise(_ def: ExerciseDefinition) {
        library.update(def)
        saveLibrary()
    }

    func setExerciseArchived(_ id: String, _ archived: Bool) {
        library.setArchived(id, archived)
        saveLibrary()
    }

    func alternatives(for exercise: ExerciseDefinition, limit: Int = 5) -> [ExerciseDefinition] {
        library.alternatives(for: exercise, trainedIds: Set(progress.keys), limit: limit)
    }

    // MARK: - 进度

    func progress(for exerciseId: String) -> ExerciseProgress {
        if let p = progress[exerciseId] { return p }
        let def = library[exerciseId]
        return ExerciseProgress(
            exerciseId: exerciseId,
            currentWeightKg: (def?.equipment.isLoadable ?? true) ? nil : 0,
            currentTargetReps: def?.defaultRepRange.lowerBound ?? 8,
            updatedAt: now()
        )
    }

    func effectiveIncrement(_ exerciseId: String) -> Double {
        progress[exerciseId]?.incrementOverrideKg ?? library[exerciseId]?.defaultIncrementKg ?? 2.5
    }

    func setCurrentWeight(_ exerciseId: String, kg: Double?) {
        updateProgress(exerciseId) { $0.currentWeightKg = kg }
    }

    func setCurrentTargetReps(_ exerciseId: String, reps: Int) {
        updateProgress(exerciseId) { $0.currentTargetReps = reps }
    }

    func setIncrementOverride(_ exerciseId: String, kg: Double?) {
        updateProgress(exerciseId) { $0.incrementOverrideKg = kg }
    }

    func resetProgress(_ exerciseId: String) {
        guard progress[exerciseId] != nil else { return }
        updateProgress(exerciseId) {
            $0.currentWeightKg = (library[exerciseId]?.equipment.isLoadable ?? true) ? nil : 0
            $0.currentTargetReps = library[exerciseId]?.defaultRepRange.lowerBound ?? 8
            $0.consecutiveFailures = 0
        }
    }

    private func updateProgress(_ exerciseId: String, _ body: (inout ExerciseProgress) -> Void) {
        var p = progress(for: exerciseId)
        body(&p)
        p.updatedAt = now()
        progress[exerciseId] = p
        saveProgress()
    }

    // MARK: - 调度

    func rankedDays(plan: WorkoutPlan? = nil) -> [RankedDay] {
        guard let plan = plan ?? activePlan else { return [] }
        return Scheduler.ranked(plan: plan, sessions: sessions, library: library)
    }

    func recommendedDay() -> RankedDay? { rankedDays().first }

    func hoursSinceTrained(_ ranked: RankedDay) -> Double? {
        ranked.lastTrainedAt.map { now().timeIntervalSince($0) / 3600 }
    }

    // MARK: - 今日目标

    func target(for item: PlanItem) -> ExerciseTarget? {
        guard let def = library[item.exerciseId] else { return nil }
        let p = progress(for: item.exerciseId)
        let rest = item.restSecondsOverride ?? def.defaultRestSeconds
        let reps = min(max(p.currentTargetReps, item.repRange.lowerBound), item.repRange.upperBound)
        guard let weight = p.currentWeightKg else {
            return ExerciseTarget(item: item, exercise: def, sets: item.targetSets, reps: item.repRange.lowerBound,
                                  weightKg: nil, restSeconds: rest, state: .needsInitialWeight)
        }
        let decay = Detraining.suggestion(lastTrainedAt: p.lastTrainedAt, lastDecayAppliedAt: p.lastDecayAppliedAt,
                                          currentWeightKg: weight, incrementKg: effectiveIncrement(item.exerciseId), now: now())
        return ExerciseTarget(item: item, exercise: def, sets: item.targetSets, reps: reps,
                              weightKg: decay?.weightKg ?? weight, restSeconds: rest,
                              state: decay.map { .decaySuggested($0) } ?? .normal)
    }

    func targets(for day: PlanDay) -> [ExerciseTarget] {
        day.items.compactMap(target(for:))
    }

    // MARK: - 会话

    var activeSession: WorkoutSession? { sessions.first { $0.status == .inProgress } }

    var completedSessions: [WorkoutSession] {
        sessions.filter { $0.status == .completed }.sorted { $0.startedAt > $1.startedAt }
    }

    func session(_ id: UUID) -> WorkoutSession? { sessions.first { $0.id == id } }

    @discardableResult
    func startSession(day: PlanDay?) -> WorkoutSession? {
        guard activeSession == nil else { return nil }
        let start = now()
        var exercises: [SessionExercise] = []
        for t in day.map(targets(for:)) ?? [] {
            var ex = makeEntry(exercise: t.exercise, sets: t.sets, repMin: t.item.repRange.lowerBound,
                               repMax: t.item.repRange.upperBound, reps: t.reps, weightKg: t.weightKg,
                               rest: t.restSeconds, fromPlan: true)
            if case let .decaySuggested(decay) = t.state {
                ex.decayReason = decay.reason
                ex.decayFromWeightKg = progress(for: t.exercise.id).currentWeightKg
                updateProgress(t.exercise.id) {
                    $0.currentWeightKg = decay.weightKg
                    $0.lastDecayAppliedAt = start
                }
            }
            exercises.append(ex)
        }
        let session = WorkoutSession(startedAt: start, planDayId: day?.id,
                                     planDayNameSnapshot: day?.name ?? "自由训练", exercises: exercises)
        sessions.append(session)
        saveSession(session)
        return session
    }

    private func makeEntry(exercise: ExerciseDefinition, sets: Int, repMin: Int, repMax: Int, reps: Int,
                           weightKg: Double?, rest: Int, fromPlan: Bool) -> SessionExercise {
        SessionExercise(
            exerciseId: exercise.id, exerciseNameSnapshot: exercise.nameZh,
            plannedSets: sets, plannedRepMin: repMin, plannedRepMax: repMax, plannedReps: reps,
            plannedWeightKg: weightKg, restSeconds: rest, isFromPlan: fromPlan,
            sets: (0..<max(sets, 1)).map { _ in SetRecord(weightKg: weightKg ?? 0, reps: reps) }
        )
    }

    func keepOriginalWeight(_ sessionId: UUID, _ entryId: UUID) {
        mutateEntry(sessionId, entryId) { ex in
            guard let original = ex.decayFromWeightKg else { return }
            ex.plannedWeightKg = original
            ex.decayReason = nil
            ex.decayFromWeightKg = nil
            for i in ex.sets.indices where !ex.sets[i].isCompleted { ex.sets[i].weightKg = original }
            updateProgress(ex.exerciseId) { $0.currentWeightKg = original }
        }
    }

    func setInitialWeight(_ sessionId: UUID, _ entryId: UUID, kg: Double) {
        mutateEntry(sessionId, entryId) { ex in
            ex.plannedWeightKg = kg
            for i in ex.sets.indices where !ex.sets[i].isCompleted { ex.sets[i].weightKg = kg }
            updateProgress(ex.exerciseId) {
                $0.currentWeightKg = kg
                $0.currentTargetReps = ex.plannedReps
            }
        }
    }

    func updateSet(_ sessionId: UUID, _ entryId: UUID, _ setId: UUID, weightKg: Double? = nil, reps: Int? = nil) {
        mutateSet(sessionId, entryId, setId) { s in
            if let w = weightKg { s.weightKg = max(0, w) }
            if let r = reps { s.reps = max(0, r) }
        }
    }

    func completeSet(_ sessionId: UUID, _ entryId: UUID, _ setId: UUID) {
        let t = now()
        var exerciseId: String?
        var isWorking = false
        mutateSet(sessionId, entryId, setId) { s in
            s.isCompleted = true
            s.completedAt = t
            isWorking = s.type == .working
        }
        if let ex = session(sessionId)?.exercises.first(where: { $0.id == entryId }) { exerciseId = ex.exerciseId }
        if isWorking, let id = exerciseId {
            updateProgress(id) { $0.lastTrainedAt = max($0.lastTrainedAt ?? t, t) }
        }
    }

    func uncompleteSet(_ sessionId: UUID, _ entryId: UUID, _ setId: UUID) {
        mutateSet(sessionId, entryId, setId) { s in
            s.isCompleted = false
            s.completedAt = nil
        }
    }

    func toggleFailure(_ sessionId: UUID, _ entryId: UUID, _ setId: UUID) {
        mutateSet(sessionId, entryId, setId) { $0.isFailure.toggle() }
    }

    func setSetType(_ sessionId: UUID, _ entryId: UUID, _ setId: UUID, _ type: SetType) {
        mutateSet(sessionId, entryId, setId) { $0.type = type }
    }

    func setSetNote(_ sessionId: UUID, _ entryId: UUID, _ setId: UUID, _ note: String?) {
        mutateSet(sessionId, entryId, setId) { $0.note = note?.isEmpty == true ? nil : note }
    }

    func addSet(_ sessionId: UUID, _ entryId: UUID) {
        mutateEntry(sessionId, entryId) { ex in
            let last = ex.sets.last
            ex.sets.append(SetRecord(weightKg: last?.weightKg ?? ex.plannedWeightKg ?? 0,
                                     reps: last?.reps ?? ex.plannedReps))
        }
    }

    func removeSet(_ sessionId: UUID, _ entryId: UUID, _ setId: UUID) {
        mutateEntry(sessionId, entryId) { ex in
            guard ex.sets.count > 1 else { return }
            ex.sets.removeAll { $0.id == setId }
        }
    }

    func skipExercise(_ sessionId: UUID, _ entryId: UUID) {
        mutateEntry(sessionId, entryId) { ex in
            ex.isSkipped = true
            ex.sets.removeAll { !$0.isCompleted }
        }
    }

    func setExerciseNote(_ sessionId: UUID, _ entryId: UUID, _ note: String?) {
        mutateEntry(sessionId, entryId) { $0.note = note?.isEmpty == true ? nil : note }
    }

    func setSessionNote(_ sessionId: UUID, _ note: String?) {
        mutate(sessionId) { $0.note = note?.isEmpty == true ? nil : note }
    }

    @discardableResult
    func addExercise(_ sessionId: UUID, exerciseId: String, sets: Int? = nil) -> UUID? {
        guard let def = library[exerciseId] else { return nil }
        let p = progress(for: exerciseId)
        let range = def.defaultRepRange
        let reps = min(max(p.currentTargetReps, range.lowerBound), range.upperBound)
        let entry = makeEntry(exercise: def, sets: sets ?? 3, repMin: range.lowerBound, repMax: range.upperBound,
                              reps: reps, weightKg: p.currentWeightKg, rest: def.defaultRestSeconds, fromPlan: false)
        mutate(sessionId) { $0.exercises.append(entry) }
        return entry.id
    }

    @discardableResult
    func replaceExercise(_ sessionId: UUID, _ entryId: UUID, with exerciseId: String) -> UUID? {
        guard let def = library[exerciseId], var session = session(sessionId),
              let index = session.exerciseIndex(entryId) else { return nil }
        let old = session.exercises[index]
        if let outcome = old.progression { revert(outcome) }
        let p = progress(for: exerciseId)
        let range = def.defaultRepRange
        let reps = min(max(p.currentTargetReps, range.lowerBound), range.upperBound)
        let entry = makeEntry(exercise: def, sets: old.plannedSets, repMin: range.lowerBound, repMax: range.upperBound,
                              reps: reps, weightKg: p.currentWeightKg, rest: def.defaultRestSeconds, fromPlan: false)
        session.exercises[index] = entry
        store(session)
        return entry.id
    }

    func removeExercise(_ sessionId: UUID, _ entryId: UUID) {
        guard var session = session(sessionId), let index = session.exerciseIndex(entryId) else { return }
        if let outcome = session.exercises[index].progression { revert(outcome) }
        session.exercises.remove(at: index)
        store(session)
    }

    func addCardio(_ sessionId: UUID, _ entry: CardioEntry) {
        mutate(sessionId) { $0.cardioEntries.append(entry) }
    }

    func logStandaloneCardio(_ entry: CardioEntry) {
        var session = WorkoutSession(startedAt: entry.performedAt, planDayNameSnapshot: "有氧", exercises: [])
        session.endedAt = entry.performedAt.addingTimeInterval(TimeInterval(entry.durationSeconds))
        session.status = .completed
        session.cardioEntries = [entry]
        sessions.append(session)
        saveSession(session)
    }

    func endSession(_ sessionId: UUID) {
        mutate(sessionId) {
            $0.status = .completed
            $0.endedAt = now()
            Self.pruneUncompleted(&$0)
        }
    }

    // 收尾清理不能走 mutateEntry：删掉未完成组后剩余组「全部完成」会误触发渐进（D3 飞鸟 2/4 不该渐进）
    private static func pruneUncompleted(_ session: inout WorkoutSession) {
        for i in session.exercises.indices { session.exercises[i].sets.removeAll { !$0.isCompleted } }
        session.exercises.removeAll { $0.sets.isEmpty }
    }

    func discardSession(_ sessionId: UUID) {
        guard let session = session(sessionId) else { return }
        for ex in session.exercises {
            if let outcome = ex.progression { revert(outcome) }
            if let original = ex.decayFromWeightKg { updateProgress(ex.exerciseId) { $0.currentWeightKg = original } }
        }
        sessions.removeAll { $0.id == sessionId }
        try? FileManager.default.removeItem(at: sessionsDir.appendingPathComponent("\(sessionId.uuidString).json"))
    }

    @discardableResult
    func autoCloseStaleSessions() -> [WorkoutSession] {
        var closed: [WorkoutSession] = []
        for session in sessions where session.status == .inProgress {
            guard now().timeIntervalSince(session.lastActivityAt) >= Limits.sessionAutoCloseInterval else { continue }
            var s = session
            s.status = .completed
            s.endedAt = s.lastActivityAt
            Self.pruneUncompleted(&s)
            store(s)
            closed.append(s)
        }
        return closed
    }

    func updateSession(_ session: WorkoutSession) {
        store(session)
    }

    func backfillSession(startedAt: Date, name: String, exercises: [SessionExercise], cardio: [CardioEntry] = []) {
        var session = WorkoutSession(startedAt: startedAt, planDayNameSnapshot: name, exercises: exercises)
        session.endedAt = startedAt.addingTimeInterval(3600)
        session.status = .completed
        session.cardioEntries = cardio
        for ex in exercises where !ex.completedWorkingSets.isEmpty {
            updateProgress(ex.exerciseId) { $0.lastTrainedAt = max($0.lastTrainedAt ?? startedAt, startedAt) }
        }
        sessions.append(session)
        saveSession(session)
    }

    // MARK: - 渐进

    func setProgressionAccepted(_ sessionId: UUID, _ entryId: UUID, _ accepted: Bool) {
        guard var session = session(sessionId), let index = session.exerciseIndex(entryId),
              var outcome = session.exercises[index].progression, outcome.accepted != accepted else { return }
        outcome.accepted = accepted
        session.exercises[index].progression = outcome
        apply(outcome, accepted: accepted)
        store(session)
    }

    private func refreshProgression(_ session: inout WorkoutSession, _ index: Int) {
        var ex = session.exercises[index]
        if ex.allWorkingCompleted && !ex.isSkipped {
            guard ex.progression == nil, let target = ex.plannedWeightKg else { return }
            let result = ProgressionEngine.evaluate(
                workingSets: ex.workingSets, targetWeightKg: target, targetReps: ex.plannedReps,
                consecutiveFailures: progress(for: ex.exerciseId).consecutiveFailures,
                repMin: ex.plannedRepMin, repMax: ex.plannedRepMax, incrementKg: effectiveIncrement(ex.exerciseId)
            )
            let p = progress(for: ex.exerciseId)
            let outcome = ProgressionOutcome(
                exerciseId: ex.exerciseId, kind: result.kind, fromWeightKg: p.currentWeightKg ?? target, fromReps: p.currentTargetReps, fromFailures: p.consecutiveFailures,
                toWeightKg: result.weightKg, toReps: result.reps, toFailures: result.failures,
                keptFailures: result.kind == .suggestDeload ? p.consecutiveFailures + 1 : result.failures,
                reason: result.reason
            )
            ex.progression = outcome
            apply(outcome, accepted: true)
        } else if let outcome = ex.progression {
            revert(outcome)
            ex.progression = nil
        }
        session.exercises[index] = ex
    }

    private func apply(_ outcome: ProgressionOutcome, accepted: Bool) {
        updateProgress(outcome.exerciseId) {
            $0.currentWeightKg = accepted ? outcome.toWeightKg : outcome.fromWeightKg
            $0.currentTargetReps = accepted ? outcome.toReps : outcome.fromReps
            $0.consecutiveFailures = accepted ? outcome.toFailures : outcome.keptFailures
        }
    }

    private func revert(_ outcome: ProgressionOutcome) {
        updateProgress(outcome.exerciseId) {
            $0.currentWeightKg = outcome.fromWeightKg
            $0.currentTargetReps = outcome.fromReps
            $0.consecutiveFailures = outcome.fromFailures
        }
    }

    // MARK: - 历史与纪录

    func sessions(on date: Date, calendar: Calendar = .current) -> [WorkoutSession] {
        completedSessions.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
    }

    func lastPerformance(of exerciseId: String, before session: WorkoutSession) -> SessionExercise? {
        completedSessions
            .filter { $0.id != session.id && $0.startedAt < session.startedAt }
            .lazy
            .compactMap { s in s.exercises.first { $0.exerciseId == exerciseId && !$0.completedWorkingSets.isEmpty } }
            .first
    }

    func workingSets(of exerciseId: String, excluding sessionId: UUID? = nil) -> [SetRecord] {
        completedSessions
            .filter { $0.id != sessionId }
            .flatMap { $0.exercises.filter { $0.exerciseId == exerciseId }.flatMap(\.completedWorkingSets) }
    }

    func record(for exerciseId: String) -> PersonalRecord? {
        PersonalRecord.compute(workingSets(of: exerciseId))
    }

    func newRecords(in session: WorkoutSession) -> [(exercise: ExerciseDefinition, kinds: [String])] {
        var seen = Set<String>()
        return session.exercises.compactMap { ex in
            guard seen.insert(ex.exerciseId).inserted, let def = library[ex.exerciseId],
                  let current = PersonalRecord.compute(session.exercises.filter { $0.exerciseId == ex.exerciseId }.flatMap(\.sets))
            else { return nil }
            let kinds: [String]
            if let before = PersonalRecord.compute(workingSets(of: ex.exerciseId, excluding: session.id)) {
                kinds = before.beaten(by: current)
            } else {
                kinds = ["首次纪录"]
            }
            return kinds.isEmpty ? nil : (def, kinds)
        }
    }

    func history(of exerciseId: String) -> [ExerciseHistoryPoint] {
        let multiplier = library[exerciseId]?.volumeMultiplier ?? 1
        return completedSessions.reversed().compactMap { s in
            let sets = s.exercises.filter { $0.exerciseId == exerciseId }.flatMap(\.completedWorkingSets)
            guard let top = sets.max(by: { $0.weightKg < $1.weightKg }) else { return nil }
            return ExerciseHistoryPoint(date: s.startedAt, topWeightKg: top.weightKg, topReps: top.reps,
                                        volumeKg: sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) } * multiplier)
        }
    }

    func volumeKg(of session: WorkoutSession) -> Double {
        session.exercises.reduce(0) { total, ex in
            let m = library[ex.exerciseId]?.volumeMultiplier ?? 1
            return total + ex.completedWorkingSets.reduce(0) { $0 + $1.weightKg * Double($1.reps) } * m
        }
    }

    // MARK: - 内部写入

    private func mutate(_ sessionId: UUID, _ body: (inout WorkoutSession) -> Void) {
        guard var s = session(sessionId) else { return }
        body(&s)
        store(s)
    }

    private func mutateEntry(_ sessionId: UUID, _ entryId: UUID, _ body: (inout SessionExercise) -> Void) {
        guard var s = session(sessionId), let index = s.exerciseIndex(entryId) else { return }
        body(&s.exercises[index])
        refreshProgression(&s, index)
        store(s)
    }

    private func mutateSet(_ sessionId: UUID, _ entryId: UUID, _ setId: UUID, _ body: (inout SetRecord) -> Void) {
        mutateEntry(sessionId, entryId) { ex in
            guard let i = ex.sets.firstIndex(where: { $0.id == setId }) else { return }
            body(&ex.sets[i])
        }
    }

    private func store(_ session: WorkoutSession) {
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[i] = session
        } else {
            sessions.append(session)
        }
        saveSession(session)
    }

    // MARK: - 磁盘

    private func load() {
        try? FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        if let s: LibraryState = read("library.json") { library.state = s }
        if let p: PlansFile = read("plans.json") {
            plans = p.plans
            activePlanId = p.activePlanId
        }
        if let pr: [String: ExerciseProgress] = read("progress.json") { progress = pr }
        let files = (try? FileManager.default.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil)) ?? []
        sessions = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in (try? Data(contentsOf: url)).flatMap { try? Self.decoder.decode(WorkoutSession.self, from: $0) } }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private func read<T: Decodable>(_ name: String) -> T? {
        guard let raw = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? Self.decoder.decode(T.self, from: raw)
    }

    private func write<T: Encodable>(_ value: T, _ name: String) {
        persist(value, to: directory.appendingPathComponent(name))
    }

    private func persist<T: Encodable>(_ value: T, to url: URL) {
        do {
            try Self.encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            saveError = "保存失败，请检查设备存储空间"
        }
    }

    private func saveLibrary() { write(library.state, "library.json") }
    private func savePlans() { write(PlansFile(plans: plans, activePlanId: activePlanId), "plans.json") }
    private func saveProgress() { write(progress, "progress.json") }

    private func saveSession(_ session: WorkoutSession) {
        persist(session, to: sessionsDir.appendingPathComponent("\(session.id.uuidString).json"))
    }
}
