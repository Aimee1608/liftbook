import SwiftUI

struct PlanListView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var creating = false
    @State private var deleting: WorkoutPlan?
    @State private var newDraft: WorkoutPlan?

    var body: some View {
        List {
            ForEach(store.plans) { plan in
                NavigationLink { PlanEditorView(planId: plan.id) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(plan.name).font(.system(size: 16, weight: .medium))
                            Text("\(plan.days.count) 个训练日").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        if store.activePlan?.id == plan.id { Chip(text: "生效中", on: true) }
                    }
                    .frame(minHeight: 48)
                }
                .listRowBackground(Theme.card)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { deleting = plan } label: { Label("删除", systemImage: "trash") }
                    Button { store.duplicatePlan(id: plan.id) } label: { Label("复制", systemImage: "doc.on.doc") }.tint(Theme.control)
                    if store.activePlan?.id != plan.id {
                        Button { store.setActivePlan(id: plan.id) } label: { Label("设为生效", systemImage: "checkmark") }.tint(Theme.accent)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("训练计划")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { creating = true } label: { Image(systemName: "plus") } } }
        .confirmationDialog("新建计划", isPresented: $creating, titleVisibility: .visible) {
            ForEach(store.templates) { t in Button(t.name) { newDraft = t.makePlan() } }
            Button("从空白开始") { newDraft = WorkoutPlan(name: "新计划", days: [PlanDay(name: "训练日 1", targetMuscles: [.chest], items: [])]) }
            Button("取消", role: .cancel) {}
        }
        .sheet(item: $newDraft) { draft in
            NavigationStack {
                PlanDraftEditor(plan: draft) { store.addPlan($0, activate: store.plans.isEmpty) }
            }
        }
        .alert("删除这个计划？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("删除", role: .destructive) { if let d = deleting { store.deletePlan(id: d.id) } }
            Button("取消", role: .cancel) {}
        } message: { Text("已完成的训练记录不会受影响。") }
    }
}

struct PlanDraftEditor: View {
    @State var plan: WorkoutPlan
    var onSave: (WorkoutPlan) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PlanStructureEditor(plan: $plan)
            .navigationTitle("新建计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { onSave(plan); dismiss() }.disabled(plan.name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
    }
}

struct PlanEditorView: View {
    let planId: UUID
    @EnvironmentObject private var store: WorkoutStore
    @State private var plan: WorkoutPlan?

    var body: some View {
        Group {
            if plan != nil {
                PlanStructureEditor(plan: Binding(get: { plan! }, set: { plan = $0; store.updatePlan($0) }))
            } else {
                Color.clear
            }
        }
        .navigationTitle(plan?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { plan = store.plans.first { $0.id == planId } }
    }
}

struct PlanStructureEditor: View {
    @Binding var plan: WorkoutPlan
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            Section("名称") {
                TextField("计划名称", text: $plan.name)
                    .onChange(of: plan.name) { v in if v.count > Limits.planNameLength.upperBound { plan.name = String(v.prefix(Limits.planNameLength.upperBound)) } }
                    .listRowBackground(Theme.card)
            }
            Section {
                ForEach($plan.days) { $day in
                    NavigationLink {
                        PlanDayEditorView(day: $day).navigationTitle(day.name).navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack {
                            Text(day.name).font(.system(size: 16))
                            Spacer()
                            Text("\(day.items.count) 个动作").font(.system(size: 13)).foregroundStyle(Theme.secondary)
                        }
                        .frame(minHeight: 44)
                    }
                    .listRowBackground(Theme.card)
                }
                .onDelete { offsets in if plan.days.count > 1 { plan.days.remove(atOffsets: offsets) } }
                .onMove { plan.days.move(fromOffsets: $0, toOffset: $1) }
                Button {
                    plan.days.append(PlanDay(name: "训练日 \(plan.days.count + 1)", targetMuscles: [.chest], items: []))
                } label: { Label("新增训练日", systemImage: "plus").foregroundStyle(Theme.accent) }
                    .disabled(plan.days.count >= Limits.daysPerPlan.upperBound)
                    .listRowBackground(Theme.card)
            } header: { Text("训练日") } footer: { Text("顺序会作为推荐时的平手决胜依据。左滑删除，拖动排序。") }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .environment(\.editMode, $editMode)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(editMode == .active ? "完成" : "排序") { editMode = editMode == .active ? .inactive : .active } } }
    }
}
