import SwiftUI

enum ExerciseArtwork {
    private static var cache: [String: [String]] = [:]

    static func names(for exerciseId: String) -> [String] {
        if let hit = cache[exerciseId] { return hit }
        let found = ["\(exerciseId)-1", "\(exerciseId)-2"].filter { UIImage(named: $0) != nil }
        cache[exerciseId] = found
        return found
    }

    static func has(_ exerciseId: String) -> Bool { !names(for: exerciseId).isEmpty }
}

struct ExerciseArtworkView: View {
    var exerciseId: String
    var tint: Color = Color(hex: 0xE8E8EA)

    var body: some View {
        let names = ExerciseArtwork.names(for: exerciseId)
        if names.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "dumbbell").font(.system(size: 34)).foregroundStyle(Theme.control)
                Text("暂无演示图").font(.system(size: 13)).foregroundStyle(Theme.tertiary)
            }
            .frame(maxWidth: .infinity).frame(height: 180).card(0)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(names.enumerated()), id: \.element) { index, name in
                    if index > 0 { Rectangle().fill(Theme.separator).frame(width: 1).padding(.vertical, 20) }
                    ZStack(alignment: .topLeading) {
                        Image(name).resizable().renderingMode(.template).scaledToFit()
                            .foregroundStyle(tint)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                        Text(index == 0 ? "起始" : "结束")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                            .padding(8)
                    }
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .card(0)
        }
    }
}

struct ExerciseThumbnail: View {
    var exerciseId: String
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous).fill(Theme.elevated)
            if let name = ExerciseArtwork.names(for: exerciseId).first {
                Image(name).resizable().renderingMode(.template).scaledToFit()
                    .foregroundStyle(Color(hex: 0xD1D1D6))
                    .padding(size * 0.06)
            } else {
                Image(systemName: "dumbbell").font(.system(size: size * 0.45)).foregroundStyle(Theme.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
