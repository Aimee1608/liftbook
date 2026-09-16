import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var coordinator: SessionCoordinator
    @State private var overrideDayId: UUID?
    @State private var switching = false
    @State private var confirmEnd = false
    @State private var confirmDiscard = false
    @State private var decayHint: ExerciseTarget?
    @State private var loggingCardio = false

    private var ranked: [RankedDay] { store.rankedDays() }
    private var shown: RankedDay? { ranked.first { $0.day.id == overrideDayId } ?? ranked.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(title: "训练") {
                    NavigationLink { PlanListView() } label: { Text("计划").font(.system(size: 15, weight: .medium)) }
                        .buttonStyle(ChipButtonStyle(accentText: true))
                        .accessibilityIdentifier("nav-plans")
                }
                .padding(.horizontal, -16)
                if let closed = coordinator.autoClosed {
                    autoClosedBanner(closed)
                }
                if let active = store.activeSession {
                    activeCard(active)
                }
                if let shown {
                    SectionLabel(text: "今天练")
                    dayCard(shown)
                    if let hint = progressionHint(shown.day) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.accent)
                            Text(hint).font(.system(size: 14)).foregroundStyle(Color(hex: 0xD1D1D6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(14)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .readable()
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if store.activeSession == nil, let shown {
                VStack(spacing: 8) {
                    if shown.day.items.isEmpty {
                        Text("这一天还没有安排动作").font(.system(size: 13)).foregroundStyle(Theme.secondary)
                        if let plan = store.activePlan {
                            NavigationLink("去添加动作") { PlanEditorView(planId: plan.id) }.font(.system(size: 15, weight: .medium))
                        }
                    }
                    Button("开始训练") {
                        if let s = store.startSession(day: shown.day) { coordinator.open(s.id) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(shown.day.items.isEmpty)
                    .accessibilityIdentifier("start-workout")
                    Button("记一次有氧") { loggingCardio = true }
                        .buttonStyle(GrayButtonStyle())
                        .accessibilityIdentifier("log-cardio")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .readable()
                .background(Theme.bg)
            }
        }
        .sheet(isPresented: $switching) { switchDaySheet }
        .sheet(isPresented: $loggingCardio) { CardioFormSheet(sessionId: nil) }
        .alert("结束并保存？", isPresented: $confirmEnd) {
            Button("结束并保存") {
                if let a = store.activeSession { store.endSession(a.id); coordinator.finish(a.id); coordinator.presentedSessionId = a.id }
            }
            Button("取消", role: .cancel) {}
        } message: { Text("未完成的组不会被保存，已完成的组会正常记录并计算下次目标。") }
        .alert("丢弃这次训练？", isPresented: $confirmDiscard) {
            Button("丢弃", role: .destructive) { if let a = store.activeSession { store.discardSession(a.id) } }
            Button("取消", role: .cancel) {}
        } message: { Text("已记录的 \(store.activeSession?.completedWorkingSetCount ?? 0) 组数据将被删除，无法恢复。") }
        .alert(item: $decayHint) { t in
            if case let .decaySuggested(d) = t.state {
                return Alert(title: Text(t.exercise.nameZh), message: Text("距上次训练 \(d.days) 天，已下调为 \(Format.weight(d.weightKg, settings.unit))，可在训练时改回"))
            }
            return Alert(title: Text(t.exercise.nameZh))
        }
    }

    private func autoClosedBanner(_ s: WorkoutSession) -> some View {
        HStack {
            Image(systemName: "checkmark.circle").foregroundStyle(Theme.accent)
            NavigationLink("上次训练已自动保存") { SessionDetailView(sessionId: s.id) }.font(.system(size: 14))
            Spacer()
            Button { coordinator.autoClosed = nil } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondary).frame(width: 32, height: 32) }
        }
        .card(12)
    }

    private func activeCard(_ s: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "timer").foregroundStyle(Theme.accent)
                Text("有一次训练还在进行中").font(.system(size: 16, weight: .semibold))
            }
            Text("\(s.planDayNameSnapshot) · 开始于 \(Format.relativeDay(s.startedAt)) \(Format.time(s.startedAt))").font(.system(size: 13)).foregroundStyle(Theme.secondary)
            Text("已完成 \(s.completedWorkingSetCount) 组").font(.num(13, .medium)).foregroundStyle(Theme.secondary)
            HStack(spacing: 8) {
                Button("继续训练") { coordinator.open(s.id) }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("resume-workout")
                Button("结束并保存") { confirmEnd = true }.buttonStyle(GrayButtonStyle())
                Button { confirmDiscard = true } label: { Image(systemName: "trash").foregroundStyle(Theme.danger).frame(width: 52, height: 52).background(Theme.elevated).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) }
            }
        }
        .card()
    }

    private func dayCard(_ r: RankedDay) -> some View {
        let targets = store.targets(for: r.day)
        let hours = store.hoursSinceTrained(r)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.day.name).font(.system(size: 28, weight: .bold))
                    Text(Format.lastTrainedText(r.lastTrainedAt)).font(.system(size: 14)).foregroundStyle(Theme.secondary)
                    if let hours, hours < Limits.recoveryWarningHours {
                        Text("这些部位可能还没完全恢复").font(.system(size: 13)).foregroundStyle(Theme.warning)
                    }
                }
                Spacer()
                Button("换一天") { switching = true }.buttonStyle(ChipButtonStyle(accentText: true)).accessibilityIdentifier("switch-day")
            }
            Divider().overlay(Theme.separator)
            VStack(spacing: 0) {
                ForEach(targets, id: \.item.id) { t in
                    HStack {
                        Text(t.exercise.nameZh).font(.system(size: 15))
                        Spacer()
                        targetText(t)
                        if case .decaySuggested = t.state {
                            Button { decayHint = t } label: { Image(systemName: "arrow.down.circle").foregroundStyle(Theme.warning) }
                        }
                    }
                    .frame(height: 44)
                }
            }
            Divider().overlay(Theme.separator)
            Text("共 \(r.day.items.count) 个动作 · 约 \(r.day.items.reduce(0) { $0 + $1.targetSets }) 组").font(.system(size: 13)).foregroundStyle(Theme.secondary)
        }
        .card(18)
    }

    @ViewBuilder
    private func targetText(_ t: ExerciseTarget) -> some View {
        let base = "\(t.sets)组 × \(t.reps)次"
        if let w = t.weightKg {
            if w == 0 && !t.exercise.equipment.isLoadable {
                Text("\(base) · 自重").font(.num(14, .medium)).foregroundStyle(Color(hex: 0xD1D1D6))
            } else {
                (Text("\(base) × \(Format.weight(w, settings.unit))") + Text(t.exercise.isPerHand ? " ×2" : "").foregroundColor(Theme.tertiary))
                    .font(.num(14, .medium)).foregroundStyle(Color(hex: 0xD1D1D6))
            }
        } else {
            (Text("\(base) · ") + Text("待设定").foregroundColor(Theme.accent).bold()).font(.num(14, .medium)).foregroundStyle(Color(hex: 0xD1D1D6))
        }
    }

    private func progressionHint(_ day: PlanDay) -> String? {
        for item in day.items {
            guard let last = store.completedSessions.lazy.compactMap({ s in s.exercises.first { $0.exerciseId == item.exerciseId && $0.progression != nil } }).first,
                  let p = last.progression, p.accepted, p.kind == .increaseWeight, let ex = store.exercise(item.exerciseId) else { continue }
            return "\(ex.nameZh)上次全部做到 \(p.fromReps) 次，今天加到 \(Format.weight(p.toWeightKg, settings.unit))"
        }
        return nil
    }

    private var switchDaySheet: some View {
        NavigationStack {
            List(ranked, id: \.day.id) { r in
                Button {
                    overrideDayId = r.day.id
                    switching = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.day.name).font(.system(size: 16, weight: .medium))
                            Text(r.day.targetMuscles.map(\.label).joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        Text(Format.lastTrainedText(r.lastTrainedAt)).font(.system(size: 13)).foregroundStyle(Theme.secondary)
                        if r.day.id == shown?.day.id { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                    }
                    .frame(minHeight: 48)
                }
                .foregroundStyle(.white)
                .listRowBackground(Theme.card)
                .accessibilityIdentifier("day-option-\(r.day.name)")
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("换一天练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { switching = false } } }
        }
        .presentationDetents([.medium, .large])
    }
}

extension ExerciseTarget: Identifiable {
    var id: UUID { item.id }
}
