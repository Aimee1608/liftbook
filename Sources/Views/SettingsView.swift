import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: WorkoutStore
    @State private var notificationsDenied = false
    @State private var shareURL: URL?
    @State private var exportError: String?

    var body: some View {
        VStack(spacing: 0) {
        PageHeader(title: "设置") { EmptyView() }
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
            Section {
                Button { export(.text) } label: { Label("导出训练记录（文本）", systemImage: "doc.text") }
                Button { export(.csv) } label: { Label("导出训练记录（CSV 表格）", systemImage: "tablecells") }
                Button { export(.backup) } label: { Label("导出全部数据（JSON 备份）", systemImage: "externaldrive") }
            } header: { Text("数据") } footer: {
                Text("文本和 CSV 适合自己看或导入表格；JSON 备份包含计划、进度、自定义动作和全部训练记录。")
            }
            Section("关于") {
                NavigationLink("免责声明") { DisclaimerView(requiresAcceptance: false) }
                NavigationLink("素材来源与许可") { CreditsView() }
                NavigationLink("关于本应用") { AboutView() }
            }
        }
        .tint(Theme.accent)
        .scrollContentBackground(.hidden)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { NotificationManager.isDenied { notificationsDenied = $0 } }
        .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
        .alert("导出失败", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(exportError ?? "") }
    }

    private enum ExportKind { case text, csv, backup }

    private func export(_ kind: ExportKind) {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        let stamp = f.string(from: Date())
        do {
            let (name, data): (String, Data) = try {
                switch kind {
                case .text: return ("力训笔记训练记录-\(stamp).txt", Data(store.exportText(unit: settings.unit).utf8))
                case .csv: return ("力训笔记训练记录-\(stamp).csv", Data(("\u{FEFF}" + store.exportCSV()).utf8))
                case .backup: return ("力训笔记备份-\(stamp).json", try store.exportBackup())
                }
            }()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            shareURL = url
        } catch {
            exportError = error.localizedDescription
        }
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
                Text("动作名称、肌群与器械归类、动作要点由开发者自行编写；动作演示图来自 Everkinetic，依据 CC BY-SA 3.0 使用，详见设置中的「素材来源与许可」。").font(.system(size: 14)).foregroundStyle(Theme.secondary)
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

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
