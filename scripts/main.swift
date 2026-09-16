import Foundation

var failures = 0

func check(_ condition: Bool, _ label: String) {
    print(condition ? "  ✓ \(label)" : "  ✗ \(label)")
    if !condition { failures += 1 }
}

func approx(_ a: Double?, _ b: Double) -> Bool {
    guard let a else { return false }
    return abs(a - b) < 1e-6
}

let fixtureExercises = """
[
 {"id":"bench","nameZh":"杠铃卧推","nameEn":"Barbell Bench Press","primaryMuscles":["chest"],"secondaryMuscles":["triceps"],"equipment":"barbell","isCompound":true},
 {"id":"fly","nameZh":"哑铃飞鸟","nameEn":"Dumbbell Fly","primaryMuscles":["chest"],"equipment":"dumbbell","isCompound":false},
 {"id":"pushup","nameZh":"俯卧撑","nameEn":"Push Up","primaryMuscles":["chest"],"equipment":"bodyweight","isCompound":true},
 {"id":"row","nameZh":"杠铃划船","nameEn":"Barbell Row","primaryMuscles":["back"],"equipment":"barbell","isCompound":true},
 {"id":"pullup","nameZh":"引体向上","nameEn":"Pull Up","primaryMuscles":["back"],"equipment":"bodyweight","isCompound":true},
 {"id":"ohp","nameZh":"杠铃推举","nameEn":"Overhead Press","primaryMuscles":["shoulders"],"equipment":"barbell","isCompound":true},
 {"id":"lateral","nameZh":"哑铃侧平举","nameEn":"Lateral Raise","primaryMuscles":["shoulders"],"equipment":"dumbbell","isCompound":false},
 {"id":"squat","nameZh":"杠铃深蹲","nameEn":"Barbell Squat","primaryMuscles":["quads"],"secondaryMuscles":["glutes"],"equipment":"barbell","isCompound":true},
 {"id":"legpress","nameZh":"腿举","nameEn":"Leg Press","primaryMuscles":["quads"],"equipment":"machine","isCompound":true},
 {"id":"curl","nameZh":"哑铃交替弯举","nameEn":"Alternating Dumbbell Curl","primaryMuscles":["biceps"],"equipment":"dumbbell","laterality":"alternating","isCompound":false}
]
"""

let fixtureTemplates = """
[
 {"id":"five","name":"五分化","summary":"每周 5 练","days":[
   {"name":"胸","targetMuscles":["chest"],"items":[{"exerciseId":"bench","targetSets":4,"repRangeMin":8,"repRangeMax":12},{"exerciseId":"fly","targetSets":3,"repRangeMin":10,"repRangeMax":15}]},
   {"name":"背","targetMuscles":["back"],"items":[{"exerciseId":"row","targetSets":4,"repRangeMin":8,"repRangeMax":12},{"exerciseId":"pullup","targetSets":3,"repRangeMin":8,"repRangeMax":12}]},
   {"name":"肩","targetMuscles":["shoulders"],"items":[{"exerciseId":"ohp","targetSets":4,"repRangeMin":8,"repRangeMax":12},{"exerciseId":"lateral","targetSets":3,"repRangeMin":10,"repRangeMax":15}]},
   {"name":"腿","targetMuscles":["quads","glutes"],"items":[{"exerciseId":"squat","targetSets":4,"repRangeMin":6,"repRangeMax":10},{"exerciseId":"legpress","targetSets":3,"repRangeMin":8,"repRangeMax":12}]},
   {"name":"手臂","targetMuscles":["biceps","triceps"],"items":[{"exerciseId":"curl","targetSets":3,"repRangeMin":10,"repRangeMax":15}]}
 ]}
]
"""

func makeDir() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("liftbook-smoke-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try! fixtureExercises.write(to: dir.appendingPathComponent("exercises.json"), atomically: true, encoding: .utf8)
    try! fixtureTemplates.write(to: dir.appendingPathComponent("templates.json"), atomically: true, encoding: .utf8)
    return dir
}

