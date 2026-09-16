import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var settings: AppSettings
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var deleting: WorkoutSession?
    @State private var backfilling = false

    private var calendar: Calendar { Calendar.current }

    private var monthSessions: [WorkoutSession] {
        store.completedSessions.filter { calendar.isDate($0.startedAt, equalTo: month, toGranularity: .month) }
    }

    var body: some View {
        Group {
            if store.completedSessions.isEmpty {
                EmptyState(symbol: "calendar.badge.clock", title: "还没有训练记录", message: "完成第一次训练后，这里会显示你的训练历史")
            } else {
                ScrollViewReader { proxy in
                    List {
                        Section { calendarCard(proxy) .listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                        Section {
                            ForEach(monthSessions) { s in
                                NavigationLink { SessionDetailView(sessionId: s.id) } label: { row(s) }
                                    .listRowBackground(Theme.card)
                                    .id(s.id)
                                    .swipeActions { Button(role: .destructive) { deleting = s } label: { Label("删除", systemImage: "trash") } }
                            }
                        } header: {
                            Text("\(Format.month(month)) · \(monthSessions.count) 次训练")
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .screenBackground()
        .navigationTitle("历史")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { backfilling = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $backfilling) { BackfillSheet() }
        .alert("删除这次训练记录？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("删除", role: .destructive) { if let d = deleting { store.deleteSession(d.id) } }
            Button("取消", role: .cancel) {}
        } message: { Text("删除后不影响已经生效的重量进度。") }
    }

    private func row(_ s: WorkoutSession) -> some View {
        HStack(spacing: 14) {
            Text(Format.relativeDay(s.startedAt)).font(.num(13, .medium)).foregroundStyle(Theme.secondary).frame(width: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.planDayNameSnapshot).font(.system(size: 16, weight: .medium))
                if s.exercises.isEmpty, let c = s.cardioEntries.first {
                    Text("\(c.type.label) \(Format.minutes(TimeInterval(c.durationSeconds)))" + (c.distanceMeters.map { " · \(Format.distance($0))" } ?? "")).font(.num(13, .medium)).foregroundStyle(Theme.secondary)
                } else {
                    Text("\(s.completedWorkingSetCount)组 · \(store.totalReps(of: s))次 · \(Format.minutes(s.duration))").font(.num(13, .medium)).foregroundStyle(Theme.secondary)
                }
            }
            Spacer()
            if !store.newRecords(in: s).isEmpty { Chip(text: "PR", on: true) }
        }
        .frame(minHeight: 52)
    }

    private func calendarCard(_ proxy: ScrollViewProxy) -> some View {
        let days = monthGrid()
        let counts = Dictionary(grouping: monthSessions) { calendar.component(.day, from: $0.startedAt) }.mapValues(\.count)
        return VStack(spacing: 8) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 32, height: 32) }
                Text(Format.month(month)).font(.system(size: 17, weight: .semibold))
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 32, height: 32) }
                Spacer()
                Button("今天") { month = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))! }.font(.system(size: 15))
            }
            .foregroundStyle(.white)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { Text($0).font(.system(size: 11)).foregroundStyle(Theme.tertiary) }
                ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                    if let d {
                        let today = calendar.isDateInToday(d)
                        let n = counts[calendar.component(.day, from: d)] ?? 0
                        Button {
                            if let s = monthSessions.first(where: { calendar.isDate($0.startedAt, inSameDayAs: d) }) { withAnimation { proxy.scrollTo(s.id, anchor: .top) } }
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(calendar.component(.day, from: d))").font(.num(15, .medium)).foregroundStyle(today ? Theme.onAccent : .white)
                                    .frame(width: 32, height: 32).background(today ? Theme.accent : .clear).clipShape(Circle())
                                Circle().fill(n > 0 ? Theme.accent : .clear).frame(width: n > 1 ? 6 : 4, height: n > 1 ? 6 : 4)
                            }
                            .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .card(12)
        .padding(.horizontal, 16)
    }

    private func monthGrid() -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: month)!
        let firstWeekday = (calendar.component(.weekday, from: month) + 5) % 7
        return Array(repeating: nil, count: firstWeekday) + range.map { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    private func shift(_ delta: Int) {
        month = calendar.date(byAdding: .month, value: delta, to: month)!
    }
}

