// Draws the WindowFrames app icon into an .iconset folder.
// Usage: swift scripts/make-icon.swift <output.iconset> [preview.png]
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Draws on a 1024-point canvas (origin bottom-left), scaled to `pixels`.
func render(_ pixels: Int) -> CGImage {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    ctx.interpolationQuality = .high

    // Body on Apple's macOS icon grid: 824 pt square, 100 pt margin.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = rounded(body, 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.30))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0x312E81))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let background = CGGradient(
        colorsSpace: space,
        colors: [color(0x38BDF8), color(0x4F46E5), color(0x6D28D9)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    ctx.drawLinearGradient(background, start: CGPoint(x: 140, y: 924), end: CGPoint(x: 884, y: 100), options: [])
    let sheen = CGGradient(
        colorsSpace: space,
        colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])
    ctx.restoreGState()

    // Monitor stand.
    ctx.setFillColor(color(0xFFFFFF, 0.92))
    ctx.addPath(rounded(CGRect(x: 476, y: 250, width: 72, height: 80), 10))
    ctx.fillPath()
    ctx.addPath(rounded(CGRect(x: 380, y: 224, width: 264, height: 40), 20))
    ctx.fillPath()

    // Screen.
    let screen = CGRect(x: 204, y: 312, width: 616, height: 476)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x1E1B4B, 0.45))
    ctx.addPath(rounded(screen, 54))
    ctx.setFillColor(color(0x1E1B4B, 0.55))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(rounded(screen.insetBy(dx: 11, dy: 11), 44))
    ctx.setStrokeColor(color(0xFFFFFF, 0.95))
    ctx.setLineWidth(22)
    ctx.strokePath()

    // Window frames: one tall pane, two stacked panes.
    let inner = screen.insetBy(dx: 52, dy: 52)
    let gap: CGFloat = 26
    let half = (inner.width - gap) / 2
    let stack = (inner.height - gap) / 2
    let panes: [(CGRect, CGFloat)] = [
        (CGRect(x: inner.minX, y: inner.minY, width: half, height: inner.height), 1.0),
        (CGRect(x: inner.minX + half + gap, y: inner.minY + stack + gap, width: half, height: stack), 0.85),
        (CGRect(x: inner.minX + half + gap, y: inner.minY, width: half, height: stack), 0.62),
    ]
    for (rect, alpha) in panes {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x1E1B4B, 0.35))
        ctx.addPath(rounded(rect, 22))
        ctx.setFillColor(color(0xFFFFFF, alpha))
        ctx.fillPath()
        ctx.restoreGState()
    }
    // Title bar dots on the big pane.
    for (i, hex) in [0xF87171, 0xFBBF24, 0x34D399].enumerated() {
        let dot = CGRect(x: inner.minX + 26 + CGFloat(i) * 34, y: inner.maxY - 46, width: 20, height: 20)
        ctx.setFillColor(color(UInt32(hex)))
        ctx.fillEllipse(in: dot)
    }

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("Couldn't write \(url.path)") }
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: swift scripts/make-icon.swift <output.iconset> [preview.png]")
    exit(2)
}
let iconset = URL(fileURLWithPath: args[1], isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    writePNG(render(points), to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    writePNG(render(points * 2), to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
if args.count >= 3 {
    writePNG(render(512), to: URL(fileURLWithPath: args[2]))
}
print("Wrote \(iconset.path)")
