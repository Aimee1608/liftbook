import SwiftUI

struct ExerciseFilterBar: View {
    @Binding var muscle: MuscleGroup?
    @Binding var equipment: EquipmentType?
    var showCustomToggle = false
    @Binding var customOnly: Bool

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("全部") { muscle = nil }.buttonStyle(ChipButtonStyle(on: muscle == nil))
                    ForEach(MuscleGroup.allCases, id: \.self) { m in
                        Button(m.label) { muscle = muscle == m ? nil : m }.buttonStyle(ChipButtonStyle(on: muscle == m))
                    }
                }
                .padding(.horizontal, 16)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("全部") { equipment = nil }.buttonStyle(ChipButtonStyle(on: equipment == nil))
                    ForEach(EquipmentType.allCases, id: \.self) { e in
                        Button(e.label) { equipment = equipment == e ? nil : e }.buttonStyle(ChipButtonStyle(on: equipment == e))
                    }
                    if showCustomToggle {
                        Button("仅自定义") { customOnly.toggle() }.buttonStyle(ChipButtonStyle(on: customOnly))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondary)
            TextField("搜索动作名称", text: $text).font(.system(size: 16)).autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.secondary) }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }
}

struct ExercisePickerSheet: View {
    var excluded: Set<String> = []
    var recommendedMuscles: [MuscleGroup] = []
    var onAdd: ([ExerciseDefinition]) -> Void

    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var segment = 0
    @State private var muscle: MuscleGroup?
    @State private var equipment: EquipmentType?
    @State private var customOnly = false
    @State private var picked: [String] = []
    @State private var creating = false

    private var results: [ExerciseDefinition] {
        var list = store.library.search(query, muscle: muscle, equipment: equipment)
        switch segment {
        case 0 where !recommendedMuscles.isEmpty:
            list = list.filter { !Set($0.primaryMuscles).isDisjoint(with: recommendedMuscles) }
        case 2:
            let recent = store.recentExerciseIds()
            list = recent.compactMap { id in list.first { $0.id == id } }
        default: break
        }
        return list
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                SearchField(text: $query)
                if !recommendedMuscles.isEmpty || !store.recentExerciseIds().isEmpty {
                    Picker("", selection: $segment) {
                        if !recommendedMuscles.isEmpty { Text("推荐").tag(0) }
                        Text("全部").tag(1)
                        Text("最近使用").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                }
                ExerciseFilterBar(muscle: $muscle, equipment: $equipment, customOnly: $customOnly)
                if results.isEmpty {
                    EmptyState(symbol: "magnifyingglass", title: "没有找到「\(query)」", message: "试试其他关键词，或创建一个自定义动作",
                               action: query.isEmpty ? nil : ("创建「\(query)」", { creating = true }))
                } else {
                    List(results) { ex in
                        let isExcluded = excluded.contains(ex.id)
                        let on = picked.contains(ex.id)
                        ExerciseRow(exercise: ex, selected: isExcluded ? true : on, disabled: isExcluded)
                            .listRowBackground(Theme.card)
                            .onTapGesture {
                                guard !isExcluded else { return }
                                if let i = picked.firstIndex(of: ex.id) { picked.remove(at: i) } else { picked.append(ex.id) }
                            }
                            .accessibilityIdentifier("pick-\(ex.id)")
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .padding(.top, 8)
            .screenBackground()
            .navigationTitle("选择动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                if !picked.isEmpty {
                    HStack {
                        Text("已选 \(picked.count) 个").font(.system(size: 15, weight: .medium))
                        Spacer()
                        Button("添加") {
                            onAdd(picked.compactMap { store.exercise($0) })
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(width: 140)
                        .accessibilityIdentifier("picker-add")
                    }
                    .padding(16)
                    .background(Theme.tabBar)
                }
            }
            .onAppear { if recommendedMuscles.isEmpty { segment = 1 } }
            .sheet(isPresented: $creating) {
                CustomExerciseEditor(presetName: query) { created in
                    picked.append(created.id)
                    query = ""
                }
            }
        }
    }
}