struct SessionDetailView: View {
    let sessionId: UUID
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var settings: AppSettings
    @State private var editing = false
    @State private var draft: WorkoutSession?
    @State private var saved = false

    private var session: WorkoutSession? { store.session(sessionId) }

    var body: some View {
        if let s = editing ? draft : session {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.planDayNameSnapshot).font(.system(size: 22, weight: .bold))
                        Text("\(Format.relativeDay(s.startedAt)) \(Format.time(s.startedAt)) · \(Format.minutes(s.duration))").font(.system(size: 13)).foregroundStyle(Theme.secondary)
                        Text("\(s.completedWorkingSetCount) 组 · \(store.totalReps(of: s)) 次").font(.num(13, .medium)).foregroundStyle(Theme.secondary)
                        if let note = s.note, !note.isEmpty { Text(note).font(.system(size: 14)).padding(.top, 4) }
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(Array(s.exercises.enumerated()), id: \.element.id) { ei, ex in
                    Section(ex.exerciseNameSnapshot + (ex.isSkipped ? " · 已跳过" : "")) {
                        ForEach(Array(ex.sets.enumerated()), id: \.element.id) { si, set in
                            HStack(spacing: 10) {
                                Text(set.type == .warmup ? "W" : "\(ex.sets[...si].filter { $0.type == .working }.count)").font(.num(14)).foregroundStyle(Theme.secondary).frame(width: 24)
                                if editing {
                                    TextField("kg", value: Binding(get: { Weight.toDisplay(draft!.exercises[ei].sets[si].weightKg, settings.unit) }, set: { draft!.exercises[ei].sets[si].weightKg = Weight.toKg($0, settings.unit) }), format: .number)
                                        .keyboardType(.decimalPad).frame(width: 70).multilineTextAlignment(.trailing)
                                    Text(settings.unit.label).foregroundStyle(Theme.secondary)
                                    TextField("次", value: Binding(get: { draft!.exercises[ei].sets[si].reps }, set: { draft!.exercises[ei].sets[si].reps = $0 }), format: .number)
                                        .keyboardType(.numberPad).frame(width: 50).multilineTextAlignment(.trailing)
                                    Text("次").foregroundStyle(Theme.secondary)
                                } else {
                                    Text(Format.weight(set.weightKg, settings.unit)).font(.num(16))
                                    Text("× \(set.reps)").font(.num(16)).foregroundStyle(Color(hex: 0xD1D1D6))
                                }
                                if set.type == .warmup { Text("热身").font(.system(size: 12)).foregroundStyle(Theme.tertiary) }
                                if set.isFailure { Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(Theme.warning) }
                                Spacer()
                                if let n = set.note, !n.isEmpty { Text(n).font(.system(size: 12)).foregroundStyle(Theme.secondary).lineLimit(1) }
                            }
                            .frame(minHeight: 40)
                            .listRowBackground(Theme.card)
                        }
                        .onDelete { offsets in if editing { draft!.exercises[ei].sets.remove(atOffsets: offsets) } }
                        if editing {
                            Button { let last = draft!.exercises[ei].sets.last; draft!.exercises[ei].sets.append(SetRecord(weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 8, isCompleted: true, completedAt: s.startedAt)) } label: { Label("加一组", systemImage: "plus").foregroundStyle(Theme.accent) }
                                .listRowBackground(Theme.card)
                        }
                    }
                }
                if !s.cardioEntries.isEmpty {
                    Section("有氧") {
                        ForEach(s.cardioEntries) { c in
                            HStack { Text(c.type.label); Spacer(); Text(Format.minutes(TimeInterval(c.durationSeconds)) + (c.distanceMeters.map { " · \(Format.distance($0))" } ?? "")).foregroundStyle(Theme.secondary) }.listRowBackground(Theme.card)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("训练详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if editing {
                        Button("保存") {
                            if var d = draft {
                                for i in d.exercises.indices { d.exercises[i].sets.removeAll { $0.reps <= 0 } }
                                store.updateSession(d)
                            }
                            editing = false
                            saved = true
                        }
                    } else {
                        Button("编辑") { draft = session; editing = true }
                    }
                }
                if editing { ToolbarItem(placement: .topBarLeading) { Button("取消") { editing = false } } }
            }
            .alert("记录已更新", isPresented: $saved) { Button("好", role: .cancel) {} } message: { Text("如需同时调整当前训练重量，请到动作详情中修改。") }
        }
    }
}

