import SwiftUI

struct ExerciseLibraryView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var settings: AppSettings
    @State private var query = ""
    @State private var muscle: MuscleGroup?
    @State private var equipment: EquipmentType?
    @State private var customOnly = false
    @State private var creating = false

    private var results: [ExerciseDefinition] {
        store.library.search(query, muscle: muscle, equipment: equipment).filter { !customOnly || !$0.isBuiltin }
    }

    var body: some View {
        VStack(spacing: 10) {
            SearchField(text: $query)
            ExerciseFilterBar(muscle: $muscle, equipment: $equipment, showCustomToggle: true, customOnly: $customOnly)
            if results.isEmpty {
                EmptyState(symbol: "magnifyingglass", title: query.isEmpty ? "没有符合条件的动作" : "没有找到「\(query)」", message: "试试其他关键词，或创建一个自定义动作",
                           action: query.isEmpty ? nil : ("创建「\(query)」", { creating = true }))
            } else {
                List {
                    Section {
                        ForEach(results) { ex in
                            NavigationLink { ExerciseDetailView(exerciseId: ex.id) } label: {
                                ExerciseRow(exercise: ex, trailing: store.progress[ex.id]?.currentWeightKg.map { Format.weight($0, settings.unit) } ?? "")
                            }
                            .listRowBackground(Theme.card)
                            .accessibilityIdentifier("lib-\(ex.id)")
                        }
                    } header: {
                        Text("\(muscle?.label ?? "全部") · \(results.count) 个动作")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.top, 4)
        .screenBackground()
        .navigationTitle("动作")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { creating = true } label: { Image(systemName: "plus") }.accessibilityIdentifier("lib-add") } }
        .sheet(isPresented: $creating) { CustomExerciseEditor(presetName: query) { _ in query = "" } }
    }
}

struct CustomExerciseEditor: View {
    var presetName = ""
    var editing: ExerciseDefinition?
    var onSaved: (ExerciseDefinition) -> Void = { _ in }
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var nameEn = ""
    @State private var primary: [MuscleGroup] = []
    @State private var secondary: [MuscleGroup] = []
    @State private var equipment: EquipmentType = .dumbbell
    @State private var laterality: Laterality = .bilateral
    @State private var incrementSteps = 10
    @State private var rest = Limits.restIsolation
    @State private var repMin = Limits.repRangeIsolation.lowerBound
    @State private var repMax = Limits.repRangeIsolation.upperBound
    @State private var instructions: [String] = []

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var nameTaken: Bool { store.isNameTaken(trimmed, excluding: editing?.id) }
    private var valid: Bool { Limits.exerciseNameLength.contains(trimmed.count) && !nameTaken && !primary.isEmpty && repMin < repMax }
    private var incrementKg: Double { Double(incrementSteps) * 0.25 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("动作名称（必填）", text: $name)
                    if nameTaken { Text("已存在同名动作「\(trimmed)」").font(.system(size: 13)).foregroundStyle(Theme.danger) }
                    TextField("英文名（可选）", text: $nameEn)
                }
                Section("主要肌群（必填）") { MuscleMultiSelect(selection: $primary, minimumOne: false).padding(.vertical, 6) }
                Section("次要肌群") { MuscleMultiSelect(selection: $secondary, minimumOne: false).padding(.vertical, 6) }
                Section {
                    Picker("器械类型", selection: $equipment) { ForEach(EquipmentType.allCases, id: \.self) { Text($0.label).tag($0) } }
                        .onChange(of: equipment) { e in incrementSteps = Int(Increment.defaultKg(equipment: e, muscle: primary.first ?? .chest) / 0.25) }
                    Text(equipment.isLoadable ? "每次加重 \(Format.weight(incrementKg, settings.unit))" : "此类动作无法加重，将通过增加次数进阶")
                        .font(.system(size: 13)).foregroundStyle(Theme.secondary)
                    Picker("单双侧", selection: $laterality) { ForEach(Laterality.allCases, id: \.self) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                }
                Section("默认参数") {
                    if equipment.isLoadable {
                        StepperRow(label: "加重步长", value: $incrementSteps, range: 1...40) { Format.weight(Double($0) * 0.25, settings.unit) }
                    }
                    StepperRow(label: "默认组间休息", value: $rest, range: Limits.restSeconds, step: Limits.restStep) { "\($0) 秒" }
                    StepperRow(label: "次数区间下限", value: $repMin, range: Limits.repRangeMin)
                    StepperRow(label: "次数区间上限", value: $repMax, range: Limits.repRangeMax)
                    if repMin >= repMax { Text("下限需小于上限").font(.system(size: 13)).foregroundStyle(Theme.danger) }
                }
                Section("动作要点") {
                    ForEach(instructions.indices, id: \.self) { i in
                        TextField("要点 \(i + 1)", text: $instructions[i], axis: .vertical)
                    }
                    .onDelete { instructions.remove(atOffsets: $0) }
                    Button { instructions.append("") } label: { Label("添加一条", systemImage: "plus").foregroundStyle(Theme.accent) }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(editing == nil ? "新建动作" : "编辑动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(!valid).accessibilityIdentifier("custom-save") }
            }
        }
        .onAppear {
            if let e = editing {
                name = e.nameZh; nameEn = e.nameEn ?? ""; primary = e.primaryMuscles; secondary = e.secondaryMuscles
                equipment = e.equipment; laterality = e.laterality; incrementSteps = Int(e.defaultIncrementKg / 0.25)
                rest = e.defaultRestSeconds; repMin = e.defaultRepRange.lowerBound; repMax = e.defaultRepRange.upperBound
                instructions = e.instructions
            } else {
                name = presetName
                incrementSteps = Int(Increment.defaultKg(equipment: equipment, muscle: .chest) / 0.25)
            }
        }
    }

    private func save() {
        var def = editing ?? ExerciseDefinition(nameZh: trimmed, primaryMuscles: primary, equipment: equipment)
        def.nameZh = trimmed
        def.nameEn = nameEn.trimmingCharacters(in: .whitespaces).isEmpty ? nil : String(nameEn.prefix(Limits.exerciseNameEnLength.upperBound))
        def.primaryMuscles = primary
        def.secondaryMuscles = secondary.filter { !primary.contains($0) }
        def.equipment = equipment
        def.laterality = laterality
        def.isCompound = false
        def.incrementKgOverride = equipment.isLoadable ? incrementKg : nil
        def.restSecondsOverride = rest
        def.repRangeMinOverride = repMin
        def.repRangeMaxOverride = repMax
        def.instructions = instructions.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)) }.filter { !$0.isEmpty }
        if editing == nil { store.addCustomExercise(def) } else { store.updateCustomExercise(def) }
        onSaved(def)
        dismiss()
    }
}
