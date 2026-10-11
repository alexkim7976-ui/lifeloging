import AppKit

guard CommandLine.arguments.count >= 4 else {
    fputs("Usage: export_appicon.swift <input.svg> <output.png> <pixelSize>\n", stderr)
    exit(1)
}

let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
let size = CGFloat(Int(CommandLine.arguments[3]) ?? 1024)

guard let image = NSImage(contentsOfFile: input) else {
    fputs("Failed to load SVG: \(input)\n", stderr)
    exit(1)
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(
    in: NSRect(x: 0, y: 0, width: size, height: size),
    from: NSRect(origin: .zero, size: image.size),
    operation: .copy,
    fraction: 1
)
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: output))
} catch {
    fputs("Failed to write PNG: \(error)\n", stderr)
    exit(1)
}