@MainActor
func makeStore(_ dir: URL) -> WorkoutStore {
    WorkoutStore(directory: dir.appendingPathComponent("data"),
                 builtinURL: dir.appendingPathComponent("exercises.json"),
                 templatesURL: dir.appendingPathComponent("templates.json"))
}

@MainActor
func complete(_ store: WorkoutStore, _ session: WorkoutSession, _ entryIndex: Int, reps: [Int], weight: Double? = nil) {
    let entry = store.session(session.id)!.exercises[entryIndex]
    let working = entry.workingSets
    for (i, r) in reps.enumerated() where i < working.count {
        store.updateSet(session.id, entry.id, working[i].id, weightKg: weight, reps: r)
        store.completeSet(session.id, entry.id, working[i].id)
    }
}

@MainActor
func runSmoke() {
    var clock = Date(timeIntervalSince1970: 1_800_000_000)
    let dir = makeDir()
    var store = makeStore(dir)
    store.now = { clock }

    print("动作库")
    check(store.library.all.count == 10, "夹具 10 个动作全部载入")
    check(store.library.search("卧推").map(\.id) == ["bench"], "中文搜索命中")
    check(store.library.search("press").count == 3, "英文搜索双向命中（bench/legpress/ohp）")
    check(store.library.search("", muscle: .chest).count == 3, "肌群筛选")
    let bench = store.exercise("bench")!
    let alts = store.alternatives(for: bench)
    check(alts.first?.equipment != .barbell && alts.allSatisfy { $0.primaryMuscles.contains(.chest) }, "替代动作：同肌群且不同器械优先")
    check(bench.defaultIncrementKg == 2.5 && bench.defaultRepRange == 8...12 && bench.defaultRestSeconds == 150, "复合动作默认步长/区间/休息")
    check(store.exercise("lateral")!.defaultRepRange == 10...15 && store.exercise("lateral")!.defaultRestSeconds == 90, "孤立动作默认区间 10–15，休息 90")
    check(store.exercise("legpress")!.defaultIncrementKg == 5.0, "固定器械大肌群步长 5")
    check(store.exercise("pullup")!.defaultIncrementKg == 0, "自重步长 0")
    store.setExerciseArchived("pushup", true)
    check(!store.library.selectable.contains { $0.id == "pushup" } && store.exercise("pushup") != nil, "归档后选择器隐藏但仍可查到")

    print("\n吸附与单位")
    check(Increment.round(50 * 0.95, to: 2.5, .down) == 47.5, "50×0.95 向下吸附得 47.5（浮点 epsilon）")
    check(Increment.round(50 * 0.9, to: 2.5, .down) == 45, "50×0.9 向下吸附得 45")
    check(Increment.round(52.5, to: 2.5, .up) == 52.5, "整档向上吸附不跳档")
    check(Increment.round(81, to: 5, .up) == 85, "81 向上吸附到 85")
    check(Weight.text(50, .kg) == "50 kg" && Weight.text(52.5, .kg) == "52.5 kg", "kg 文本")
    check(Weight.text(50, .lb) == "110 lb" && Weight.text(52.5, .lb) == "115.5 lb", "lb 显示换算到 0.5")
    check(store.library.search("glwt").map(\.id) == ["bench"] && Pinyin.initials("杠铃卧推") == "glwt", "拼音首字母搜索 glwt → 杠铃卧推（实际 \(Pinyin.initials("杠铃卧推"))）")
    check(approx(Weight.toKg(Weight.toDisplay(47.5, .lb), .lb), 47.5), "lb 往返换算无损")

    print("\n渐进引擎 A")
    let plan = store.createPlan(from: store.templates[0])
    check(store.activePlan?.id == plan.id && plan.days.count == 5, "模板生成 5 天计划并激活")
    let chest = plan.days[0]
    store.setCurrentWeight("bench", kg: 50)
    store.setCurrentTargetReps("bench", reps: 10)

    var s = store.startSession(day: chest)!
    check(s.exercises.count == 2 && s.exercises[0].plannedReps == 10 && approx(s.exercises[0].plannedWeightKg, 50), "开始训练：目标合成 50kg × 10")
    check(s.exercises[0].sets.count == 4 && s.exercises[0].sets.allSatisfy { $0.reps == 10 && $0.weightKg == 50 }, "每组预填目标值")
    check(store.startSession(day: chest) == nil, "D4 已有进行中会话时不能再开")
    complete(store, s, 0, reps: [10, 10, 10, 10])
    var p = store.progress(for: "bench")
    check(p.currentTargetReps == 11 && approx(p.currentWeightKg, 50) && p.consecutiveFailures == 0, "A1 全达标 → 11 次 × 50kg")
    check(store.session(s.id)!.exercises[0].progression?.kind == .increaseReps, "A1 结果种类 increaseReps")
    store.endSession(s.id)

    store.setCurrentTargetReps("bench", reps: 12)
    s = store.startSession(day: chest)!
    complete(store, s, 0, reps: [12, 12, 12, 12])
    p = store.progress(for: "bench")
    check(p.currentTargetReps == 8 && approx(p.currentWeightKg, 52.5), "A2 达上限 → 8 次 × 52.5kg")
    let outcome = store.session(s.id)!.exercises[0].progression!
    check(outcome.reason.contains("52.5 kg") && outcome.reason.contains("8 次"), "A2 reason 带人话解释")
    store.setProgressionAccepted(s.id, s.exercises[0].id, false)
    p = store.progress(for: "bench")
    check(p.currentTargetReps == 12 && approx(p.currentWeightKg, 50), "B6 拒绝建议 → 恢复 12 次 × 50kg")
    store.setProgressionAccepted(s.id, s.exercises[0].id, true)
    p = store.progress(for: "bench")
    check(p.currentTargetReps == 8 && approx(p.currentWeightKg, 52.5), "重新接受 → 8 次 × 52.5kg")
    let lastSet = store.session(s.id)!.exercises[0].workingSets.last!
    store.uncompleteSet(s.id, s.exercises[0].id, lastSet.id)
    check(store.session(s.id)!.exercises[0].progression == nil && approx(store.progress(for: "bench").currentWeightKg, 50), "取消最后一组 → 撤回渐进")
    store.updateSet(s.id, s.exercises[0].id, lastSet.id, reps: 8)
    store.completeSet(s.id, s.exercises[0].id, lastSet.id)
    p = store.progress(for: "bench")
    check(store.session(s.id)!.exercises[0].progression?.kind == .hold && p.consecutiveFailures == 1 && p.currentTargetReps == 12, "A3 12/12/12/8 → 保持，failures = 1")
    store.endSession(s.id)
    check(store.session(s.id)!.exercises.count == 1 && store.session(s.id)!.exercises[0].sets.count == 4, "结束训练：未完成的飞鸟条目被清掉，卧推 4 组保留")

    s = store.startSession(day: chest)!
    complete(store, s, 0, reps: [12, 11, 10, 9])
    p = store.progress(for: "bench")
    check(store.session(s.id)!.exercises[0].progression?.kind == .suggestDeload && approx(p.currentWeightKg, 45) && p.currentTargetReps == 8, "A4 连续两次未达标 → deload 45kg × 8")
    store.setProgressionAccepted(s.id, s.exercises[0].id, false)
    p = store.progress(for: "bench")
    check(approx(p.currentWeightKg, 50) && p.currentTargetReps == 12 && p.consecutiveFailures == 2, "拒绝 deload → 重量次数不变，失败计数保留为 2")
    store.setProgressionAccepted(s.id, s.exercises[0].id, true)
    store.endSession(s.id)

    s = store.startSession(day: chest)!
    complete(store, s, 0, reps: [8, 8, 8, 8])
    p = store.progress(for: "bench")
    check(p.consecutiveFailures == 0 && p.currentTargetReps == 9 && approx(p.currentWeightKg, 45), "A5 deload 后达标 → failures 归零，9 次")
    store.endSession(s.id)

    let back = plan.days[1]
    store.setCurrentTargetReps("pullup", reps: 12)
    s = store.startSession(day: back)!
    let pullIndex = s.exercises.firstIndex { $0.exerciseId == "pullup" }!
    check(approx(s.exercises[pullIndex].plannedWeightKg, 0), "自重动作不要求设初始重量")
    complete(store, s, pullIndex, reps: [12, 12, 12])
    let pullOutcome = store.session(s.id)!.exercises[pullIndex].progression!
    check(pullOutcome.kind == .increaseReps && pullOutcome.toReps == 13 && pullOutcome.reason.contains("负重"), "A6 自重达上限 → 继续加次数并提示负重带")
    store.endSession(s.id)

    let legs = plan.days[3]
    store.setCurrentWeight("legpress", kg: 80)
    store.setCurrentTargetReps("legpress", reps: 12)
    store.setCurrentWeight("squat", kg: 100)
    s = store.startSession(day: legs)!
    let lpIndex = s.exercises.firstIndex { $0.exerciseId == "legpress" }!
    complete(store, s, lpIndex, reps: [12, 12, 12])
    check(approx(store.progress(for: "legpress").currentWeightKg, 85), "A7 器械 80 → 85")
    let squatEntry = s.exercises[0]
    for _ in 0..<3 { store.addSet(s.id, squatEntry.id) }
    var sets = store.session(s.id)!.exercises[0].sets
    check(sets.count == 7, "加 3 组 → 7 组")
    for i in 0..<3 { store.setSetType(s.id, squatEntry.id, sets[i].id, .warmup) }
    sets = store.session(s.id)!.exercises[0].sets
    for i in 0..<3 {
        store.updateSet(s.id, squatEntry.id, sets[i].id, weightKg: 60, reps: 5)
        store.completeSet(s.id, squatEntry.id, sets[i].id)
    }
    check(store.session(s.id)!.exercises[0].progression == nil, "A8 热身组完成不触发渐进")
    complete(store, s, 0, reps: [8, 8, 8, 8])
    check(store.session(s.id)!.exercises[0].progression?.kind == .increaseReps && store.progress(for: "squat").currentTargetReps == 9, "A8 正式组全达标 → 渐进正常触发")
    let squatRecord = store.record(for: "squat")
    check(squatRecord == nil, "进行中会话不计入 PR")
    store.endSession(s.id)
    check(approx(store.record(for: "squat")?.maxWeightKg, 100) && store.record(for: "squat")?.maxReps == 8, "PR 只看正式组：最大重量 100，不被热身 60 拉低")
    check(approx(store.volumeKg(of: store.session(s.id)!), 100 * 8 * 4 + 80 * 12 * 3), "容量只算正式组")

    s = store.startSession(day: chest)!
    let flyEntry = s.exercises[1]
    check(flyEntry.plannedWeightKg == nil && store.target(for: chest.items[1])?.state == .needsInitialWeight, "A9 未设重量 → needsInitialWeight")
    complete(store, s, 1, reps: [12, 12, 12])
    check(store.session(s.id)!.exercises[1].progression == nil, "A9 未设重量不执行渐进")
    store.discardSession(s.id)
    s = store.startSession(day: chest)!
    complete(store, s, 0, reps: [10, 10])
    store.skipExercise(s.id, s.exercises[0].id)
    let skipped = store.session(s.id)!.exercises[0]
    check(skipped.isSkipped && skipped.sets.count == 2 && skipped.progression == nil, "跳过动作：移除未完成组且不触发渐进")
    store.discardSession(s.id)
    s = store.startSession(day: chest)!
    store.setInitialWeight(s.id, s.exercises[1].id, kg: 14)
    var fly = store.session(s.id)!.exercises[1]
    check(fly.sets.allSatisfy { $0.weightKg == 14 } && approx(store.progress(for: "fly").currentWeightKg, 14) && store.progress(for: "fly").currentTargetReps == 10, "设初始重量 → 预填 14kg，目标次数落到区间下限 10")
    complete(store, s, 1, reps: [10, 10, 10])
    fly = store.session(s.id)!.exercises[1]
    check(fly.progression?.kind == .increaseReps, "D3 飞鸟做完即独立渐进，不等卧推")
    check(store.session(s.id)!.exercises[0].progression == nil, "D3 卧推未完成不触发")
    check(approx(store.volumeKg(of: store.session(s.id)!), 14 * 10 * 3 * 2), "D8 哑铃容量按 ×2 计")
    check(store.exercise("fly")!.isPerHand, "D8 哑铃显示单只标识")
    store.endSession(s.id)

    print("\n退阶衰减 B")
    let day = 86_400.0
    let inc = 2.5
    let base = clock
    check(Detraining.suggestion(lastTrainedAt: base.addingTimeInterval(-10 * day), lastDecayAppliedAt: nil, currentWeightKg: 50, incrementKg: inc, now: base) == nil, "B1 10 天不衰减")
    check(approx(Detraining.suggestion(lastTrainedAt: base.addingTimeInterval(-20 * day), lastDecayAppliedAt: nil, currentWeightKg: 50, incrementKg: inc, now: base)?.weightKg, 47.5), "B2 20 天 → 47.5")
    check(approx(Detraining.suggestion(lastTrainedAt: base.addingTimeInterval(-40 * day), lastDecayAppliedAt: nil, currentWeightKg: 50, incrementKg: inc, now: base)?.weightKg, 45), "B3 40 天 → 45")
    let d90 = Detraining.suggestion(lastTrainedAt: base.addingTimeInterval(-90 * day), lastDecayAppliedAt: nil, currentWeightKg: 50, incrementKg: inc, now: base)
    check(approx(d90?.weightKg, 40) && d90?.needsRetest == true && d90!.reason.contains("探底"), "B4 90 天 → 40 并提示探底")
    check(Detraining.suggestion(lastTrainedAt: base.addingTimeInterval(-40 * day), lastDecayAppliedAt: base.addingTimeInterval(-1 * day), currentWeightKg: 50, incrementKg: inc, now: base) == nil, "B5 已衰减过不重复")
    check(Detraining.suggestion(lastTrainedAt: base.addingTimeInterval(-40 * day), lastDecayAppliedAt: nil, currentWeightKg: 0, incrementKg: 0, now: base) == nil, "自重 0kg 不衰减")

    store.setCurrentWeight("ohp", kg: 50)
    let shoulders = plan.days[2]
    s = store.startSession(day: shoulders)!
    complete(store, s, 0, reps: [8, 8, 8, 8])
    store.endSession(s.id)
    store.setCurrentWeight("ohp", kg: 50)
    clock = clock.addingTimeInterval(40 * day)
    var t = store.target(for: shoulders.items[0])!
    check(approx(t.weightKg, 45), "B3 合成目标时带衰减 45")
    if case .decaySuggested = t.state {} else { check(false, "state 应为 decaySuggested") }
    s = store.startSession(day: shoulders)!
    check(approx(s.exercises[0].plannedWeightKg, 45) && s.exercises[0].decayReason != nil && approx(store.progress(for: "ohp").currentWeightKg, 45), "开始训练默认接受衰减")
    store.keepOriginalWeight(s.id, s.exercises[0].id)
    check(approx(store.session(s.id)!.exercises[0].plannedWeightKg, 50) && approx(store.progress(for: "ohp").currentWeightKg, 50), "B6 一键保持原重量")
    complete(store, s, 0, reps: [8, 8, 8, 8])
    store.endSession(s.id)
    clock = clock.addingTimeInterval(1 * day)
    t = store.target(for: shoulders.items[0])!
    check(t.state == .normal, "B5 训练后次日不再衰减")

    print("\n分化调度 C")
    let dir2 = makeDir()
    var s2 = makeStore(dir2)
    var clock2 = Date(timeIntervalSince1970: 1_800_000_000)
    s2.now = { clock2 }
    let plan2 = s2.createPlan(from: s2.templates[0])
    for id in ["bench", "row", "ohp", "squat", "curl"] { s2.setCurrentWeight(id, kg: 40) }
    check(s2.recommendedDay()?.day.id == plan2.days[0].id, "C1 新计划推荐第 1 天")

    func train(_ store: WorkoutStore, _ d: PlanDay) {
        let ses = store.startSession(day: d)!
        complete(store, ses, 0, reps: [8, 8, 8, 8])
        store.endSession(ses.id)
        clock2 = clock2.addingTimeInterval(86_400)
    }
    train(s2, plan2.days[0])
    check(s2.recommendedDay()?.day.id == plan2.days[1].id, "C2 完成第 1 天 → 推荐第 2 天")
    for i in 1..<5 { train(s2, plan2.days[i]) }
    check(s2.recommendedDay()?.day.id == plan2.days[0].id, "C3 跑完一轮 → 回到第 1 天（等价循环队列）")
    train(s2, plan2.days[2])
    check(s2.recommendedDay()?.day.id == plan2.days[0].id, "C4 该练胸时改练肩 → 下次仍推荐第 1 天")
    for _ in 0..<4 { train(s2, plan2.days[0]) }
    check(s2.recommendedDay()?.day.id == plan2.days[1].id && s2.rankedDays().last?.day.id == plan2.days[0].id, "C5 只练胸 → 胸排最后，最久没练的排首位")
    let fresh = s2.startSession(day: plan2.days[1])!
    complete(s2, fresh, 0, reps: [8, 8, 8, 8])
    s2.endSession(fresh.id)
    clock2 = clock2.addingTimeInterval(3600)
    let ranked = s2.rankedDays()
    check(ranked.first?.day.id == plan2.days[3].id, "C6 之后推荐腿")
    let backRanked = ranked.first { $0.day.id == plan2.days[1].id }!
    check((s2.hoursSinceTrained(backRanked) ?? 99) < 48, "C6 刚练过的日新鲜度 < 48h 可用于恢复提示")
    check(s2.rankedDays().count == 5, "「换一天练」列出全部训练日")

    print("\n会话与一致性 D")
    var s3 = s2.startSession(day: plan2.days[3])!
    complete(s2, s3, 0, reps: [8, 8])
    let reloaded = makeStore(dir2)
    reloaded.now = { clock2 }
    check(reloaded.sessions.count == s2.sessions.count && reloaded.activeSession?.id == s3.id, "D1 重新加载后进行中会话完整保留")
    check(reloaded.activeSession!.exercises[0].completedWorkingSets.count == 2, "D1 已记录的 2 组保留")
    let key = { (p: [String: ExerciseProgress]) in p.mapValues { "\($0.currentWeightKg ?? -1)|\($0.currentTargetReps)|\($0.consecutiveFailures)" } }
    check(key(reloaded.progress) == key(s2.progress) && reloaded.plans.map(\.days) == s2.plans.map(\.days) && reloaded.activePlanId == s2.activePlanId, "进度与计划落盘一致")
    clock2 = clock2.addingTimeInterval(7 * 3600)
    let closed = reloaded.autoCloseStaleSessions()
    check(closed.count == 1 && reloaded.activeSession == nil && reloaded.session(s3.id)?.status == .completed, "D2 超 6h 自动收尾")
    s2 = reloaded
    s3 = s2.startSession(day: plan2.days[0])!
    let benchEntryId = s3.exercises[0].id
    let replaced = s2.replaceExercise(s3.id, benchEntryId, with: "pushup")
    check(replaced != nil && s2.session(s3.id)!.exercises[0].exerciseId == "pushup" && s2.activePlan!.days[0].items[0].exerciseId == "bench", "D6 会话内替换不改计划")
    let added = s2.addExercise(s3.id, exerciseId: "curl")
    check(added != nil && s2.session(s3.id)!.exercises.count == 3 && s2.session(s3.id)!.exercises[2].isFromPlan == false, "临时添加计划外动作")
    let custom = ExerciseDefinition(nameZh: "我的动作", primaryMuscles: [.abs], equipment: .other)
    s2.addCustomExercise(custom)
    let customEntry = s2.addExercise(s3.id, exerciseId: custom.id)!
    var renamed = custom
    renamed.nameZh = "改名了"
    s2.updateCustomExercise(renamed)
    check(s2.session(s3.id)!.exercises.first { $0.id == customEntry }!.exerciseNameSnapshot == "我的动作" && s2.exercise(custom.id)?.nameZh == "改名了", "D5 历史用快照名，不随改名变化")
    check(s2.progress(for: custom.id).currentWeightKg == nil, "自定义可加重动作初始重量为空")
    s2.addCardio(s3.id, CardioEntry(type: .treadmill, durationSeconds: 1200, distanceMeters: 3000))
    check(s2.session(s3.id)!.cardioEntries.count == 1, "会话内挂有氧")
    let before = s2.progress(for: "curl")
    complete(s2, s3, 2, reps: [10, 10, 10])
    check(s2.progress(for: "curl").currentTargetReps == before.currentTargetReps + 1, "计划外动作也独立渐进")
    s2.discardSession(s3.id)
    check(s2.session(s3.id) == nil && s2.progress(for: "curl") .currentTargetReps == before.currentTargetReps, "丢弃会话 → 删除并回滚渐进")
    let cardioCount = s2.completedSessions.count
    let recommendedBefore = s2.recommendedDay()?.day.id
    s2.logStandaloneCardio(CardioEntry(type: .bike, durationSeconds: 1800))
    check(s2.completedSessions.count == cardioCount + 1 && s2.recommendedDay()?.day.id == recommendedBefore, "单独记有氧不影响调度")
    let last = s2.lastPerformance(of: "bench", before: WorkoutSession(startedAt: clock2, planDayNameSnapshot: "", exercises: []))
    check(last != nil && last!.completedWorkingSets.count == 4, "上次成绩查询")
    check(s2.history(of: "bench").count >= 5, "动作历史曲线点数")
    s2.setIncrementOverride("bench", kg: 1.25)
    s2.resetProgress("bench")
    check(s2.progress(for: "bench").currentWeightKg == nil && s2.progress(for: "bench").incrementOverrideKg == 1.25, "重置进度清空重量，保留步长覆盖")
    let customCompound = ExerciseDefinition(nameZh: "自定义器械推", primaryMuscles: [.chest], equipment: .machine, incrementKgOverride: 1.0, restSecondsOverride: 120, repRangeMinOverride: 6, repRangeMaxOverride: 9)
    check(customCompound.defaultIncrementKg == 1.0 && customCompound.defaultRestSeconds == 120 && customCompound.defaultRepRange == 6...9, "自定义动作可覆盖步长/休息/区间")

    print("\n真实动作库")
    let libDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Sources/Resources/Library")
    if let real = try? ExerciseLibrary.loadBuiltin(from: libDir.appendingPathComponent("exercises.json")),
       let temps = try? SplitTemplate.loadAll(from: libDir.appendingPathComponent("templates.json")) {
        let ids = Set(real.map(\.id))
        check(real.count == 72, "内置 72 个动作（实际 \(real.count)）")
        check(ids.count == real.count, "id 无重复")
        check(real.allSatisfy { (3...5).contains($0.instructions.count) }, "每个动作 3–5 条要点")
        check(temps.count == 5, "5 套分化模板")
        let missing = temps.flatMap { $0.days.flatMap { $0.items.map(\.exerciseId) } }.filter { !ids.contains($0) }
        check(missing.isEmpty, "模板引用的动作全部存在\(missing.isEmpty ? "" : "：缺 \(missing)")")
        let covered = temps.allSatisfy { t in
            t.days.allSatisfy { d in
                d.items.allSatisfy { item in
                    let prim = real.first { $0.id == item.exerciseId }?.primaryMuscles ?? []
                    return !Set(prim).isDisjoint(with: d.targetMuscles)
                }
            }
        }
        check(covered, "训练日目标肌群覆盖其动作")
        for m in MuscleGroup.allCases {
            let equipments = Set(real.filter { $0.primaryMuscles.contains(m) }.map(\.equipment))
            let need = m.isLarge ? 3 : 2
            check(equipments.count >= need, "\(m.label) 至少 \(need) 类器械（\(equipments.count)）")
        }
    } else {
        print("  （未找到 \(libDir.path)，跳过）")
    }

    try? FileManager.default.removeItem(at: dir)
    try? FileManager.default.removeItem(at: dir2)
    _ = store
    store = makeStore(dir)
}

MainActor.assumeIsolated { runSmoke() }
print(failures == 0 ? "\n全部通过" : "\n失败 \(failures) 项")
exit(failures == 0 ? 0 : 1)
