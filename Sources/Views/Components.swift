import SwiftUI

struct MuscleMultiSelect: View {
    @Binding var selection: [MuscleGroup]
    var minimumOne = true
    var idPrefix = "muscle"

    private static let groups: [(String, [MuscleGroup])] = [
        ("上肢推", [.chest, .shoulders, .triceps]),
        ("上肢拉", [.back, .biceps, .forearms]),
        ("下肢", [.quads, .hamstrings, .glutes, .calves]),
        ("核心", [.abs]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Self.groups, id: \.0) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.0).font(.system(size: 12)).foregroundStyle(Theme.tertiary)
                    WrapLayout(spacing: 8) {
                        ForEach(group.1, id: \.self) { m in
                            let on = selection.contains(m)
                            Button(m.label) { toggle(m) }
                                .buttonStyle(ChipButtonStyle(on: on))
                                .accessibilityIdentifier("\(idPrefix)-\(m.rawValue)")
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ m: MuscleGroup) {
        if let i = selection.firstIndex(of: m) {
            if minimumOne && selection.count == 1 { return }
            selection.remove(at: i)
        } else {
            selection.append(m)
        }
    }
}

struct StepperRow: View {
    var label: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step = 1
    var format: (Int) -> String = { "\($0)" }

    var body: some View {
        HStack {
            Text(label).font(.system(size: 16))
            Spacer()
            Text(format(value)).font(.num(16)).foregroundStyle(Theme.secondary)
            Stepper("", value: $value, in: range, step: step).labelsHidden()
        }
        .frame(minHeight: 44)
    }
}

struct NumberPadSheet: View {
    var title: String
    var unitLabel: String
    var initial: Double
    var step: Double
    var range: ClosedRange<Double>
    var allowsDecimal: Bool
    var quick: [(label: String, value: Double)] = []
    var onConfirm: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var typing = false

    private var value: Double { Double(text) ?? 0 }

    var body: some View {
        VStack(spacing: 14) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.secondary).padding(.top, 14)
            HStack(spacing: 18) {
                padButton("minus") { set(value - step) }.disabled(value - step < range.lowerBound - 1e-9)
                VStack(spacing: 2) {
                    Text(text.isEmpty ? "0" : text).font(.num(44, .bold)).lineLimit(1).minimumScaleFactor(0.5)
                    Text(unitLabel).font(.system(size: 13)).foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity)
                padButton("plus") { set(value + step) }.disabled(value + step > range.upperBound + 1e-9)
            }
            .padding(.horizontal, 20)
            if !quick.isEmpty {
                HStack(spacing: 8) {
                    ForEach(quick, id: \.label) { q in
                        Button(q.label) { set(q.value) }.buttonStyle(ChipButtonStyle(accentText: true))
                    }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", allowsDecimal ? "." : "", "0", "⌫"], id: \.self) { key in
                    if key.isEmpty {
                        Color.clear.frame(height: 48)
                    } else {
                        Button { tap(key) } label: {
                            Text(key).font(.num(22, .medium)).frame(maxWidth: .infinity).frame(height: 48)
                        }
                        .buttonStyle(GrayButtonStyle(height: 48))
                    }
                }
            }
            .padding(.horizontal, 20)
            Button("确定") {
                onConfirm(min(max(value, range.lowerBound), range.upperBound))
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(500)])
        .onAppear { text = Self.string(initial) }
    }

    private func padButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
                .frame(width: 60, height: 60)
                .background(Theme.elevated)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func set(_ v: Double) {
        typing = false
        text = Self.string(min(max(v, range.lowerBound), range.upperBound))
    }

    private func tap(_ key: String) {
        if !typing { text = ""; typing = true }
        switch key {
        case "⌫": if !text.isEmpty { text.removeLast() }
        case ".": if !text.contains(".") { text += text.isEmpty ? "0." : "." }
        default:
            if text == "0" { text = key } else if text.count < 7 { text += key }
        }
    }

    static func string(_ v: Double) -> String {
        let r = (v * 100).rounded() / 100
        return r == r.rounded() ? String(Int(r)) : String(r)
    }
}

struct ExerciseRow: View {
    var exercise: ExerciseDefinition
    var trailing: String?
    var selected: Bool? = nil
    var disabled = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell")
                .font(.system(size: 18))
                .foregroundStyle(Theme.secondary)
                .frame(width: 40, height: 40)
                .background(Theme.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.nameZh).font(.system(size: 16, weight: .medium)).lineLimit(1)
                Text([exercise.nameEn, exercise.primaryMuscles.map(\.label).joined(separator: "/"), exercise.equipment.label].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundStyle(Theme.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let selected {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Theme.accent : Theme.control)
            } else if let trailing {
                Text(trailing).font(.num(14, .medium)).foregroundStyle(Theme.secondary)
            } else {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.tertiary)
            }
        }
        .frame(minHeight: 56)
        .opacity(disabled ? 0.4 : 1)
        .contentShape(Rectangle())
    }
}

struct PlanItemEditorSheet: View {
    @Binding var item: PlanItem
    var exercise: ExerciseDefinition?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PlanItem = PlanItem(exerciseId: "", targetSets: 4, repRangeMin: 8, repRangeMax: 12)
    @State private var rest = 90
    @State private var note = ""

    private var valid: Bool { draft.repRangeMin < draft.repRangeMax }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    StepperRow(label: "组数", value: $draft.targetSets, range: Limits.sets)
                    StepperRow(label: "次数区间下限", value: $draft.repRangeMin, range: Limits.repRangeMin)
                    StepperRow(label: "次数区间上限", value: $draft.repRangeMax, range: Limits.repRangeMax)
                    if !valid { Text("下限需小于上限").font(.system(size: 13)).foregroundStyle(Theme.danger) }
                    StepperRow(label: "组间休息", value: $rest, range: Limits.restSeconds, step: Limits.restStep) { "\($0) 秒" }
                }
                Section("备注") {
                    TextField("可选", text: $note, axis: .vertical).lineLimit(2...4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle(exercise?.nameZh ?? "动作设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var d = draft
                        d.restSecondsOverride = rest == exercise?.defaultRestSeconds ? nil : rest
                        d.note = String(note.prefix(Limits.noteLength.upperBound)).isEmpty ? nil : String(note.prefix(Limits.noteLength.upperBound))
                        item = d
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            draft = item
            rest = item.restSecondsOverride ?? exercise?.defaultRestSeconds ?? Limits.restIsolation
            note = item.note ?? ""
        }
    }
}
