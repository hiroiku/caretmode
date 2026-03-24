#!/usr/bin/env swift

import AppKit
import CoreGraphics
import UniformTypeIdentifiers

// MARK: - Configuration

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let projectDir = scriptDir.deletingLastPathComponent()
let appIconDir = projectDir
    .appendingPathComponent("CaretMode/Resources/Assets.xcassets/AppIcon.appiconset")
let menuBarIconDir = projectDir
    .appendingPathComponent("CaretMode/Resources/Assets.xcassets/MenuBarIcon.imageset")

let appIconSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16@1x", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32@1x", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128@1x", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256@1x", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512@1x", 512),
    ("icon_512x512@2x", 1024),
]

let menuBarIconSizes: [(name: String, pixels: Int)] = [
    ("menubar_icon@1x", 18),
    ("menubar_icon@2x", 36),
    ("menubar_icon@3x", 54),
]

// MARK: - PNG Export

func exportPNG(name: String, pixels: Int, outputDir: URL, draw: (CGFloat, CGContext) -> Void) {
    let s = CGFloat(pixels)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("Failed to create context for \(name)")
        return
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    draw(s, ctx)

    guard let image = ctx.makeImage() else {
        print("Failed to create image for \(name)")
        return
    }

    let url = outputDir.appendingPathComponent("\(name).png")
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("Failed to create destination for \(name)")
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Generated: \(name).png (\(pixels)x\(pixels))")
}

// MARK: - Menu Bar Icon Drawing

func drawMenuBarIcon(s: CGFloat, ctx: CGContext) {
    let margin = s * 0.1
    let rect = CGRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let cornerRadius = s * 0.20
    let lineWidth = s * 0.07

    // Rounded rectangle outline
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.setLineWidth(lineWidth)
    ctx.addPath(path)
    ctx.strokePath()

    // "A" + block caret centered
    let fontSize = rect.height * 0.55
    let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.black,
    ]
    let str = NSAttributedString(string: "A", attributes: attrs)
    let line = CTLineCreateWithAttributedString(str)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

    let caretGap = fontSize * 0.05
    let caretWidth = fontSize * 0.45
    let totalWidth = bounds.width + caretGap + caretWidth

    let textX = rect.midX - totalWidth / 2 - bounds.origin.x
    let textY = rect.midY - bounds.height / 2 - bounds.origin.y

    ctx.saveGState()
    ctx.textPosition = CGPoint(x: textX, y: textY)
    CTLineDraw(line, ctx)
    ctx.restoreGState()

    // Block caret
    let caretX = textX + bounds.origin.x + bounds.width + caretGap
    let caretY = textY + bounds.origin.y
    let caretRect = CGRect(x: caretX, y: caretY, width: caretWidth, height: bounds.height)
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fill(caretRect)
}

// MARK: - App Icon Drawing

func drawAppIcon(s: CGFloat, ctx: CGContext) {
    let cornerRadius = s * 0.22
    let fullRect = CGRect(x: 0, y: 0, width: s, height: s)

    // Layer 1: Background gradient (blue to cyan)
    let bgPath = CGPath(roundedRect: fullRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.06, green: 0.20, blue: 0.50, alpha: 1.0),  // Deep blue (bottom)
        CGColor(red: 0.08, green: 0.35, blue: 0.65, alpha: 1.0),  // Mid blue
        CGColor(red: 0.10, green: 0.50, blue: 0.78, alpha: 1.0),  // Cyan-blue (top)
    ] as CFArray
    let gradientLocations: [CGFloat] = [0.0, 0.5, 1.0]

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: s / 2, y: 0),
            end: CGPoint(x: s / 2, y: s),
            options: []
        )
    }
    ctx.restoreGState()

    // Layer 2: Subtle outer highlight at top edge
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let outerHighlightColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.15),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    if let highlight = CGGradient(colorsSpace: colorSpace, colors: outerHighlightColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            highlight,
            start: CGPoint(x: s / 2, y: s),
            end: CGPoint(x: s / 2, y: s * 0.6),
            options: []
        )
    }
    ctx.restoreGState()

    // Layer 3: Inner glass panel
    let inset = s * 0.12
    let innerRect = fullRect.insetBy(dx: inset, dy: inset)
    let innerCornerRadius = s * 0.16
    let innerPath = CGPath(roundedRect: innerRect, cornerWidth: innerCornerRadius, cornerHeight: innerCornerRadius, transform: nil)

    // Glass panel base fill
    ctx.saveGState()
    ctx.addPath(innerPath)
    ctx.clip()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    ctx.fill(innerRect)

    // Glass panel top highlight gradient
    let glassHighlightColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.30),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.05),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    let glassLocations: [CGFloat] = [0.0, 0.4, 1.0]
    if let glassGradient = CGGradient(colorsSpace: colorSpace, colors: glassHighlightColors, locations: glassLocations) {
        ctx.drawLinearGradient(
            glassGradient,
            start: CGPoint(x: innerRect.midX, y: innerRect.maxY),
            end: CGPoint(x: innerRect.midX, y: innerRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Glass panel inner border
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.20))
    ctx.setLineWidth(s * 0.006)
    ctx.addPath(innerPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Layer 4: "A" + block caret with drop shadow
    let fontSize = innerRect.height * 0.55
    let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let str = NSAttributedString(string: "A", attributes: attrs)
    let line = CTLineCreateWithAttributedString(str)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

    let caretGap = fontSize * 0.05
    let caretWidth = fontSize * 0.45
    let totalWidth = bounds.width + caretGap + caretWidth

    let textX = innerRect.midX - totalWidth / 2 - bounds.origin.x
    let textY = innerRect.midY - bounds.height / 2 - bounds.origin.y + s * 0.01

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.015),
        blur: s * 0.025,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.4)
    )
    ctx.textPosition = CGPoint(x: textX, y: textY)
    CTLineDraw(line, ctx)

    // Block caret (glass effect)
    let caretX = textX + bounds.origin.x + bounds.width + caretGap
    let caretY = textY + bounds.origin.y
    let caretRect = CGRect(x: caretX, y: caretY, width: caretWidth, height: bounds.height)
    ctx.restoreGState()

    // Caret base fill (semi-transparent white)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
    ctx.fill(caretRect)

    // Caret top highlight gradient
    let caretHighlightColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.45),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.10),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    let caretGradientLocations: [CGFloat] = [0.0, 0.4, 1.0]
    ctx.clip(to: caretRect)
    if let caretGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: caretHighlightColors, locations: caretGradientLocations) {
        ctx.drawLinearGradient(
            caretGradient,
            start: CGPoint(x: caretRect.midX, y: caretRect.maxY),
            end: CGPoint(x: caretRect.midX, y: caretRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Caret border
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
    ctx.setLineWidth(s * 0.004)
    ctx.stroke(caretRect)
    ctx.restoreGState()
}

// MARK: - Main

print("Generating app icons...")
for entry in appIconSizes {
    exportPNG(name: entry.name, pixels: entry.pixels, outputDir: appIconDir) { s, ctx in
        drawAppIcon(s: s, ctx: ctx)
    }
}

print("\nGenerating menu bar icons...")
for entry in menuBarIconSizes {
    exportPNG(name: entry.name, pixels: entry.pixels, outputDir: menuBarIconDir) { s, ctx in
        drawMenuBarIcon(s: s, ctx: ctx)
    }
}

print("\nDone! All icons generated.")
