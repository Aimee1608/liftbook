import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var notificationsDenied = false

    var body: some View {
        List {
            Section("单位") {
                Picker("重量单位", selection: $settings.unit) { ForEach(WeightUnit.allCases, id: \.self) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
            }
            Section("训练") {
                toggle("组间休息计时器", "打完一组自动开始倒计时", $settings.restTimerEnabled)
                if settings.restTimerEnabled {
                    Toggle("　到时震动", isOn: $settings.restTimerHapticsEnabled)
                    Toggle("　到时提示音", isOn: $settings.restTimerSoundEnabled)
                    StepperRow(label: "　默认休息时长", value: $settings.defaultRestSeconds, range: Limits.restSeconds, step: Limits.restStep) { "\($0) 秒" }
                    if notificationsDenied {
                        Button { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } label: {
                            Text("未开启通知权限，计时器到时将无法在后台提醒你。前往系统设置开启 >").font(.system(size: 12)).foregroundStyle(Theme.warning)
                        }
                    }
                }
                toggle("训练时屏幕常亮", "训练页面不会自动锁屏", $settings.keepScreenAwake)
                toggle("备注与力竭标记", "可以给每组或整次训练写备注", $settings.notesEnabled)
            }
            Section("计划") {
                NavigationLink("训练计划管理") { PlanListView() }
            }
            Section("关于") {
                NavigationLink("免责声明") { DisclaimerView(requiresAcceptance: false) }
                NavigationLink("关于本应用") { AboutView() }
            }
        }
        .tint(Theme.accent)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("设置")
        .onAppear { NotificationManager.isDenied { notificationsDenied = $0 } }
    }

    private func toggle(_ title: String, _ subtitle: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack { Text("版本"); Spacer(); Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "").foregroundStyle(Theme.secondary) }
            }
            Section("动作库") {
                Text("内置动作库由开发者自行编写，动作名称与肌群、器械归类为通行事实，动作要点为原创内容。").font(.system(size: 14)).foregroundStyle(Theme.secondary)
            }
            Section("数据") {
                Text("所有数据仅保存在本设备，随系统备份一起备份。应用不联网、不收集任何信息。").font(.system(size: 14)).foregroundStyle(Theme.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("关于本应用")
        .navigationBarTitleDisplayMode(.inline)
    }
}
