import SwiftUI

struct PlanDayEditorView: View {
    @Binding var day: PlanDay
    var showsHeader = true
    @EnvironmentObject private var store: WorkoutStore
    @State private var editingItemId: UUID?
    @State private var picking = false

    private var actualMuscles: [MuscleGroup] {
        var seen: [MuscleGroup] = []
        for item in day.items { for m in store.exercise(item.exerciseId)?.primaryMuscles ?? [] where !seen.contains(m) { seen.append(m) } }
        return seen
    }

    private var mismatch: Bool {
        !actualMuscles.isEmpty && !Set(actualMuscles).isSubset(of: day.targetMuscles)
    }

    var body: some View {
        List {
            if showsHeader {
                Section {
                    TextField("训练日名称", text: $day.name)
                        .onChange(of: day.name) { v in if v.count > Limits.planNameLength.upperBound { day.name = String(v.prefix(Limits.planNameLength.upperBound)) } }
                } header: { Text("名称") }
                Section {
                    MuscleMultiSelect(selection: $day.targetMuscles).padding(.vertical, 6)
                    if mismatch {
                        Text("这一天的动作主要练的是「\(actualMuscles.map(\.label).joined(separator: "、"))」，与设置的目标肌群不完全一致")
                            .font(.system(size: 13)).foregroundStyle(Theme.warning)
                    }
                } header: { Text("目标肌群") }
            }
            Section {
                ForEach($day.items) { $item in
                    let ex = store.exercise(item.exerciseId)
                    Button { editingItemId = item.id } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex?.nameZh ?? "已删除的动作").font(.system(size: 16))
                                if let note = item.note, !note.isEmpty { Text(note).font(.system(size: 12)).foregroundStyle(Theme.secondary).lineLimit(1) }
                            }
                            Spacer()
                            Text("\(item.targetSets)组 × \(item.repRangeMin)-\(item.repRangeMax)次").font(.num(14, .medium)).foregroundStyle(Theme.secondary)
                        }
                        .frame(minHeight: 44)
                    }
                    .foregroundStyle(.white)
                    .sheet(isPresented: Binding(get: { editingItemId == item.id }, set: { if !$0 { editingItemId = nil } })) {
                        PlanItemEditorSheet(item: $item, exercise: ex)
                    }
                }
                .onDelete { day.items.remove(atOffsets: $0) }
                .onMove { day.items.move(fromOffsets: $0, toOffset: $1) }
                if day.items.isEmpty {
                    Text("这一天还没有动作，点击下方添加").font(.system(size: 14)).foregroundStyle(Theme.secondary)
                }
                Button { picking = true } label: {
                    Label("添加动作", systemImage: "plus").foregroundStyle(Theme.accent).frame(minHeight: 44)
                }
                .disabled(day.items.count >= Limits.itemsPerDay.upperBound)
                .accessibilityIdentifier("day-add-exercise")
            } header: {
                Text("动作")
            } footer: {
                if !day.items.isEmpty {
                    Text("\(day.items.count) 个动作 · \(day.items.reduce(0) { $0 + $1.targetSets }) 组 · 约 \(store.estimatedSeconds(for: day) / 60) 分钟")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .environment(\.editMode, .constant(.active))
        .sheet(isPresented: $picking) {
            ExercisePickerSheet(excluded: Set(day.items.map(\.exerciseId)), recommendedMuscles: day.targetMuscles) { picked in
                for ex in picked {
                    day.items.append(PlanItem(exerciseId: ex.id, targetSets: Limits.defaultSets,
                                              repRangeMin: ex.defaultRepRange.lowerBound, repRangeMax: ex.defaultRepRange.upperBound))
                }
            }
        }
    }
}
