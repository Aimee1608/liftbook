import SwiftUI

struct SessionSummaryView: View {
    let sessionId: UUID
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var coordinator: SessionCoordinator
    @State private var prDetail: (String, [String])?

    private var session: WorkoutSession? { store.session(sessionId) }

    var body: some View {
        if let s = session {
            let records = store.newRecords(in: s)
            let recordIds = Set(records.map(\.exercise.id))
            VStack(spacing: 0) {
                Text("训练完成").font(.system(size: 17, weight: .semibold)).frame(height: 44)
                ScrollView {
                    VStack(spacing: 12) {
                        Text("\(s.planDayNameSnapshot) · \(Format.minutes(s.duration))").font(.system(size: 15)).foregroundStyle(Theme.secondary)
                        HStack(spacing: 10) {
                            tile("\(s.completedWorkingSetCount)", "组", "正式组")
                            tile("\(store.totalReps(of: s))", "次", "总次数")
                            if !records.isEmpty { tile("\(records.count)", "个", "新纪录") }
                        }
                        if !s.exercises.isEmpty {
                            SectionLabel(text: "本次记录").padding(.top, 6)
                            VStack(spacing: 0) {
                                ForEach(s.exercises) { ex in recordRow(ex, pr: recordIds.contains(ex.exerciseId)) }
                            }
                            .padding(.horizontal, 16)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                        }
                        if !s.cardioEntries.isEmpty {
                            HStack {
                                Image(systemName: "figure.run").foregroundStyle(Theme.accent)
                                Text(s.cardioEntries.map { "\($0.type.label) \(Format.minutes(TimeInterval($0.durationSeconds)))" + ($0.distanceMeters.map { " · \(Format.distance($0))" } ?? "") }.joined(separator: "，"))
                                    .font(.system(size: 14))
                                Spacer()
                            }
                            .card(14)
                        }
                        let suggestions = s.exercises.filter { $0.progression != nil }
                        if !suggestions.isEmpty {
                            SectionLabel(text: "下次训练建议").padding(.top, 6)
                            ForEach(suggestions) { ex in suggestionCard(ex, pr: records.first { $0.exercise.id == ex.exerciseId }) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .readable()
                }
                Button("完成") { coordinator.close() }
                    .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 16).padding(.bottom, 8).readable()
                    .accessibilityIdentifier("summary-done")
            }
            .screenBackground()
            .interactiveDismissDisabled()
            .alert(prDetail?.0 ?? "", isPresented: Binding(get: { prDetail != nil }, set: { if !$0 { prDetail = nil } })) {
                Button("好", role: .cancel) {}
            } message: { Text("新纪录：" + (prDetail?.1.joined(separator: "、") ?? "")) }
        } else {
            Color.clear.onAppear { coordinator.close() }
        }
    }

    private func tile(_ v: String, _ unit: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            (Text(v).font(.num(28, .bold)) + Text(" \(unit)").font(.system(size: 14, weight: .medium)).foregroundColor(Theme.secondary))
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
        .card(14)
    }

    private func recordRow(_ ex: SessionExercise, pr: Bool) -> some View {
        let sets = ex.completedWorkingSets
        let weights = Set(sets.map(\.weightKg))
        let def = store.exercise(ex.exerciseId)
        let weightText: String = {
            if def?.equipment.isLoadable == false && weights == [0] { return "自重" }
            guard let lo = weights.min(), let hi = weights.max() else { return "—" }
            let base = lo == hi ? Format.weight(lo, settings.unit) : "\(Format.weight(lo, settings.unit, withUnit: false))–\(Format.weight(hi, settings.unit))"
            return base + (def?.isPerHand == true ? " ×2" : "")
        }()
        return HStack {
            HStack(spacing: 8) {
                Text(ex.exerciseNameSnapshot).font(.system(size: 15))
                if pr { Chip(text: "PR", on: true) }
                if ex.isSkipped { Chip(text: "已跳过") }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(weightText).font(.num(15))
                Text(sets.isEmpty ? "未完成" : sets.map { "\($0.reps)" }.joined(separator: " / ") + " 次").font(.num(12, .medium)).foregroundStyle(Theme.secondary)
            }
        }
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { if ex.id != session?.exercises.last?.id { Divider().overlay(Theme.separator) } }
    }

    private func suggestionCard(_ ex: SessionExercise, pr: (exercise: ExerciseDefinition, kinds: [String])?) -> some View {
        let p = ex.progression!
        let unit = settings.unit
        let from = "\(Format.weight(p.fromWeightKg, unit)) × \(p.fromReps)"
        let to = "\(Format.weight(p.toWeightKg, unit)) × \(p.toReps)"
        let toColor: Color = p.kind == .suggestDeload ? Theme.warning : Theme.accent
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ex.exerciseNameSnapshot).font(.system(size: 17, weight: .semibold))
                Spacer()
                if let pr {
                    Button { prDetail = (pr.exercise.nameZh, pr.kinds) } label: { Image(systemName: "trophy.fill").foregroundStyle(Theme.accent).frame(width: 32, height: 32) }
                }
            }
            Text(p.reason).font(.system(size: 13)).foregroundStyle(Theme.secondary)
            if p.kind == .suggestDeload { Text("减重是正常的训练调整，不是退步").font(.system(size: 12)).foregroundStyle(Theme.warning) }
            if p.kind == .hold {
                (Text("保持 ").foregroundColor(Theme.secondary) + Text(from)).font(.num(17))
            } else {
                (Text(from) + Text("  →  ").foregroundColor(Theme.secondary) + Text(to).foregroundColor(toColor)).font(.num(17))
                HStack(spacing: 8) {
                    Spacer()
                    Button("保持原样") { store.setProgressionAccepted(sessionId, ex.id, false) }
                        .buttonStyle(ChipButtonStyle(on: !p.accepted)).frame(height: 40)
                    Button("接受") { store.setProgressionAccepted(sessionId, ex.id, true) }
                        .buttonStyle(ChipButtonStyle(on: p.accepted)).frame(height: 40)
                        .accessibilityIdentifier("accept-\(ex.exerciseId)")
                }
                .padding(.top, 2)
            }
        }
        .card()
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(p.kind == .suggestDeload ? Theme.warning : .clear, lineWidth: 1.5))
    }
}
