import AppKit
import Foundation

// SVG -> 透明底 PNG。macOS 的 NSImage 原生认 SVG,所以不用装 rsvg/inkscape。
// 产物当 template image 用,iOS 侧只取 alpha 通道,源色是黑是白都无所谓。
// 用法: render_svg <输入目录> <输出目录> <目标高度px>
let args = CommandLine.arguments
guard args.count >= 4, let targetH = Double(args[3]) else {
    print("usage: render_svg <in_dir> <out_dir> <height_px>")
    exit(2)
}
let inDir = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let files = (try? FileManager.default.contentsOfDirectory(at: inDir, includingPropertiesForKeys: nil))?
    .filter { $0.pathExtension.lowercased() == "svg" }.sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []

var ok = 0, failed: [String] = []
for url in files {
    guard let img = NSImage(contentsOf: url), img.size.height > 0 else {
        failed.append(url.lastPathComponent); continue
    }
    let scale = targetH / img.size.height
    let w = Int((img.size.width * scale).rounded()), h = Int(targetH.rounded())
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
        failed.append(url.lastPathComponent); continue
    }
    rep.size = NSSize(width: w, height: h)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    img.draw(in: NSRect(x: 0, y: 0, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [.interlaced: false]) else {
        failed.append(url.lastPathComponent); continue
    }
    try png.write(to: outDir.appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".png"))
    ok += 1
}
print("渲染成功 \(ok) / \(files.count)")
if !failed.isEmpty { print("失败: \(failed.prefix(10).joined(separator: ", "))") }
