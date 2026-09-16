import SwiftUI

struct DisclaimerView: View {
    var requiresAcceptance: Bool
    var onAccept: () -> Void = {}
    @State private var reachedEnd = false

    static let sections: [(title: String, body: [String])] = [
        ("使用前请阅读", ["本应用是一款训练记录工具，不是医疗设备，也不提供医疗建议或专业训练指导。"]),
        ("关于训练建议", ["本应用给出的建议重量与次数，是基于你自己录入的历史训练数据推算得出的参考值。它无法感知你当天的身体状态、疲劳程度、动作质量或潜在伤病，因此这些数字仅供参考，不构成任何形式的专业指导。"]),
        ("请务必量力而行", [
            "· 每次训练前请充分热身",
            "· 采用你能够全程控制的重量，不要为了达成应用给出的数字而牺牲动作质量",
            "· 进行大重量训练时请使用保护杠或寻求他人保护",
            "· 出现疼痛、头晕、呼吸困难等任何不适时，请立即停止训练",
            "· 如你有心血管疾病、既往运动损伤或其他健康问题，请在开始训练计划前咨询医生",
        ]),
        ("责任声明", ["你需要对自己的训练行为及其后果负责。因使用本应用而产生的任何身体损伤或健康问题，开发者不承担责任。", "如对训练动作或计划安排有疑问，请咨询有资质的健身教练或医疗专业人士。"]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if requiresAcceptance {
                        Text("1 / 5").font(.num(13, .medium)).foregroundStyle(Theme.secondary)
                    }
                    Text("免责声明").font(.system(size: 28, weight: .bold))
                    ForEach(Self.sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title).font(.system(size: 17, weight: .semibold))
                            ForEach(section.body, id: \.self) { line in
                                Text(line).font(.system(size: 15)).foregroundStyle(Color(hex: 0xD1D1D6)).lineSpacing(4)
                            }
                        }
                    }
                    Color.clear.frame(height: 1).onAppear { reachedEnd = true }
                }
                .padding(20)
                .padding(.bottom, 12)
                .readable()
            }
            if requiresAcceptance {
                Button("我已阅读并同意", action: onAccept)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!reachedEnd)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .readable()
                    .accessibilityIdentifier("disclaimer-accept")
            }
        }
        .screenBackground()
        .navigationTitle(requiresAcceptance ? "" : "免责声明")
        .navigationBarTitleDisplayMode(.inline)
    }
}
