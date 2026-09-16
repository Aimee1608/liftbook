import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var step = 2
    @State private var draft = WorkoutPlan(name: "我的计划", days: [PlanDay(name: "训练日 1", targetMuscles: [.chest], items: [])])
    @State private var chosen: String?
    @State private var editingDayIndex: Int?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("\(step) / 5").font(.num(13, .medium)).foregroundStyle(Theme.secondary)
                    Spacer()
                    if step == 3 || step == 4 {
                        Button("跳过") { step += 1 }.font(.system(size: 15))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                switch step {
                case 2: templateStep
                case 3: daysStep
                case 4: itemsStep
                default: doneStep
                }
            }
            .screenBackground()
            .navigationDestination(isPresented: Binding(get: { editingDayIndex != nil }, set: { if !$0 { editingDayIndex = nil } })) {
                if let i = editingDayIndex, draft.days.indices.contains(i) {
                    PlanDayEditorView(day: $draft.days[i]).navigationTitle(draft.days[i].name).navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    private func header(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 28, weight: .bold))
            Text(subtitle).font(.system(size: 15)).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var templateStep: some View {
        VStack(spacing: 0) {
            header("选一个分化方案", "之后随时可以改。先选一个最接近你现在练法的。")
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.templates) { t in
                        templateCard(id: t.id, name: t.name, days: t.days.map(\.name).joined(separator: " / "), summary: t.summary)
                    }
                    templateCard(id: "custom", name: "自定义", days: "从空白开始", summary: "自己安排训练日和动作")
                }
                .padding(.horizontal, 16)
                .readable()
            }
            Button("下一步") {
                if let t = store.templates.first(where: { $0.id == chosen }) {
                    draft = t.makePlan()
                } else {
                    draft = WorkoutPlan(name: "我的计划", days: [PlanDay(name: "训练日 1", targetMuscles: [.chest], items: [])])
                }
                step = 3
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(chosen == nil)
            .padding(16)
            .readable()
            .accessibilityIdentifier("onb-next")
        }
    }

    private func templateCard(id: String, name: String, days: String, summary: String) -> some View {
        let on = chosen == id
        return Button { chosen = id } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name).font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(on ? Theme.accent : Theme.control)
                }
                Text(days).font(.system(size: 13)).foregroundStyle(Theme.accent)
                Text(summary).font(.system(size: 13)).foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(on ? Theme.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("template-\(id)")
    }

    private var daysStep: some View {
        VStack(spacing: 0) {
            header("确认训练日", "可以改名、调整目标肌群和顺序。")
            List {
                ForEach(Array(draft.days.enumerated()), id: \.element.id) { i, day in
                    Button { editingDayIndex = i } label: {
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(.num(15)).foregroundStyle(Theme.secondary).frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(day.name).font(.system(size: 16, weight: .medium))
                                Text(day.targetMuscles.map(\.label).joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(Theme.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.tertiary)
                        }
                        .frame(minHeight: 48)
                    }
                    .foregroundStyle(.white)
                    .listRowBackground(Theme.card)
                }
                .onDelete { offsets in
                    if draft.days.count > 1 { draft.days.remove(atOffsets: offsets) }
                }
                .onMove { draft.days.move(fromOffsets: $0, toOffset: $1) }
                Button {
                    draft.days.append(PlanDay(name: "训练日 \(draft.days.count + 1)", targetMuscles: [.chest], items: []))
                } label: { Label("新增训练日", systemImage: "plus").foregroundStyle(Theme.accent) }
                    .disabled(draft.days.count >= Limits.daysPerPlan.upperBound)
                    .listRowBackground(Theme.card)
                if draft.days.count == 1 {
                    Text("至少需要保留一个训练日").font(.system(size: 12)).foregroundStyle(Theme.secondary).listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
            Button("下一步") { step = 4 }.buttonStyle(PrimaryButtonStyle()).padding(16).readable().accessibilityIdentifier("onb-next")
        }
    }

    private var itemsStep: some View {
        VStack(spacing: 0) {
            header("挑选动作", "模板已经预填好了，可以直接下一步。")
            List {
                ForEach(Array(draft.days.enumerated()), id: \.element.id) { i, day in
                    Section {
                        ForEach(day.items) { item in
                            HStack {
                                Text(store.exercise(item.exerciseId)?.nameZh ?? "—").font(.system(size: 16))
                                Spacer()
                                Text("\(item.targetSets)组 × \(item.repRangeMin)-\(item.repRangeMax)次").font(.num(14, .medium)).foregroundStyle(Theme.secondary)
                            }
                            .listRowBackground(Theme.card)
                        }
                        if day.items.isEmpty {
                            Text("这一天还没有动作，点击下方添加").font(.system(size: 14)).foregroundStyle(Theme.secondary).listRowBackground(Theme.card)
                        }
                        Button { editingDayIndex = i } label: {
                            Label("编辑这一天的动作", systemImage: "pencil").foregroundStyle(Theme.accent)
                        }
                        .listRowBackground(Theme.card)
                    } header: {
                        Text("\(day.name) · \(day.items.count) 个动作")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            Button("下一步") { step = 5 }.buttonStyle(PrimaryButtonStyle()).padding(16).readable().accessibilityIdentifier("onb-next")
        }
    }

    private var doneStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(Theme.accent)
                Text("计划已就绪").font(.system(size: 28, weight: .bold))
                Text("下次去健身房时，打开应用就能看到今天该练什么。").font(.system(size: 16)).foregroundStyle(Color(hex: 0xD1D1D6))
                Text("第一次做某个动作时，先选一个你能轻松完成 8–10 次的重量作为起点，之后应用会根据你的实际表现自动调整。")
                    .font(.system(size: 16)).foregroundStyle(Color(hex: 0xD1D1D6)).lineSpacing(4)
            }
            .padding(.horizontal, 24)
            .readable()
            Spacer()
            Button("开始使用") { store.addPlan(draft) }
                .buttonStyle(PrimaryButtonStyle()).padding(16).readable().accessibilityIdentifier("onb-finish")
        }
    }
}
