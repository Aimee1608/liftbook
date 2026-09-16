import SwiftUI
import Charts

struct ExerciseDetailView: View {
    let exerciseId: String
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var metric = 0
    @State private var range = 1
    @State private var adjusting = false
    @State private var editing = false
    @State private var confirmArchive = false

    private var exercise: ExerciseDefinition? { store.exercise(exerciseId) }

    var body: some View {
        if let ex = exercise {
            let p = store.progress(for: exerciseId)
            let history = store.history(of: exerciseId)
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "dumbbell").font(.system(size: 22)).foregroundStyle(Theme.secondary)
                            .frame(width: 56, height: 56).background(Theme.elevated).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 6) {
                            WrapLayout(spacing: 6) {
                                ForEach(ex.primaryMuscles, id: \.self) { Chip(text: $0.label, on: true) }
                                if !ex.secondaryMuscles.isEmpty { Chip(text: ex.secondaryMuscles.map(\.label).joined(separator: " · ")) }
                                Chip(text: ex.equipment.label)
                                Chip(text: ex.laterality.label)
                            }
                            if let en = ex.nameEn { Text(en).font(.system(size: 12)).foregroundStyle(Theme.tertiary) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    progressCard(ex, p)
                    if history.count >= 2 { chartCard(history) } else {
                        Text("再训练几次就能看到进步曲线了").font(.system(size: 14)).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity).card()
                    }
                    if let r = store.record(for: exerciseId) { recordsCard(r) }
                    if !ex.instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("动作要点").font(.system(size: 15, weight: .semibold))
                            ForEach(Array(ex.instructions.enumerated()), id: \.offset) { i, line in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(i + 1)").font(.num(13)).foregroundStyle(Theme.accent).frame(width: 16)
                                    Text(line).font(.system(size: 14)).foregroundStyle(Color(hex: 0xD1D1D6))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).card()
                    } else if !ex.isBuiltin {
                        Text("自定义动作暂无演示图与要点").font(.system(size: 13)).foregroundStyle(Theme.tertiary)
                    }
                }
                .padding(16)
                .readable()
            }
            .screenBackground()
            .navigationTitle(ex.nameZh)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if !ex.isBuiltin { Button("编辑动作", systemImage: "pencil") { editing = true } }
                        Button(ex.isArchived ? "恢复到选择列表" : "删除动作", systemImage: ex.isArchived ? "arrow.uturn.backward" : "trash", role: ex.isArchived ? nil : .destructive) {
                            if ex.isArchived { store.setExerciseArchived(exerciseId, false) } else { confirmArchive = true }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $adjusting) { ProgressEditorSheet(exerciseId: exerciseId) }
            .sheet(isPresented: $editing) { CustomExerciseEditor(editing: ex) }
            .alert("删除「\(ex.nameZh)」？", isPresented: $confirmArchive) {
                Button("删除", role: .destructive) {
                    store.setExerciseArchived(exerciseId, true)
                    store.removeExerciseFromPlans(exerciseId)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                let refs = store.plansReferencing(exerciseId)
                Text("已有的训练记录会保留，这个动作将不再出现在选择列表中。" + (refs.isEmpty ? "" : "该动作正在「\(refs.map(\.name).joined(separator: "」「"))」计划中使用，删除后会从计划中移除。"))
            }
        }
    }

    private func progressCard(_ ex: ExerciseDefinition, _ p: ExerciseProgress) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("当前进度").font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("调整") { adjusting = true }.font(.system(size: 15)).accessibilityIdentifier("adjust-progress")
            }
            .frame(height: 44)
            Divider().overlay(Theme.separator)
            if p.currentWeightKg == nil {
                VStack(spacing: 4) {
                    Text("还没有训练记录").font(.system(size: 15))
                    Text("第一次训练时设定起始重量").font(.system(size: 13)).foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity).frame(height: 88)
            } else {
                kv("当前重量", ex.equipment.isLoadable ? Format.weight(p.currentWeightKg ?? 0, settings.unit) : "自重")
                kv("目标次数", "\(p.currentTargetReps) 次")
                kv("加重步长", Format.weight(store.effectiveIncrement(exerciseId), settings.unit))
                kv("上次训练", p.lastTrainedAt.map { Format.relativeDay($0) } ?? "—")
            }
        }
        .padding(.horizontal, 16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(Theme.secondary); Spacer(); Text(v).font(.num(15, .medium)) }.font(.system(size: 15)).frame(height: 44)
    }

    private func chartCard(_ history: [ExerciseHistoryPoint]) -> some View {
        let cutoff: Date? = [30, 90, 365].indices.contains(range) ? Calendar.current.date(byAdding: .day, value: -[30, 90, 365][range], to: Date()) : nil
        let points = history.filter { cutoff == nil || $0.date >= cutoff! }
        let values = points.map { pt -> Double in
            metric == 0 ? Weight.toDisplay(pt.topWeightKg, settings.unit)
                : metric == 1 ? Weight.toDisplay(pt.volumeKg, settings.unit)
                : Weight.toDisplay(PersonalRecord.epley(weightKg: pt.topWeightKg, reps: pt.topReps), settings.unit)
        }
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = max((hi - lo) * 0.25, hi * 0.05, 1)
        return VStack(spacing: 10) {
            HStack {
                Picker("", selection: $metric) { Text("重量").tag(0); Text("容量").tag(1); Text("估算 1RM").tag(2) }.pickerStyle(.segmented)
            }
            Chart(points, id: \.date) { pt in
                let y: Double = metric == 0 ? Weight.toDisplay(pt.topWeightKg, settings.unit)
                    : metric == 1 ? Weight.toDisplay(pt.volumeKg, settings.unit)
                    : Weight.toDisplay(PersonalRecord.epley(weightKg: pt.topWeightKg, reps: pt.topReps), settings.unit)
                LineMark(x: .value("日期", pt.date), y: .value("值", y)).foregroundStyle(Theme.accent).interpolationMethod(.monotone)
                PointMark(x: .value("日期", pt.date), y: .value("值", y)).foregroundStyle(Theme.accent)
            }
            .chartYScale(domain: max(0, lo - pad)...(hi + pad))
            .chartYAxis { AxisMarks(position: .leading) { AxisGridLine().foregroundStyle(Theme.separator); AxisValueLabel().foregroundStyle(Theme.secondary) } }
            .chartXAxis { AxisMarks { AxisValueLabel(format: .dateTime.month().day()).foregroundStyle(Theme.secondary) } }
            .frame(height: 160)
            Picker("", selection: $range) { Text("1个月").tag(0); Text("3个月").tag(1); Text("1年").tag(2); Text("全部").tag(3) }.pickerStyle(.segmented)
            if metric == 2 { Text("根据公式估算，仅供参考").font(.system(size: 11)).foregroundStyle(Theme.tertiary) }
        }
        .card()
    }

    private func recordsCard(_ r: PersonalRecord) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            recordTile("最大重量", Format.weight(r.maxWeightKg, settings.unit))
            recordTile("单组最多次数", "\(r.maxReps) 次")
            recordTile("单组最大容量", Format.weight(r.maxVolumeSingleSet, settings.unit))
            recordTile("估算 1RM", Format.weight(r.estimated1RM, settings.unit), note: "根据公式估算，仅供参考")
        }
    }

    private func recordTile(_ label: String, _ value: String, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            Text(value).font(.num(22, .bold))
            if let note { Text(note).font(.system(size: 10)).foregroundStyle(Theme.tertiary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(14)
    }
}

struct ProgressEditorSheet: View {
    let exerciseId: String
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""
    @State private var reps = 8
    @State private var incrementSteps = 10
    @State private var confirmReset = false

    var body: some View {
        let ex = store.exercise(exerciseId)
        let unit = settings.unit
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("当前重量")
                        Spacer()
                        TextField("未设定", text: $weightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                        Text(unit.label).foregroundStyle(Theme.secondary)
                    }
                    StepperRow(label: "目标次数", value: $reps, range: Limits.reps) { "\($0) 次" }
                    StepperRow(label: "加重步长", value: $incrementSteps, range: 1...40) { Format.weight(Double($0) * 0.25, unit) }
                    Text("不同健身房的配重档位不同，可以改成你实际能用的最小增量").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
                Section {
                    Button("重置进度", role: .destructive) { confirmReset = true }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(ex?.nameZh ?? "进度设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let v = Double(weightText) { store.setCurrentWeight(exerciseId, kg: min(max(Weight.toKg(v, unit), 0), Limits.weightKg.upperBound)) }
                        store.setCurrentTargetReps(exerciseId, reps: reps)
                        let inc = Double(incrementSteps) * 0.25
                        store.setIncrementOverride(exerciseId, kg: inc == ex?.defaultIncrementKg ? nil : inc)
                        dismiss()
                    }
                }
            }
            .alert("重置这个动作的进度？", isPresented: $confirmReset) {
                Button("重置", role: .destructive) { store.resetProgress(exerciseId); dismiss() }
                Button("取消", role: .cancel) {}
            } message: { Text("当前重量与目标次数会被清空，下次训练时需要重新设定。已有的训练记录不受影响。") }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            let p = store.progress(for: exerciseId)
            weightText = p.currentWeightKg.map { Format.weight($0, unit, withUnit: false) } ?? ""
            reps = p.currentTargetReps
            incrementSteps = max(1, Int((store.effectiveIncrement(exerciseId) / 0.25).rounded()))
        }
    }
}
