import SwiftUI

struct CreditsView: View {
    @EnvironmentObject private var store: WorkoutStore

    private var illustrated: [ExerciseDefinition] {
        store.library.all.filter { ExerciseArtwork.has($0.id) }.sorted { $0.nameZh < $1.nameZh }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("动作演示图").font(.system(size: 17, weight: .semibold))
                    Text("本应用的动作演示图由 Everkinetic 绘制，依据知识共享署名-相同方式共享 3.0 协议（CC BY-SA 3.0）使用。原图通过维基共享资源发布。")
                        .font(.system(size: 14)).foregroundStyle(Color(hex: 0xD1D1D6)).lineSpacing(3)
                    Text("我们把原图转换为矢量并调整了配色以适配深色界面。这些修改后的图同样依据 CC BY-SA 3.0 发布，源文件在本应用的开源仓库中。")
                        .font(.system(size: 14)).foregroundStyle(Color(hex: 0xD1D1D6)).lineSpacing(3)
                }
                .padding(.vertical, 6)
                .listRowBackground(Theme.card)
                link("维基共享资源上的原图", "https://commons.wikimedia.org/wiki/Category:Weight_training_diagrams")
                link("CC BY-SA 3.0 协议全文", "https://creativecommons.org/licenses/by-sa/3.0/deed.zh")
                link("本应用的开源仓库", "https://github.com/Aimee1608/liftbook")
            }
            Section {
                Text("动作名称、肌群与器械归类、动作要点文字均由开发者自行编写，不属于上述素材的一部分。")
                    .font(.system(size: 13)).foregroundStyle(Theme.secondary)
                    .listRowBackground(Theme.card)
            }
            Section {
                ForEach(illustrated) { ex in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.nameZh).font(.system(size: 15))
                        Text("Everkinetic · CC BY-SA 3.0").font(.system(size: 11)).foregroundStyle(Theme.tertiary)
                    }
                    .frame(minHeight: 44)
                    .listRowBackground(Theme.card)
                }
            } header: {
                Text("逐条动作来源 · 共 \(illustrated.count) 个")
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("素材来源")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func link(_ title: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title).font(.system(size: 15)).foregroundStyle(Theme.accent)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.tertiary)
            }
            .frame(minHeight: 44)
        }
        .listRowBackground(Theme.card)
    }
}
