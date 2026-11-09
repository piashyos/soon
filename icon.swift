// Draws AppIcon.icns: `swift icon.swift` (needs iconutil, ships with macOS).
import AppKit

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: srgb, components: [r, g, b, a])! }
func gradient(_ colors: [CGColor]) -> CGGradient { CGGradient(colorsSpace: srgb, colors: colors as CFArray, locations: nil)! }

func pill(_ ctx: CGContext, _ r: CGRect, _ color: CGColor, shadow: CGFloat = 0) {
    ctx.saveGState()
    if shadow > 0 { ctx.setShadow(offset: CGSize(width: 0, height: -shadow / 3), blur: shadow, color: rgb(0.05, 0.1, 0.35, 0.35)) }
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: r.height / 2, cornerHeight: r.height / 2, transform: nil))
    ctx.setFillColor(color)
    ctx.fillPath()
    ctx.restoreGState()
}

/// 1024×1024 canvas, macOS icon grid: 824pt body with 100pt margins.
func draw(_ ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // drop shadow under the tile
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: rgb(0, 0, 0, 0.28))
    ctx.addPath(shape)
    ctx.setFillColor(rgb(0.2, 0.4, 0.95))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    // background: bright blue to deep indigo
    ctx.drawLinearGradient(gradient([rgb(0.36, 0.64, 1.0), rgb(0.17, 0.33, 0.92), rgb(0.20, 0.18, 0.72)]),
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // soft glass highlight on the upper half
    ctx.drawLinearGradient(gradient([rgb(1, 1, 1, 0.22), rgb(1, 1, 1, 0)]),
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])

    // upcoming events: the next one solid, later ones fading
    pill(ctx, CGRect(x: 292, y: 277, width: 440, height: 96), rgb(1, 1, 1, 0.28))
    pill(ctx, CGRect(x: 252, y: 413, width: 520, height: 120), rgb(1, 1, 1, 0.5))
    let next = CGRect(x: 212, y: 577, width: 600, height: 170)
    pill(ctx, next, rgb(1, 1, 1), shadow: 40)
    // the colored event bar from the menu bar item
    ctx.saveGState()
    let accent = CGRect(x: next.minX + 56, y: next.midY - 52, width: 32, height: 104)
    ctx.addPath(CGPath(roundedRect: accent, cornerWidth: 16, cornerHeight: 16, transform: nil))
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(1.0, 0.62, 0.25), rgb(1.0, 0.36, 0.30)]),
                           start: CGPoint(x: 0, y: accent.maxY), end: CGPoint(x: 0, y: accent.minY), options: [])
    ctx.restoreGState()
    // title placeholder
    pill(ctx, CGRect(x: accent.maxX + 40, y: next.midY - 18, width: 330, height: 36), rgb(0.80, 0.85, 0.95))
    ctx.restoreGState()
}

func png(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: dir)
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for pt in [16, 32, 128, 256, 512] {
    try png(pt).write(to: dir.appendingPathComponent("icon_\(pt)x\(pt).png"))
    try png(pt * 2).write(to: dir.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", dir.path, "-o", "AppIcon.icns"]
try p.run()
p.waitUntilExit()
if let preview = CommandLine.arguments.dropFirst().first { try png(1024).write(to: URL(fileURLWithPath: preview)) }
print(p.terminationStatus == 0 ? "AppIcon.icns written" : "iconutil failed")
