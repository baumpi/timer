#!/usr/bin/env swift
import AppKit
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count >= 2 else {
    print("usage: make-icon.swift <output-dir> [font-path]"); exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let fontPath = (CommandLine.arguments.count >= 3) ? CommandLine.arguments[2] : ""
if !fontPath.isEmpty {
    var err: Unmanaged<CFError>?
    let url = URL(fileURLWithPath: fontPath) as CFURL
    CTFontManagerRegisterFontsForURL(url, .process, &err)
}

func render(size: Int) -> Data? {
    let s = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // BG rounded square
    ctx.setFillColor(CGColor(srgbRed: 0x1F/255, green: 0x1E/255, blue: 0x1C/255, alpha: 1))
    let radius = s * 0.22
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                        cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(bgPath); ctx.fillPath()

    // Accent dot top-right
    let dotR = s * 0.06
    ctx.setFillColor(CGColor(srgbRed: 0xC4/255, green: 0x1E/255, blue: 0x3A/255, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: s - dotR*2 - s*0.12,
                               y: s - dotR*2 - s*0.12,
                               width: dotR*2, height: dotR*2))

    // "00:00" centered, primary text color
    let fontSize = s * 0.28
    let cgFontName = "JetBrainsMono-Bold" as CFString
    let ctFont = CTFontCreateWithName(cgFontName, fontSize, nil)
    let fg = CGColor(srgbRed: 0xFA/255, green: 0xFA/255, blue: 0xF7/255, alpha: 1)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: ctFont,
        kCTForegroundColorAttributeName: fg,
        kCTKernAttributeName: -fontSize * 0.04
    ]
    let attr = NSAttributedString(string: "00:00", attributes: attrs as [NSAttributedString.Key: Any])
    let line = CTLineCreateWithAttributedString(attr as CFAttributedString)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    let tx = (s - bounds.width) / 2 - bounds.origin.x
    let ty = (s - bounds.height) / 2 - bounds.origin.y
    ctx.textPosition = CGPoint(x: tx, y: ty)
    CTLineDraw(line, ctx)

    // Bottom accent stroke
    ctx.setFillColor(CGColor(srgbRed: 0xC4/255, green: 0x1E/255, blue: 0x3A/255, alpha: 1))
    let stroke = CGPath(roundedRect: CGRect(x: s*0.30, y: s*0.16, width: s*0.40, height: s*0.025),
                        cornerWidth: s*0.012, cornerHeight: s*0.012, transform: nil)
    ctx.addPath(stroke); ctx.fillPath()

    guard let img = ctx.makeImage() else { return nil }
    let mutableData = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(dest, img, nil)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return mutableData as Data
}

let sizes: [(Int, String)] = [
    (16,  "icon_16x16.png"),
    (32,  "icon_16x16@2x.png"),
    (32,  "icon_32x32.png"),
    (64,  "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024,"icon_512x512@2x.png"),
]
var ok = 0
for (size, name) in sizes {
    if let data = render(size: size) {
        try data.write(to: outDir.appendingPathComponent(name))
        ok += 1
    } else {
        print("failed: \(name)")
    }
}
print("wrote \(ok)/\(sizes.count) PNGs to \(outDir.path)")
