// Draws the Cambio app icon and writes an .icns.
// Usage: swift scripts/make-icon.swift Resources/AppIcon.icns [preview.png]
//
// A green squircle on the macOS icon grid (824 px body on a 1024 px canvas) with a
// rising white sparkline that echoes the chart in the panel. Pure CoreGraphics: no
// SF Symbols or Apple fonts, so the artwork is free to ship under the MIT license.
import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <out.icns> [preview.png]\n".utf8))
    exit(2)
}
let outputURL = URL(fileURLWithPath: arguments[1])
let previewURL = arguments.count >= 3 ? URL(fileURLWithPath: arguments[2]) : nil

let canvas: CGFloat = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [r / 255, g / 255, b / 255, a])!
}

/// A superellipse (n = 5) approximates Apple's continuous-corner squircle.
func squircle(in rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let n: CGFloat = 5
    let a = rect.width / 2, b = rect.height / 2
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = rect.midX + a * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
        let y = rect.midY + b * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

/// Catmull-Rom through the points, as cubic Béziers.
func smoothLine(through points: [CGPoint]) -> CGMutablePath {
    let path = CGMutablePath()
    path.move(to: points[0])
    for i in 0..<(points.count - 1) {
        let p0 = points[max(i - 1, 0)], p1 = points[i], p2 = points[i + 1], p3 = points[min(i + 2, points.count - 1)]
        let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
        let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        path.addCurve(to: p2, control1: c1, control2: c2)
    }
    return path
}

func drawIcon() -> CGImage {
    let context = CGContext(
        data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = squircle(in: body)

    // Soft drop shadow under the body, as in the macOS icon template.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.32))
    context.addPath(shape)
    context.setFillColor(color(20, 120, 96))
    context.fillPath()
    context.restoreGState()

    // Body gradient: fresh green at the top to deep teal at the bottom.
    context.saveGState()
    context.addPath(shape)
    context.clip()
    let fill = CGGradient(colorsSpace: colorSpace, colors: [color(58, 214, 140), color(11, 104, 92)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(fill, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // Light catching the top edge.
    let sheen = CGGradient(colorsSpace: colorSpace, colors: [color(255, 255, 255, 0.20), color(255, 255, 255, 0)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])

    // The sparkline, rising left to right.
    let points: [CGPoint] = [
        CGPoint(x: 236, y: 418), CGPoint(x: 318, y: 462), CGPoint(x: 392, y: 440),
        CGPoint(x: 472, y: 534), CGPoint(x: 548, y: 512), CGPoint(x: 628, y: 604),
        CGPoint(x: 702, y: 628), CGPoint(x: 788, y: 700),
    ]
    let line = smoothLine(through: points)

    // Area under the line, fading down like the panel chart.
    let area = line.mutableCopy()!
    area.addLine(to: CGPoint(x: points.last!.x, y: 236))
    area.addLine(to: CGPoint(x: points.first!.x, y: 236))
    area.closeSubpath()
    context.saveGState()
    context.addPath(area)
    context.clip()
    let areaFill = CGGradient(colorsSpace: colorSpace, colors: [color(255, 255, 255, 0.26), color(255, 255, 255, 0)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(areaFill, start: CGPoint(x: 512, y: 700), end: CGPoint(x: 512, y: 400), options: [])
    context.restoreGState()

    context.addPath(line)
    context.setStrokeColor(color(255, 255, 255))
    context.setLineWidth(46)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()

    // The latest value: a dot with a soft glow.
    let end = points.last!
    context.setShadow(offset: .zero, blur: 30, color: color(255, 255, 255, 0.75))
    context.setFillColor(color(255, 255, 255))
    context.fillEllipse(in: CGRect(x: end.x - 40, y: end.y - 40, width: 80, height: 80))
    context.restoreGState()

    return context.makeImage()!
}

func png(_ image: CGImage, size: Int) -> Data {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

let master = drawIcon()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(master, size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(master, size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
if let previewURL {
    try png(master, size: 1024).write(to: previewURL)
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { exit(iconutil.terminationStatus) }
print("wrote \(outputURL.path)")
