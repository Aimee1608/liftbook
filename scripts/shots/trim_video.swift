import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 用法: trim_video <input.mov> [output.mov start duration]
// 只给 input 时打印时长和分辨率;给全参数时按区间裁剪(passthrough,不重编码、不改分辨率)。
let args = CommandLine.arguments
guard args.count >= 2 else { exit(2) }
let input = URL(fileURLWithPath: args[1])
let asset = AVURLAsset(url: input)
let done = DispatchSemaphore(value: 0)

Task {
    let duration = try await asset.load(.duration)
    let seconds = CMTimeGetSeconds(duration)
    if let track = try await asset.loadTracks(withMediaType: .video).first {
        let size = try await track.load(.naturalSize)
        print(String(format: "时长 %.2fs · %dx%d", seconds, Int(size.width), Int(size.height)))
    }
    if args.count >= 5 {
        let output = URL(fileURLWithPath: args[2])
        try? FileManager.default.removeItem(at: output)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else { exit(3) }
        export.outputURL = output
        export.outputFileType = .mov
        export.timeRange = CMTimeRange(
            start: CMTime(seconds: Double(args[3])!, preferredTimescale: 600),
            duration: CMTime(seconds: Double(args[4])!, preferredTimescale: 600)
        )
        try await export.export(to: output, as: .mov)
        let out = AVURLAsset(url: output)
        let d = try await out.load(.duration)
        print(String(format: "导出 %.2fs -> %@", CMTimeGetSeconds(d), output.lastPathComponent))
        // 抽首/中/尾三帧,用来确认剪的位置对不对
        if args.count >= 6 {
            let dir = URL(fileURLWithPath: args[5])
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let gen = AVAssetImageGenerator(asset: out)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceBefore = .zero
            gen.requestedTimeToleranceAfter = CMTime(seconds: 0.2, preferredTimescale: 600)
            let total = CMTimeGetSeconds(d)
            for (name, at) in [("head", 0.4), ("mid", total / 2), ("tail", total - 0.5)] {
                let (cg, _) = try await gen.image(at: CMTime(seconds: at, preferredTimescale: 600))
                let url = dir.appendingPathComponent("\(name).png")
                if let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) {
                    CGImageDestinationAddImage(dest, cg, nil)
                    CGImageDestinationFinalize(dest)
                }
            }
            print("抽帧 -> \(dir.path)")
        }
    }
    done.signal()
}
done.wait()
