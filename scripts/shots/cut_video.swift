import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 用法: cut_video <in.mov> <out.mov> [frames_dir] -- <start> <dur> [<start> <dur> ...]
// 把若干片段按顺序拼成一条(passthrough,不重编码、不改分辨率)。App 预览要求 15~30 秒,
// 而 XCUITest 录出来总是长一截,靠这个把中间的空转剪掉。
let args = CommandLine.arguments
guard let sep = args.firstIndex(of: "--"), args.count > sep + 2 else {
    print("usage: cut_video <in.mov> <out.mov> [frames_dir] -- <start> <dur> ...")
    exit(2)
}
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let framesDir: URL? = sep == 4 ? URL(fileURLWithPath: args[3]) : nil
let nums = args[(sep + 1)...].compactMap(Double.init)
guard nums.count % 2 == 0 else { exit(2) }

let asset = AVURLAsset(url: input)
let done = DispatchSemaphore(value: 0)

Task {
    let comp = AVMutableComposition()
    guard let src = try await asset.loadTracks(withMediaType: .video).first,
          let dst = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { exit(3) }
    dst.preferredTransform = try await src.load(.preferredTransform)
    var cursor = CMTime.zero
    for i in stride(from: 0, to: nums.count, by: 2) {
        let range = CMTimeRange(start: CMTime(seconds: nums[i], preferredTimescale: 600),
                                duration: CMTime(seconds: nums[i + 1], preferredTimescale: 600))
        try dst.insertTimeRange(range, of: src, at: cursor)
        cursor = cursor + range.duration
    }
    try? FileManager.default.removeItem(at: output)
    guard let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough) else { exit(3) }
    try await export.export(to: output, as: .mov)

    let out = AVURLAsset(url: output)
    let total = CMTimeGetSeconds(try await out.load(.duration))
    let size = try await out.loadTracks(withMediaType: .video).first?.load(.naturalSize) ?? .zero
    print(String(format: "导出 %.2fs · %dx%d -> %@", total, Int(size.width), Int(size.height), output.lastPathComponent))

    if let dir = framesDir {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let gen = AVAssetImageGenerator(asset: out)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 300, height: 700)
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        var t = 0.0
        while t < total {
            let (cg, _) = try await gen.image(at: CMTime(seconds: t, preferredTimescale: 600))
            let url = dir.appendingPathComponent(String(format: "f%05.1f.png", t))
            if let d = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImage(d, cg, nil)
                CGImageDestinationFinalize(d)
            }
            t += 1.5
        }
        print("抽帧 -> \(dir.path)")
    }
    done.signal()
}
done.wait()