struct BackfillSheet: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var dayId: UUID?
    @State private var name = "自由训练"

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                Picker("训练日", selection: $dayId) {
                    Text("空白").tag(UUID?.none)
                    ForEach(store.activePlan?.days ?? []) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                if dayId == nil { TextField("名称", text: $name) }
                Text("补录的训练只进入历史与纪录，不会改变当前重量进度。").font(.system(size: 13)).foregroundStyle(Theme.secondary)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("补录训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        let day = store.activePlan?.days.first { $0.id == dayId }
                        let exercises = (day?.items ?? []).compactMap { item -> SessionExercise? in
                            guard let def = store.exercise(item.exerciseId) else { return nil }
                            let w = store.progress(for: item.exerciseId).currentWeightKg ?? 0
                            return SessionExercise(exerciseId: def.id, exerciseNameSnapshot: def.nameZh, plannedSets: item.targetSets, plannedRepMin: item.repRangeMin, plannedRepMax: item.repRangeMax,
                                                   plannedReps: item.repRangeMin, plannedWeightKg: w, restSeconds: def.defaultRestSeconds, isFromPlan: true,
                                                   sets: (0..<item.targetSets).map { _ in SetRecord(weightKg: w, reps: item.repRangeMin, isCompleted: true, completedAt: date) })
                        }
                        store.backfillSession(startedAt: date, name: day?.name ?? name, exercises: exercises)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct CardioFormSheet: View {
    var sessionId: UUID?
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var type: CardioType = .treadmill
    @State private var minutes = 30
    @State private var distanceKm = ""
    @State private var note = ""

    private var types: [CardioType] {
        let f = store.cardioTypeFrequency()
        return f.values.reduce(0, +) >= 2 ? CardioType.allCases.sorted { (f[$0] ?? 0) > (f[$1] ?? 0) } : CardioType.allCases
    }

    private var meters: Double? { Double(distanceKm).map { $0 * 1000 } }

    var body: some View {
        NavigationStack {
            Form {
                Picker("类型", selection: $type) { ForEach(types, id: \.self) { Text($0.label).tag($0) } }
                StepperRow(label: "时长", value: $minutes, range: 1...600) { "\($0) 分钟" }
                HStack { Text("距离"); Spacer(); TextField("可选", text: $distanceKm).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90); Text("km").foregroundStyle(Theme.secondary) }
                if [.treadmill, .outdoorRun].contains(type), let m = meters, let pace = Format.pace(seconds: minutes * 60, meters: m) {
                    Text("配速 \(pace)").font(.system(size: 13)).foregroundStyle(Theme.secondary)
                }
                TextField("备注", text: $note, axis: .vertical)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("记一次有氧")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let entry = CardioEntry(type: type, durationSeconds: minutes * 60, distanceMeters: meters.map { min($0, Limits.cardioDistanceMeters.upperBound) },
                                                note: note.isEmpty ? nil : String(note.prefix(Limits.noteLength.upperBound)))
                        if let sessionId { store.addCardio(sessionId, entry) } else { store.logStandaloneCardio(entry) }
                        dismiss()
                    }
                    .disabled(meters.map { $0 < 0 } ?? false)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
