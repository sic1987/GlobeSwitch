// Renders the app icon (a white SF "globe" on a blue rounded square) into an .iconset folder.
// Usage: swift Tools/make_icon.swift <out.iconset>
import Cocoa

let outDir = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func bitmap(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    return rep
}

func draw(into rep: NSBitmapImageRep, _ body: (CGFloat) -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    body(CGFloat(rep.pixelsWide))
    ctx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
}

/// The glyph as a white shape on transparent background.
func glyph(_ px: Int) -> NSImage {
    let rep = bitmap(px)
    draw(into: rep) { s in
        let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.56, weight: .medium)
        guard let sym = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg) else { return }
        let r = NSRect(x: (s - sym.size.width) / 2, y: (s - sym.size.height) / 2,
                       width: sym.size.width, height: sym.size.height)
        sym.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        NSRect(x: 0, y: 0, width: s, height: s).fill(using: .sourceIn)
    }
    let img = NSImage(size: rep.size)
    img.addRepresentation(rep)
    return img
}

func icon(_ px: Int) -> Data {
    let rep = bitmap(px)
    draw(into: rep) { s in
        let r = NSRect(x: 0, y: 0, width: s, height: s).insetBy(dx: s * 0.09, dy: s * 0.09)
        let path = NSBezierPath(roundedRect: r, xRadius: r.width * 0.225, yRadius: r.width * 0.225)
        NSGradient(starting: NSColor(calibratedRed: 0.30, green: 0.62, blue: 1.00, alpha: 1),
                   ending: NSColor(calibratedRed: 0.08, green: 0.28, blue: 0.80, alpha: 1))!
            .draw(in: path, angle: -90)
        glyph(px).draw(in: NSRect(x: 0, y: 0, width: s, height: s), from: .zero, operation: .sourceOver, fraction: 1)
    }
    return rep.representation(using: .png, properties: [:])!
}

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in entries {
    try icon(px).write(to: URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png"))
}
print("iconset: \(outDir)")
