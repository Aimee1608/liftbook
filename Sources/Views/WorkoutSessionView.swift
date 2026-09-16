import SwiftUI

struct NumberEdit: Identifiable {
    enum Field { case weight, reps, initialWeight }
    let id = UUID()
    var entryId: UUID
    var setId: UUID?
    var field: Field
}

struct NoteTarget: Identifiable {
    enum Kind { case session, exercise(UUID), set(UUID, UUID) }
    let id = UUID()
    var kind: Kind
    var title: String
    var initial: String
}

struct WorkoutSessionView: View {
    let sessionId: UUID
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var coordinator: SessionCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var timer = RestTimer()
    @State private var now = Date()
    @State private var expandedId: UUID?
    @State private var showExit = false
    @State private var confirmDiscard = false
    @State private var confirmEnd = false
    @State private var picking = false
    @State private var replacing: SessionExercise?
    @State private var numberEdit: NumberEdit?
    @State private var noteTarget: NoteTarget?
    @State private var addingCardio = false
    @State private var prSetIds: Set<UUID> = []
    @State private var deletingSet: (UUID, UUID)?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var session: WorkoutSession? { store.session(sessionId) }

    var body: some View {
        if let session {
            VStack(spacing: 0) {
                header(session)
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(session.exercises) { ex in
                            exerciseCard(ex, session: session)
                        }
                        Button { picking = true } label: {
                            Label("添加动作", systemImage: "plus").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.accent).frame(maxWidth: .infinity).frame(height: 44)
                        }
                        .accessibilityIdentifier("session-add-exercise")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .readable()
                }
                bottomBar(session)
            }
            .screenBackground()
            .onAppear {
                expandedId = session.exercises.first { !$0.isSkipped && !$0.allWorkingCompleted }?.id ?? session.exercises.first?.id
                UIApplication.shared.isIdleTimerDisabled = settings.keepScreenAwake
            }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: scenePhase) { phase in
                UIApplication.shared.isIdleTimerDisabled = phase == .active && settings.keepScreenAwake
            }
            .onReceive(ticker) { t in
                now = t
                timer.tick(now: t, haptics: settings.restTimerHapticsEnabled, sound: settings.restTimerSoundEnabled)
                timer.clearFinished(now: t)
            }
            .confirmationDialog("退出训练", isPresented: $showExit, titleVisibility: .hidden) {
                Button("保留进度，稍后继续") { leave() }
                Button("结束并保存") { finish() }
                Button("丢弃这次训练", role: .destructive) { confirmDiscard = true }
                Button("取消", role: .cancel) {}
            }
            .alert("丢弃这次训练？", isPresented: $confirmDiscard) {
                Button("丢弃", role: .destructive) { store.discardSession(sessionId); timer.skip(); coordinator.close() }
                Button("取消", role: .cancel) {}
            } message: { Text("已记录的 \(session.completedWorkingSetCount) 组数据将被删除，无法恢复。") }
            .alert("结束训练？", isPresented: $confirmEnd) {
                Button("结束") { finish() }
                Button("继续训练", role: .cancel) {}
            } message: { Text("还有 \(uncompletedCount(session)) 组没有完成，未完成的组不会被保存。") }
            .alert("删除这一组？", isPresented: Binding(get: { deletingSet != nil }, set: { if !$0 { deletingSet = nil } })) {
                Button("删除", role: .destructive) { if let d = deletingSet { store.removeSet(sessionId, d.0, d.1) } }
                Button("取消", role: .cancel) {}
            } message: { Text("这一组已经完成，删除后它的记录会丢失。") }
            .sheet(isPresented: $picking) {
                ExercisePickerSheet { picked in
                    var first: UUID?
                    for ex in picked { let id = store.addExercise(sessionId, exerciseId: ex.id); first = first ?? id }
                    if let first { expandedId = first }
                }
            }
            .sheet(item: $replacing) { entry in AlternativesSheet(sessionId: sessionId, entry: entry) { newId in expandedId = newId } }
            .sheet(item: $numberEdit) { edit in numberPad(edit, session: session) }
            .sheet(item: $noteTarget) { target in NoteSheet(title: target.title, initial: target.initial) { save(note: $0, target) } }
            .sheet(isPresented: $addingCardio) { CardioFormSheet(sessionId: sessionId) }
        } else {
            Color.clear.onAppear { coordinator.close() }
        }
    }

    // MARK: - 顶部与底部

    private func header(_ s: WorkoutSession) -> some View {
        HStack {
            Button { showExit = true } label: { Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44) }
                .accessibilityIdentifier("session-exit")
            Spacer()
            Text(s.planDayNameSnapshot).font(.system(size: 17, weight: .semibold))
            Spacer()
            Text(Format.duration(now.timeIntervalSince(s.startedAt))).font(.num(15)).foregroundStyle(Theme.secondary)
            Menu {
                if settings.notesEnabled { Button("本次训练备注", systemImage: "note.text") { noteTarget = NoteTarget(kind: .session, title: "本次训练备注", initial: s.note ?? "") } }
                Button("添加有氧", systemImage: "figure.run") { addingCardio = true }
            } label: { Image(systemName: "ellipsis").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44) }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private func bottomBar(_ s: WorkoutSession) -> some View {
        VStack(spacing: 10) {
            if timer.isRunning || timer.finishedAt != nil {
                HStack(spacing: 10) {
                    Image(systemName: "timer").foregroundStyle(Theme.accent)
                    if timer.isRunning {
                        Text(Format.clock(timer.remaining(at: now))).font(.num(24, .bold)).foregroundStyle(Theme.accent).fixedSize()
                        Spacer(minLength: 4)
                        Button("−30s") { timer.adjust(by: -Limits.timerAdjustStep) }.buttonStyle(GrayButtonStyle(height: 40)).frame(width: 60)
                        Button("+30s") { timer.adjust(by: Limits.timerAdjustStep) }.buttonStyle(GrayButtonStyle(height: 40)).frame(width: 60)
                        Button("跳过") { timer.skip() }.buttonStyle(GrayButtonStyle(height: 40)).frame(width: 56)
                    } else {
                        Text("休息结束").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.accent).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .frame(height: 56)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("rest-timer")
            }
            Button("结束训练") {
                if uncompletedCount(s) > 0 { confirmEnd = true } else { finish() }
            }
            .buttonStyle(GrayButtonStyle())
            .accessibilityIdentifier("end-workout")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .readable()
        .background(Theme.bg)
    }

    private func uncompletedCount(_ s: WorkoutSession) -> Int {
        s.exercises.filter { !$0.isSkipped }.reduce(0) { $0 + $1.sets.filter { !$0.isCompleted }.count }
    }

    private func finish() {
        timer.skip()
        store.endSession(sessionId)
        coordinator.finish(sessionId)
    }

    private func leave() {
        timer.skip()
        coordinator.close()
    }

    // MARK: - 动作卡片

    @ViewBuilder
    private func exerciseCard(_ ex: SessionExercise, session: WorkoutSession) -> some View {
        let expanded = expandedId == ex.id && !ex.isSkipped
        let def = store.exercise(ex.exerciseId)
        VStack(spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expandedId = expanded ? nil : ex.id }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary).frame(width: 18)
                    Text(ex.exerciseNameSnapshot).font(.system(size: expanded ? 20 : 16, weight: expanded ? .bold : .medium)).lineLimit(1)
                    if !ex.isFromPlan { Chip(text: "临时") }
                    if ex.isSkipped { Chip(text: "已跳过") }
                    if let p = ex.progression { progressionBadge(p) }
                    Spacer()
                    Text("\(ex.completedWorkingSets.count)/\(ex.workingSets.count) 组").font(.num(13, .medium)).foregroundStyle(Theme.secondary)
                    exerciseMenu(ex, session: session)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(ex.isSkipped)
            .padding(.horizontal, 8)
            .accessibilityIdentifier("exercise-\(ex.exerciseId)")

            if expanded {
                if ex.plannedWeightKg == nil {
                    banner("第一次做这个动作，先选一个能轻松完成 8–10 次的重量", symbol: "lightbulb", color: Theme.accent, action: nil)
                }
                if let reason = ex.decayReason, let original = ex.decayFromWeightKg {
                    banner(reason, symbol: "arrow.down", color: Theme.warning,
                           action: ("改回 \(Format.weight(original, settings.unit))", { store.keepOriginalWeight(sessionId, ex.id) }))
                }
                let last = store.lastSetsByIndex(of: ex.exerciseId, before: session)
                var workingIndex = 0
                ForEach(ex.sets) { set in
                    let idx: Int? = set.type == .working ? { workingIndex += 1; return workingIndex }() : nil
                    setRow(set, index: idx, entry: ex, def: def, last: idx.flatMap { last.indices.contains($0 - 1) ? last[$0 - 1] : nil }, hasHistory: !last.isEmpty)
                }
                Button { store.addSet(sessionId, ex.id) } label: {
                    Label("加一组", systemImage: "plus").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.accent).frame(height: 44).padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("add-set")
            }
        }
        .padding(8)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: expanded ? Theme.cardRadius : 16, style: .continuous))
        .opacity(ex.isSkipped ? 0.5 : 1)
    }

    private func exerciseMenu(_ ex: SessionExercise, session: WorkoutSession) -> some View {
        Menu {
            if !ex.isSkipped { Button("跳过这个动作", systemImage: "forward") { store.skipExercise(sessionId, ex.id) } }
            Button("换一个动作", systemImage: "arrow.triangle.2.circlepath") { replacing = ex }
            if settings.notesEnabled { Button("添加备注", systemImage: "note.text") { noteTarget = NoteTarget(kind: .exercise(ex.id), title: ex.exerciseNameSnapshot, initial: ex.note ?? "") } }
            Button("上移", systemImage: "arrow.up") { store.moveExercise(sessionId, ex.id, by: -1) }.disabled(session.exercises.first?.id == ex.id)
            Button("下移", systemImage: "arrow.down") { store.moveExercise(sessionId, ex.id, by: 1) }.disabled(session.exercises.last?.id == ex.id)
            if !ex.isFromPlan { Button("移除", systemImage: "trash", role: .destructive) { store.removeExercise(sessionId, ex.id) } }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.secondary).frame(width: 36, height: 44)
        }
    }

    private func banner(_ text: String, symbol: String, color: Color, action: (String, () -> Void)?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).font(.system(size: 13)).foregroundStyle(Color(hex: 0xD1D1D6)).frame(maxWidth: .infinity, alignment: .leading)
            if let action { Button(action.0, action: action.1).buttonStyle(ChipButtonStyle(accentText: true)) }
        }
        .padding(10)
        .background(Theme.elevated.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private func progressionBadge(_ p: ProgressionOutcome) -> some View {
        let (text, color): (String, Color) = {
            switch p.kind {
            case .increaseWeight: return ("↑ \(Format.weight(p.toWeightKg, settings.unit))", Theme.accent)
            case .increaseReps: return ("↑ \(p.toReps)次", Theme.accent)
            case .hold: return ("→ 保持", Theme.secondary)
            case .suggestDeload: return ("↓ \(Format.weight(p.toWeightKg, settings.unit))", Theme.warning)
            }
        }()
        return Text(text).font(.num(12, .semibold)).foregroundStyle(color).padding(.horizontal, 6).frame(height: 22).background(color.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - 组行

    private func setRow(_ set: SetRecord, index: Int?, entry: SessionExercise, def: ExerciseDefinition?, last: SetRecord?, hasHistory: Bool) -> some View {
        let isWarm = set.type == .warmup
        let isCurrent = !set.isCompleted && entry.sets.first { !$0.isCompleted }?.id == set.id
        let needsWeight = entry.plannedWeightKg == nil
        let dim = set.isCompleted ? 0.6 : (isWarm ? 0.75 : 1)
        return HStack(spacing: 6) {
            Text(isWarm ? "W" : "\(index ?? 0)")
                .font(.num(15)).foregroundStyle(isWarm ? Theme.secondary : (isCurrent ? Theme.accent : .white)).frame(width: 28)
            Button {
                numberEdit = NumberEdit(entryId: entry.id, setId: set.id, field: needsWeight ? .initialWeight : .weight)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    if needsWeight {
                        Text("设定重量").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
                    } else {
                        Text(Format.weight(set.weightKg, settings.unit, withUnit: false)).font(.num(20))
                        Text(settings.unit.label).font(.system(size: 12)).foregroundStyle(Theme.secondary)
                        if def?.isPerHand == true { Text("×2").font(.system(size: 11)).foregroundStyle(Theme.tertiary) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).frame(height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("set-weight-\(index ?? 0)")
            Button { numberEdit = NumberEdit(entryId: entry.id, setId: set.id, field: .reps) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("×").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                    Text("\(set.reps)").font(.num(20))
                }
                .frame(width: 56, alignment: .leading).frame(height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("set-reps-\(index ?? 0)")
            Group {
                if isWarm {
                    Text("热身").font(.system(size: 12)).foregroundStyle(Theme.tertiary)
                } else if prSetIds.contains(set.id) {
                    Chip(text: "PR", on: true)
                } else if let last {
                    Text("上次 \(Format.weight(last.weightKg, settings.unit, withUnit: false))×\(last.reps)").font(.num(12, .medium)).foregroundStyle(Theme.secondary)
                } else if !hasHistory {
                    Text("首次").font(.system(size: 12)).foregroundStyle(Theme.tertiary)
                }
                if set.isFailure { Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(Theme.warning) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Button { toggleComplete(set, entry: entry) } label: {
                ZStack {
                    Circle().fill(set.isCompleted ? Theme.accent : .clear).frame(width: 30, height: 30)
                    Circle().stroke(set.isCompleted ? .clear : (isCurrent ? Theme.accent : Theme.control), lineWidth: 2).frame(width: 30, height: 30)
                    if set.isCompleted { Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.onAccent) }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(needsWeight && !set.isCompleted)
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                guard settings.notesEnabled, !set.isCompleted, !needsWeight else { return }
                toggleComplete(set, entry: entry)
                store.toggleFailure(sessionId, entry.id, set.id)
            })
            .accessibilityIdentifier("set-done-\(isWarm ? "w" : String(index ?? 0))")
        }
        .padding(.leading, 8)
        .frame(height: Theme.rowHeight)
        .background(isCurrent ? Theme.elevated : .clear)
        .overlay(alignment: .leading) {
            if isCurrent { RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 3).padding(.vertical, 10) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(dim)
        .contextMenu {
            Button(isWarm ? "设为正式组" : "设为热身组", systemImage: isWarm ? "flame" : "figure.walk") { store.setSetType(sessionId, entry.id, set.id, isWarm ? .working : .warmup) }
            if settings.notesEnabled {
                Button(set.isFailure ? "取消力竭标记" : "标记力竭", systemImage: "flame.fill") { store.toggleFailure(sessionId, entry.id, set.id) }
                Button("组备注", systemImage: "note.text") { noteTarget = NoteTarget(kind: .set(entry.id, set.id), title: "第 \(index ?? 0) 组备注", initial: set.note ?? "") }
            }
            if entry.sets.count > 1 {
                Button("删除这组", systemImage: "trash", role: .destructive) {
                    if set.isCompleted { deletingSet = (entry.id, set.id) } else { store.removeSet(sessionId, entry.id, set.id) }
                }
            }
        }
    }

    private func toggleComplete(_ set: SetRecord, entry: SessionExercise) {
        if set.isCompleted {
            store.uncompleteSet(sessionId, entry.id, set.id)
            prSetIds.remove(set.id)
            return
        }
        let before = store.record(for: entry.exerciseId)
        store.completeSet(sessionId, entry.id, set.id)
        Haptics.light()
        if set.type == .working, let before, !before.beaten(by: PersonalRecord.compute([SetRecord(type: .working, weightKg: set.weightKg, reps: set.reps, isCompleted: true)]) ?? before).isEmpty {
            prSetIds.insert(set.id)
            Haptics.success()
        }
        if settings.restTimerEnabled, set.type == .working || entry.sets.last?.id != set.id {
            NotificationManager.requestIfNeeded()
            timer.start(seconds: entry.restSeconds)
        }
        if let updated = store.session(sessionId)?.exercises.first(where: { $0.id == entry.id }), updated.allWorkingCompleted, updated.sets.allSatisfy(\.isCompleted) {
            let next = store.session(sessionId)?.exercises.first { !$0.isSkipped && !$0.allWorkingCompleted && $0.id != entry.id }
            withAnimation(.easeInOut(duration: 0.25)) { expandedId = next?.id }
        }
    }

    // MARK: - 数字输入

    @ViewBuilder
    private func numberPad(_ edit: NumberEdit, session: WorkoutSession) -> some View {
        if let entry = session.exercises.first(where: { $0.id == edit.entryId }) {
            let def = store.exercise(entry.exerciseId)
            let set = entry.sets.first { $0.id == edit.setId }
            let unit = settings.unit
            let last = store.lastSetsByIndex(of: entry.exerciseId, before: session)
            switch edit.field {
            case .reps:
                NumberPadSheet(title: "次数", unitLabel: "次", initial: Double(set?.reps ?? entry.plannedReps), step: 1,
                               range: Double(Limits.reps.lowerBound)...Double(Limits.reps.upperBound), allowsDecimal: false,
                               quick: [("目标 \(entry.plannedReps)", Double(entry.plannedReps)), ("−1", Double(max(1, (set?.reps ?? 1) - 1))), ("−2", Double(max(1, (set?.reps ?? 2) - 2)))]
                                + (last.first.map { [("上次 \($0.reps)", Double($0.reps))] } ?? [])) { v in
                    if let sid = edit.setId { store.updateSet(sessionId, entry.id, sid, reps: Int(v)) }
                }
            case .weight, .initialWeight:
                let step = Weight.toDisplay(store.effectiveIncrement(entry.exerciseId), unit)
                let initial = Weight.toDisplay(set?.weightKg ?? entry.plannedWeightKg ?? 0, unit)
                var quick: [(label: String, value: Double)] = []
                let _ = {
                    if let p = entry.plannedWeightKg { quick.append(("目标 \(Format.weight(p, unit, withUnit: false))", Weight.toDisplay(p, unit))) }
                    if let l = last.first { quick.append(("上次 \(Format.weight(l.weightKg, unit, withUnit: false))", Weight.toDisplay(l.weightKg, unit))) }
                }()
                NumberPadSheet(title: edit.field == .initialWeight ? "起始重量" : "重量", unitLabel: unit.label + (def?.isPerHand == true ? " · 单只" : ""),
                               initial: initial, step: max(step, unit == .kg ? 0.25 : 0.5),
                               range: 0...Weight.toDisplay(Limits.weightKg.upperBound, unit), allowsDecimal: true, quick: quick) { v in
                    let kg = Weight.toKg(v, unit)
                    if edit.field == .initialWeight {
                        store.setInitialWeight(sessionId, entry.id, kg: kg)
                    } else if let sid = edit.setId {
                        store.updateSet(sessionId, entry.id, sid, weightKg: kg)
                    }
                }
            }
        }
    }

    private func save(note: String, _ target: NoteTarget) {
        let n = String(note.prefix(Limits.noteLength.upperBound))
        switch target.kind {
        case .session: store.setSessionNote(sessionId, n)
        case let .exercise(e): store.setExerciseNote(sessionId, e, n)
        case let .set(e, s): store.setSetNote(sessionId, e, s, n)
        }
    }
}

struct NoteSheet: View {
    var title: String
    var initial: String
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(16)
                .screenBackground()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") { onSave(text); dismiss() } }
                }
        }
        .presentationDetents([.medium])
        .onAppear { text = initial }
    }
}

struct AlternativesSheet: View {
    let sessionId: UUID
    let entry: SessionExercise
    var onReplaced: (UUID) -> Void
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false

    var body: some View {
        NavigationStack {
            List {
                if let def = store.exercise(entry.exerciseId) {
                    Section {
                        ForEach(store.alternatives(for: def, limit: 8)) { alt in
                            Button { replace(with: alt.id) } label: {
                                ExerciseRow(exercise: alt, trailing: store.progress(for: alt.id).currentWeightKg.map { Format.weight($0, settings.unit) } ?? "")
                            }
                            .foregroundStyle(.white)
                            .listRowBackground(Theme.card)
                        }
                    } header: { Text("与「\(def.nameZh)」练相同部位的动作") }
                }
                Section {
                    Button { picking = true } label: { Label("从动作库选择", systemImage: "list.bullet").foregroundStyle(Theme.accent) }.listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("换一个动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .sheet(isPresented: $picking) {
                ExercisePickerSheet { picked in if let first = picked.first { replace(with: first.id) } }
            }
        }
    }

    private func replace(with id: String) {
        if let newId = store.replaceExercise(sessionId, entry.id, with: id) { onReplaced(newId) }
        dismiss()
    }
}
